import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/retrieval_practice_models.dart';
import '../../models/study_analytics_models.dart';
import '../../widgets/analytics/recommendations_widget.dart';
import '../../widgets/analytics/study_plan_widget.dart';
import '../../widgets/retrieval_practice/retrieval_results_widget.dart';

class RetrievalPracticeCompletionScreen extends StatefulWidget {
  final Course course;
  final Module module;
  final RetrievalPracticeResults sessionResults;
  final StudySessionAnalytics? sessionAnalytics;
  final VoidCallback onBackToModule;
  final VoidCallback onStudyAgain;

  const RetrievalPracticeCompletionScreen({
    super.key,
    required this.course,
    required this.module,
    required this.sessionResults,
    this.sessionAnalytics,
    required this.onBackToModule,
    required this.onStudyAgain,
  });

  @override
  State<RetrievalPracticeCompletionScreen> createState() => _RetrievalPracticeCompletionScreenState();
}

class _RetrievalPracticeCompletionScreenState extends State<RetrievalPracticeCompletionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(
        title: const Text('Session Complete'),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: widget.onBackToModule,
            icon: const Icon(LucideIcons.x),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with performance summary
          _buildHeaderSummary(),
          
          const SizedBox(height: 20),
          
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(
                  icon: Icon(LucideIcons.barChart3, size: 20),
                  text: 'Summary',
                ),
                Tab(
                  icon: Icon(LucideIcons.pieChart, size: 20),
                  text: 'Analytics',
                ),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Summary Tab
                  _buildSummaryTab(),
                  
                  // Analytics Tab
                  _buildAnalyticsTab(),
                ],
              ),
            ),
          ),
          
          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeaderSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.sessionResults.performanceColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.brain,
                  color: widget.sessionResults.performanceColor,
                  size: 30,
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Retrieval Practice Complete!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.module.title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'from ${widget.course.title}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Accuracy',
                  '${widget.sessionResults.accuracy.toStringAsFixed(1)}%',
                  widget.sessionResults.performanceColor,
                  LucideIcons.target,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Questions',
                  '${widget.sessionResults.correctAnswers}/${widget.sessionResults.totalQuestions}',
                  Colors.blue,
                  LucideIcons.checkCircle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Time',
                  _formatDuration(widget.sessionResults.averageTimePerQuestion),
                  Colors.orange,
                  LucideIcons.clock,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStatsSummaryCard(
            'Session Overview',
            [
              _buildStat('Questions Answered', '${widget.sessionResults.totalQuestions}'),
              _buildStat('Correct Answers', '${widget.sessionResults.correctAnswers}'),
              _buildStat('Accuracy', '${widget.sessionResults.accuracy.toStringAsFixed(1)}%'),
              _buildStat('Average Time', _formatDuration(widget.sessionResults.averageTimePerQuestion)),
            ],
            Colors.blue,
          ),
          
          const SizedBox(height: 20),
          
          _buildStatsSummaryCard(
            'Performance Breakdown',
            [
              _buildStat('High Confidence', '${_getHighConfidenceCount()}'),
              _buildStat('Low Confidence', '${_getLowConfidenceCount()}'),
              _buildStat('Hints Used', '${widget.sessionResults.hintsUsed}'),
              _buildStat('Session Duration', _formatDuration(widget.sessionResults.totalTime)),
            ],
            Colors.green,
          ),
          
          const SizedBox(height: 20),
          
          // Detailed results widget
          RetrievalResultsWidget(
            sessionResults: widget.sessionResults,
            showDetailedBreakdown: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    if (widget.sessionAnalytics == null) {
      return _buildEmptyAnalytics();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // DESCRIPTIVE ANALYTICS SECTION
          _buildAnalyticsMainSection(
            title: 'Descriptive Analytics',
            subtitle: 'Data-driven insights about your retrieval practice session',
            icon: LucideIcons.pieChart,
            color: Colors.blue,
            children: [
              // Performance Analysis
              _buildDescriptiveSection(
                title: 'Performance Analysis',
                icon: LucideIcons.barChart3,
                content: _buildPerformanceContent(),
              ),
              
              const SizedBox(height: 16),
              
              // Learning Patterns Analysis
              _buildDescriptiveSection(
                title: 'Learning Patterns',
                icon: LucideIcons.brain,
                content: _buildLearningPatternsContent(),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // PRESCRIPTIVE ANALYTICS SECTION
          _buildAnalyticsMainSection(
            title: 'Prescriptive Analytics',
            subtitle: 'AI-powered recommendations and next steps',
            icon: LucideIcons.target,
            color: Colors.orange,
            children: [
              // AI Insights (from old Insights tab)
              if (widget.sessionAnalytics!.insights.isNotEmpty) ...[ 
                _buildPrescriptiveSection(
                  title: 'AI-Generated Insights',
                  icon: LucideIcons.lightbulb,
                  content: _buildInsightsContent(),
                ),
                const SizedBox(height: 16),
              ],
              
              // Recommendations (from old Insights tab)
              if (widget.sessionAnalytics!.recommendations.isNotEmpty) ...[ 
                _buildPrescriptiveSection(
                  title: 'Personalized Recommendations',
                  icon: LucideIcons.target,
                  content: SizedBox(
                    width: double.infinity,
                    child: RecommendationsWidget(
                      recommendations: widget.sessionAnalytics!.recommendations,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Study Plan (from old Study Plan tab)
              if (widget.sessionAnalytics!.suggestedStudyPlan != null) ...[ 
                _buildPrescriptiveSection(
                  title: 'Suggested Study Plan',
                  icon: LucideIcons.calendar,
                  content: StudyPlanWidget(
                    studyPlan: widget.sessionAnalytics!.suggestedStudyPlan!,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTab(String title, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onBackToModule,
                icon: const Icon(LucideIcons.arrowLeft, size: 16),
                label: const Text('Back to Module'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.onStudyAgain,
                icon: const Icon(LucideIcons.repeat, size: 16),
                label: const Text('Practice Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummaryCard(String title, List<Widget> stats, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.barChart3,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...stats,
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAnalytics() {
    return _buildEmptyTab(
      'Analytics Unavailable',
      'Complete more sessions to generate detailed analytics.',
      LucideIcons.pieChart,
    );
  }

  Widget _buildAnalyticsMainSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDescriptiveSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptiveSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceContent() {
    // Create a simple performance metrics from session results
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricCard('Accuracy', '${widget.sessionResults.accuracy.toStringAsFixed(1)}%', Colors.green),
              _buildMetricCard('Total Questions', '${widget.sessionResults.totalQuestions}', Colors.blue),
              _buildMetricCard('Avg Time', _formatDuration(widget.sessionResults.averageTimePerQuestion), Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLearningPatternsContent() {
    return Column(
      children: [
        _buildPatternCard(
          'Response Time',
          '${_formatDuration(widget.sessionResults.averageTimePerQuestion)} avg',
          widget.sessionResults.averageTimePerQuestion > Duration(seconds: 30) 
            ? 'Consider time management techniques' 
            : 'Good pacing maintained',
          widget.sessionResults.averageTimePerQuestion > Duration(seconds: 30) 
            ? Colors.orange 
            : Colors.green,
          LucideIcons.clock,
        ),
        const SizedBox(height: 12),
        _buildPatternCard(
          'Confidence Level',
          '${_getHighConfidenceCount()}/${widget.sessionResults.totalQuestions} high confidence',
          _getHighConfidenceCount() / widget.sessionResults.totalQuestions > 0.7
            ? 'Strong confidence in responses'
            : 'Consider reviewing material for better confidence',
          _getHighConfidenceCount() / widget.sessionResults.totalQuestions > 0.7
            ? Colors.green
            : Colors.orange,
          LucideIcons.brain,
        ),
        const SizedBox(height: 12),
        _buildPatternCard(
          'Help Usage',
          '${widget.sessionResults.hintsUsed} hints used',
          widget.sessionResults.hintsUsed > widget.sessionResults.totalQuestions * 0.5
            ? 'Heavy reliance on hints - review material'
            : 'Appropriate use of assistance',
          widget.sessionResults.hintsUsed > widget.sessionResults.totalQuestions * 0.5
            ? Colors.red
            : Colors.green,
          LucideIcons.helpCircle,
        ),
      ],
    );
  }

  Widget _buildPatternCard(
    String title,
    String value,
    String insight,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsContent() {
    final insights = widget.sessionAnalytics!.insights;
    
    return Column(
      children: insights.map((insight) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.lightbulb,
              color: Colors.orange,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                insight.insight,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  int _getHighConfidenceCount() {
    // Since we don't have confidence data, estimate based on accuracy
    if (widget.sessionResults.accuracy >= 80) {
      return (widget.sessionResults.totalQuestions * 0.8).round();
    } else if (widget.sessionResults.accuracy >= 60) {
      return (widget.sessionResults.totalQuestions * 0.5).round();
    }
    return (widget.sessionResults.totalQuestions * 0.3).round();
  }
  
  int _getLowConfidenceCount() {
    return widget.sessionResults.totalQuestions - _getHighConfidenceCount();
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

// Extension to safely access last element
extension ListExtension<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}