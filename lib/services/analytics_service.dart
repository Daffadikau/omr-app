import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/exam_submission.dart';

class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get analytics data for dashboard
  static Future<AnalyticsData> getAnalyticsData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final defaultStart = startDate ?? DateTime(now.year, now.month, 1);
      final defaultEnd = endDate ?? now;

      // Convert DateTime to Timestamp for Firestore queries
      final startTimestamp = Timestamp.fromDate(defaultStart);
      final endTimestamp = Timestamp.fromDate(defaultEnd);

      // Get submissions in date range
      final submissionsQuery = await _firestore
          .collection('exam_scans')
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .get();

      final submissions = submissionsQuery.docs
          .map((doc) => ExamSubmission.fromSnapshot(doc))
          .toList();

      // Calculate analytics
      final totalSubmissions = submissions.length;
      final completedSubmissions = submissions
          .where((s) => s.status == 'completed')
          .length;
      final processingSubmissions = submissions
          .where((s) => s.status == 'processing')
          .length;

      // Calculate average score
      final scores = submissions
          .where((s) => s.resultScore != null)
          .map((s) => (s.resultScore as num).toDouble())
          .toList();

      final averageScore = scores.isNotEmpty
          ? scores.reduce((a, b) => a + b) / scores.length
          : 0.0;

      // Generate daily chart data
      final dailyData = _generateDailyData(
        submissions,
        defaultStart,
        defaultEnd,
      );

      // Generate subject performance data
      final subjectData = _generateSubjectData(submissions);

      return AnalyticsData(
        totalSubmissions: totalSubmissions,
        completedSubmissions: completedSubmissions,
        processingSubmissions: processingSubmissions,
        averageScore: averageScore,
        dailyData: dailyData,
        subjectData: subjectData,
        period:
            '${DateFormat('MMM dd').format(defaultStart)} - ${DateFormat('MMM dd').format(defaultEnd)}',
      );
    } catch (e) {
      throw Exception('Failed to load analytics: $e');
    }
  }

  // Generate daily submission data for chart
  static List<FlSpot> _generateDailyData(
    List<ExamSubmission> submissions,
    DateTime startDate,
    DateTime endDate,
  ) {
    final Map<String, int> dailyCounts = {};

    // Initialize all days with 0
    for (
      DateTime date = startDate;
      date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
      date = date.add(const Duration(days: 1))
    ) {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      dailyCounts[dateKey] = 0;
    }

    // Count submissions per day
    for (final submission in submissions) {
      final timestamp = (submission.timestamp as Timestamp?)?.toDate();
      if (timestamp != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);
        dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
      }
    }

    // Convert to chart data
    return dailyCounts.entries.map((entry) {
      final date = DateFormat('yyyy-MM-dd').parse(entry.key);
      final dayOfMonth = date.day.toDouble();
      final count = entry.value.toDouble();
      return FlSpot(dayOfMonth, count);
    }).toList();
  }

  // Generate subject performance data
  static List<SubjectPerformance> _generateSubjectData(
    List<ExamSubmission> submissions,
  ) {
    final Map<String, List<double>> subjectScores = {};

    // Group scores by subject
    for (final submission in submissions) {
      final subject = submission.subject ?? 'General'; // Default to 'General'
      final score = submission.resultScore;

      if (score != null) {
        subjectScores.putIfAbsent(subject, () => []);
        subjectScores[subject]!.add((score as num).toDouble());
      }
    }

    // Calculate average scores per subject
    return subjectScores.entries.map((entry) {
      final scores = entry.value;
      final averageScore = scores.isNotEmpty
          ? scores.reduce((a, b) => a + b) / scores.length
          : 0.0;

      return SubjectPerformance(
        subject: entry.key,
        averageScore: averageScore,
        totalSubmissions: scores.length,
      );
    }).toList()..sort((a, b) => b.averageScore.compareTo(a.averageScore));
  }

  // Get top performing students
  static Future<List<StudentPerformance>> getTopStudents({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final defaultStart = startDate ?? DateTime(now.year, now.month, 1);
      final defaultEnd = endDate ?? now;

      // Convert DateTime to Timestamp for Firestore queries
      final startTimestamp = Timestamp.fromDate(defaultStart);
      final endTimestamp = Timestamp.fromDate(defaultEnd);

      final submissionsQuery = await _firestore
          .collection('exam_scans')
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .get();

      final submissions = submissionsQuery.docs
          .map((doc) => ExamSubmission.fromSnapshot(doc))
          .toList();

      // Group by student
      final Map<String, List<ExamSubmission>> studentSubmissions = {};
      for (final submission in submissions) {
        studentSubmissions
            .putIfAbsent(submission.studentName, () => [])
            .add(submission);
      }

      // Calculate performance per student
      final List<StudentPerformance> students = [];
      for (final entry in studentSubmissions.entries) {
        final studentSubmissions = entry.value;
        final scores = studentSubmissions
            .where((s) => s.resultScore != null)
            .map((s) => (s.resultScore as num).toDouble())
            .toList();

        if (scores.isNotEmpty) {
          final averageScore = scores.reduce((a, b) => a + b) / scores.length;
          students.add(
            StudentPerformance(
              studentName: entry.key,
              averageScore: averageScore,
              totalExams: studentSubmissions.length,
              completedExams: scores.length,
            ),
          );
        }
      }

      // Sort by average score and return top students
      students.sort((a, b) => b.averageScore.compareTo(a.averageScore));
      return students.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to load student performance: $e');
    }
  }
}

// Analytics data model
class AnalyticsData {
  final int totalSubmissions;
  final int completedSubmissions;
  final int processingSubmissions;
  final double averageScore;
  final List<FlSpot> dailyData;
  final List<SubjectPerformance> subjectData;
  final String period;

  AnalyticsData({
    required this.totalSubmissions,
    required this.completedSubmissions,
    required this.processingSubmissions,
    required this.averageScore,
    required this.dailyData,
    required this.subjectData,
    required this.period,
  });
}

// Subject performance model
class SubjectPerformance {
  final String subject;
  final double averageScore;
  final int totalSubmissions;

  SubjectPerformance({
    required this.subject,
    required this.averageScore,
    required this.totalSubmissions,
  });
}

// Student performance model
class StudentPerformance {
  final String studentName;
  final double averageScore;
  final int totalExams;
  final int completedExams;

  StudentPerformance({
    required this.studentName,
    required this.averageScore,
    required this.totalExams,
    required this.completedExams,
  });
}
