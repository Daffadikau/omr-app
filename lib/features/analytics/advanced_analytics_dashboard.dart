import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/analytics_service.dart';
import '../../models/exam_submission.dart';

class AdvancedAnalyticsDashboard extends StatefulWidget {
  const AdvancedAnalyticsDashboard({super.key});

  @override
  State<AdvancedAnalyticsDashboard> createState() =>
      _AdvancedAnalyticsDashboardState();
}

class _AdvancedAnalyticsDashboardState extends State<AdvancedAnalyticsDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  AnalyticsData? _analyticsData;
  List<StudentPerformance> _topStudents = [];
  List<SubjectPerformance> _subjectData = [];

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final data = await AnalyticsService.getAnalyticsData(
        startDate: _startDate,
        endDate: _endDate,
      );

      final students = await AnalyticsService.getTopStudents(
        startDate: _startDate,
        endDate: _endDate,
        limit: 20,
      );

      setState(() {
        _analyticsData = data;
        _topStudents = students;
        _subjectData = data.subjectData;
        _fadeController.forward();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load analytics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAnalytics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Analytics'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.analytics), text: 'Performance'),
            Tab(icon: Icon(Icons.people), text: 'Students'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Subjects'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildPerformanceTab(),
                  _buildStudentsTab(),
                  _buildSubjectsTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewTab() {
    if (_analyticsData == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics Cards
          _buildKeyMetricsCards(),
          const SizedBox(height: 24),

          // Daily Trends Chart
          _buildDailyTrendsChart(),
          const SizedBox(height: 24),

          // Grade Distribution
          _buildGradeDistributionChart(),
        ],
      ),
    );
  }

  Widget _buildKeyMetricsCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Submissions',
          _analyticsData!.totalSubmissions.toString(),
          Icons.assignment,
          Colors.blue,
        ),
        _buildMetricCard(
          'Completed',
          _analyticsData!.completedSubmissions.toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildMetricCard(
          'Processing',
          _analyticsData!.processingSubmissions.toString(),
          Icons.hourglass_empty,
          Colors.orange,
        ),
        _buildMetricCard(
          'Avg Score',
          '${_analyticsData!.averageScore.toStringAsFixed(1)}%',
          Icons.trending_up,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTrendsChart() {
    if (_analyticsData!.dailyData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.show_chart, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text('No daily data available'),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Submission Trends',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _analyticsData!.dailyData,
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY:
                      _analyticsData!.dailyData
                          .map((e) => e.y)
                          .reduce((a, b) => a > b ? a : b) +
                      1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeDistributionChart() {
    if (_subjectData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.pie_chart, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text('No grade distribution data available'),
            ],
          ),
        ),
      );
    }

    // Calculate grade distribution
    final gradeDistribution = <String, int>{
      'Excellent (90-100)': 0,
      'Good (80-89)': 0,
      'Average (70-79)': 0,
      'Below Average (60-69)': 0,
      'Poor (<60)': 0,
    };

    for (final subject in _subjectData) {
      final score = subject.averageScore;
      if (score >= 90) {
        gradeDistribution['Excellent (90-100)'] =
            gradeDistribution['Excellent (90-100)']! + 1;
      } else if (score >= 80)
        gradeDistribution['Good (80-89)'] =
            gradeDistribution['Good (80-89)']! + 1;
      else if (score >= 70)
        gradeDistribution['Average (70-79)'] =
            gradeDistribution['Average (70-79)']! + 1;
      else if (score >= 60)
        gradeDistribution['Below Average (60-69)'] =
            gradeDistribution['Below Average (60-69)']! + 1;
      else
        gradeDistribution['Poor (<60)'] = gradeDistribution['Poor (<60)']! + 1;
    }

    final pieData = gradeDistribution.entries
        .where((entry) => entry.value > 0)
        .toList();

    final sections = pieData.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final isSelected = index == 0;
      final double radius = isSelected ? 60 : 50;

      return PieChartSectionData(
        color: _getGradeColor(item.key),
        value: item.value.toDouble(),
        title: '${item.value}',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titlePositionPercentageOffset: 0.5,
      );
    }).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grade Distribution',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Performance Metrics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildPerformanceMetric(
                    'Average Score',
                    '${_analyticsData?.averageScore.toStringAsFixed(1) ?? '0'}%',
                  ),
                  _buildPerformanceMetric(
                    'Completion Rate',
                    '${_getCompletionRate().toStringAsFixed(1)}%',
                  ),
                  _buildPerformanceMetric(
                    'Processing Rate',
                    '${_getProcessingRate().toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsTab() {
    if (_topStudents.isEmpty) {
      return const Center(child: Text('No student data available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _topStudents.length,
      itemBuilder: (context, index) {
        final student = _topStudents[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: _buildStudentRankIcon(index + 1),
            title: Text(student.studentName),
            subtitle: Text('${student.completedExams} exams completed'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${student.averageScore.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(student.averageScore),
                  ),
                ),
                Text('Avg Score', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentRankIcon(int rank) {
    Color color;
    IconData icon;

    switch (rank) {
      case 1:
        color = Colors.amber;
        icon = Icons.emoji_events;
        break;
      case 2:
        color = Colors.grey;
        icon = Icons.emoji_events;
        break;
      case 3:
        color = Colors.brown;
        icon = Icons.emoji_events;
        break;
      default:
        color = Theme.of(context).primaryColor;
        icon = Icons.person;
    }

    return CircleAvatar(
      backgroundColor: color,
      child: Icon(icon, color: Colors.white),
    );
  }

  Widget _buildSubjectsTab() {
    if (_subjectData.isEmpty) {
      return const Center(child: Text('No subject data available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjectData.length,
      itemBuilder: (context, index) {
        final subject = _subjectData[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      subject.subject,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${subject.averageScore.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(subject.averageScore),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: subject.averageScore / 100,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getScoreColor(subject.averageScore),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${subject.totalSubmissions} submissions',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _getCompletionRate() {
    if (_analyticsData == null) return 0.0;
    final total = _analyticsData!.totalSubmissions;
    if (total == 0) return 0.0;
    return (_analyticsData!.completedSubmissions / total) * 100;
  }

  double _getProcessingRate() {
    if (_analyticsData == null) return 0.0;
    final total = _analyticsData!.totalSubmissions;
    if (total == 0) return 0.0;
    return (_analyticsData!.processingSubmissions / total) * 100;
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 80) return Colors.blue;
    if (score >= 70) return Colors.orange;
    if (score >= 60) return Colors.amber;
    return Colors.red;
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'Excellent (90-100)':
        return Colors.green;
      case 'Good (80-89)':
        return Colors.blue;
      case 'Average (70-79)':
        return Colors.orange;
      case 'Below Average (60-69)':
        return Colors.amber;
      case 'Poor (<60)':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
