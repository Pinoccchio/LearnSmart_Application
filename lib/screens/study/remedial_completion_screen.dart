import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/active_recall_models.dart';
import '../../models/remedial_models.dart';
import '../../models/study_analytics_models.dart';
import '../../widgets/analytics/insights_widget.dart';
import '../../widgets/analytics/recommendations_widget.dart';
import '../../widgets/analytics/study_plan_widget.dart';

class RemedialCompletionScreen extends StatelessWidget {
  final Course course;
  final Module module;
  final StudySessionResults originalResults;
  final RemedialResults remedialResults;
  final StudySessionAnalytics? sessionAnalytics;
  final VoidCallback onBackToModule;
  final VoidCallback onRetakeRemedial;

  const RemedialCompletionScreen({
    super.key,
    required this.course,
    required this.module,
    required this.originalResults,
    required this.remedialResults,
    this.sessionAnalytics,
    required this.onBackToModule,
    required this.onRetakeRemedial,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(
        title: const Text('Remedial Complete'),
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
                    text: 'Results',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.pieChart, size: 20),
                    text: 'Progress',
                  ),
                ],
              ),
            ),
            
            // Tab Content - Full screen scrollable
            Expanded(
              child: TabBarView(
                children: [
                  _buildResultsTab(),
                  _buildProgressTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final isPassing = remedialResults.isPassing;
    final heroColor = isPassing ? Colors.green : Colors.orange;
    final heroIcon = isPassing ? LucideIcons.checkCircle : LucideIcons.target;
    final heroTitle = isPassing ? 'Great Improvement!' : 'Keep Practicing!';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            heroColor.withValues(alpha: 0.1),
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
              color: heroColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              heroIcon,
              color: heroColor,
              size: 40,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Title
          Text(
            heroTitle,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'You completed the remedial quiz for ${module.title}',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          // Quick Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickStat(
                'Original',
                '${((originalResults.postStudyCorrect / originalResults.totalFlashcards) * 100).toStringAsFixed(1)}%',
                LucideIcons.alertTriangle,
                Colors.red,
              ),
              _buildQuickStat(
                'Remedial',
                '${remedialResults.accuracyPercentage.toStringAsFixed(1)}%',
                LucideIcons.target,
                isPassing ? Colors.green : Colors.orange,
              ),
              _buildQuickStat(
                'Improvement',
                remedialResults.showsImprovement 
                    ? '+${remedialResults.improvementFromOriginal.toStringAsFixed(1)}%'
                    : '${remedialResults.improvementFromOriginal.toStringAsFixed(1)}%',
                LucideIcons.trendingUp,
                remedialResults.showsImprovement ? Colors.green : Colors.grey,
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
            color: color.withValues(alpha: 0.1),
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
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildResultsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero Section (moved into tab content)
          _buildHeroSection(),
          
          // Results Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildResultsCard(
                  'Remedial Performance',
                  [
                    _buildStat('Questions Answered', '${remedialResults.totalQuestions}'),
                    _buildStat('Correct Answers', '${remedialResults.correctAnswers}'),
                    _buildStat('Accuracy', '${remedialResults.accuracyPercentage.toStringAsFixed(1)}%'),
                    _buildStat('Performance Level', remedialResults.performanceLevel),
                  ],
                  remedialResults.isPassing ? Colors.green : Colors.orange,
                ),
                
                const SizedBox(height: 20),
                
                _buildResultsCard(
                  'Concept Mastery',
                  [
                    _buildStat('Concepts Mastered', '${remedialResults.masteredConcepts.length}'),
                    _buildStat('Still Practicing', '${remedialResults.stillStrugglingConcepts.length}'),
                    _buildStat('Average Response Time', '${remedialResults.averageResponseTime}s'),
                    _buildStat('Improvement', '${remedialResults.improvementFromOriginal.toStringAsFixed(1)}%'),
                  ],
                  Colors.blue,
                ),
                
                const SizedBox(height: 20),
                
                if (remedialResults.masteredConcepts.isNotEmpty)
                  _buildConceptsList(
                    'Concepts You\'ve Mastered',
                    remedialResults.masteredConcepts,
                    Colors.green,
                    LucideIcons.checkCircle,
                  ),
                
                if (remedialResults.stillStrugglingConcepts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildConceptsList(
                    'Concepts to Keep Practicing',
                    remedialResults.stillStrugglingConcepts,
                    Colors.orange,
                    LucideIcons.target,
                  ),
                ],
                
                const SizedBox(height: 30),
                
                // Action buttons moved into tab content
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero Section (moved into tab content)
          _buildHeroSection(),
          
          // Progress Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildProgressCard(),
                
                const SizedBox(height: 20),
                
                if (sessionAnalytics != null) ...[
                  // AI Insights
                  if (sessionAnalytics!.insights.isNotEmpty) ...[
                    _buildAnalyticsSection(
                      title: 'AI Insights',
                      icon: LucideIcons.lightbulb,
                      color: Colors.amber,
                      content: InsightsWidget(
                        insights: sessionAnalytics!.insights,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Recommendations
                  if (sessionAnalytics!.recommendations.isNotEmpty) ...[
                    _buildAnalyticsSection(
                      title: 'Recommendations',
                      icon: LucideIcons.checkSquare,
                      color: Colors.blue,
                      content: RecommendationsWidget(
                        recommendations: sessionAnalytics!.recommendations,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Study Plan
                  _buildAnalyticsSection(
                    title: 'Next Steps',
                    icon: LucideIcons.calendar,
                    color: Colors.green,
                    content: StudyPlanWidget(
                      studyPlan: sessionAnalytics!.suggestedStudyPlan,
                    ),
                  ),
                ] else
                  _buildEmptyAnalytics(),
                
                const SizedBox(height: 30),
                
                // Action buttons moved into tab content
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard(String title, List<Widget> stats, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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

  Widget _buildConceptsList(String title, List<String> concepts, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Icon(icon, size: 20, color: color),
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
          ...concepts.map((concept) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  LucideIcons.circle,
                  size: 12,
                  color: color.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    concept,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final originalAccuracy = (originalResults.postStudyCorrect / originalResults.totalFlashcards) * 100;
    final remedialAccuracy = remedialResults.accuracyPercentage;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              const Icon(LucideIcons.trendingUp, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Learning Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Original vs Remedial Progress Bar
          _buildProgressBar('Original Score', originalAccuracy, Colors.red),
          const SizedBox(height: 16),
          _buildProgressBar('Remedial Score', remedialAccuracy, remedialResults.isPassing ? Colors.green : Colors.orange),
          
          const SizedBox(height: 20),
          
          // Achievement Badge
          if (remedialResults.isPassing)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.award, size: 20, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Congratulations! You\'ve achieved passing level (80%+)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.target, size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keep practicing! You need 80% or higher to pass.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: AppColors.grey200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
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
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: content,
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
              color: AppColors.textSecondary.withValues(alpha: 0.5),
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
              'Unable to generate detailed analytics for this remedial session.',
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

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Retake button (only if not passing)
        if (!remedialResults.isPassing) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onRetakeRemedial,
              icon: const Icon(LucideIcons.repeat, size: 16),
              label: const Text('Retake Remedial Quiz'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.bgPrimary,
                side: BorderSide(color: AppColors.bgPrimary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Back to Module button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: onBackToModule,
            icon: const Icon(LucideIcons.arrowLeft, size: 16),
            label: Text(remedialResults.isPassing ? 'Continue Learning' : 'Back to Module'),
            style: ElevatedButton.styleFrom(
              backgroundColor: remedialResults.isPassing ? Colors.green : AppColors.bgPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        // Add bottom padding for safe area
        const SizedBox(height: 20),
      ],
    );
  }
}