import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class RemedialProgressWidget extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final double progress;

  const RemedialProgressWidget({
    super.key,
    required this.currentIndex,
    required this.totalQuestions,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.grey200, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.grey200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? Colors.green : AppColors.bgPrimary,
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${currentIndex + 1}/$totalQuestions',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Progress description
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Remedial Quiz Progress',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% Complete',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}