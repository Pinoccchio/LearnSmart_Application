import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/study_analytics_models.dart';

class RecommendationsWidget extends StatelessWidget {
  final List<PersonalizedRecommendation> recommendations;
  final VoidCallback? onRecommendationTap;

  const RecommendationsWidget({
    super.key,
    required this.recommendations,
    this.onRecommendationTap,
  });

  @override
  Widget build(BuildContext context) {
    // Sort recommendations by priority and confidence
    final sortedRecommendations = List<PersonalizedRecommendation>.from(recommendations)
      ..sort((a, b) {
        final priorityComparison = a.priority.compareTo(b.priority);
        if (priorityComparison != 0) return priorityComparison;
        return b.confidenceScore.compareTo(a.confidenceScore);
      });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.target,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Personalized Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (sortedRecommendations.isEmpty)
            _buildEmptyState()
          else
            ...sortedRecommendations.take(3).map((rec) => _buildRecommendationCard(rec)),
          
          if (sortedRecommendations.length > 3) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () => _showAllRecommendations(context, sortedRecommendations),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text('View ${sortedRecommendations.length - 3} More'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(PersonalizedRecommendation recommendation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getTypeColor(recommendation.type).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getTypeColor(recommendation.type).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with type, priority, and confidence
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getTypeColor(recommendation.type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getTypeIcon(recommendation.type),
                      size: 12,
                      color: _getTypeColor(recommendation.type),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTypeName(recommendation.type),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _getTypeColor(recommendation.type),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              
              _buildPriorityBadge(recommendation.priority),
              
              _buildConfidenceBadge(recommendation.confidenceScore),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Title
          Text(
            recommendation.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          
          const SizedBox(height: 6),
          
          // Description
          Text(
            recommendation.description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
            softWrap: true,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 12),
          
          // Actionable advice with action button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.checkCircle,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Action Steps',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 6),
                
                Text(
                  recommendation.actionableAdvice,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                  softWrap: true,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Reasons (if space allows)
          if (recommendation.reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: recommendation.reasons.take(2).map((reason) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getTypeColor(recommendation.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 10,
                      color: _getTypeColor(recommendation.type),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(int priority) {
    final priorityText = priority == 1 
        ? 'High' 
        : priority == 2 
            ? 'Med' 
            : 'Low';
    
    final color = priority == 1 
        ? Colors.red 
        : priority == 2 
            ? Colors.orange 
            : Colors.green;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        priorityText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(double confidence) {
    final confidencePercent = (confidence * 100).toInt();
    final color = confidence >= 0.8 
        ? Colors.green 
        : confidence >= 0.6 
            ? Colors.orange 
            : Colors.red;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.target,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '$confidencePercent%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            LucideIcons.compass,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          const Text(
            'Preparing Recommendations...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI is creating personalized study recommendations for you.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.studyTiming:
        return Colors.blue;
      case RecommendationType.materialFocus:
        return Colors.teal;
      case RecommendationType.studyTechnique:
        return Colors.purple;
      case RecommendationType.practiceFrequency:
        return Colors.orange;
      case RecommendationType.difficultyAdjustment:
        return Colors.red;
      case RecommendationType.conceptReinforcement:
        return Colors.green;
      case RecommendationType.studyMethods:
        return Colors.indigo;
      case RecommendationType.pomodoroOptimization:
        return Colors.redAccent;
      case RecommendationType.focusImprovement:
        return Colors.deepOrange;
      case RecommendationType.cycleManagement:
        return Colors.blueGrey;
      case RecommendationType.breakStrategy:
        return Colors.cyan;
      case RecommendationType.timeBlocking:
        return Colors.brown;
      case RecommendationType.distractionControl:
        return Colors.pink;
    }
  }

  IconData _getTypeIcon(RecommendationType type) {
    switch (type) {
      case RecommendationType.studyTiming:
        return LucideIcons.clock;
      case RecommendationType.materialFocus:
        return LucideIcons.bookOpen;
      case RecommendationType.studyTechnique:
        return LucideIcons.brain;
      case RecommendationType.practiceFrequency:
        return LucideIcons.repeat;
      case RecommendationType.difficultyAdjustment:
        return LucideIcons.trendingUp;
      case RecommendationType.conceptReinforcement:
        return LucideIcons.target;
      case RecommendationType.studyMethods:
        return LucideIcons.bookMarked;
      case RecommendationType.pomodoroOptimization:
        return LucideIcons.timer;
      case RecommendationType.focusImprovement:
        return LucideIcons.focus;
      case RecommendationType.cycleManagement:
        return LucideIcons.rotateCw;
      case RecommendationType.breakStrategy:
        return LucideIcons.coffee;
      case RecommendationType.timeBlocking:
        return LucideIcons.calendar;
      case RecommendationType.distractionControl:
        return LucideIcons.eyeOff;
    }
  }

  String _formatTypeName(RecommendationType type) {
    switch (type) {
      case RecommendationType.studyTiming:
        return 'Timing';
      case RecommendationType.materialFocus:
        return 'Material';
      case RecommendationType.studyTechnique:
        return 'Technique';
      case RecommendationType.practiceFrequency:
        return 'Practice';
      case RecommendationType.difficultyAdjustment:
        return 'Difficulty';
      case RecommendationType.conceptReinforcement:
        return 'Concepts';
      case RecommendationType.studyMethods:
        return 'Methods';
      case RecommendationType.pomodoroOptimization:
        return 'Pomodoro';
      case RecommendationType.focusImprovement:
        return 'Focus';
      case RecommendationType.cycleManagement:
        return 'Cycles';
      case RecommendationType.breakStrategy:
        return 'Breaks';
      case RecommendationType.timeBlocking:
        return 'Time Blocks';
      case RecommendationType.distractionControl:
        return 'Distractions';
    }
  }

  void _showAllRecommendations(BuildContext context, List<PersonalizedRecommendation> recommendations) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grey300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.target,
                        color: Colors.green,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'All Recommendations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    ...recommendations.map((rec) => _buildRecommendationCard(rec)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}