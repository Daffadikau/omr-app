"""
OMR Model Runner - Listens to Firebase and processes LJK scans with YOLOv11
"""
import os
import time
import logging
from pathlib import Path
from typing import Dict, Optional

import requests
from PIL import Image

import firebase_admin
from firebase_admin import credentials, firestore, storage
from ultralytics import YOLO


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
)
logger = logging.getLogger(__name__)


class ModelRunner:
    def __init__(
        self,
        credentials_path: str,
        storage_bucket: str,
        model_path: str,
        workdir: str = '/tmp/omr_runner',
    ):
        """
        Initialize the model runner

        Args:
            credentials_path: Path to Firebase service account JSON
            storage_bucket: Firebase Storage bucket name
            model_path: Path to YOLOv11 model weights (.pt file)
            workdir: Working directory for temp files
        """
        self.workdir = Path(workdir)
        self.workdir.mkdir(parents=True, exist_ok=True)

        # Initialize Firebase
        cred = credentials.Certificate(credentials_path)
        firebase_admin.initialize_app(cred, {
            'storageBucket': storage_bucket
        })

        self.db = firestore.client()
        self.bucket = storage.bucket()

        # Load YOLO model
        logger.info(f"Loading YOLO model from {model_path}")
        self.model = YOLO(model_path)
        logger.info("Model loaded successfully")

    def download_image(self, image_url: str, dest_path: Path) -> None:
        """Download image from URL"""
        logger.info(f"Downloading image from {image_url}")
        response = requests.get(image_url, timeout=60)
        response.raise_for_status()

        dest_path.parent.mkdir(parents=True, exist_ok=True)
        with open(dest_path, 'wb') as f:
            f.write(response.content)

        logger.info(f"Image saved to {dest_path}")

    def extract_answers_from_results(self, results) -> Dict[str, str]:
        """
        Extract answers from YOLO detection results

        PENTING: Implementasi ini harus disesuaikan dengan output model YOLO kamu!

        Model harus mendeteksi:
        - 100 nomor soal (1-100)
        - Pilihan jawaban (A, B, C, D, E) yang dipilih untuk tiap nomor

        Returns:
            Dict mapping nomor soal (string) ke jawaban (A-E)
            Contoh: {"1": "A", "2": "B", "3": "C", ...}
        """
        answers = {}

        # TODO: Implement sesuai output model kamu
        # Contoh skeleton untuk parsing results:

        for result in results:
            boxes = result.boxes

            for box in boxes:
                # Get class name and confidence
                cls_id = int(box.cls[0])
                conf = float(box.conf[0])

                # Get box coordinates
                x1, y1, x2, y2 = box.xyxy[0].tolist()

                # TODO: Parse class_id menjadi nomor soal dan jawaban
                # Misalnya jika model mendeteksi "1_A" untuk nomor 1 jawaban A:
                # class_name = result.names[cls_id]  # e.g., "1_A"
                # number, answer = class_name.split('_')
                # answers[number] = answer

                # Atau jika model terpisah untuk nomor dan jawaban:
                # - Cluster berdasarkan posisi Y (baris soal)
                # - Identifikasi kolom A-E berdasarkan posisi X
                # - Map ke nomor soal 1-100

                pass

        # TEMPORARY: Fill dengan dummy data untuk testing
        # HAPUS INI setelah implementasi real!
        logger.warning(
            "Using DUMMY answers - implement extract_answers_from_results!")
        for i in range(1, 101):
            answers[str(i)] = 'A'  # Semua dijawab A

        return answers

    def process_scan(self, doc_id: str, data: Dict) -> None:
        """Process a single exam scan"""
        logger.info(f"Processing scan {doc_id}")

        try:
            # 1. Download image
            image_url = data.get('image_url')
            if not image_url:
                raise ValueError("Missing image_url")

            input_path = self.workdir / 'input' / f'{doc_id}.jpg'
            self.download_image(image_url, input_path)

            # 2. Run YOLO inference
            logger.info("Running YOLO inference...")
            results = self.model.predict(
                str(input_path),
                conf=0.25,  # Confidence threshold
                verbose=False,
            )

            # 3. Extract answers
            logger.info("Extracting answers...")
            answers = self.extract_answers_from_results(results)

            if len(answers) == 0:
                raise ValueError("No answers detected from image")

            # 4. Save annotated image (optional) and upload to Storage
            output_path = self.workdir / 'output' / f'{doc_id}_annotated.jpg'
            output_path.parent.mkdir(parents=True, exist_ok=True)

            if results and len(results) > 0:
                annotated = results[0].plot()
                Image.fromarray(annotated).save(output_path)
                logger.info(f"Annotated image saved to {output_path}")

                # Upload annotated image to Firebase Storage
                blob_path = f"annotated/exam_scans/{doc_id}_annotated.jpg"
                blob = self.bucket.blob(blob_path)
                blob.cache_control = "public, max-age=3600"
                blob.upload_from_filename(
                    str(output_path), content_type='image/jpeg')
                logger.info(
                    f"Uploaded annotated image to gs://{self.bucket.name}/{blob_path}")

                # Update Firestore with annotated path for client retrieval
                try:
                    self.db.collection('exam_scans').document(doc_id).update({
                        'annotated_path': blob_path,
                    })
                except Exception as e:
                    logger.warning(
                        f"Failed to update annotated_path for {doc_id}: {e}")

            # 5. Update Firestore
            logger.info("Updating Firestore...")
            self.db.collection('exam_scans').document(doc_id).update({
                'results': answers,
                'status': 'completed',
                'processed_at': firestore.SERVER_TIMESTAMP,
            })

            logger.info(f"✓ Scan {doc_id} processed successfully")

        except Exception as e:
            logger.error(f"✗ Failed to process scan {doc_id}: {e}")

            # Update Firestore with error
            self.db.collection('exam_scans').document(doc_id).update({
                'status': 'failed',
                'error_message': str(e),
                'processed_at': firestore.SERVER_TIMESTAMP,
            })

    def run(self, poll_interval: int = 3) -> None:
        """
        Main loop - listen for processing requests

        Args:
            poll_interval: Seconds between polls
        """
        logger.info("=" * 60)
        logger.info("OMR Model Runner Started")
        logger.info("=" * 60)
        logger.info(f"Workdir: {self.workdir}")
        logger.info(f"Poll interval: {poll_interval}s")
        logger.info("Listening for new scans with status='processing'...")
        logger.info("")

        # Watch for documents with status='processing'
        query = self.db.collection('exam_scans').where(
            'status', '==', 'processing')

        def on_snapshot(col_snapshot, changes, read_time):
            for change in changes:
                if change.type.name in ['ADDED', 'MODIFIED']:
                    doc = change.document
                    data = doc.to_dict()

                    # Skip if already processed or being processed
                    if data.get('status') != 'processing':
                        continue

                    # Process in background (or could use threading)
                    self.process_scan(doc.id, data)

        # Start watching
        watch = query.on_snapshot(on_snapshot)

        try:
            # Keep running
            while True:
                time.sleep(poll_interval)
        except KeyboardInterrupt:
            logger.info("")
            logger.info("Stopping runner (KeyboardInterrupt)...")
            watch.unsubscribe()
            logger.info("Runner stopped")


def main():
    # Load config from environment variables
    credentials_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
    storage_bucket = os.environ.get('FIREBASE_STORAGE_BUCKET')
    model_path = os.environ.get('MODEL_PATH')
    workdir = os.environ.get('WORKDIR', '/tmp/omr_runner')

    if not credentials_path:
        raise ValueError("GOOGLE_APPLICATION_CREDENTIALS not set")
    if not storage_bucket:
        raise ValueError("FIREBASE_STORAGE_BUCKET not set")
    if not model_path:
        raise ValueError("MODEL_PATH not set")

    # Create and run runner
    runner = ModelRunner(
        credentials_path=credentials_path,
        storage_bucket=storage_bucket,
        model_path=model_path,
        workdir=workdir,
    )

    runner.run()


if __name__ == '__main__':
    main()
