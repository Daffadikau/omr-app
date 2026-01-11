# Dokumentasi Aplikasi OMR Grader Pro

## 📋 Daftar Isi
1. [Overview](#overview)
2. [Persyaratan Sistem](#persyaratan-sistem)
3. [Dependencies](#dependencies)
4. [Struktur Folder](#struktur-folder)
5. [Fitur Utama](#fitur-utama)
6. [Konfigurasi Backend](#konfigurasi-backend)
7. [API Endpoints](#api-endpoints)
8. [Komponen UI](#komponen-ui)
9. [State Management](#state-management)
10. [Cara Menjalankan](#cara-menjalankan)

---

## Overview

**OMR Grader Pro** adalah aplikasi Flutter cross-platform untuk:
- ✅ Input kunci jawaban ujian (100 soal) dengan UI yang user-friendly
- ✅ Scan lembar jawab komputerisasi (LJK) menggunakan kamera/galeri
- ✅ Koreksi otomatis menggunakan YOLO AI model (via backend Python)
- ✅ Kompatibel web dan mobile (Android, iOS, Windows, macOS, Linux)
- ✅ Sinkronisasi dengan aplikasi tester teman (ngrok + Firebase)

**Technology Stack:**
- Frontend: Flutter 3.x
- Backend: Python dengan ngrok tunnel (Flask/FastAPI)
- Database: Firebase Firestore & Storage
- ML: YOLOv11 untuk scanning LJK
- Real-time: StreamBuilder & Firestore snapshots

---

## Persyaratan Sistem

### Minimum Requirements
- **Flutter SDK**: 3.10.1 atau lebih tinggi
- **Dart SDK**: 3.10.1 atau lebih tinggi
- **Java**: JDK 11+ (untuk Android)
- **Python**: 3.8+ (untuk backend)
- **ngrok**: Untuk tunneling backend

### Recommended
- Flutter SDK: Latest stable
- IDE: VS Code atau Android Studio
- Browser modern: Chrome, Safari, Firefox

---

## Dependencies

### pubspec.yaml (Key Dependencies)
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase
  firebase_core: ^3.10.0
  cloud_firestore: ^5.7.2
  firebase_storage: ^13.0.5
  firebase_auth: ^5.4.2
  
  # UI & Utils
  cupertino_icons: ^1.0.8
  google_fonts: ^6.2.1
  cached_network_image: ^3.3.0
  
  # HTTP & Image
  http: ^1.6.0
  image_picker: ^1.2.1
  file_picker: ^8.1.6

environment:
  sdk: ^3.10.1
```

### Cara Menginstall Dependencies
```bash
cd /Users/dikau/demo
flutter pub get
```

---

## Struktur Folder

```
demo/
├── lib/
│   ├── main.dart                          # Entry point
│   ├── firebase_options.dart              # Firebase config (generated)
│   ├── screens/
│   │   ├── upload_scan_screen.dart        # Upload LJK
│   │   ├── scan_history_screen.dart       # Riwayat scan
│   │   ├── scan_result_screen.dart        # Detail hasil
│   │   ├── answer_key_screen.dart         # Input kunci
│   │   └── answer_key_list_screen.dart    # List kunci
│   ├── services/
│   │   ├── scan_service.dart              # Firebase + Upload logic
│   │   ├── backend_service.dart           # ngrok API integration ⭐ BARU
│   │   └── auth_service.dart              # Authentication
│   └── widgets/                           # Reusable widgets
├── tools/
│   └── model_runner/                      # Python backend
│       ├── runner.py                      # YOLO processing
│       ├── requirements.txt
│       ├── .env.example
│       └── run.sh
├── android/                               # Android config
├── ios/                                   # iOS config
├── web/                                   # Web config
├── pubspec.yaml                           # Dependencies
└── DOKUMENTASI.md                        # File ini
```

---

## Fitur Utama

### Tab 1: Upload LJK
**Purpose:** Upload dan scan lembar jawab

**Features:**
- Input Nama Siswa & NIM
- Pilih kunci jawaban dari list
- Ambil foto dari kamera/galeri
- Preview foto sebelum upload
- **Langsung proses dengan backend ngrok** ⭐
- Hasil instant (skor, benar, salah)
- Timeout protection (60 detik)
- Tombol retry jika gagal

### Tab 2: Riwayat Scan
**Purpose:** Lihat semua scan sebelumnya

**Features:**
- List scan dengan status
- Show score jika completed
- Real-time update via Firestore
- Delete scan + image
- Tap untuk detail

### Tab 3: Kunci Jawaban
**Purpose:** Manage kunci jawaban

**Features:**
- Input 100 soal (A-E)
- Grid layout 10x10
- Auto-save ke Firebase
- **Auto-sync ke backend ngrok** ⭐
- Edit/Delete kunci

---

## Konfigurasi Backend

### 1. Backend Service (ngrok)
**File:** `lib/services/backend_service.dart`

```dart
class BackendService {
  // ⚠️ PENTING: Update URL ini setiap kali restart ngrok!
  static const String baseUrl = 'https://5762e32e8134.ngrok-free.app';
  
  // Upload kunci jawaban
  static Future<Map<String, dynamic>> uploadKunciJawaban({
    required String kodeSoal,
    required Map<String, String> answers,
  })
  
  // Scan LJK dengan AI
  static Future<Map<String, dynamic>> scanLJK({
    required String kodeSoal,
    required dynamic imageFile,
    required String fileName,
  })
}
```

### 2. Cara Update ngrok URL
Setiap kali restart ngrok:
1. Copy URL baru dari terminal ngrok
2. Update `baseUrl` di `lib/services/backend_service.dart` line 12
3. Hot reload app: `r` di terminal Flutter

### 3. Firebase Configuration
**File:** `lib/firebase_options.dart` (auto-generated)

Pastikan Firebase project sudah setup dengan:
- ✅ Firestore Database
- ✅ Firebase Storage
- ✅ Firebase Auth (opsional)

### 4. Python Backend Requirements
**File:** `tools/model_runner/requirements.txt`

```txt
firebase-admin==6.5.0
ultralytics==8.3.0
requests==2.32.3
Pillow==10.4.0
python-dotenv==1.0.1
flask==3.0.0  # atau fastapi
```

---

## API Endpoints

### 1. Upload Kunci Jawaban
**Endpoint:** `POST {baseUrl}/upload-kunci`

**Request Body:**
```json
{
  "kode_soal": "UJIAN-01",
  "kunci": "A, B, C, D, E, A, B, C, D, E, ...(100 jawaban)"
}
```

**Response (Success):**
```json
{
  "status": "success",
  "message": "Kunci jawaban tersimpan"
}
```

**Response (Error):**
```json
{
  "status": "error",
  "message": "Kode soal sudah ada"
}
```

---

### 2. Scan LJK
**Endpoint:** `POST {baseUrl}/scan?kode_soal=UJIAN-01`

**Request Body:** Multipart Form Data
- `file`: Binary image file (JPG/PNG)

**Response (Success):**
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

**Response (Error):**
```json
{
  "error": "Kode soal tidak ditemukan",
  "status": 404
}
```

---

## Komponen UI

### Main Widgets
| Widget | Lokasi | Fungsi |
|--------|--------|--------|
| `Scaffold` | `build()` | Struktur utama dengan AppBar |
| `TabBar` | `build()` | 2 tab: Input Kunci & Scan |
| `TabBarView` | `build()` | Container untuk 2 tab |
| `PageView` | `_buildInputKunciTab()` | Carousel untuk soal 1-100 |
| `LinearProgressIndicator` | PageView builder | Progress bar |
| `GridView` | `_buildScanTab()` | Preview image |
| `Wrap` | PageView builder | Tombol A-E |
| `Card` | PageView builder | Container soal |
| `TextField` | Setiap tab | Input field |
| `ElevatedButton` | Setiap tab | Action buttons |

### Warna & Styling
- **Primary**: Colors.blueAccent
- **Success**: Colors.green
- **Warning**: Colors.orangeAccent
- **Background**: Colors.grey[100]
- **Button A-E Selected**: Colors.green
- **Button A-E Unselected**: Colors.grey[400]

---

## State Management

### Stateful Widget
**Class:** `_LjkControlPanelState`

### State Variables (Properties)
```dart
// Controllers
late TabController _tabController;
late PageController _pageController;
final TextEditingController _kodeKunciController = TextEditingController();
final TextEditingController _kodeScanController = TextEditingController();
late List<TextEditingController> _jawabControllers;

// Configuration
final String baseUrl = "https://...";
static const int _jumlahSoal = 100;

// UI State
bool _isUploadingKey = false;
bool _isScanning = false;
XFile? _imageLJK;
String _scanResult = "";
```

### Lifecycle Methods
```dart
@override
void initState() {
  // Inisialisasi controllers & PageView
}

@override
void dispose() {
  // Cleanup semua controllers
}
```

---

## Cara Menjalankan

### Run di Web (Chrome)
```bash
cd /Users/dikau/Downloads/ljk_tester
flutter run -d chrome
```

Output akan tampil di: `http://localhost:XXXX`

### Run di Android (Emulator)
```bash
flutter emulators --launch android_emulator
flutter run -d emulator-5554
```

### Run di iOS (Simulator)
```bash
open -a Simulator
flutter run -d booted
```

### Run di Windows
```bash
flutter run -d windows
```

### Build Release
```bash
# Web
flutter build web

# Android
flutter build apk --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release
```

---

## Troubleshooting

### Error: "Dart SDK version 3.9.2"
**Solution:** 
```bash
flutter upgrade --force
```

### Error: "_pageController has not been initialized"
**Solution:** Pastikan `initState()` dipanggil sebelum build widget

### Image tidak tampil di Web
**Solution:** Gunakan `Image.network()` untuk web, `Image.file()` untuk mobile

### Koneksi ke Backend Error
**Solution:** Pastikan ngrok URL sudah update dan backend sedang running

---

## Notes untuk Development

### Code Structure
- Semua kode di dalam 1 file `main.dart`
- Menggunakan Private methods (prefix `_`) untuk internal functions
- Menggunakan `const` untuk UI yang static
- Responsive design untuk mobile & web

### Best Practices Digunakan
- ✅ Proper resource cleanup di `dispose()`
- ✅ Error handling dengan try-catch
- ✅ Loading indicators saat async operations
- ✅ SnackBar untuk user feedback
- ✅ Input validation sebelum submit
- ✅ Cross-platform compatibility (Web & Mobile)

### Code Comments
- Comments menggunakan Bahasa Indonesia
- Section separator: `// ================= NAMA SECTION =================`
- Inline comments untuk logika kompleks

---

## Future Enhancements

Fitur yang bisa ditambahkan:
- [ ] Database lokal untuk caching kunci
- [ ] Export hasil scan ke PDF
- [ ] Dark mode
- [ ] Multi-language support
- [ ] Offline mode untuk scan
- [ ] Real-time sync dengan Firebase
- [ ] Authentication/Login
- [ ] Analytics tracking
- [ ] Batch upload multiple kunci
- [ ] Edit kunci yang sudah ada

---

## Contact & Support

**Dibuat:** 11 Januari 2026  
**Framework:** Flutter 3.x  
**Author:** Dikau  
**Location:** `/Users/dikau/Downloads/ljk_tester`

---

*Last Updated: 11 Januari 2026*
