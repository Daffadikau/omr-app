import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/exam_submission.dart';
import '../services/analytics_service.dart';

class PDFReportService {
  static const String institutionName = 'Your Institution';
  static const String institutionLogoPath = 'assets/images/logo.png';

  /// Generate comprehensive analytics report
  static Future<Uint8List> generateAnalyticsReport({
    required AnalyticsData analyticsData,
    required List<StudentPerformance> topStudents,
    required List<SubjectPerformance> subjectData,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document(
      title: 'OMR Analytics Report',
      author: institutionName,
      subject: 'Analytics Report',
      keywords: 'OMR, Analytics, Report',
    );

    // Build report content
    pdf.addPage(
      await _buildAnalyticsReportPage(
        analyticsData: analyticsData,
        topStudents: topStudents,
        subjectData: subjectData,
        startDate: startDate,
        endDate: endDate,
      ),
    );

    return pdf.save();
  }

  /// Generate student performance report
  static Future<Uint8List> generateStudentReport({
    required List<ExamSubmission> studentSubmissions,
    required String studentName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document(
      title: 'Student Performance Report - $studentName',
      author: institutionName,
    );

    pdf.addPage(
      await _buildStudentReportPage(
        submissions: studentSubmissions,
        studentName: studentName,
        startDate: startDate,
        endDate: endDate,
      ),
    );

    return pdf.save();
  }

  /// Generate class performance report
  static Future<Uint8List> generateClassReport({
    required List<ExamSubmission> allSubmissions,
    required String className,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document(
      title: 'Class Performance Report - $className',
      author: institutionName,
    );

    pdf.addPage(
      await _buildClassReportPage(
        submissions: allSubmissions,
        className: className,
        startDate: startDate,
        endDate: endDate,
      ),
    );

    return pdf.save();
  }

  /// Build main analytics report page
  static Future<pw.Page> _buildAnalyticsReportPage({
    required AnalyticsData analyticsData,
    required List<StudentPerformance> topStudents,
    required List<SubjectPerformance> subjectData,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          _buildReportHeader(
            title: 'OMR Analytics Report',
            subtitle: _buildDateRangeString(startDate, endDate),
          ),
          pw.SizedBox(height: 20),

          // Executive Summary
          _buildSectionHeader('Executive Summary'),
          pw.SizedBox(height: 10),
          _buildSummaryCards(analyticsData),
          pw.SizedBox(height: 20),

          // Performance Overview
          _buildSectionHeader('Performance Overview'),
          pw.SizedBox(height: 10),
          _buildPerformanceTable(analyticsData),
          pw.SizedBox(height: 20),

          // Top Students
          _buildSectionHeader('Top Performing Students'),
          pw.SizedBox(height: 10),
          _buildTopStudentsTable(topStudents.take(10).toList()),
          pw.SizedBox(height: 20),

          // Subject Performance
          _buildSectionHeader('Subject Performance Analysis'),
          pw.SizedBox(height: 10),
          _buildSubjectPerformanceTable(subjectData),
          pw.SizedBox(height: 20),

          // Footer
          pw.Spacer(),
          _buildReportFooter(),
        ],
      ),
    );
  }

  /// Build student report page
  static Future<pw.Page> _buildStudentReportPage({
    required List<ExamSubmission> submissions,
    required String studentName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          _buildReportHeader(
            title: 'Student Performance Report',
            subtitle: studentName,
          ),
          pw.SizedBox(height: 20),

          // Student Summary
          _buildSectionHeader('Student Summary'),
          pw.SizedBox(height: 10),
          _buildStudentSummary(submissions),
          pw.SizedBox(height: 20),

          // Exam History
          _buildSectionHeader('Exam History'),
          pw.SizedBox(height: 10),
          _buildExamHistoryTable(submissions),
          pw.SizedBox(height: 20),

          // Performance Trends
          _buildSectionHeader('Performance Trends'),
          pw.SizedBox(height: 10),
          _buildStudentTrendsChart(submissions),

          // Footer
          pw.Spacer(),
          _buildReportFooter(),
        ],
      ),
    );
  }

  /// Build class report page
  static Future<pw.Page> _buildClassReportPage({
    required List<ExamSubmission> submissions,
    required String className,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          _buildReportHeader(
            title: 'Class Performance Report',
            subtitle: className,
          ),
          pw.SizedBox(height: 20),

          // Class Summary
          _buildSectionHeader('Class Summary'),
          pw.SizedBox(height: 10),
          _buildClassSummary(submissions),
          pw.SizedBox(height: 20),

          // Student Performance
          _buildSectionHeader('Student Performance'),
          pw.SizedBox(height: 10),
          _buildClassStudentTable(submissions),

          // Footer
          pw.Spacer(),
          _buildReportFooter(),
        ],
      ),
    );
  }

  /// Build report header
  static pw.Widget _buildReportHeader({
    required String title,
    required String subtitle,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              subtitle,
              style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
            ),
          ],
        ),
        // Logo placeholder
        pw.Container(
          width: 60,
          height: 60,
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey300,
            shape: pw.BoxShape.circle,
          ),
          child: pw.Center(
            child: pw.Text(
              'LOGO',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
        ),
      ],
    );
  }

  /// Build section header
  static pw.Widget _buildSectionHeader(String title) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 20,
          color: const PdfColor.fromInt(0xFF2196F3),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  /// Build summary cards
  static pw.Widget _buildSummaryCards(AnalyticsData data) {
    return pw.Row(
      children: [
        _buildSummaryCard(
          'Total Submissions',
          data.totalSubmissions.toString(),
        ),
        pw.SizedBox(width: 16),
        _buildSummaryCard('Completed', data.completedSubmissions.toString()),
        pw.SizedBox(width: 16),
        _buildSummaryCard(
          'Average Score',
          '${data.averageScore.toStringAsFixed(1)}%',
        ),
      ],
    );
  }

  /// Build summary card
  static pw.Widget _buildSummaryCard(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF2196F3),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 12),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build performance table
  static pw.Widget _buildPerformanceTable(AnalyticsData data) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('Metric', isHeader: true),
            _buildTableCell('Value', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Total Submissions'),
            _buildTableCell(data.totalSubmissions.toString()),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Completed Submissions'),
            _buildTableCell(data.completedSubmissions.toString()),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Processing Submissions'),
            _buildTableCell(data.processingSubmissions.toString()),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Average Score'),
            _buildTableCell('${data.averageScore.toStringAsFixed(1)}%'),
          ],
        ),
      ],
    );
  }

  /// Build top students table
  static pw.Widget _buildTopStudentsTable(List<StudentPerformance> students) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('Rank', isHeader: true),
            _buildTableCell('Student Name', isHeader: true),
            _buildTableCell('Average Score', isHeader: true),
            _buildTableCell('Completed Exams', isHeader: true),
          ],
        ),
        ...students.asMap().entries.map((entry) {
          final index = entry.key;
          final student = entry.value;
          return pw.TableRow(
            children: [
              _buildTableCell('${index + 1}'),
              _buildTableCell(student.studentName),
              _buildTableCell('${student.averageScore.toStringAsFixed(1)}%'),
              _buildTableCell(student.completedExams.toString()),
            ],
          );
        }),
      ],
    );
  }

  /// Build subject performance table
  static pw.Widget _buildSubjectPerformanceTable(
    List<SubjectPerformance> subjects,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('Subject', isHeader: true),
            _buildTableCell('Average Score', isHeader: true),
            _buildTableCell('Submissions', isHeader: true),
          ],
        ),
        ...subjects.map(
          (subject) => pw.TableRow(
            children: [
              _buildTableCell(subject.subject),
              _buildTableCell('${subject.averageScore.toStringAsFixed(1)}%'),
              _buildTableCell(subject.totalSubmissions.toString()),
            ],
          ),
        ),
      ],
    );
  }

  /// Build student summary
  static pw.Widget _buildStudentSummary(List<ExamSubmission> submissions) {
    final completed = submissions.where((s) => s.isCompleted).length;
    final averageScore = submissions
        .where((s) => s.resultScore != null)
        .map((s) => (s.resultScore as num).toDouble())
        .fold<double>(0.0, (a, b) => a + b);

    return pw.Row(
      children: [
        _buildSummaryCard('Total Exams', submissions.length.toString()),
        pw.SizedBox(width: 16),
        _buildSummaryCard('Completed', completed.toString()),
        pw.SizedBox(width: 16),
        _buildSummaryCard(
          'Average Score',
          '${(averageScore / completed).toStringAsFixed(1)}%',
        ),
      ],
    );
  }

  /// Build exam history table
  static pw.Widget _buildExamHistoryTable(List<ExamSubmission> submissions) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('Date', isHeader: true),
            _buildTableCell('Status', isHeader: true),
            _buildTableCell('Score', isHeader: true),
            _buildTableCell('Subject', isHeader: true),
          ],
        ),
        ...submissions.map(
          (submission) => pw.TableRow(
            children: [
              _buildTableCell(
                submission.timestamp?.toString().split(' ').first ?? 'N/A',
              ),
              _buildTableCell(submission.displayStatus),
              _buildTableCell(
                submission.resultScore != null
                    ? '${submission.resultScore}%'
                    : 'N/A',
              ),
              _buildTableCell(submission.subject ?? 'N/A'),
            ],
          ),
        ),
      ],
    );
  }

  /// Build student trends chart (placeholder)
  static pw.Widget _buildStudentTrendsChart(List<ExamSubmission> submissions) {
    return pw.Container(
      height: 200,
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Center(
        child: pw.Text(
          'Performance Trend Chart',
          style: pw.TextStyle(color: PdfColors.grey600, fontSize: 16),
        ),
      ),
    );
  }

  /// Build class summary
  static pw.Widget _buildClassSummary(List<ExamSubmission> submissions) {
    final students = submissions.map((s) => s.studentName).toSet().length;
    final completed = submissions.where((s) => s.isCompleted).length;

    return pw.Row(
      children: [
        _buildSummaryCard('Total Students', students.toString()),
        pw.SizedBox(width: 16),
        _buildSummaryCard('Total Submissions', submissions.length.toString()),
        pw.SizedBox(width: 16),
        _buildSummaryCard('Completed', completed.toString()),
      ],
    );
  }

  /// Build class student table
  static pw.Widget _buildClassStudentTable(List<ExamSubmission> submissions) {
    final studentMap = <String, List<ExamSubmission>>{};

    for (final submission in submissions) {
      if (!studentMap.containsKey(submission.studentName)) {
        studentMap[submission.studentName] = [];
      }
      studentMap[submission.studentName]!.add(submission);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('Student Name', isHeader: true),
            _buildTableCell('Total Exams', isHeader: true),
            _buildTableCell('Average Score', isHeader: true),
            _buildTableCell('Status', isHeader: true),
          ],
        ),
        ...studentMap.entries.map((entry) {
          final studentName = entry.key;
          final submissions = entry.value;
          final scores = submissions
              .where((s) => s.resultScore != null)
              .map((s) => (s.resultScore as num).toDouble());
          final avgScore = scores.isNotEmpty
              ? scores.reduce((a, b) => a + b) / scores.length
              : 0.0;

          return pw.TableRow(
            children: [
              _buildTableCell(studentName),
              _buildTableCell(submissions.length.toString()),
              _buildTableCell('${avgScore.toStringAsFixed(1)}%'),
              _buildTableCell('Active'),
            ],
          );
        }),
      ],
    );
  }

  /// Build table cell
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Build report footer
  static pw.Widget _buildReportFooter() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(institutionName, style: const pw.TextStyle(fontSize: 10)),
            pw.Text(
              'Generated on ${DateTime.now().toString().split(' ').first}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  /// Build date range string
  static String _buildDateRangeString(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) {
      return 'All Time';
    }

    final start = startDate?.toString().split(' ').first ?? '';
    final end = endDate?.toString().split(' ').first ?? '';

    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start to $end';
    } else if (start.isNotEmpty) {
      return 'From $start';
    } else {
      return 'Until $end';
    }
  }

  /// Print PDF document
  static Future<void> printPDF(Uint8List pdfBytes) async {
    // Placeholder implementation - would integrate with printing package
    throw UnimplementedError('PDF printing not implemented');
  }

  /// Share PDF document
  static Future<void> sharePDF(Uint8List pdfBytes, String fileName) async {
    // This would integrate with the share_plus package
    // For now, it's a placeholder
    throw UnimplementedError('PDF sharing not implemented');
  }
}
