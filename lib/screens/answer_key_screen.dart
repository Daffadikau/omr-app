import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/backend_service.dart';

class AnswerKeyScreen extends StatefulWidget {
  const AnswerKeyScreen({super.key});

  @override
  State<AnswerKeyScreen> createState() => _AnswerKeyScreenState();
}

class _AnswerKeyScreenState extends State<AnswerKeyScreen> {
  final Map<int, String> _answers = {};
  final TextEditingController _nameController = TextEditingController();
  late PageController _pageController;
  int _currentQuestion = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Jangan initialize dengan nilai default, biarkan kosong
    // User harus memilih jawaban terlebih dahulu
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
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

      // 1. Simpan ke Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('answer_keys')
          .add({
            'name': _nameController.text.trim(),
            'created_by': userId,
            'answers': answersForFirestore,
            'created_at': FieldValue.serverTimestamp(),
          });

      // 2. Upload ke backend (ngrok) untuk sinkronisasi dengan tester
      try {
        await BackendService.uploadKunciJawaban(
          kodeSoal: _nameController.text.trim(),
          answers: answersForFirestore.map((k, v) => MapEntry(k, v.toString())),
        );
      } catch (e) {
        // Log error tapi tetap lanjutkan jika backend gagal
        print('Warning: Backend upload gagal - $e');
      }

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  void _selectAnswer(String answer) {
    setState(() {
      _answers[_currentQuestion] = answer;
    });
    // Auto advance ke soal berikutnya
    if (_currentQuestion < 100) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousQuestion() {
    if (_currentQuestion > 1) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextQuestion() {
    if (_currentQuestion < 100) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToQuestion(int question) {
    _pageController.animateToPage(
      question - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
                hintText: 'Contoh: MTK-01',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            ),
          ),

          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Soal $_currentQuestion / 100',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Terjawab: ${_answers.values.where((v) => v.isNotEmpty).length}/100',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _currentQuestion / 100,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          // PageView untuk scroll soal
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentQuestion = index + 1;
                });
              },
              itemCount: 100,
              itemBuilder: (context, index) {
                final number = index + 1;
                return _buildQuestionCard(number);
              },
            ),
          ),

          // Tombol navigasi & pilihan jawaban
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tombol jawaban A-E
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAnswerButton('A', Colors.blue),
                    _buildAnswerButton('B', Colors.green),
                    _buildAnswerButton('C', Colors.orange),
                    _buildAnswerButton('D', Colors.purple),
                    _buildAnswerButton('E', Colors.red),
                  ],
                ),
                const SizedBox(height: 16),
                // Tombol navigasi & simpan
                Row(
                  children: [
                    // Tombol Previous
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _currentQuestion > 1 ? _previousQuestion : null,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Sebelumnya'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Input Go To Question
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showGoToDialog(),
                        child: Text('${_currentQuestion}/100'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tombol Next
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _currentQuestion < 100 ? _nextQuestion : null,
                        label: const Text('Selanjutnya'),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Tombol Simpan
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveAnswerKey,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan Kunci Jawaban',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int number) {
    final answer = _answers[number];
    final hasAnswer = answer != null && answer.isNotEmpty;
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Soal Nomor',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$number',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 32),
              if (hasAnswer)
                Text(
                  'Jawaban: $answer',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _getColorForAnswer(answer!),
                  ),
                )
              else
                Text(
                  'Belum Ada Jawaban',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Tekan tombol A-E di bawah untuk memilih',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerButton(String answer, Color color) {
    final isSelected = _answers[_currentQuestion] == answer;
    return SizedBox(
      width: 56,
      height: 56,
      child: ElevatedButton(
        onPressed: () => _selectAnswer(answer),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? color : Colors.grey[300],
          foregroundColor: isSelected ? Colors.white : Colors.black87,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: color, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Text(
          answer,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
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

  void _showGoToDialog() {
    final controller = TextEditingController(text: _currentQuestion.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pergi ke Soal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Masukkan nomor soal (1-100)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              final number = int.tryParse(controller.text) ?? _currentQuestion;
              if (number >= 1 && number <= 100) {
                _goToQuestion(number);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Masukkan nomor soal 1-100')),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
