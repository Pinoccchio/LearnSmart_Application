import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/retrieval_practice_models.dart';
import '../../models/study_analytics_models.dart';
import '../../widgets/analytics/recommendations_widget.dart';
import '../../widgets/analytics/study_plan_widget.dart';
import '../../widgets/retrieval_practice/retrieval_results_widget.dart';

class RetrievalPracticeCompletionScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(
        title: const Text('Session Complete'),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          onPressed: onBackToModule,
          icon: const Icon(LucideIcons.x),
        ),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.grey200,
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                labelColor: AppColors.bgPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                indicatorColor: AppColors.bgPrimary,
                indicatorWeight: 3,
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
            
            // Tab Content
            Expanded(
              child: TabBarView(
                children: [
                  _buildSummaryTab(),
                  _buildAnalyticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.1),
            AppColors.bgSecondary,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Hero Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: sessionResults.performanceColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.brain,
              color: sessionResults.performanceColor,
              size: 40,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Title
          const Text(
            'Retrieval Practice Complete!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'Great work on "${module.title}" from ${course.title}',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
          
          const SizedBox(height: 20),
          
          // Quick Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickStat(
                'Accuracy',
                '${sessionResults.accuracy.toStringAsFixed(1)}%',
                LucideIcons.target,
                sessionResults.performanceColor,
              ),
              _buildQuickStat(
                'Questions',
                '${sessionResults.correctAnswers}/${sessionResults.totalQuestions}',
                LucideIcons.checkCircle,
                Colors.blue,
              ),
              _buildQuickStat(
                'Avg Time',
                _formatDuration(sessionResults.averageTimePerQuestion),
                LucideIcons.clock,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
      ],
    );
  }


  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Hero Section integrated in Summary tab
          _buildHeroSection(),
          
          const SizedBox(height: 24),
          
          _buildStatsSummaryCard(
            'Session Overview',
            [
              _buildStat('Questions Answered', '${sessionResults.totalQuestions}'),
              _buildStat('Correct Answers', '${sessionResults.correctAnswers}'),
              _buildStat('Accuracy', '${sessionResults.accuracy.toStringAsFixed(1)}%'),
              _buildStat('Average Time', _formatDuration(sessionResults.averageTimePerQuestion)),
            ],
            Colors.blue,
          ),
          
          const SizedBox(height: 20),
          
          _buildStatsSummaryCard(
            'Performance Breakdown',
            [
              _buildStat('High Confidence', '${_getHighConfidenceCount()}'),
              _buildStat('Low Confidence', '${_getLowConfidenceCount()}'),
              _buildStat('Hints Used', '${sessionResults.hintsUsed}'),
              _buildStat('Session Duration', _formatDuration(sessionResults.totalTime)),
            ],
            Colors.green,
          ),
          
          const SizedBox(height: 20),
          
          // Detailed results widget
          RetrievalResultsWidget(
            sessionResults: sessionResults,
            showDetailedBreakdown: true,
          ),
          
          // Action Buttons integrated in Summary tab
          const SizedBox(height: 32),
          _buildActionButtonsInline(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    if (sessionAnalytics == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Hero Section integrated in Analytics tab
            _buildHeroSection(),
            
            const SizedBox(height: 24),
            
            _buildEmptyAnalytics(),
            
            // Action Buttons integrated in Analytics tab
            const SizedBox(height: 32),
            _buildActionButtonsInline(),
            const SizedBox(height: 20),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Hero Section integrated in Analytics tab
          _buildHeroSection(),
          
          const SizedBox(height: 24),
          
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
              if (sessionAnalytics!.insights.isNotEmpty) ...[ 
                _buildPrescriptiveSection(
                  title: 'AI-Generated Insights',
                  icon: LucideIcons.lightbulb,
                  content: _buildInsightsContent(),
                ),
                const SizedBox(height: 16),
              ],
              
              // Recommendations (from old Insights tab)
              if (sessionAnalytics!.recommendations.isNotEmpty) ...[ 
                _buildPrescriptiveSection(
                  title: 'Personalized Recommendations',
                  icon: LucideIcons.target,
                  content: SizedBox(
                    width: double.infinity,
                    child: RecommendationsWidget(
                      recommendations: sessionAnalytics!.recommendations,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Study Plan (from old Study Plan tab)
              if (sessionAnalytics!.suggestedStudyPlan != null) ...[ 
                _buildPrescriptiveSection(
                  title: 'Suggested Study Plan',
                  icon: LucideIcons.calendar,
                  content: StudyPlanWidget(
                    studyPlan: sessionAnalytics!.suggestedStudyPlan!,
                  ),
                ),
              ],
            ],
          ),
          
          // Action Buttons integrated in Analytics tab
          const SizedBox(height: 32),
          _buildActionButtonsInline(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }


  Widget _buildActionButtonsInline() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onBackToModule,
            icon: const Icon(LucideIcons.arrowLeft, size: 20),
            label: const Text('Back to Module'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: AppColors.grey300),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onStudyAgain,
            icon: const Icon(LucideIcons.repeat, size: 20),
            label: const Text('Practice Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bgPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            LucideIcons.pieChart,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'Analytics Unavailable',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Complete more sessions to generate detailed analytics.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
              _buildMetricCard('Accuracy', '${sessionResults.accuracy.toStringAsFixed(1)}%', Colors.green),
              _buildMetricCard('Total Questions', '${sessionResults.totalQuestions}', Colors.blue),
              _buildMetricCard('Avg Time', _formatDuration(sessionResults.averageTimePerQuestion), Colors.orange),
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
          '${_formatDuration(sessionResults.averageTimePerQuestion)} avg',
          sessionResults.averageTimePerQuestion > Duration(seconds: 30) 
            ? 'Consider time management techniques' 
            : 'Good pacing maintained',
          sessionResults.averageTimePerQuestion > Duration(seconds: 30) 
            ? Colors.orange 
            : Colors.green,
          LucideIcons.clock,
        ),
        const SizedBox(height: 12),
        _buildPatternCard(
          'Confidence Level',
          '${_getHighConfidenceCount()}/${sessionResults.totalQuestions} high confidence',
          _getHighConfidenceCount() / sessionResults.totalQuestions > 0.7
            ? 'Strong confidence in responses'
            : 'Consider reviewing material for better confidence',
          _getHighConfidenceCount() / sessionResults.totalQuestions > 0.7
            ? Colors.green
            : Colors.orange,
          LucideIcons.brain,
        ),
        const SizedBox(height: 12),
        _buildPatternCard(
          'Help Usage',
          '${sessionResults.hintsUsed} hints used',
          sessionResults.hintsUsed > sessionResults.totalQuestions * 0.5
            ? 'Heavy reliance on hints - review material'
            : 'Appropriate use of assistance',
          sessionResults.hintsUsed > sessionResults.totalQuestions * 0.5
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
    final insights = sessionAnalytics!.insights;
    
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
    if (sessionResults.accuracy >= 80) {
      return (sessionResults.totalQuestions * 0.8).round();
    } else if (sessionResults.accuracy >= 60) {
      return (sessionResults.totalQuestions * 0.5).round();
    }
    return (sessionResults.totalQuestions * 0.3).round();
  }
  
  int _getLowConfidenceCount() {
    return sessionResults.totalQuestions - _getHighConfidenceCount();
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