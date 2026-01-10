import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/scan_service.dart';

class ScanResultScreen extends StatelessWidget {
  final String scanId;

  const ScanResultScreen({super.key, required this.scanId});

  @override
  Widget build(BuildContext context) {
    final scanService = ScanService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Scan'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: scanService.getScanStream(scanId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text('Data tidak ditemukan'));
          }

          final status = data['status'] as String? ?? 'processing';
          final studentName = data['student_name'] as String? ?? '-';

          // Processing state
          if (status == 'processing') {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(strokeWidth: 6),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sedang Diproses...',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Model sedang membaca jawaban dari LJK',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nama: $studentName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          // Failed state
          if (status == 'failed') {
            final errorMessage = data['error_message'] as String? ?? 'Unknown error';
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Proses Gagal',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kembali'),
                  ),
                ],
              ),
            );
          }

          // Completed state - show results
          if (status == 'completed') {
            final answerKeyId = data['answer_key_id'] as String?;
            final results = data['results'] as Map<String, dynamic>?;

            if (answerKeyId == null || results == null) {
              return const Center(child: Text('Data hasil tidak lengkap'));
            }

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('answer_keys')
                  .doc(answerKeyId)
                  .get(),
              builder: (context, keySnapshot) {
                if (!keySnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final keyData = keySnapshot.data!.data() as Map<String, dynamic>?;
                if (keyData == null) {
                  return const Center(child: Text('Kunci jawaban tidak ditemukan'));
                }

                final correctAnswers = keyData['answers'] as Map<String, dynamic>;
                final keyName = keyData['name'] as String? ?? 'Tanpa Nama';

                // Calculate score
                int correct = 0;
                int wrong = 0;
                int unanswered = 0;

                for (int i = 1; i <= 100; i++) {
                  final userAnswer = results[i.toString()];
                  final correctAnswer = correctAnswers[i.toString()];

                  if (userAnswer == null || userAnswer == '' || userAnswer == '-') {
                    unanswered++;
                  } else if (userAnswer == correctAnswer) {
                    correct++;
                  } else {
                    wrong++;
                  }
                }

                final score = (correct / 100 * 100).round();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Summary Card
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              studentName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              keyName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  'Benar',
                                  correct.toString(),
                                  Colors.green,
                                  Icons.check_circle,
                                ),
                                _buildStatItem(
                                  'Salah',
                                  wrong.toString(),
                                  Colors.red,
                                  Icons.cancel,
                                ),
                                _buildStatItem(
                                  'Kosong',
                                  unanswered.toString(),
                                  Colors.orange,
                                  Icons.help_outline,
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'NILAI AKHIR',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    score.toString(),
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: _getScoreColor(score),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Detail jawaban
                    Text(
                      'Detail Jawaban',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),

                    ...List.generate(100, (index) {
                      final num = index + 1;
                      final userAnswer = results[num.toString()] ?? '-';
                      final correctAnswer = correctAnswers[num.toString()] ?? '-';
                      
                      final isCorrect = userAnswer == correctAnswer;
                      final isEmpty = userAnswer == '-' || userAnswer == '' || userAnswer == null;

                      Color bgColor;
                      Color textColor;
                      IconData icon;

                      if (isEmpty) {
                        bgColor = Colors.orange[100]!;
                        textColor = Colors.orange[900]!;
                        icon = Icons.help_outline;
                      } else if (isCorrect) {
                        bgColor = Colors.green[100]!;
                        textColor = Colors.green[900]!;
                        icon = Icons.check_circle;
                      } else {
                        bgColor = Colors.red[100]!;
                        textColor = Colors.red[900]!;
                        icon = Icons.cancel;
                      }

                      return Card(
                        color: bgColor,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: textColor,
                            child: Text(
                              '$num',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                'Jawaban: ',
                                style: TextStyle(color: textColor),
                              ),
                              Text(
                                userAnswer,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Kunci: $correctAnswer',
                            style: TextStyle(color: textColor),
                          ),
                          trailing: Icon(icon, color: textColor),
                        ),
                      );
                    }),
                  ],
                );
              },
            );
          }

          return Center(child: Text('Status: $status'));
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}
