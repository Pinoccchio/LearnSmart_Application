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

      // Close loading dialog and show results
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showSessionResultsDialog();
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
                    _showSessionResultsDialog(); // Show results without analytics
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


  Widget _buildResultsDialog(PomodoroSessionResults results) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        maxWidth: MediaQuery.of(context).size.width * 0.95,
      ),
      child: DefaultTabController(
        length: 2,
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
                        // Close the dialog first
                        Navigator.of(context).pop();
                        
                        // Pop twice to go back to module details:
                        // 1st pop: Close Pomodoro session screen
                        // 2nd pop: Close study technique selector modal
                        Navigator.of(context).pop(); // Close Pomodoro screen
                        Navigator.of(context).pop(); // Close technique selector modal
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
    // Show comprehensive analytics if available
    if (_sessionAnalytics != null) {
      return SingleChildScrollView(
        child: Column(
          children: [
            // DESCRIPTIVE ANALYTICS SECTION
            _buildAnalyticsMainSection(
              title: 'Descriptive Analytics',
              subtitle: 'Data-driven insights about your study session',
              icon: LucideIcons.pieChart,
              color: Colors.blue,
              children: [
                // Behavior Analysis
                _buildDescriptiveSection(
                  title: 'Focus Behavior Analysis',
                  icon: LucideIcons.activity,
                  content: _buildPomodoroFocusBehaviorContent(),
                ),
                
                const SizedBox(height: 12),
                
                // Cognitive Analysis
                _buildDescriptiveSection(
                  title: 'Cognitive Performance',
                  icon: LucideIcons.brain,
                  content: _buildPomodoroCognitiveAnalysisContent(),
                ),
                
                const SizedBox(height: 12),
                
                // Learning Patterns
                _buildDescriptiveSection(
                  title: 'Focus Patterns',
                  icon: LucideIcons.trendingUp,
                  content: _buildPomodoroLearningPatternsContent(),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // PRESCRIPTIVE ANALYTICS SECTION
            _buildAnalyticsMainSection(
              title: 'Prescriptive Analytics',
              subtitle: 'AI-powered recommendations and next steps',
              icon: LucideIcons.target,
              color: Colors.orange,
              children: [
                // AI Insights
                if (_sessionAnalytics!.insights.isNotEmpty) ...[ 
                  _buildPrescriptiveSection(
                    title: 'AI-Generated Insights',
                    icon: LucideIcons.lightbulb,
                    content: InsightsWidget(
                      insights: _sessionAnalytics!.insights,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Actionable Recommendations
                if (_sessionAnalytics!.recommendations.isNotEmpty) ...[ 
                  _buildPrescriptiveSection(
                    title: 'Personalized Recommendations',
                    icon: LucideIcons.checkSquare,
                    content: RecommendationsWidget(
                      recommendations: _sessionAnalytics!.recommendations,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Study Plan (Next Steps)
                _buildPrescriptiveSection(
                  title: 'Recommended Next Steps',
                  icon: LucideIcons.calendar,
                  content: StudyPlanWidget(
                    studyPlan: _sessionAnalytics!.suggestedStudyPlan,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    return _buildEmptyTab(
      'Analytics Unavailable',
      'Unable to generate detailed analytics for this session.',
      LucideIcons.pieChart,
    );
  }


  // Helper methods for analytics content
  Widget _buildAnalyticsMainSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main section header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Content area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptiveSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptiveSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTab(String title, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPomodoroFocusBehaviorContent() {
    final analytics = _sessionAnalytics!;
    final behavior = analytics.behaviorAnalysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnalyticsRow('Engagement Level', '${(behavior.engagementLevel * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 8),
        _buildAnalyticsRow('Persistence Score', '${(behavior.persistenceScore * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 8),
        _buildAnalyticsRow('Total Study Time', '${behavior.totalStudyTime.inMinutes} minutes'),
        const SizedBox(height: 8),
        _buildAnalyticsRow('Hint Usage', '${behavior.hintUsageCount}'),
        const SizedBox(height: 12),
        if (behavior.commonErrorTypes.isNotEmpty) ...[
          const Text(
            'Common Error Patterns:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...behavior.commonErrorTypes.map((error) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $error', 
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildPomodoroCognitiveAnalysisContent() {
    final analytics = _sessionAnalytics!;
    final cognitive = analytics.cognitiveAnalysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnalyticsRow('Cognitive Load Score', '${cognitive.cognitiveLoadScore.toStringAsFixed(1)}/10'),
        const SizedBox(height: 8),
        _buildAnalyticsRow('Processing Speed', '${cognitive.processingSpeed.toStringAsFixed(2)}s avg'),
        const SizedBox(height: 8),
        _buildAnalyticsRow('Attention Span', '${cognitive.attentionSpan.toStringAsFixed(1)} minutes'),
        const SizedBox(height: 12),
        if (cognitive.cognitiveStrengths.isNotEmpty) ...[
          const Text(
            'Cognitive Strengths:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...cognitive.cognitiveStrengths.map((strength) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $strength', 
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          )),
          const SizedBox(height: 8),
        ],
        if (cognitive.cognitiveWeaknesses.isNotEmpty) ...[
          const Text(
            'Areas for Improvement:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...cognitive.cognitiveWeaknesses.map((weakness) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $weakness', 
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildPomodoroLearningPatternsContent() {
    final analytics = _sessionAnalytics!;
    final patterns = analytics.learningPatterns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnalyticsRow('Learning Pattern', patterns.patternType.name.replaceAll('_', ' ').toUpperCase()),
        const SizedBox(height: 8),
        _buildAnalyticsRow('Learning Velocity', '${patterns.learningVelocity.toStringAsFixed(2)}x'),
        const SizedBox(height: 12),
        if (patterns.strongConcepts.isNotEmpty) ...[
          const Text(
            'Strong Concepts:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...patterns.strongConcepts.map((concept) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $concept', 
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          )),
          const SizedBox(height: 8),
        ],
        if (patterns.weakConcepts.isNotEmpty) ...[
          const Text(
            'Areas to Focus:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...patterns.weakConcepts.map((concept) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $concept', 
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildAnalyticsRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            textAlign: TextAlign.right,
          ),
        ),
      ],
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