import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'upload_scan_screen.dart';
import 'scan_result_screen.dart';
import 'answer_key_list_screen.dart';

class ScanHistoryScreen extends StatelessWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Scan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.quiz),
            tooltip: 'Kunci Jawaban',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnswerKeyListScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('exam_scans')
            .orderBy('submitted_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada scan LJK',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UploadScanScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload LJK'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final studentName = data['student_name'] as String? ?? 'Tanpa Nama';
              final status = data['status'] as String? ?? 'processing';
              final submittedAt = (data['submitted_at'] as Timestamp?)?.toDate();
              final results = data['results'] as Map<String, dynamic>?;

              Color statusColor;
              IconData statusIcon;
              String statusText;

              switch (status) {
                case 'completed':
                  statusColor = Colors.green;
                  statusIcon = Icons.check_circle;
                  statusText = 'Selesai';
                  break;
                case 'failed':
                  statusColor = Colors.red;
                  statusIcon = Icons.error;
                  statusText = 'Gagal';
                  break;
                default:
                  statusColor = Colors.orange;
                  statusIcon = Icons.hourglass_empty;
                  statusText = 'Diproses';
              }

              // Calculate score if completed
              String? scoreText;
              if (status == 'completed' && results != null) {
                final answerKeyId = data['answer_key_id'] as String?;
                if (answerKeyId != null) {
                  // We'll show score from future builder
                  scoreText = '...';
                }
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.2),
                    child: Icon(statusIcon, color: statusColor),
                  ),
                  title: Text(
                    studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (scoreText != null) ...[
                            const SizedBox(width: 8),
                            if (status == 'completed' && results != null)
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('answer_keys')
                                    .doc(data['answer_key_id'])
                                    .get(),
                                builder: (context, keySnapshot) {
                                  if (!keySnapshot.hasData) {
                                    return const SizedBox();
                                  }
                                  
                                  final keyData = keySnapshot.data!.data() as Map<String, dynamic>?;
                                  if (keyData == null) return const SizedBox();
                                  
                                  final correctAnswers = keyData['answers'] as Map<String, dynamic>;
                                  int correct = 0;
                                  for (int i = 1; i <= 100; i++) {
                                    if (results[i.toString()] == correctAnswers[i.toString()]) {
                                      correct++;
                                    }
                                  }
                                  
                                  return Text(
                                    'Nilai: $correct',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ],
                      ),
                      if (submittedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('dd MMM yyyy HH:mm').format(submittedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScanResultScreen(scanId: doc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'scan_history_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UploadScanScreen(),
            ),
          );
        },
        label: const Text('Upload LJK'),
        icon: const Icon(Icons.upload),
      ),
    );
  }
}
