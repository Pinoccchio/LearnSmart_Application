import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../../constants/app_colors.dart';
import '../../services/pomodoro_service.dart';
import '../../models/pomodoro_models.dart';

class PomodoroTimerWidget extends StatefulWidget {
  final PomodoroService pomodoroService;
  final VoidCallback? onTimerComplete;

  const PomodoroTimerWidget({
    super.key,
    required this.pomodoroService,
    this.onTimerComplete,
  });

  @override
  State<PomodoroTimerWidget> createState() => _PomodoroTimerWidgetState();
}

class _PomodoroTimerWidgetState extends State<PomodoroTimerWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start pulse animation if timer is running
    if (widget.pomodoroService.isRunning) {
      _pulseController.repeat(reverse: true);
    }

    // Listen to service changes
    widget.pomodoroService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) {
      if (widget.pomodoroService.isRunning && !_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      } else if (!widget.pomodoroService.isRunning && _pulseController.isAnimating) {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    widget.pomodoroService.removeListener(_onServiceChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.pomodoroService,
      builder: (context, child) {
        final service = widget.pomodoroService;
        final progress = service.progress;
        final remainingTime = service.remainingTime;
        
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Timer Circle
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: service.isRunning ? _pulseAnimation.value : 1.0,
                    child: SizedBox(
                      width: 280,
                      height: 280,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background Circle
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          
                          // Progress Circle
                          SizedBox(
                            width: 260,
                            height: 260,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 12,
                              backgroundColor: AppColors.grey200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getPhaseColor(service),
                              ),
                            ),
                          ),
                          
                          // Center Content
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Time Display
                              Text(
                                _formatDuration(remainingTime),
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: _getPhaseColor(service),
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Phase Label
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getPhaseColor(service).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getPhaseLabel(service),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _getPhaseColor(service),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // Session Progress
              if (service.currentSession != null) ...[
                _buildSessionProgress(service),
                const SizedBox(height: 24),
              ],
              
              // Phase Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  service.currentPhaseDescription,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionProgress(PomodoroService service) {
    final session = service.currentSession;
    if (session == null) return const SizedBox.shrink();
    
    final cyclesCompleted = session.cyclesCompleted;
    final totalCycles = session.totalCyclesPlanned;
    
    return Column(
      children: [
        // Progress Text
        Text(
          'Session Progress',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Cycle Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalCycles, (index) {
            final isCompleted = index < cyclesCompleted;
            final isCurrent = index == session.currentCycle - 1;
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isCurrent ? 16 : 12,
                height: isCurrent ? 16 : 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? Colors.green
                      : isCurrent
                          ? _getPhaseColor(service)
                          : AppColors.grey300,
                  border: isCurrent && !isCompleted
                      ? Border.all(
                          color: _getPhaseColor(service),
                          width: 2,
                        )
                      : null,
                ),
                child: isCompleted
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 8,
                      )
                    : null,
              ),
            );
          }),
        ),
        
        const SizedBox(height: 8),
        
        // Progress Text
        Text(
          '$cyclesCompleted of $totalCycles cycles completed',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Color _getPhaseColor(PomodoroService service) {
    final session = service.currentSession;
    if (session == null) return AppColors.bgPrimary;
    
    switch (session.status) {
      case PomodoroSessionStatus.active:
        return Colors.red; // Work time - red for focus/urgency
      case PomodoroSessionStatus.break_:
        // Check if it's a long break
        final isLongBreak = session.currentCycle % 4 == 0;
        return isLongBreak ? Colors.blue : Colors.green; // Long break blue, short break green
      case PomodoroSessionStatus.completed:
        return Colors.green;
      case PomodoroSessionStatus.paused:
        return Colors.orange;
      default:
        return AppColors.bgPrimary;
    }
  }

  String _getPhaseLabel(PomodoroService service) {
    final session = service.currentSession;
    if (session == null) return 'Ready';
    
    switch (session.status) {
      case PomodoroSessionStatus.preparing:
        return 'Preparing';
      case PomodoroSessionStatus.active:
        return 'Work Time';
      case PomodoroSessionStatus.break_:
        final isLongBreak = session.currentCycle % 4 == 0;
        return isLongBreak ? 'Long Break' : 'Short Break';
      case PomodoroSessionStatus.completed:
        return 'Complete';
      case PomodoroSessionStatus.paused:
        return 'Paused';
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.clamp(0, 999);
    final seconds = (duration.inSeconds % 60).clamp(0, 59);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

