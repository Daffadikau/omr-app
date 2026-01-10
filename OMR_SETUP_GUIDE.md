# OMR Grading System

Sistem grading LJK (Lembar Jawaban Komputer) berbasis Firebase dengan model YOLOv11 untuk deteksi jawaban otomatis.

## Fitur

✅ **Input Kunci Jawaban** - Buat kunci jawaban 1-100 soal (A-E)  
✅ **Upload LJK** - Scan LJK via kamera atau galeri  
✅ **Processing Otomatis** - Model YOLO deteksi jawaban di laptop terpisah  
✅ **Hasil Real-time** - Lihat hasil grading secara real-time  
✅ **Riwayat Scan** - Semua scan tersimpan dengan statusnya  

## Arsitektur

```
┌─────────────┐
│ Flutter App │ (User upload LJK)
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ Firebase        │
│ - Storage       │ (Simpan gambar)
│ - Firestore     │ (Status: processing)
└──────┬──────────┘
       │
       ▼
┌──────────────────┐
│ Model Runner     │ (Laptop teman)
│ - Listen Firestore
│ - Download image
│ - YOLO detection
│ - Upload results
└──────┬───────────┘
       │
       ▼
┌─────────────────┐
│ Firebase        │
│ - Firestore     │ (Status: completed, results)
└──────┬──────────┘
       │
       ▼
┌─────────────┐
│ Flutter App │ (User lihat hasil)
└─────────────┘
```

## Setup

### A. Setup Flutter App

1. Install dependencies:

```bash
flutter pub get
```

2. Jalankan app dengan entry point baru:

```bash
# Ganti main.dart dengan main_omr.dart
mv lib/main.dart lib/main_old.dart
mv lib/main_omr.dart lib/main.dart

# Atau langsung run
flutter run -t lib/main_omr.dart
```

### B. Setup Firebase

1. Buat project di [Firebase Console](https://console.firebase.google.com)

2. Enable Firestore:
   - Build > Firestore Database > Create database
   - Start in test mode

3. Enable Storage:
   - Build > Storage > Get Started
   - Start in test mode

4. Setup rules untuk development:

**Firestore Rules**:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;  // CHANGE FOR PRODUCTION
    }
  }
}
```

**Storage Rules**:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if true;  // CHANGE FOR PRODUCTION
    }
  }
}
```

5. Download service account key (untuk model runner):
   - Settings > Service Accounts
   - Generate New Private Key
   - Simpan JSON file

### C. Setup Model Runner (Laptop Teman)

Lihat dokumentasi lengkap di [tools/model_runner/README.md](tools/model_runner/README.md)

Quick start:

```bash
cd tools/model_runner

# Install dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Setup config
cp .env.example .env
# Edit .env dengan credential yang benar

# Run
python runner.py
```

## Usage

### 1. Buat Kunci Jawaban

1. Buka app → Tab "Kunci"
2. Klik "Buat Baru"
3. Input nama (contoh: "Ujian Matematika")
4. Isi jawaban 1-100 (A-E)
5. Simpan

### 2. Upload LJK

1. Tab "Upload"
2. Input nama siswa
3. Pilih kunci jawaban
4. Ambil foto LJK atau pilih dari galeri
5. Upload & Proses

### 3. Lihat Hasil

- Otomatis redirect ke halaman hasil
- Status "Sedang Diproses..." → tunggu model selesai
- Status "Selesai" → lihat:
  - Skor (benar/salah/kosong)
  - Nilai akhir
  - Detail jawaban per nomor

### 4. Riwayat

Tab "Riwayat" menampilkan semua scan dengan status:
- 🟠 Diproses - Model sedang bekerja
- 🟢 Selesai - Sudah ada hasil
- 🔴 Gagal - Ada error

## Firestore Collections

### `answer_keys`

```javascript
{
  "name": "Ujian Matematika",
  "created_by": "userId",
  "answers": {
    "1": "A",
    "2": "B",
    ...
    "100": "E"
  },
  "created_at": timestamp
}
```

### `exam_scans`

```javascript
{
  "student_name": "John Doe",
  "image_url": "https://...",
  "answer_key_id": "keyId",
  "status": "processing|completed|failed",
  "results": {
    "1": "A",
    "2": "B",
    ...
    "100": "E"
  },
  "submitted_at": timestamp,
  "processed_at": timestamp
}
```

## Development

### Adding Features

- Screens: `lib/screens/`
- Services: `lib/services/`
- Models: `lib/models/`

### Testing Model Runner

Gunakan dummy data atau test dengan scan real. Check logs untuk debug.

### Deployment

- **App**: Build APK/IPA dan distribute
- **Runner**: Deploy ke server/laptop yang selalu online
- **Firebase**: Upgrade ke Blaze plan jika perlu

## Troubleshooting

### App tidak connect ke Firebase

- Check `lib/firebase_options.dart`
- Run `flutterfire configure` ulang

### Upload gagal

- Check Firebase Storage rules
- Check internet connection
- Check file size (max 10MB default)

### Model tidak process

- Check runner masih running
- Check credentials valid
- Check Firestore connection
- Lihat log runner untuk error

### Hasil tidak muncul

- Check status di Firestore Console
- Refresh app
- Check internet connection

## Production Checklist

- [ ] Update Firebase rules (auth required)
- [ ] Add user authentication
- [ ] Limit file upload size/type
- [ ] Add error tracking (Sentry/Crashlytics)
- [ ] Setup monitoring untuk runner
- [ ] Backup database regular
- [ ] Test dengan berbagai format LJK
- [ ] Add admin dashboard
- [ ] Setup CI/CD

## License

Private project for internal use.
