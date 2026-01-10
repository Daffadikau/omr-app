import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnswerKeyScreen extends StatefulWidget {
  const AnswerKeyScreen({super.key});

  @override
  State<AnswerKeyScreen> createState() => _AnswerKeyScreenState();
}

class _AnswerKeyScreenState extends State<AnswerKeyScreen> {
  final Map<int, String> _answers = {};
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize dengan nilai default A
    for (int i = 1; i <= 100; i++) {
      _answers[i] = 'A';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveAnswerKey() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nama kunci jawaban')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      
      // Convert Map<int, String> to Map<String, dynamic> untuk Firestore
      final answersForFirestore = <String, dynamic>{};
      _answers.forEach((key, value) {
        answersForFirestore[key.toString()] = value;
      });

      await FirebaseFirestore.instance.collection('answer_keys').add({
        'name': _nameController.text.trim(),
        'created_by': userId,
        'answers': answersForFirestore,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunci jawaban berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _fillAll(String value) {
    setState(() {
      for (int i = 1; i <= 100; i++) {
        _answers[i] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Kunci Jawaban'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Isi Semua',
            onSelected: _fillAll,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'A', child: Text('Isi Semua: A')),
              const PopupMenuItem(value: 'B', child: Text('Isi Semua: B')),
              const PopupMenuItem(value: 'C', child: Text('Isi Semua: C')),
              const PopupMenuItem(value: 'D', child: Text('Isi Semua: D')),
              const PopupMenuItem(value: 'E', child: Text('Isi Semua: E')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Input nama kunci jawaban
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Kunci Jawaban',
                hintText: 'Contoh: Ujian Matematika Kelas 12',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            ),
          ),

          // Grid jawaban
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: 100,
              itemBuilder: (context, index) {
                final number = index + 1;
                return Card(
                  elevation: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$number',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<String>(
                        value: _answers[number],
                        isDense: true,
                        underline: Container(),
                        items: ['A', 'B', 'C', 'D', 'E']
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _getColorForAnswer(e),
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _answers[number] = val);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Tombol simpan
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAnswerKey,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Kunci Jawaban'),
                  style: ElevatedButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForAnswer(String answer) {
    switch (answer) {
      case 'A':
        return Colors.blue;
      case 'B':
        return Colors.green;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.purple;
      case 'E':
        return Colors.red;
      default:
        return Colors.black;
    }
  }
}
