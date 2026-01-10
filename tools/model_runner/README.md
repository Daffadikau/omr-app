# OMR Grading System - Model Runner

Model runner untuk memproses scan LJK dengan YOLOv11 dan mengirim hasilnya ke Firebase.

## Setup (Di Laptop Teman)

### 1. Prerequisites

- Python 3.9 atau lebih baru
- Model YOLOv11 weights (`.pt` file)
- Firebase service account key (JSON)

### 2. Install Dependencies

```bash
cd tools/model_runner

# Buat virtual environment
python3 -m venv venv

# Activate venv
source venv/bin/activate  # Linux/Mac
# atau
venv\Scripts\activate  # Windows

# Install requirements
pip install -r requirements.txt
```

### 3. Konfigurasi

Copy `.env.example` ke file baru dan isi dengan nilai yang benar:

```bash
cp .env.example .env
nano .env
```

Edit file `.env`:

```bash
# Path ke service account key dari Firebase Console
GOOGLE_APPLICATION_CREDENTIALS=/Users/teman/Downloads/serviceAccountKey.json

# Firebase Storage bucket (dari Firebase Console)
FIREBASE_STORAGE_BUCKET=your-project.appspot.com

# Path ke model YOLO weights
MODEL_PATH=/Users/teman/models/LJKYolo11m.pt

# Working directory (optional)
WORKDIR=/tmp/omr_runner
```

### 4. Download Service Account Key

1. Buka [Firebase Console](https://console.firebase.google.com)
2. Pilih project kamu
3. Settings > Service Accounts
4. Klik "Generate New Private Key"
5. Simpan file JSON ke lokasi aman
6. Update path di `GOOGLE_APPLICATION_CREDENTIALS`

### 5. Cek Firebase Storage Bucket

Di Firebase Console > Storage, lihat bucket name di bagian atas (biasanya `project-id.appspot.com` atau `project-id.firebasestorage.app`).

## Menjalankan Runner

```bash
# Activate venv
source venv/bin/activate

# Set environment variables
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
export FIREBASE_STORAGE_BUCKET="your-project.appspot.com"
export MODEL_PATH="/path/to/LJKYolo11m.pt"

# Run
python runner.py
```

Atau gunakan file `.env`:

```bash
# Install python-dotenv
pip install python-dotenv

# Buat wrapper script
cat > run.sh << 'EOF'
#!/bin/bash
source venv/bin/activate
export $(cat .env | xargs)
python runner.py
EOF

chmod +x run.sh
./run.sh
```

## Output

Saat berjalan, runner akan:

```
============================================================
OMR Model Runner Started
============================================================
Workdir: /tmp/omr_runner
Poll interval: 3s
Listening for new scans with status='processing'...

[INFO] Processing scan abc123xyz
[INFO] Downloading image from https://...
[INFO] Image saved to /tmp/omr_runner/input/abc123xyz.jpg
[INFO] Running YOLO inference...
[INFO] Extracting answers...
[INFO] Annotated image saved to /tmp/omr_runner/output/abc123xyz_annotated.jpg
[INFO] Updating Firestore...
[INFO] ✓ Scan abc123xyz processed successfully
```

## Implementasi Extract Answers

**PENTING**: File `runner.py` memiliki fungsi `extract_answers_from_results()` yang harus kamu sesuaikan dengan output model YOLO kamu.

### Contoh Output Model

Model harus mendeteksi 100 nomor soal dengan jawaban A-E yang dipilih. Ada beberapa cara:

#### Option 1: Single Class per Answer

Model mendeteksi class seperti `1_A`, `2_B`, `3_C`, dst.

```python
def extract_answers_from_results(self, results) -> Dict[str, str]:
    answers = {}
    
    for result in results:
        for box in result.boxes:
            cls_id = int(box.cls[0])
            class_name = result.names[cls_id]  # e.g., "1_A"
            
            if '_' in class_name:
                number, answer = class_name.split('_')
                answers[number] = answer
    
    return answers
```

#### Option 2: Separate Detection

Model mendeteksi:
- Posisi nomor (1-100)
- Bubbles yang diisi (A-E)

```python
def extract_answers_from_results(self, results) -> Dict[str, str]:
    # Cluster detections berdasarkan posisi Y (baris)
    # Group berdasarkan nomor soal
    # Identifikasi bubble mana yang diisi
    # Return mapping nomor -> jawaban
    pass
```

### Testing

Untuk testing awal, runner menggunakan dummy data (semua jawaban A). Cek log:

```
[WARNING] Using DUMMY answers - implement extract_answers_from_results!
```

Setelah implementasi, hapus kode dummy dan test dengan scan real.

## Troubleshooting

### Error: "GOOGLE_APPLICATION_CREDENTIALS not set"

Pastikan environment variable sudah diset:

```bash
echo $GOOGLE_APPLICATION_CREDENTIALS
```

### Error: "Permission denied" saat akses Storage

Cek Firebase Storage Rules. Untuk development, bisa pakai:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Model tidak deteksi jawaban

1. Cek confidence threshold di `runner.py` (default 0.25)
2. Pastikan gambar LJK terlihat jelas
3. Test model dengan `yolo predict model.pt source=image.jpg`

### Runner tidak pickup scan baru

1. Cek koneksi internet
2. Pastikan Firestore Rules allow read/write
3. Cek log untuk error

## Production Tips

1. **Auto-restart**: Gunakan supervisor/systemd untuk auto-restart
2. **Monitoring**: Add logging ke file atau monitoring service
3. **Scaling**: Jalankan multiple runner dengan ID berbeda
4. **GPU**: Install PyTorch dengan GPU support untuk inference lebih cepat

## Architecture

```
User (App) → Firebase Storage (upload LJK)
               ↓
           Firestore (status: processing)
               ↓
           Model Runner (listen)
               ↓
           YOLO Detection
               ↓
           Firestore (status: completed, results)
               ↓
           User (App) - lihat hasil real-time
```

## Support

Jika ada pertanyaan atau issue dengan model runner, check:
1. Log output di terminal
2. Firestore console untuk status dokumen
3. Firebase Storage untuk file upload
