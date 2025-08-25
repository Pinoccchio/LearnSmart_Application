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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Pause timer when app goes to background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_pomodoroService.isRunning) {
        _pomodoroService.pauseTimer();
      }
    }
  }

  Future<void> _initializeSession() async {
    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not authenticated. Please log in to start a study session.');
      }

      print('🍅 [POMODORO SCREEN] Initializing Pomodoro session for ${widget.module.title}');
      
      await _pomodoroService.initializeSession(
        userId: currentUser.id,
        module: widget.module,
        customSettings: widget.customSettings,
      );

      setState(() {
        _isInitializing = false;
      });

      print('✅ [POMODORO SCREEN] Session initialized successfully');

    } catch (e) {
      print('❌ [POMODORO SCREEN] Failed to initialize session: $e');
      setState(() {
        _errorMessage = 'Failed to initialize Pomodoro session: $e';
        _isInitializing = false;
      });
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
      setState(() {
        _showFocusScore = true;
      });
    }
  }

  void _onFocusScoreSubmitted() {
    setState(() {
      _showFocusScore = false;
    });
    
    // If we're awaiting focus score from natural cycle completion, continue progression
    if (_pomodoroService.isAwaitingFocusScore) {
      _pomodoroService.continueCycleProgression();
    }
  }

  void _onWorkCycleComplete() {
    // Work cycle completed naturally - show focus score dialog
    _showFocusScoreDialog();
  }

  Future<void> _onSessionComplete() async {
    try {
      print('🎉 [POMODORO SCREEN] Session completed, generating results...');
      
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

      // Loading dialog is already shown above
      
      // Get session results
      _sessionResults = await _pomodoroService.getSessionResults();
      
      // Generate comprehensive analytics
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _sessionAnalytics = await _pomodoroService.generateSessionAnalytics(
        userId: authProvider.currentUser!.id,
        module: widget.module,
        course: widget.course,
      );
      
      // Analytics generation completed

      // Close loading dialog and navigate to completion screen
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _navigateToCompletionScreen();
      }
      
    } catch (e) {
      print('❌ [POMODORO SCREEN] Failed to process session completion: $e');
      
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
                color: Colors.black.withOpacity(0.05),
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
                  color: Colors.blue.withOpacity(0.1),
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
      final Uri url = Uri.parse(material.fileUrl);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
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