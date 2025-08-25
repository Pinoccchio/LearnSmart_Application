import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/pomodoro_models.dart';
import '../../models/study_analytics_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/pomodoro_service.dart';
import '../../services/study_analytics_service.dart';
import '../../widgets/pomodoro/pomodoro_timer_widget.dart';
import '../../widgets/pomodoro/pomodoro_controls_widget.dart';
import '../../widgets/pomodoro/pomodoro_notes_widget.dart';
import '../../widgets/pomodoro/focus_score_widget.dart';
import '../../widgets/analytics/performance_chart_widget.dart';
import '../../widgets/analytics/insights_widget.dart';
import '../../widgets/analytics/recommendations_widget.dart';
import '../../widgets/analytics/study_plan_widget.dart';

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
  late final StudyAnalyticsService _analyticsService;
  
  bool _isInitializing = true;
  String? _errorMessage;
  bool _showFocusScore = false;
  StudySessionAnalytics? _sessionAnalytics;
  PomodoroSessionResults? _sessionResults;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _pomodoroService = PomodoroService();
    _analyticsService = StudyAnalyticsService();
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

  Future<void> _skipCycle() async {
    final currentStatus = _pomodoroService.currentSession?.status;
    final isWorkCycle = currentStatus == PomodoroSessionStatus.active;
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.skipForward, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            const Text('Skip Cycle'),
          ],
        ),
        content: Text(
          isWorkCycle
              ? 'Are you sure you want to skip this work cycle? It will be marked as incomplete and you\'ll move to the next cycle.'
              : 'Are you sure you want to skip this break? Breaks are important for maintaining focus, but you\'ll move to the next work cycle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Skip Cycle'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // If it's a work cycle, show focus score first (optional but recommended)
        if (isWorkCycle) {
          // Give option to rate focus before skipping
          _showFocusScoreDialog();
        }
        
        // Skip the cycle using the service method
        await _pomodoroService.skipCycle();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isWorkCycle ? 'Work cycle skipped' : 'Break skipped'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to skip cycle: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
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
  }

  Future<void> _onSessionComplete() async {
    try {
      print('🎉 [POMODORO SCREEN] Session completed, generating results...');
      
      // Get session results
      _sessionResults = await _pomodoroService.getSessionResults();
      
      // Generate comprehensive analytics
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await _pomodoroService.generateSessionAnalytics(
        userId: authProvider.currentUser!.id,
        module: widget.module,
        course: widget.course,
      );
      
      // Get the analytics (this would be implemented in the service)
      // For now, we'll show the results dialog
      _showSessionResultsDialog();
      
    } catch (e) {
      print('❌ [POMODORO SCREEN] Failed to process session completion: $e');
    }
  }

  void _showSessionResultsDialog() {
    if (_sessionResults == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: _buildResultsDialog(_sessionResults!),
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
                onSkipCycle: _skipCycle,
                onStopSession: _stopSession,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSessionContent_WithControls() {
    return Column(
      children: [
        // Timer and content area
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                PomodoroTimerWidget(
                  pomodoroService: _pomodoroService,
                ),
                
                PomodoroNotesWidget(
                  pomodoroService: _pomodoroService,
                ),
              ],
            ),
          ),
        ),
        
        // Controls at bottom
        PomodoroControlsWidget(
          pomodoroService: _pomodoroService,
          onStartSession: _startSession,
          onPauseResume: _pauseResumeSession,
          onSkipCycle: _skipCycle,
          onStopSession: _stopSession,
        ),
      ],
    );
  }

  Widget _buildResultsDialog(PomodoroSessionResults results) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        maxWidth: MediaQuery.of(context).size.width * 0.95,
      ),
      child: DefaultTabController(
        length: 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.checkCircle,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pomodoro Complete!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Your focus session analysis',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
            ),
            
            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                indicator: BoxDecoration(
                  color: AppColors.bgPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(LucideIcons.barChart3, size: 16),
                    text: 'Summary',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.pieChart, size: 16),
                    text: 'Analytics',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.target, size: 16),
                    text: 'Insights',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.calendar, size: 16),
                    text: 'Next Steps',
                  ),
                ],
              ),
            ),
            
            // Tab content
            Flexible(
              child: Container(
                margin: const EdgeInsets.all(16),
                child: TabBarView(
                  children: [
                    _buildSummaryTab(results),
                    _buildAnalyticsTab(results),
                    _buildInsightsTab(results),
                    _buildNextStepsTab(results),
                  ],
                ),
              ),
            ),
            
            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        Navigator.of(context).pop(); // Go back to module details
                      },
                      icon: const Icon(LucideIcons.arrowLeft, size: 16),
                      label: const Text('Back to Module'),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        _initializeSession(); // Start new session
                      },
                      icon: const Icon(LucideIcons.repeat, size: 16),
                      label: const Text('Study Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bgPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab(PomodoroSessionResults results) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSummaryCard(
            'Session Overview',
            [
              _buildStat('Cycles Completed', '${results.totalCyclesCompleted}/${results.totalCyclesPlanned}'),
              _buildStat('Work Time', '${results.totalWorkTime.inMinutes} minutes'),
              _buildStat('Break Time', '${results.totalBreakTime.inMinutes} minutes'),
              _buildStat('Completion Rate', '${results.completionPercentage.toStringAsFixed(1)}%'),
            ],
            Colors.blue,
          ),
          
          const SizedBox(height: 16),
          
          _buildSummaryCard(
            'Focus & Performance',
            [
              _buildStat('Average Focus', '${results.averageFocusScore.toStringAsFixed(1)}/10'),
              _buildStat('Interruptions', '${results.totalInterruptions}'),
              _buildStat('Notes Taken', '${results.totalNotes}'),
              _buildStat('Session Time', '${results.totalSessionTime.inMinutes} minutes'),
            ],
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(PomodoroSessionResults results) {
    // This would show detailed analytics if available
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.pieChart, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'Detailed Analytics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Advanced analytics will be available here.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsTab(PomodoroSessionResults results) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.target, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'AI Insights',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'AI-generated insights about your focus patterns will appear here.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepsTab(PomodoroSessionResults results) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.calendar, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'Recommended Next Steps',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Personalized study recommendations will be shown here.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, List<Widget> stats, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.barChart3, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...stats,
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
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