import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/retrieval_practice_models.dart';
import '../../models/study_analytics_models.dart';
import '../../widgets/analytics/performance_chart_widget.dart';
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
    _tabController = TabController(length: 4, vsync: this);
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
                  icon: Icon(LucideIcons.barChart3, size: 16),
                  text: 'Results',
                ),
                Tab(
                  icon: Icon(LucideIcons.pieChart, size: 16),
                  text: 'Analytics',
                ),
                Tab(
                  icon: Icon(LucideIcons.target, size: 16),
                  text: 'Insights',
                ),
                Tab(
                  icon: Icon(LucideIcons.calendar, size: 16),
                  text: 'Study Plan',
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
                  // Results Tab
                  _buildResultsTab(),
                  
                  // Analytics Tab
                  _buildAnalyticsTab(),
                  
                  // Insights Tab
                  _buildInsightsTab(),
                  
                  // Study Plan Tab
                  _buildStudyPlanTab(),
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

  Widget _buildResultsTab() {
    return SingleChildScrollView(
      child: RetrievalResultsWidget(
        sessionResults: widget.sessionResults,
        showDetailedBreakdown: true,
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    if (widget.sessionAnalytics != null) {
      return SingleChildScrollView(
        child: PerformanceChartWidget(
          performanceMetrics: widget.sessionAnalytics!.performanceMetrics,
          showDetails: true,
        ),
      );
    }
    
    return _buildEmptyTab(
      'Analytics Unavailable',
      'Unable to generate detailed analytics for this session.',
      LucideIcons.pieChart,
    );
  }

  Widget _buildInsightsTab() {
    if (widget.sessionAnalytics?.recommendations.isNotEmpty == true) {
      return SingleChildScrollView(
        child: RecommendationsWidget(
          recommendations: widget.sessionAnalytics!.recommendations,
        ),
      );
    }
    
    return _buildEmptyTab(
      'Insights Unavailable',
      'Unable to generate insights for this session.',
      LucideIcons.target,
    );
  }

  Widget _buildStudyPlanTab() {
    if (widget.sessionAnalytics?.suggestedStudyPlan != null) {
      return SingleChildScrollView(
        child: StudyPlanWidget(
          studyPlan: widget.sessionAnalytics!.suggestedStudyPlan,
        ),
      );
    }
    
    return _buildEmptyTab(
      'Study Plan Unavailable',
      'Unable to generate study plan recommendations.',
      LucideIcons.calendar,
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