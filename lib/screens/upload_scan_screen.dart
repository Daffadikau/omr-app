import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/scan_service.dart';
import 'answer_key_list_screen.dart';
import 'scan_result_screen.dart';

class UploadScanScreen extends StatefulWidget {
  const UploadScanScreen({super.key});

  @override
  State<UploadScanScreen> createState() => _UploadScanScreenState();
}

class _UploadScanScreenState extends State<UploadScanScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ScanService _scanService = ScanService();
  final ImagePicker _picker = ImagePicker();
  static const Duration _uploadTimeout = Duration(seconds: 60);

  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String? _selectedFileName;
  String? _selectedAnswerKeyId;
  String? _selectedAnswerKeyName;
  bool _isUploading = false;
  String? _uploadError;
  bool _hasTimeout = false;

  void _clearImage() {
    setState(() {
      _selectedImageFile = null;
      _selectedImageBytes = null;
      _selectedFileName = null;
      _uploadError = null;
      _hasTimeout = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImageFile = null;
            _selectedFileName = image.name;
          });
        } else {
          setState(() {
            _selectedImageFile = File(image.path);
            _selectedImageBytes = null;
            _selectedFileName = image.name;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error memilih gambar: $e')),
        );
      }
    }
  }

  Future<void> _selectAnswerKey() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const AnswerKeyListScreen(),
      ),
    );

    if (result != null) {
      // Get answer key name
      final doc = await FirebaseFirestore.instance
          .collection('answer_keys')
          .doc(result)
          .get();

      setState(() {
        _selectedAnswerKeyId = result;
        _selectedAnswerKeyName = doc.data()?['name'] as String? ?? 'Tanpa Nama';
      });
    }
  }

  Future<void> _uploadScan() async {
    if (_selectedImageFile == null && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih gambar LJK terlebih dahulu')),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nama siswa')),
      );
      return;
    }

    if (_selectedAnswerKeyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kunci jawaban terlebih dahulu')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
      _hasTimeout = false;
    });

    try {
      final scanId = await _scanService.uploadScan(
        imageFile: _selectedImageFile,
        imageBytes: _selectedImageBytes,
        fileName: _selectedFileName ?? 'scan.jpg',
        studentName: _nameController.text.trim(),
        answerKeyId: _selectedAnswerKeyId!,
      ).timeout(
        _uploadTimeout,
        onTimeout: () {
          setState(() => _hasTimeout = true);
          throw TimeoutException('Upload timeout setelah ${_uploadTimeout.inSeconds} detik');
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('LJK berhasil diupload, sedang diproses...'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to result screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ScanResultScreen(scanId: scanId),
          ),
        );
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() {
          _uploadError = 'Timeout: ${e.message}';
          _hasTimeout = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadError = 'Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload LJK'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input nama siswa
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Siswa',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            // Pilih kunci jawaban
            InkWell(
              onTap: _isUploading ? null : _selectAnswerKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.quiz),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kunci Jawaban',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedAnswerKeyName ?? 'Pilih Kunci Jawaban',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedAnswerKeyName != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Error message display
            if (_uploadError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _uploadError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _uploadError = null;
                                _hasTimeout = false;
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearImage,
                            icon: const Icon(Icons.delete),
                            label: const Text('Hapus Foto'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Preview gambar
            if (_selectedImageFile != null || _selectedImageBytes != null) ...[
              Stack(
                children: [
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _selectedImageBytes != null
                          ? Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.contain,
                            )
                          : Image.file(
                              _selectedImageFile!,
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                  // Delete button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: FloatingActionButton.small(
                      onPressed: _clearImage,
                      backgroundColor: Colors.red,
                      heroTag: 'delete_photo_btn',
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                  ),
                  if (_selectedFileName != null)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _selectedFileName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Tombol pilih gambar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tombol upload
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadScan,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isUploading ? 'Mengupload...' : 'Upload & Proses'),
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
