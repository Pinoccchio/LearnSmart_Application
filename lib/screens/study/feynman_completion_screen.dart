import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/feynman_models.dart';
import '../../models/study_analytics_models.dart';
import '../../widgets/analytics/insights_widget.dart';
import '../../widgets/analytics/recommendations_widget.dart';
import '../../widgets/analytics/study_plan_widget.dart';

class FeynmanCompletionScreen extends StatelessWidget {
  final Course course;
  final Module module;
  final FeynmanSessionResults sessionResults;
  final StudySessionAnalytics? sessionAnalytics;
  final VoidCallback onBackToModule;
  final VoidCallback onStudyAgain;

  const FeynmanCompletionScreen({
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
              color: Colors.purple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.graduationCap,
              color: Colors.purple,
              size: 40,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Title
          const Text(
            'Feynman Session Complete!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'Excellent work explaining "${module.title}" concepts',
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
                'Attempts',
                '${sessionResults.totalExplanations}',
                LucideIcons.edit,
                Colors.blue,
              ),
              _buildQuickStat(
                'Avg Score',
                sessionResults.averageScore != null 
                  ? '${sessionResults.averageScore!.toStringAsFixed(1)}/10'
                  : 'N/A',
                LucideIcons.target,
                Colors.orange,
              ),
              _buildQuickStat(
                'Time',
                '${sessionResults.totalSessionTime.inMinutes}m',
                LucideIcons.timer,
                Colors.purple,
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
              _buildStat('Explanations Submitted', '${sessionResults.totalExplanations}'),
              _buildStat('Total Words Written', '${sessionResults.totalWordsWritten}'),
              _buildStat('Session Duration', '${sessionResults.totalSessionTime.inMinutes} minutes'),
              _buildStat('Topic Mastery', sessionResults.conceptMasteryLevel != null 
                ? '${(sessionResults.conceptMasteryLevel! * 100).toStringAsFixed(1)}%'
                : 'Analyzing...'),
            ],
            Colors.blue,
          ),
          
          const SizedBox(height: 20),
          
          _buildSummaryCard(
            'Understanding & Performance',
            [
              _buildStat('Average Score', sessionResults.averageScore != null
                ? '${sessionResults.averageScore!.toStringAsFixed(1)}/10'
                : 'Processing...'),
              if (sessionResults.bestScore != null)
                _buildStat('Best Score', '${sessionResults.bestScore!.toStringAsFixed(1)}/10'),
              if (sessionResults.improvementScore != null)
                _buildStat('Improvement', 
                  '${sessionResults.improvementScore! > 0 ? '+' : ''}${sessionResults.improvementScore!.toStringAsFixed(1)}'),
              _buildStat('Completion Status', sessionResults.completionStatus.name.toUpperCase()),
            ],
            Colors.purple,
          ),
          
          if (sessionResults.keyStrengths.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildStrengthsCard(),
          ],
          
          if (sessionResults.identifiedGaps.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildGapsCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildStrengthsCard() {
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
              Icon(LucideIcons.checkCircle2, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Key Strengths',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sessionResults.keyStrengths.map((strength) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 12),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    strength,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildGapsCard() {
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
              Icon(LucideIcons.alertTriangle, size: 20, color: Colors.orange),
              const SizedBox(width: 8),
              const Text(
                'Areas to Improve',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sessionResults.identifiedGaps.map((gap) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 12),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    gap,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          )),
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
            subtitle: 'Data-driven insights about your learning session',
            icon: LucideIcons.pieChart,
            color: Colors.blue,
            children: [
              // Explanation Analysis
              _buildDescriptiveSection(
                title: 'Explanation Analysis',
                icon: LucideIcons.messageSquare,
                content: _buildExplanationAnalysisContent(),
              ),
              
              const SizedBox(height: 16),
              
              // Cognitive Analysis
              _buildDescriptiveSection(
                title: 'Cognitive Performance',
                icon: LucideIcons.brain,
                content: _buildCognitiveAnalysisContent(),
              ),
              
              const SizedBox(height: 16),
              
              // Learning Patterns
              _buildDescriptiveSection(
                title: 'Learning Patterns',
                icon: LucideIcons.trendingUp,
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
            color: Colors.purple,
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
              color: Colors.purple.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.purple),
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
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
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

  // Analytics content builders
  Widget _buildExplanationAnalysisContent() {
    if (sessionAnalytics == null) return const SizedBox.shrink();
    
    final behavior = sessionAnalytics!.behaviorAnalysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnalyticsRow('Explanation Quality', '${(behavior.engagementLevel * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Concept Coverage', '${(behavior.persistenceScore * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Communication Clarity', '${(behavior.totalStudyTime.inMinutes / 10.0 * 100).clamp(0, 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Teaching Effectiveness', '${(behavior.engagementLevel * behavior.persistenceScore * 100).toStringAsFixed(1)}%'),
        if (behavior.commonErrorTypes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Common Explanation Patterns:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...behavior.commonErrorTypes.take(3).map((pattern) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '• $pattern', 
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
        _buildAnalyticsRow('Understanding Depth', '${cognitive.cognitiveLoadScore.toStringAsFixed(1)}/10'),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Explanation Speed', '${cognitive.processingSpeed.toStringAsFixed(2)}s avg'),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Teaching Stamina', '${cognitive.attentionSpan.toStringAsFixed(1)} minutes'),
        if (cognitive.cognitiveStrengths.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Teaching Strengths:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...cognitive.cognitiveStrengths.take(3).map((strength) => Padding(
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
            'Areas to Develop:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...cognitive.cognitiveWeaknesses.take(3).map((weakness) => Padding(
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

  Widget _buildLearningPatternsContent() {
    if (sessionAnalytics == null) return const SizedBox.shrink();
    
    final patterns = sessionAnalytics!.learningPatterns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnalyticsRow('Teaching Pattern', patterns.patternType.name.replaceAll('_', ' ').toUpperCase()),
        const SizedBox(height: 12),
        _buildAnalyticsRow('Learning Velocity', '${patterns.learningVelocity.toStringAsFixed(2)}x'),
        if (patterns.strongConcepts.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Well-Explained Concepts:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...patterns.strongConcepts.take(3).map((concept) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '• $concept', 
              style: const TextStyle(fontSize: 13),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          )),
        ],
        if (patterns.weakConcepts.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Concepts Needing Clarity:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...patterns.weakConcepts.take(3).map((concept) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '• $concept', 
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