import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Service untuk komunikasi dengan backend Python (ngrok tunnel)
/// Sesuai dengan aplikasi tester teman
class BackendService {
  // ⚠️ PENTING: Update URL ini setiap kali restart ngrok!
  static const String baseUrl = 'https://5762e32e8134.ngrok-free.app';

  /// Upload kunci jawaban ke backend
  ///
  /// Format request:
  /// ```json
  /// {
  ///   "kode_soal": "UJIAN-01",
  ///   "kunci": "A, B, C, D, E, A, B, C, ..."
  /// }
  /// ```
  static Future<Map<String, dynamic>> uploadKunciJawaban({
    required String kodeSoal,
    required Map<String, String> answers, // {"1": "A", "2": "B", ...}
  }) async {
    try {
      // Convert map to comma-separated string
      final kunciString = List.generate(100, (i) {
        final num = (i + 1).toString();
        return answers[num] ?? '-';
      }).join(', ');

      final response = await http.post(
        Uri.parse('$baseUrl/upload-kunci'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'kode_soal': kodeSoal, 'kunci': kunciString}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Upload gagal: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error upload kunci: $e');
    }
  }

  /// Scan LJK menggunakan backend AI model
  ///
  /// Format response:
  /// ```json
  /// {
  ///   "kode_soal": "UJIAN-01",
  ///   "koreksi": {
  ///     "skor": 85.5,
  ///     "benar": 85,
  ///     "salah": 15
  ///   },
  ///   "ai_raw_data": {
  ///     "jawaban": "A, B, C, D, E, ...",
  ///     "confidence": [0.99, 0.95, ...]
  ///   }
  /// }
  /// ```
  static Future<Map<String, dynamic>> scanLJK({
    required String kodeSoal,
    required dynamic imageFile, // File untuk mobile, Uint8List untuk web
    required String fileName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/scan?kode_soal=$kodeSoal');
      final request = http.MultipartRequest('POST', uri);

      // Add file based on platform
      if (kIsWeb) {
        // Web: use bytes
        final bytes = imageFile as List<int>;
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: fileName),
        );
      } else {
        // Mobile: use file path
        final file = imageFile as File;
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            filename: fileName,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;

        // Parse jawaban - handle both String and List format
        final answersMap = <String, String>{};
        final jawabanData = result['ai_raw_data']?['jawaban'];

        if (jawabanData is String) {
          // Format: "A, B, C, D, E, ..."
          final jawabanList = jawabanData
              .split(', ')
              .map((e) => e.trim())
              .toList();
          for (int i = 0; i < jawabanList.length && i < 100; i++) {
            answersMap[(i + 1).toString()] = jawabanList[i];
          }
        } else if (jawabanData is List) {
          // Format: ["A", "B", "C", "D", "E", ...]
          for (int i = 0; i < jawabanData.length && i < 100; i++) {
            answersMap[(i + 1).toString()] = jawabanData[i].toString();
          }
        }

        return {
          'kode_soal': result['kode_soal'],
          'skor': result['koreksi']?['skor'] ?? 0.0,
          'benar': result['koreksi']?['benar'] ?? 0,
          'salah': result['koreksi']?['salah'] ?? 0,
          'jawaban': answersMap,
          'confidence': result['ai_raw_data']?['confidence'] ?? [],
        };
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
          errorBody['error'] ?? 'Scan gagal: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error scan LJK: $e');
    }
  }

  /// Check koneksi backend
  static Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
