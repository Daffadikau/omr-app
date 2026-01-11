import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Report',
            onSelected: (value) async {
              final snapshot = await FirebaseFirestore.instance
                  .collection('exam_scans')
                  .where('status', isEqualTo: 'completed')
                  .get();
              
              final scans = snapshot.docs;
              final studentScores = <String, Map<String, dynamic>>{};

              for (var doc in scans) {
                final data = doc.data();
                final studentName = data['student_name'] as String? ?? 'Unknown';
                final results = data['results'] as Map<String, dynamic>?;
                final answerKeyId = data['answer_key_id'] as String?;

                if (results != null && answerKeyId != null) {
                  studentScores[doc.id] = {
                    'student_name': studentName,
                    'nim': data['nim'] ?? '-',
                    'results': results,
                    'answer_key_id': answerKeyId,
                    'submitted_at': data['submitted_at'],
                  };
                }
              }

              final scores = await _calculateScores(studentScores);
              
              if (value == 'csv') {
                await _exportToCSV(scores);
              } else if (value == 'pdf') {
                await _exportToPDF(scores);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 20),
                    SizedBox(width: 8),
                    Text('Export CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 20),
                    SizedBox(width: 8),
                    Text('Export PDF'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('exam_scans')
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final scans = snapshot.data?.docs ?? [];

          if (scans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada data scan',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Process analytics data
          final studentScores = <String, Map<String, dynamic>>{};
          int totalScans = 0;

          for (var doc in scans) {
            final data = doc.data() as Map<String, dynamic>;
            final studentName = data['student_name'] as String? ?? 'Unknown';
            final results = data['results'] as Map<String, dynamic>?;
            final answerKeyId = data['answer_key_id'] as String?;

            if (results != null && answerKeyId != null) {
              totalScans++;

              // We'll calculate score inside FutureBuilder
              studentScores[doc.id] = {
                'student_name': studentName,
                'nim': data['nim'] ?? '-',
                'results': results,
                'answer_key_id': answerKeyId,
                'submitted_at': data['submitted_at'],
              };
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Cards Row 1
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Scan',
                      totalScans.toString(),
                      Icons.assignment,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Siswa',
                      studentScores.length.toString(),
                      Icons.people,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Summary Cards Row 2 - Highest and Lowest Scores
              _buildHighestLowestScoresCards(studentScores),
              const SizedBox(height: 24),

              // Score Distribution Chart
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Distribusi Nilai',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildScoreDistributionChart(studentScores),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Student List with Scores
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hasil Per Siswa',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStudentScoresList(studentScores),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHighestLowestScoresCards(
    Map<String, Map<String, dynamic>> studentScores,
  ) {
    return FutureBuilder<List<ScoreData>>(
      future: _calculateScores(studentScores),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Row(
            children: [
              Expanded(
                child: _buildSummaryCard('Nilai Tertinggi', '-', Icons.trending_up, Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard('Nilai Terendah', '-', Icons.trending_down, Colors.red),
              ),
            ],
          );
        }

        final scores = snapshot.data ?? [];
        if (scores.isEmpty) {
          return Row(
            children: [
              Expanded(
                child: _buildSummaryCard('Nilai Tertinggi', '-', Icons.trending_up, Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard('Nilai Terendah', '-', Icons.trending_down, Colors.red),
              ),
            ],
          );
        }

        final highestScore = scores.reduce((a, b) => a.score > b.score ? a : b);
        final lowestScore = scores.reduce((a, b) => a.score < b.score ? a : b);

        return Row(
          children: [
            Expanded(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Nilai Tertinggi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Icon(Icons.trending_up, color: Colors.green, size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        highestScore.score.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        highestScore.studentName,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Nilai Terendah',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Icon(Icons.trending_down, color: Colors.red, size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lowestScore.score.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lowestScore.studentName,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreDistributionChart(
    Map<String, Map<String, dynamic>> studentScores,
  ) {
    return FutureBuilder<List<ScoreData>>(
      future: _calculateScores(studentScores),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final scores = snapshot.data ?? [];
        if (scores.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('No data available')),
          );
        }

        // Create histogram data (0-10, 10-20, ..., 90-100)
        final histogram = List<int>.filled(10, 0);
        for (var score in scores) {
          final bin = (score.score ~/ 10).clamp(0, 9);
          histogram[bin]++;
        }

        final maxValue = histogram.reduce((a, b) => a > b ? a : b).toDouble();

        return SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              borderData: FlBorderData(show: false),
              barGroups: List.generate(
                10,
                (index) => BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: histogram[index].toDouble(),
                      color: Colors.blue,
                      width: 16,
                    ),
                  ],
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      return Text(
                        '${index * 10}-${(index + 1) * 10}',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
              ),
              maxY: maxValue == 0 ? 10 : maxValue + 2,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentScoresList(
    Map<String, Map<String, dynamic>> studentScores,
  ) {
    return FutureBuilder<List<ScoreData>>(
      future: _calculateScores(studentScores),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final scores = snapshot.data ?? [];
        
        // Sort by score descending
        scores.sort((a, b) => b.score.compareTo(a.score));

        return Column(
          children: List.generate(
            scores.length,
            (index) {
              final scoreData = scores[index];
              final rank = index + 1;
              
              Color scoreColor;
              if (scoreData.score >= 80) {
                scoreColor = Colors.green;
              } else if (scoreData.score >= 60) {
                scoreColor = Colors.orange;
              } else {
                scoreColor = Colors.red;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      // Rank
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.indigo,
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Student Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scoreData.studentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'NIM: ${scoreData.nim}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Score
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          scoreData.score.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _exportToCSV(List<ScoreData> scores) async {
    try {
      // Sort by rank (descending score)
      scores.sort((a, b) => b.score.compareTo(a.score));

      // Prepare CSV data
      List<List<dynamic>> rows = [];
      
      // Header
      rows.add(['Rank', 'Nama Siswa', 'NIM', 'Nilai', 'Grade']);
      
      // Data
      for (int i = 0; i < scores.length; i++) {
        final scoreData = scores[i];
        String grade;
        if (scoreData.score >= 80) {
          grade = 'A';
        } else if (scoreData.score >= 70) {
          grade = 'B';
        } else if (scoreData.score >= 60) {
          grade = 'C';
        } else if (scoreData.score >= 50) {
          grade = 'D';
        } else {
          grade = 'E';
        }
        
        rows.add([
          i + 1,
          scoreData.studentName,
          scoreData.nim,
          scoreData.score.toStringAsFixed(1),
          grade,
        ]);
      }
      
      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);
      
      // Share/Save the CSV
      final bytes = Uint8List.fromList(csv.codeUnits);
      final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Analytics_Report_$dateStr.csv',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV report berhasil di-export')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error export CSV: $e')),
        );
      }
    }
  }

  Future<void> _exportToPDF(List<ScoreData> scores) async {
    try {
      // Sort by rank (descending score)
      scores.sort((a, b) => b.score.compareTo(a.score));

      final pdf = pw.Document();
      final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

      // Calculate statistics
      final totalStudents = scores.length;
      final avgScore = scores.isEmpty 
          ? 0.0 
          : scores.map((e) => e.score).reduce((a, b) => a + b) / totalStudents;
      final highestScore = scores.isEmpty ? 0.0 : scores.first.score;
      final lowestScore = scores.isEmpty ? 0.0 : scores.last.score;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LAPORAN ANALISIS NILAI',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Tanggal: $dateStr',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Divider(thickness: 2),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Statistics Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RINGKASAN STATISTIK',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Total Siswa:', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Nilai Rata-rata:', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('$totalStudents', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text('${avgScore.toStringAsFixed(1)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Nilai Tertinggi:', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Nilai Terendah:', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('${highestScore.toStringAsFixed(1)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                          pw.Text('${lowestScore.toStringAsFixed(1)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Student Scores Table
            pw.Text(
              'DAFTAR NILAI SISWA',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FixedColumnWidth(60),
                4: const pw.FixedColumnWidth(50),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Rank',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Nama Siswa',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'NIM',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Nilai',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Grade',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // Data rows
                ...List.generate(scores.length, (index) {
                  final scoreData = scores[index];
                  String grade;
                  if (scoreData.score >= 80) {
                    grade = 'A';
                  } else if (scoreData.score >= 70) {
                    grade = 'B';
                  } else if (scoreData.score >= 60) {
                    grade = 'C';
                  } else if (scoreData.score >= 50) {
                    grade = 'D';
                  } else {
                    grade = 'E';
                  }

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          '${index + 1}',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          scoreData.studentName,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          scoreData.nim,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          scoreData.score.toStringAsFixed(1),
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          grade,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ),
      );

      // Share/Print the PDF
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Analytics_Report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF report berhasil dibuat')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error export PDF: $e')),
        );
      }
    }
  }

  Future<List<ScoreData>> _calculateScores(
    Map<String, Map<String, dynamic>> studentScores,
  ) async {
    final scores = <ScoreData>[];

    for (var entry in studentScores.entries) {
      final data = entry.value;
      final studentName = data['student_name'] as String;
      final nim = data['nim'] as String;
      final results = data['results'] as Map<String, dynamic>;
      final answerKeyId = data['answer_key_id'] as String;

      try {
        final keyDoc = await FirebaseFirestore.instance
            .collection('answer_keys')
            .doc(answerKeyId)
            .get();

        if (!keyDoc.exists) continue;

        final keyData = keyDoc.data() as Map<String, dynamic>;
        final correctAnswers = keyData['answers'] as Map<String, dynamic>;

        int correct = 0;
        for (int i = 1; i <= 100; i++) {
          final userAnswer = results[i.toString()];
          final correctAnswer = correctAnswers[i.toString()];

          final isEmpty = userAnswer == null ||
              userAnswer.toString().trim().isEmpty ||
              userAnswer == '-' ||
              userAnswer == '' ||
              userAnswer.toString().toUpperCase() == 'KOSONG';

          if (!isEmpty && userAnswer == correctAnswer) {
            correct++;
          }
        }

        final score = (correct / 100 * 100);
        scores.add(ScoreData(
          studentName: studentName,
          nim: nim,
          score: score,
        ));
      } catch (e) {
        debugPrint('Error calculating score: $e');
      }
    }

    return scores;
  }
}

class ScoreData {
  final String studentName;
  final String nim;
  final double score;

  ScoreData({
    required this.studentName,
    required this.nim,
    required this.score,
  });
}
