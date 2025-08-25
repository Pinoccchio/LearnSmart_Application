import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/active_recall_models.dart';

class FlashcardResultWidget extends StatelessWidget {
  final ActiveRecallFlashcard flashcard;
  final String userAnswer;
  final bool isCorrect;
  final int responseTimeMs;
  final VoidCallback onContinue;

  const FlashcardResultWidget({
    super.key,
    required this.flashcard,
    required this.userAnswer,
    required this.isCorrect,
    required this.responseTimeMs,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Result header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCorrect 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCorrect ? LucideIcons.checkCircle : LucideIcons.xCircle,
                    color: isCorrect ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCorrect ? 'Correct!' : 'Incorrect',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        'Response time: ${(responseTimeMs / 1000).toStringAsFixed(1)}s',
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
            
            const SizedBox(height: 24),
            
            // Question recap
            _buildSection(
              'Question',
              flashcard.question,
              Colors.blue,
              LucideIcons.helpCircle,
            ),
            
            const SizedBox(height: 16),
            
            // Your answer
            _buildSection(
              'Your Answer',
              userAnswer,
              isCorrect ? Colors.green : Colors.red,
              isCorrect ? LucideIcons.check : LucideIcons.x,
            ),
            
            const SizedBox(height: 16),
            
            // Correct answer (if wrong)
            if (!isCorrect) ...[
              _buildSection(
                'Correct Answer',
                flashcard.answer,
                Colors.green,
                LucideIcons.checkCircle,
              ),
              const SizedBox(height: 16),
            ],
            
            // Explanation (if available)
            if (flashcard.explanation.isNotEmpty) ...[
              _buildSection(
                'Explanation',
                flashcard.explanation,
                Colors.orange,
                LucideIcons.lightbulb,
              ),
              const SizedBox(height: 16),
            ],
            
            const SizedBox(height: 24),
            
            // Performance feedback
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.brain,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getPerformanceFeedback(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _getPerformanceFeedback() {
    if (isCorrect) {
      if (responseTimeMs < 5000) {
        return 'Excellent! Quick and accurate response shows strong recall.';
      } else if (responseTimeMs < 15000) {
        return 'Good work! You retrieved the information successfully.';
      } else {
        return 'Correct answer, but consider reviewing for faster recall.';
      }
    } else {
      return 'Don\'t worry! Review the material and try to remember the key concepts.';
    }
  }
}