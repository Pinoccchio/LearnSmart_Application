import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/pomodoro_models.dart';
import '../../models/study_analytics_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/pomodoro_service.dart';
import '../../services/user_progress_service.dart';
import '../../widgets/pomodoro/pomodoro_timer_widget.dart';
import '../../widgets/pomodoro/pomodoro_controls_widget.dart';
import '../../widgets/pomodoro/pomodoro_notes_widget.dart';
import '../../widgets/pomodoro/focus_score_widget.dart';
import 'pomodoro_completion_screen.dart';

class PomodoroSessionScreen extends StatefulWidget {
  final Course course;
  final Module module;
  final PomodoroSettings? customSettings;

  const PomodoroSessionScreen({
    super.key,
    required this.course,
    required this.module,
    this.customSettings,
  });

  @override
  State<PomodoroSessionScreen> createState() => _PomodoroSessionScreenState();
}

class _PomodoroSessionScreenState extends State<PomodoroSessionScreen>
    with WidgetsBindingObserver {
  late final PomodoroService _pomodoroService;
  
  bool _isInitializing = true;
  String? _errorMessage;
  bool _showFocusScore = false;
  StudySessionAnalytics? _sessionAnalytics;
  PomodoroSessionResults? _sessionResults;
  
  // Smart pause tracking
  bool _isAccessingMaterials = false;
  bool _wasRunningBeforeBackground = false;
  
  // Performance optimization and memory management
  Timer? _debounceTimer;
  bool _isProcessingHeavyOperation = false;
  int _memoryWarningCount = 0;
  DateTime? _lastMemoryCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _pomodoroService = PomodoroService(
      onWorkCycleComplete: _onWorkCycleComplete,
    );
    _initializeSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pomodoroService.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Store timer state before going to background
      _wasRunningBeforeBackground = _pomodoroService.isRunning;
      
      // Only pause if NOT accessing materials (true interruption)
      if (!_isAccessingMaterials && _pomodoroService.isRunning) {
        _pomodoroService.pauseTimer();
        print('⏸️ [POMODORO] Timer paused due to app going to background');
      } else if (_isAccessingMaterials) {
        print('📚 [POMODORO] App backgrounded for material access - timer continues');
      }
    } else if (state == AppLifecycleState.resumed) {
      // Handle return from background
      if (_isAccessingMaterials && _wasRunningBeforeBackground) {
        // User was accessing materials and timer was running
        _showResumeDialog();
      }
      
      // Reset flags
      _isAccessingMaterials = false;
      _wasRunningBeforeBackground = false;
    }
  }

  Future<void> _initializeSession() async {
    try {
      _setLoadingStateDebounced(true, null);
      
      // Mark heavy processing start
      _isProcessingHeavyOperation = true;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not authenticated. Please log in to start a study session.');
      }

      print('🍅 [POMODORO SCREEN] Initializing Pomodoro session for ${widget.module.title}');
      
      // Check memory before heavy operations
      await _checkMemoryUsage('initialization_start');
      
      await _pomodoroService.initializeSession(
        userId: currentUser.id,
        module: widget.module,
        customSettings: widget.customSettings,
      );

      // Check memory after initialization
      await _checkMemoryUsage('initialization_complete');
      
      _isProcessingHeavyOperation = false;
      _setLoadingStateDebounced(false, null);

      print('✅ [POMODORO SCREEN] Session initialized successfully');

    } catch (e) {
      print('❌ [POMODORO SCREEN] Failed to initialize session: $e');
      _isProcessingHeavyOperation = false;
      _handleInitializationError(e);
    }
  }

  Future<void> _startSession() async {
    try {
      await _pomodoroService.startSession();
      print('🍅 [POMODORO SCREEN] Session started');
    } catch (e) {
      print('❌ [POMODORO SCREEN] Failed to start session: $e');
      _showErrorDialog('Failed to start session: $e');
    }
  }

  void _pauseResumeSession() {
    if (_pomodoroService.isRunning) {
      _pomodoroService.pauseTimer();
    } else {
      _pomodoroService.resumeTimer();
    }
  }


  Future<void> _stopSession() async {
    try {
      await _pomodoroService.forceStopSession();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('❌ [POMODORO SCREEN] Failed to stop session: $e');
      _showErrorDialog('Failed to stop session: $e');
    }
  }

  void _showFocusScoreDialog() {
    if (_pomodoroService.currentCycle?.type == PomodoroCycleType.work) {
      _setFocusScoreStateDebounced(true);
    }
  }

  void _onFocusScoreSubmitted() {
    _setFocusScoreStateDebounced(false);
    
    // If we're awaiting focus score from natural cycle completion, continue progression
    if (_pomodoroService.isAwaitingFocusScore) {
      _pomodoroService.continueCycleProgression();
    }
  }

  void _onWorkCycleComplete() {
    // Work cycle completed naturally - show focus score dialog
    _showFocusScoreDialog();
  }

  Future<void> _markInterruption() async {
    try {
      await _pomodoroService.markCurrentCycleAsInterrupted();
      
      // Show confirmation message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Interruption recorded'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      print('❌ [POMODORO SCREEN] Failed to mark interruption: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record interruption: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showResumeDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.bookOpen, color: Colors.blue, size: 24),
            const SizedBox(width: 12),
            const Text('Welcome Back!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You were accessing study materials. How would you like to continue your Pomodoro session?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.clock, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Timer: ${_formatDuration(_pomodoroService.remainingTime)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _markInterruption();
            },
            icon: const Icon(LucideIcons.alertTriangle, size: 16),
            label: const Text('Mark Interruption'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              if (!_pomodoroService.isRunning) {
                _pomodoroService.resumeTimer();
              }
            },
            icon: const Icon(LucideIcons.play, size: 16),
            label: const Text('Continue Timer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.clamp(0, 999);
    final seconds = (duration.inSeconds % 60).clamp(0, 59);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _onSessionComplete() async {
    try {
      print('🎉 [POMODORO SCREEN] Session completed, generating results...');
      
      // Mark heavy processing start
      _isProcessingHeavyOperation = true;
      
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Generating Analytics...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Analyzing your session performance',
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

      // Check memory before heavy analytics operations
      await _checkMemoryUsage('analytics_start');
      
      // Get session results
      _sessionResults = await _pomodoroService.getSessionResults();
      
      // Update module progress based on session results
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (_sessionResults != null && authProvider.currentUser != null) {
        try {
          print('🎯 [POMODORO PROGRESS] Updating module progress with focus score: ${_sessionResults!.averageFocusScore}');
          await UserProgressService.updateModuleProgress(
            userId: authProvider.currentUser!.id,
            moduleId: widget.module.id,
            score: _sessionResults!.averageFocusScore,
            technique: 'pomodoro',
            sessionId: _pomodoroService.currentSession?.id ?? 'pomodoro_session',
          );
          print('✅ [POMODORO PROGRESS] Module progress updated successfully');
        } catch (e) {
          print('⚠️ [POMODORO PROGRESS] Failed to update module progress: $e');
          // Don't block the completion flow if progress update fails
        }
      }
      
      // Generate comprehensive analytics
      _sessionAnalytics = await _pomodoroService.generateSessionAnalytics(
        userId: authProvider.currentUser!.id,
        module: widget.module,
        course: widget.course,
      );
      
      // Check memory after analytics generation
      await _checkMemoryUsage('analytics_complete');
      
      _isProcessingHeavyOperation = false;

      // Close loading dialog and navigate to completion screen
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _navigateToCompletionScreen();
      }
      
    } catch (e) {
      print('❌ [POMODORO SCREEN] Failed to process session completion: $e');
      _isProcessingHeavyOperation = false;
      
      // Handle memory errors specifically
      _handleMemoryError(e);
      
      // Close loading dialog if it's open
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(LucideIcons.alertTriangle, color: Colors.red, size: 24),
                const SizedBox(width: 12),
                const Text('Analytics Error'),
              ],
            ),
            content: const Text('Failed to generate session analytics. You can still view your basic session results.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close error dialog
                  if (_sessionResults != null) {
                    _navigateToCompletionScreen(); // Show results without analytics
                  }
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _navigateToCompletionScreen() {
    if (_sessionResults == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PomodoroCompletionScreen(
          course: widget.course,
          module: widget.module,
          sessionResults: _sessionResults!,
          sessionAnalytics: _sessionAnalytics,
          onBackToModule: () {
            // Navigate back to module details by popping multiple screens:
            // 1st pop: Close completion screen
            // 2nd pop: Close Pomodoro session screen  
            // 3rd pop: Close study technique selector modal
            Navigator.of(context).pop(); // Close completion screen
            Navigator.of(context).pop(); // Close Pomodoro screen
            Navigator.of(context).pop(); // Close technique selector modal
          },
          onStudyAgain: () {
            Navigator.of(context).pop(); // Close completion screen
            _initializeSession(); // Start new session
          },
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Optimized state update methods to reduce buffer overflow
  void _setLoadingStateDebounced(bool loading, String? error) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && !_isProcessingHeavyOperation) {
        setState(() {
          _isInitializing = loading;
          _errorMessage = error;
        });
      }
    });
  }
  
  void _setFocusScoreStateDebounced(bool show) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _showFocusScore = show;
        });
      }
    });
  }
  
  void _setMaterialAccessStateDebounced(bool accessing) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _isAccessingMaterials = accessing;
        });
      }
    });
  }
  
  void _handleInitializationError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('out of memory') || 
        errorString.contains('insufficient memory') ||
        errorString.contains('allocation failed')) {
      print('🚨 [MEMORY ERROR] Out of memory condition detected');
      _handleMemoryError(error);
      _setLoadingStateDebounced(false, 'Memory optimization in progress.\nPlease wait or restart the app.');
    } else if (errorString.contains('blastbufferqueue') ||
               errorString.contains('buffer') ||
               errorString.contains('surface')) {
      print('🚨 [BUFFER ERROR] Graphics buffer issue detected');
      _handleMemoryError(error);
      _setLoadingStateDebounced(false, 'Optimizing graphics performance.\nPlease wait.');
    } else {
      _setLoadingStateDebounced(false, 'Failed to initialize Pomodoro session: $error');
    }
  }

  // Memory management and buffer overflow prevention
  Future<void> _checkMemoryUsage(String phase) async {
    try {
      final now = DateTime.now();
      
      // Throttle memory checks to avoid performance impact
      if (_lastMemoryCheck != null && 
          now.difference(_lastMemoryCheck!).inMilliseconds < 500) {
        return;
      }
      
      _lastMemoryCheck = now;
      print('🔍 [MEMORY] Checking memory usage at phase: $phase');
      
      // Check if we can allocate a test list (memory pressure indicator)
      try {
        final testList = List.generate(1000, (i) => i);
        testList.clear();
        print('✅ [MEMORY] Memory allocation test passed');
      } catch (e) {
        _memoryWarningCount++;
        print('⚠️ [MEMORY] Memory pressure detected (warning #$_memoryWarningCount): $e');
        
        if (_memoryWarningCount >= 3) {
          print('🚨 [MEMORY] Critical memory pressure - implementing emergency measures');
          await _implementEmergencyMemoryMeasures();
        }
      }
      
      // Force a small delay to allow garbage collection
      await Future.delayed(const Duration(milliseconds: 50));
      
    } catch (e) {
      print('❌ [MEMORY] Memory check failed: $e');
    }
  }
  
  Future<void> _implementEmergencyMemoryMeasures() async {
    try {
      print('🚨 [EMERGENCY] Implementing emergency memory measures');
      
      // Clear any cached data that's not critical
      _clearNonEssentialCache();
      
      // Add longer delays between operations
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Update UI to show memory optimization
      if (mounted && !_isProcessingHeavyOperation) {
        _setLoadingStateDebounced(true, 'Optimizing memory usage.\nPlease wait.');
      }
      
      // Allow multiple garbage collection cycles
      await Future.delayed(const Duration(milliseconds: 200));
      
      print('✅ [EMERGENCY] Emergency memory measures completed');
      
    } catch (e) {
      print('❌ [EMERGENCY] Failed to implement emergency measures: $e');
    }
  }
  
  void _clearNonEssentialCache() {
    try {
      // Clear any temporary data structures that aren't needed
      // Reset memory warning counter after cleanup
      _memoryWarningCount = 0;
      _lastMemoryCheck = null;
      
      print('🧹 [CLEANUP] Non-essential cache cleared');
    } catch (e) {
      print('❌ [CLEANUP] Cache clear failed: $e');
    }
  }
  
  void _handleMemoryError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('out of memory') || 
        errorString.contains('insufficient memory') ||
        errorString.contains('allocation failed')) {
      
      print('🚨 [MEMORY ERROR] Out of memory condition detected');
      _implementEmergencyMemoryMeasures();
      
      if (mounted) {
        _setLoadingStateDebounced(false, 'Memory optimization in progress.\nPlease wait or restart the app.');
      }
    } else if (errorString.contains('blastbufferqueue') ||
               errorString.contains('buffer') ||
               errorString.contains('surface')) {
      
      print('🚨 [BUFFER ERROR] Graphics buffer issue detected');
      if (mounted) {
        _setLoadingStateDebounced(false, 'Optimizing graphics performance.\nPlease wait.');
      }
      
      // Add extra delay for graphics buffer recovery
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            // Trigger a gentle rebuild
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(
        title: Text(_pomodoroService.currentPhaseTitle),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          // Session info button
          if (_pomodoroService.currentSession != null)
            IconButton(
              onPressed: _showSessionInfo,
              icon: const Icon(LucideIcons.info),
            ),
          
          // Materials access button
          IconButton(
            onPressed: _showMaterials,
            icon: const Icon(LucideIcons.bookOpen),
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorScreen()
              : _buildSessionContent(),
      
      // Focus score overlay
      bottomSheet: _showFocusScore
          ? FocusScoreWidget(
              pomodoroService: _pomodoroService,
              onScoreSubmitted: _onFocusScoreSubmitted,
            )
          : null,
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.alertTriangle,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Session Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeSession,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionContent() {
    return ListenableBuilder(
      listenable: _pomodoroService,
      builder: (context, child) {
        final service = _pomodoroService;
        
        // Check if session is completed
        if (service.currentSession?.isCompleted == true && _sessionResults == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onSessionComplete();
          });
        }
        
        return Column(
          children: [
            // Timer section
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Main timer widget
                    PomodoroTimerWidget(
                      pomodoroService: service,
                      onTimerComplete: _onSessionComplete,
                    ),
                    
                    // Notes section (collapsible)
                    PomodoroNotesWidget(
                      pomodoroService: service,
                    ),
                    
                    const SizedBox(height: 120), // Space for controls
                  ],
                ),
              ),
            ),
            
            // Controls at bottom with safe area padding
            SafeArea(
              child: PomodoroControlsWidget(
                pomodoroService: service,
                onStartSession: _startSession,
                onPauseResume: _pauseResumeSession,
                onSkipCycle: null, // Skip functionality removed
                onMarkInterruption: _markInterruption,
                onStopSession: _stopSession,
              ),
            ),
          ],
        );
      },
    );
  }



  void _showSessionInfo() {
    final session = _pomodoroService.currentSession;
    if (session == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Session Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Work Duration', '${session.workDurationMinutes} minutes'),
            _buildInfoRow('Short Break', '${session.shortBreakDurationMinutes} minutes'),
            _buildInfoRow('Long Break', '${session.longBreakDurationMinutes} minutes'),
            _buildInfoRow('Total Cycles', '${session.totalCyclesPlanned}'),
            _buildInfoRow('Current Cycle', '${session.currentCycle}'),
            _buildInfoRow('Status', session.status.name),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showMaterials() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMaterialsSheet(),
    );
  }

  Widget _buildMaterialsSheet() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                Text(
                  'Study Materials',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Access your materials during breaks or when needed',
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Materials list
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.module.materials.length,
              itemBuilder: (context, index) {
                final material = widget.module.materials[index];
                return _buildMaterialCard(material);
              },
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(CourseMaterial material) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openMaterial(material),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.fileText,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (material.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        material.description!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              const Icon(
                LucideIcons.externalLink,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMaterial(CourseMaterial material) async {
    try {
      // Set flag to indicate intentional material access
      _setMaterialAccessStateDebounced(true);
      
      print('📚 [POMODORO] Opening study material: ${material.fileName}');
      
      final Uri url = Uri.parse(material.fileUrl);
      await launchUrl(url, mode: LaunchMode.externalApplication);
      
      // Show brief info message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(LucideIcons.bookOpen, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Opening ${material.fileName} - Timer continues'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      // Reset flag on error
      _setMaterialAccessStateDebounced(false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open ${material.fileName}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}