import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/retrieval_practice_models.dart';

class RetrievalResultsWidget extends StatelessWidget {
  final RetrievalPracticeResults sessionResults;
  final bool showDetailedBreakdown;

  const RetrievalResultsWidget({
    super.key,
    required this.sessionResults,
    this.showDetailedBreakdown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall performance card
        _buildOverallPerformanceCard(context),
        
        const SizedBox(height: 16),
        
        // Time statistics
        _buildTimeStatistics(),
        
        if (showDetailedBreakdown) ...[
          const SizedBox(height: 16),
          
          // Question type breakdown
          if (sessionResults.questionTypeBreakdown.isNotEmpty)
            _buildQuestionTypeBreakdown(),
          
          const SizedBox(height: 16),
          
          // Difficulty breakdown
          if (sessionResults.accuracyByDifficulty.isNotEmpty)
            _buildDifficultyBreakdown(),
          
          const SizedBox(height: 16),
          
          // Concept analysis
          if (sessionResults.strongConcepts.isNotEmpty || sessionResults.weakConcepts.isNotEmpty)
            _buildConceptAnalysis(),
        ],
        
        // Additional insights
        if (sessionResults.hintsUsed > 0 || sessionResults.averageConfidence != null) ...[
          const SizedBox(height: 16),
          _buildAdditionalInsights(),
        ],
      ],
    );
  }

  Widget _buildOverallPerformanceCard(BuildContext context) {
    return Container(
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
                  color: sessionResults.performanceColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.target,
                  color: sessionResults.performanceColor,
                  size: 30,
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Performance',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      sessionResults.performanceLevel,
                      style: TextStyle(
                        fontSize: 16,
                        color: sessionResults.performanceColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${sessionResults.accuracy.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: sessionResults.performanceColor,
                    ),
                  ),
                  const Text(
                    'Accuracy',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: _buildResultStat(
                  'Questions',
                  '${sessionResults.totalQuestions}',
                  Colors.blue,
                  LucideIcons.helpCircle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildResultStat(
                  'Correct',
                  '${sessionResults.correctAnswers}',
                  Colors.green,
                  LucideIcons.checkCircle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildResultStat(
                  'Incorrect',
                  '${sessionResults.wrongAnswers}',
                  Colors.red,
                  LucideIcons.xCircle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeStatistics() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Icon(
                LucideIcons.clock,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Time Statistics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Time',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(sessionResults.totalTime),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Avg. per Question',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(sessionResults.averageTimePerQuestion),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTypeBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Icon(
                LucideIcons.pieChart,
                color: Colors.purple,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Question Type Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          ...sessionResults.questionTypeBreakdown.entries.map((entry) {
            final type = entry.key;
            final count = entry.value;
            final accuracy = sessionResults.accuracyByType[type] ?? 0.0;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getQuestionTypeLabel(type),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '$count questions • ${accuracy.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: accuracy / 100,
                      backgroundColor: AppColors.grey200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getAccuracyColor(accuracy),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDifficultyBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Icon(
                LucideIcons.trendingUp,
                color: Colors.indigo,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Difficulty Level Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          ...sessionResults.accuracyByDifficulty.entries.map((entry) {
            final difficulty = entry.key;
            final accuracy = entry.value;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 24,
                    decoration: BoxDecoration(
                      color: difficulty.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: difficulty.color.withOpacity(0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        difficulty.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: difficulty.color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${difficulty.name.substring(0, 1).toUpperCase()}${difficulty.name.substring(1)} Questions',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${accuracy.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: accuracy / 100,
                            backgroundColor: AppColors.grey200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getAccuracyColor(accuracy),
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildConceptAnalysis() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Icon(
                LucideIcons.brain,
                color: Colors.teal,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Concept Analysis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (sessionResults.strongConcepts.isNotEmpty) ...[
            const Text(
              'Strong Concepts',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: sessionResults.strongConcepts.map((concept) => 
                Chip(
                  label: Text(
                    concept.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.green.shade50,
                  side: BorderSide(color: Colors.green.shade200),
                  avatar: Icon(
                    LucideIcons.check,
                    size: 14,
                    color: Colors.green,
                  ),
                ),
              ).toList(),
            ),
          ],
          
          if (sessionResults.strongConcepts.isNotEmpty && sessionResults.weakConcepts.isNotEmpty)
            const SizedBox(height: 16),
          
          if (sessionResults.weakConcepts.isNotEmpty) ...[
            const Text(
              'Areas for Improvement',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: sessionResults.weakConcepts.map((concept) => 
                Chip(
                  label: Text(
                    concept.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.orange.shade50,
                  side: BorderSide(color: Colors.orange.shade200),
                  avatar: Icon(
                    LucideIcons.alertTriangle,
                    size: 14,
                    color: Colors.orange,
                  ),
                ),
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalInsights() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Icon(
                LucideIcons.lightbulb,
                color: Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Additional Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (sessionResults.hintsUsed > 0)
            _buildInsightItem(
              'Hints Used',
              '${sessionResults.hintsUsed} hints used during the session',
              LucideIcons.helpCircle,
              Colors.blue,
            ),
          
          if (sessionResults.averageConfidence != null) ...[
            if (sessionResults.hintsUsed > 0) const SizedBox(height: 12),
            _buildInsightItem(
              'Average Confidence',
              '${sessionResults.averageConfidence!.toStringAsFixed(1)}/5.0 confidence rating',
              LucideIcons.star,
              Colors.purple,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightItem(String title, String description, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultStat(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
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
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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

  String _getQuestionTypeLabel(RetrievalQuestionType type) {
    switch (type) {
      case RetrievalQuestionType.multipleChoice:
        return 'Multiple Choice';
      case RetrievalQuestionType.shortAnswer:
        return 'Short Answer';
      case RetrievalQuestionType.fillInBlank:
        return 'Fill in Blank';
      case RetrievalQuestionType.trueFalse:
        return 'True/False';
    }
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 80) return Colors.lightGreen;
    if (accuracy >= 70) return Colors.orange;
    if (accuracy >= 60) return Colors.deepOrange;
    return Colors.red;
  }
}

extension on DifficultyLevel {
  Color get color {
    switch (this) {
      case DifficultyLevel.easy:
        return Colors.green;
      case DifficultyLevel.medium:
        return Colors.orange;
      case DifficultyLevel.hard:
        return Colors.red;
    }
  }
}