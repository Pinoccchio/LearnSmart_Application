import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../services/retrieval_practice_service.dart';

class RetrievalProgressWidget extends StatelessWidget {
  final RetrievalPracticeService retrievalService;

  const RetrievalProgressWidget({
    super.key,
    required this.retrievalService,
  });

  @override
  Widget build(BuildContext context) {
    final session = retrievalService.currentSession;
    if (session == null) return const SizedBox.shrink();

    final currentIndex = retrievalService.currentQuestionIndex;
    final totalQuestions = retrievalService.sessionQuestions.length;
    final progress = retrievalService.progress;
    final correctAnswers = retrievalService.sessionAttempts.where((a) => a.isCorrect).length;
    final totalAttempts = retrievalService.sessionAttempts.length;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.brain,
                  color: AppColors.bgPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Retrieval Practice Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Question ${currentIndex + 1} of $totalQuestions',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.bgPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.grey200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.bgPrimary),
              minHeight: 8,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Attempted',
                  '$totalAttempts',
                  Colors.blue,
                  LucideIcons.edit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Correct',
                  '$correctAnswers',
                  Colors.green,
                  LucideIcons.checkCircle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Accuracy',
                  totalAttempts > 0 
                      ? '${((correctAnswers / totalAttempts) * 100).toInt()}%'
                      : '0%',
                  Colors.orange,
                  LucideIcons.target,
                ),
              ),
            ],
          ),
          
          // Question dots indicator
          if (totalQuestions <= 20) ...[
            const SizedBox(height: 16),
            _buildQuestionDots(currentIndex, totalQuestions),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
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
              fontSize: 14,
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

  Widget _buildQuestionDots(int currentIndex, int totalQuestions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Questions',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(totalQuestions, (index) {
            final isCurrentQuestion = index == currentIndex;
            final isCompleted = index < currentIndex;
            final attempt = retrievalService.sessionAttempts
                .where((a) => a.questionId == retrievalService.sessionQuestions[index].id)
                .firstOrNull;
            
            Color dotColor;
            IconData? dotIcon;
            
            if (isCurrentQuestion) {
              dotColor = AppColors.bgPrimary;
              dotIcon = LucideIcons.play;
            } else if (isCompleted && attempt != null) {
              dotColor = attempt.isCorrect ? Colors.green : Colors.red;
              dotIcon = attempt.isCorrect ? LucideIcons.check : LucideIcons.x;
            } else {
              dotColor = AppColors.grey300;
            }
            
            return Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
              child: dotIcon != null
                  ? Icon(
                      dotIcon,
                      size: 12,
                      color: Colors.white,
                    )
                  : Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
            );
          }),
        ),
      ],
    );
  }
}

// Extension to safely access first element
extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}