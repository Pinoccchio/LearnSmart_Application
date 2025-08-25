import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../services/pomodoro_service.dart';

class FocusScoreWidget extends StatefulWidget {
  final PomodoroService pomodoroService;
  final VoidCallback? onScoreSubmitted;

  const FocusScoreWidget({
    super.key,
    required this.pomodoroService,
    this.onScoreSubmitted,
  });

  @override
  State<FocusScoreWidget> createState() => _FocusScoreWidgetState();
}

class _FocusScoreWidgetState extends State<FocusScoreWidget> {
  int? _selectedScore;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.target,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How was your focus?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    
                    Text(
                      'Rate your focus level during this cycle',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Score selection
          _buildScoreSelection(),
          
          const SizedBox(height: 24),
          
          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _selectedScore != null && !_isSubmitting
                  ? _submitScore
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Submit Focus Score',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildScoreSelection() {
    return Column(
      children: [
        // Score buttons
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: List.generate(10, (index) {
            final score = index + 1;
            final isSelected = _selectedScore == score;
            
            return InkWell(
              onTap: () => _selectScore(score),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? _getScoreColor(score)
                      : AppColors.grey100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? _getScoreColor(score)
                        : AppColors.grey300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    score.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        
        const SizedBox(height: 16),
        
        // Score labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Icon(
                  LucideIcons.frown,
                  color: Colors.red.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Poor Focus',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Text(
                  '1-3',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            
            Column(
              children: [
                Icon(
                  LucideIcons.meh,
                  color: Colors.orange.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Average',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Text(
                  '4-6',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            
            Column(
              children: [
                Icon(
                  LucideIcons.smile,
                  color: Colors.green.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Excellent',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Text(
                  '7-10',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        
        // Selected score description
        if (_selectedScore != null) ...[
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getScoreColor(_selectedScore!).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getScoreDescription(_selectedScore!),
              style: TextStyle(
                fontSize: 14,
                color: _getScoreColor(_selectedScore!),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  void _selectScore(int score) {
    setState(() {
      _selectedScore = score;
    });
  }

  Future<void> _submitScore() async {
    if (_selectedScore == null || _isSubmitting) return;
    
    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.pomodoroService.addFocusScore(_selectedScore!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Focus score of $_selectedScore/10 recorded!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        widget.onScoreSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record focus score: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }


  Color _getScoreColor(int score) {
    if (score <= 3) {
      return Colors.red;
    } else if (score <= 6) {
      return Colors.orange;
    } else if (score <= 8) {
      return Colors.blue;
    } else {
      return Colors.green;
    }
  }

  String _getScoreDescription(int score) {
    if (score == 1) {
      return 'Very distracted - couldn\'t focus at all';
    } else if (score == 2) {
      return 'Highly distracted - frequent interruptions';
    } else if (score == 3) {
      return 'Poor focus - struggled to concentrate';
    } else if (score == 4) {
      return 'Below average - some distractions';
    } else if (score == 5) {
      return 'Average focus - moderate concentration';
    } else if (score == 6) {
      return 'Good focus - mostly concentrated';
    } else if (score == 7) {
      return 'Very good focus - few distractions';
    } else if (score == 8) {
      return 'Excellent focus - highly concentrated';
    } else if (score == 9) {
      return 'Outstanding focus - deep concentration';
    } else {
      return 'Perfect focus - completely absorbed';
    }
  }
}