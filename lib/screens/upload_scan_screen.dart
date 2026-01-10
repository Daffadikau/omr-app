import 'dart:io';
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

  File? _selectedImage;
  String? _selectedAnswerKeyId;
  String? _selectedAnswerKeyName;
  bool _isUploading = false;

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
        setState(() {
          _selectedImage = File(image.path);
        });
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
    if (_selectedImage == null) {
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

    setState(() => _isUploading = true);

    try {
      final scanId = await _scanService.uploadScan(
        imageFile: _selectedImage!,
        studentName: _nameController.text.trim(),
        answerKeyId: _selectedAnswerKeyId!,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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

            // Preview gambar
            if (_selectedImage != null) ...[
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.contain,
                  ),
                ),
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
