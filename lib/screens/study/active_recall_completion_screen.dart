import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/active_recall_models.dart';
import '../../models/study_analytics_models.dart';
import '../../widgets/analytics/insights_widget.dart';
import '../../widgets/analytics/recommendations_widget.dart';
import '../../widgets/analytics/study_plan_widget.dart';
import '../../widgets/analytics/performance_chart_widget.dart';

class ActiveRecallCompletionScreen extends StatelessWidget {
  final Course course;
  final Module module;
  final StudySessionResults sessionResults;
  final StudySessionAnalytics? sessionAnalytics;
  final VoidCallback onBackToModule;
  final VoidCallback onStudyAgain;

  const ActiveRecallCompletionScreen({
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
      body: Column(
        children: [
          // Hero Section
          _buildHeroSection(),
          
          // Content Section with Tabs
          Expanded(
            child: DefaultTabController(
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
          ),
          
          // Bottom Action Bar
          _buildActionBar(),
        ],
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
            Colors.green.withOpacity(0.1),
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
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.checkCircle,
              color: Colors.green,
              size: 40,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Title
          const Text(
            'Active Recall Complete!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'Great job on completing your ${module.title} study session',
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
                'Pre-Study',
                '${sessionResults.preStudyCorrect}/${sessionResults.totalFlashcards}',
                LucideIcons.alertCircle,
                Colors.orange,
              ),
              _buildQuickStat(
                'Post-Study',
                '${sessionResults.postStudyCorrect}/${sessionResults.totalFlashcards}',
                LucideIcons.checkCircle,
                Colors.green,
              ),
              _buildQuickStat(
                'Improvement',
                sessionResults.improvementPercentage > 0 
                    ? '+${sessionResults.improvementPercentage.toStringAsFixed(1)}%'
                    : '${sessionResults.improvementPercentage.toStringAsFixed(1)}%',
                LucideIcons.trendingUp,
                sessionResults.improvementPercentage > 0 ? Colors.green : Colors.red,
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
          _buildSummaryCard(
            'Session Overview',
            [
              _buildStat('Total Questions', '${sessionResults.totalFlashcards}'),
              _buildStat('Pre-Study Correct', '${sessionResults.preStudyCorrect}'),
              _buildStat('Post-Study Correct', '${sessionResults.postStudyCorrect}'),
              _buildStat('Learning Improvement', '${sessionResults.improvementPercentage.toStringAsFixed(1)}%'),
            ],
            Colors.blue,
          ),
          
          const SizedBox(height: 20),
          
          _buildSummaryCard(
            'Performance Analysis',
            [
              _buildStat('Pre-Study Accuracy', '${((sessionResults.preStudyCorrect / sessionResults.totalFlashcards) * 100).toStringAsFixed(1)}%'),
              _buildStat('Post-Study Accuracy', '${((sessionResults.postStudyCorrect / sessionResults.totalFlashcards) * 100).toStringAsFixed(1)}%'),
              _buildStat('Average Response Time', '${sessionResults.averageResponseTime.toStringAsFixed(1)}s'),
              _buildStat('Study Method', 'Active Recall'),
            ],
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    if (sessionAnalytics == null) {
      return _buildEmptyAnalytics();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // DESCRIPTIVE ANALYTICS SECTION
          _buildAnalyticsMainSection(
            title: 'Descriptive Analytics',
            subtitle: 'Data-driven insights about your study session',
            icon: LucideIcons.pieChart,
            color: Colors.blue,
            children: [
              // Performance Analytics
              _buildDescriptiveSection(
                title: 'Performance Analysis',
                icon: LucideIcons.barChart3,
                content: _buildPerformanceAnalysisContent(),
              ),
              
              const SizedBox(height: 16),
              
              // Behavior Analysis
              _buildDescriptiveSection(
                title: 'Learning Behavior',
                icon: LucideIcons.activity,
                content: _buildBehaviorAnalysisContent(),
              ),
              
              const SizedBox(height: 16),
              
              // Cognitive Analysis
              _buildDescriptiveSection(
                title: 'Cognitive Performance',
                icon: LucideIcons.brain,
                content: _buildCognitiveAnalysisContent(),
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
              // AI Insights
              if (sessionAnalytics!.insights.isNotEmpty) ...[ 
                _buildPrescriptiveSection(
                  title: 'AI-Generated Insights',
                  icon: LucideIcons.lightbulb,
                  content: InsightsWidget(
                    insights: sessionAnalytics!.insights,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Actionable Recommendations
              if (sessionAnalytics!.recommendations.isNotEmpty) ...[ 
                _buildPrescriptiveSection(
                  title: 'Personalized Recommendations',
                  icon: LucideIcons.checkSquare,
                  content: RecommendationsWidget(
                    recommendations: sessionAnalytics!.recommendations,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Study Plan (Next Steps)
              _buildPrescriptiveSection(
                title: 'Recommended Next Steps',
                icon: LucideIcons.calendar,
                content: StudyPlanWidget(
                  studyPlan: sessionAnalytics!.suggestedStudyPlan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAnalytics() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              'Unable to generate detailed analytics for this session.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.grey200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
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
                label: const Text('Study Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for analytics content
  Widget _buildAnalyticsMainSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main section header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: color),
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
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Content area
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: children,
            ),
          ),
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
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
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
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, List<Widget> stats, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.barChart3, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
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
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // Analytics content builders
  Widget _buildPerformanceAnalysisContent() {
    if (sessionAnalytics != null) {
      return PerformanceChartWidget(
        performanceMetrics: sessionAnalytics!.performanceMetrics,
        showDetails: true,
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnalyticsRow('Pre-Study Accuracy', '${((sessionResults.preStudyCorrect / sessionResults.totalFlashcards) * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Post-Study Accuracy', '${((sessionResults.postStudyCorrect / sessionResults.totalFlashcards) * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Improvement', '${sessionResults.improvementPercentage.toStringAsFixed(1)}%'),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Response Time', '${sessionResults.averageResponseTime.toStringAsFixed(1)}s avg'),
      ],
    );
  }

  Widget _buildBehaviorAnalysisContent() {
    if (sessionAnalytics == null) return const SizedBox.shrink();
    
    final behavior = sessionAnalytics!.behaviorAnalysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnalyticsRow('Engagement Level', '${(behavior.engagementLevel * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Persistence Score', '${(behavior.persistenceScore * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Total Study Time', '${behavior.totalStudyTime.inMinutes} minutes'),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Hint Usage', '${behavior.hintUsageCount}'),
        if (behavior.commonErrorTypes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Common Error Patterns:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...behavior.commonErrorTypes.map((error) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '• $error', 
              style: const TextStyle(fontSize: 13),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildCognitiveAnalysisContent() {
    if (sessionAnalytics == null) return const SizedBox.shrink();
    
    final cognitive = sessionAnalytics!.cognitiveAnalysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnalyticsRow('Cognitive Load Score', '${cognitive.cognitiveLoadScore.toStringAsFixed(1)}/10'),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Processing Speed', '${cognitive.processingSpeed.toStringAsFixed(2)}s avg'),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Attention Span', '${cognitive.attentionSpan.toStringAsFixed(1)} minutes'),
        if (cognitive.cognitiveStrengths.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Cognitive Strengths:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...cognitive.cognitiveStrengths.map((strength) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '• $strength', 
              style: const TextStyle(fontSize: 13),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          )),
        ],
        if (cognitive.cognitiveWeaknesses.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Areas for Improvement:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...cognitive.cognitiveWeaknesses.map((weakness) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '• $weakness', 
              style: const TextStyle(fontSize: 13),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildAnalyticsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13, 
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }
}