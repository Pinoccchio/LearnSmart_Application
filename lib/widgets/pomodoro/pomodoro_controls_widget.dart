import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../services/pomodoro_service.dart';
import '../../models/pomodoro_models.dart';

class PomodoroControlsWidget extends StatelessWidget {
  final PomodoroService pomodoroService;
  final VoidCallback? onStartSession;
  final VoidCallback? onPauseResume;
  final VoidCallback? onSkipCycle;
  final VoidCallback? onStopSession;

  const PomodoroControlsWidget({
    super.key,
    required this.pomodoroService,
    this.onStartSession,
    this.onPauseResume,
    this.onSkipCycle,
    this.onStopSession,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pomodoroService,
      builder: (context, child) {
        final service = pomodoroService;
        final session = service.currentSession;
        
        if (session == null) {
          return _buildStartButton(context);
        }
        
        switch (session.status) {
          case PomodoroSessionStatus.preparing:
            return _buildStartButton(context);
            
          case PomodoroSessionStatus.active:
          case PomodoroSessionStatus.break_:
            return _buildActiveControls(context, service);
            
          case PomodoroSessionStatus.completed:
            return _buildCompletedControls(context);
            
          case PomodoroSessionStatus.paused:
            return _buildPausedControls(context, service);
        }
      },
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: onStartSession,
          icon: const Icon(LucideIcons.play, size: 20),
          label: const Text(
            'Start Pomodoro Session',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveControls(BuildContext context, PomodoroService service) {
    final isRunning = service.isRunning;
    final canSkip = service.remainingTime.inSeconds > 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Pause/Resume Button
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: onPauseResume,
                icon: Icon(
                  isRunning ? LucideIcons.pause : LucideIcons.play,
                  size: 20,
                ),
                label: Text(
                  isRunning ? 'Pause' : 'Resume',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRunning ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Skip Button
          if (canSkip) ...[
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: onSkipCycle,
                  icon: const Icon(LucideIcons.skipForward, size: 18),
                  label: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.grey300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
          ],
          
          // Stop Button
          SizedBox(
            width: 56,
            height: 56,
            child: OutlinedButton(
              onPressed: () => _showStopConfirmation(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(LucideIcons.square, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPausedControls(BuildContext context, PomodoroService service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Status Message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.pause, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Session is paused. You can resume or start over.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Control Buttons
          Row(
            children: [
              // Resume Button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onPauseResume,
                    icon: const Icon(LucideIcons.play, size: 20),
                    label: const Text(
                      'Resume',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Reset Button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => _showResetConfirmation(context),
                    icon: const Icon(LucideIcons.rotateCcw, size: 20),
                    label: const Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Congratulations Message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.checkCircle, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Complete! 🎉',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Great work! Check your analytics below.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              // View Results Button (handled by parent)
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {}, // Handled by parent screen
                    icon: const Icon(LucideIcons.barChart3, size: 20),
                    label: const Text(
                      'Analytics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bgPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Start New Session Button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: onStartSession,
                    icon: const Icon(LucideIcons.repeat, size: 20),
                    label: const Text(
                      'Study Again',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.bgPrimary,
                      side: BorderSide(color: AppColors.bgPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStopConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            const Text('Stop Session'),
          ],
        ),
        content: const Text(
          'Are you sure you want to stop the current Pomodoro session? Your progress will be saved, but the current cycle will be marked as incomplete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onStopSession?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Stop Session'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.rotateCcw, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            const Text('Reset Session'),
          ],
        ),
        content: const Text(
          'Are you sure you want to reset the session? All progress will be lost and you\'ll start over with a new session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onStopSession?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}