# 🔧 Panduan Integrasi Backend dengan OMR Grader Pro

## 📌 Overview
Aplikasi OMR Grader Pro sekarang sudah terintegrasi dengan backend Python (ngrok) teman Anda. Sistem ini sinkron dengan aplikasi tester yang sudah berjalan.

---

## ✅ Yang Sudah Dikonfigurasi

### 1. Backend Service (`lib/services/backend_service.dart`)
Service baru yang handle komunikasi dengan ngrok backend:

**Endpoints:**
- `POST /upload-kunci` - Upload kunci jawaban
- `POST /scan?kode_soal=XXX` - Scan LJK dengan AI

**Base URL:** `https://5762e32e8134.ngrok-free.app`

### 2. Scan Service (`lib/services/scan_service.dart`)
Ditambahkan method baru: `uploadAndProcessWithBackend()`
- Upload image ke Firebase Storage
- Kirim ke backend untuk AI processing
- Simpan hasil langsung ke Firestore

### 3. Answer Key Screen (`lib/screens/answer_key_screen.dart`)
Auto-sync kunci jawaban ke backend saat save:
- Simpan ke Firestore ✅
- Upload ke backend ngrok ✅

### 4. Upload Screen (`lib/screens/upload_scan_screen.dart`)
Langsung proses dengan backend (instant results):
- Upload → Process → Results dalam 1 flow

---

## 🚀 Cara Menjalankan

### Step 1: Update ngrok URL
Setiap kali restart ngrok, update URL di:

**File:** `lib/services/backend_service.dart` line 12
```dart
static const String baseUrl = 'https://XXXX.ngrok-free.app'; // ← Ganti ini
```

### Step 2: Jalankan Backend Python
```bash
# Terminal 1: Start ngrok
ngrok http 5000

# Terminal 2: Start Python backend
cd /path/to/backend
python app.py
```

### Step 3: Jalankan Flutter App
```bash
cd /Users/dikau/demo
flutter run -d chrome
```

---

## 📡 API Contract

### 1. Upload Kunci Jawaban
**Request:**
```bash
POST /upload-kunci
Content-Type: application/json

{
  "kode_soal": "UJIAN-01",
  "kunci": "A, B, C, D, E, A, B, C, D, E, ...(100 jawaban)"
}
```

**Response Success:**
```json
{
  "status": "success",
  "message": "Kunci jawaban tersimpan"
}
```

**Response Error:**
```json
{
  "status": "error",
  "message": "Kode soal sudah ada"
}
```

---

### 2. Scan LJK
**Request:**
```bash
POST /scan?kode_soal=UJIAN-01
Content-Type: multipart/form-data

file: [binary image data]
```

**Response Success:**
```json
{
  "kode_soal": "UJIAN-01",
  "koreksi": {
    "skor": 85.5,
    "benar": 85,
    "salah": 15
  },
  "ai_raw_data": {
    "jawaban": "A, B, C, D, E, A, B, C, ...",
    "confidence": [0.99, 0.95, 0.87, ...]
  }
}
```

**Response Error:**
```json
{
  "error": "Kode soal tidak ditemukan",
  "status": 404
}
```

---

## 🗂️ Data Flow

```
┌─────────────────┐
│   Flutter App   │
└────────┬────────┘
         │
         │ 1. Upload Image
         ▼
┌─────────────────┐
│ Firebase Storage│ (original.jpg)
└────────┬────────┘
         │
         │ 2. Send to Backend
         ▼
┌─────────────────┐
│  ngrok Backend  │
│  (Python YOLO)  │
└────────┬────────┘
         │
         │ 3. AI Processing
         ▼
┌─────────────────┐
│    Firebase     │
│   Firestore     │ (results + score)
└────────┬────────┘
         │
         │ 4. Real-time Update
         ▼
┌─────────────────┐
│  Result Screen  │
└─────────────────┘
```

---

## 🔍 Testing Checklist

### Test 1: Upload Kunci Jawaban
- [ ] Buka tab "Kunci Jawaban"
- [ ] Input 100 jawaban (grid 10x10)
- [ ] Klik "Simpan"
- [ ] Cek Firestore: koleksi `answer_keys`
- [ ] Cek backend logs: POST /upload-kunci success

### Test 2: Scan LJK
- [ ] Buka tab "Upload"
- [ ] Input Nama & NIM
- [ ] Pilih kunci jawaban
- [ ] Upload foto LJK
- [ ] Tunggu processing (max 60 detik)
- [ ] Cek hasil: skor, benar, salah tampil
- [ ] Cek Firestore: dokumen `exam_scans` status "completed"

### Test 3: Lihat Riwayat
- [ ] Buka tab "Riwayat"
- [ ] Lihat list scan
- [ ] Tap untuk detail
- [ ] Lihat annotated image (jika ada)

---

## ⚙️ Environment Setup

### Backend Requirements
```txt
firebase-admin==6.5.0
ultralytics==8.3.0
requests==2.32.3
Pillow==10.4.0
python-dotenv==1.0.1
flask==3.0.0  # atau fastapi
ngrok
```

### Flutter Dependencies (sudah installed)
```yaml
http: ^1.6.0
firebase_core: ^4.3.0
cloud_firestore: ^6.1.1
firebase_storage: ^13.0.5
image_picker: ^1.2.1
```

---

## 🐛 Troubleshooting

### Error: "Connection refused"
**Solusi:**
1. Pastikan backend Python running
2. Pastikan ngrok tunnel aktif
3. Update `baseUrl` di `backend_service.dart`

### Error: "Kode soal tidak ditemukan"
**Solusi:**
1. Pastikan kunci jawaban sudah di-upload ke backend
2. Check nama kode soal sama persis (case-sensitive)

### Error: "Upload timeout"
**Solusi:**
1. Cek koneksi internet
2. Cek backend logs untuk error
3. Coba compress image sebelum upload

### Backend tidak menerima request
**Solusi:**
1. Check ngrok URL masih valid (restart = URL baru)
2. Check Flask/FastAPI CORS settings
3. Check firewall/port 5000

---

## 📝 Notes untuk Teman

### Yang Perlu Diperhatikan:
1. **ngrok URL berubah** setiap restart → Update di `backend_service.dart`
2. **Firebase** harus sama (credentials teman & aplikasi ini)
3. **Format response** harus sesuai contract di atas
4. **Kode soal** dari Firestore `answer_keys.name` digunakan sebagai parameter

### File Penting di Backend:
- `app.py` atau `main.py` - Flask/FastAPI server
- `model_weights.pt` - YOLO model
- `.env` - Firebase credentials
- `ngrok.yml` - ngrok config

### Testing Command:
```bash
# Test upload kunci
curl -X POST http://localhost:5000/upload-kunci \
  -H "Content-Type: application/json" \
  -d '{"kode_soal":"TEST-01","kunci":"A,B,C,..."}'

# Test scan (dengan file)
curl -X POST "http://localhost:5000/scan?kode_soal=TEST-01" \
  -F "file=@ljk_sample.jpg"
```

---

## 🎯 Success Indicators

Aplikasi berjalan dengan baik jika:
- ✅ Kunci jawaban tersimpan di Firestore & backend
- ✅ Upload LJK langsung dapat hasil (< 60 detik)
- ✅ Skor & jawaban tampil di Result Screen
- ✅ Annotated image (opsional) tampil jika ada
- ✅ Riwayat scan ter-update real-time

---

## 📞 Contact

Jika ada masalah integrasi:
1. Check Flutter logs: `flutter logs`
2. Check backend logs: terminal Python
3. Check ngrok dashboard: http://localhost:4040
4. Check Firebase console: https://console.firebase.google.com

---

*Last Updated: 11 Januari 2026*
*Integration Version: 1.0*
