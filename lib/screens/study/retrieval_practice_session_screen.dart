import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/retrieval_practice_models.dart';
import '../../models/study_analytics_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/retrieval_practice_service.dart';
import '../../widgets/retrieval_practice/retrieval_question_widget.dart';
import '../../widgets/retrieval_practice/retrieval_results_widget.dart';
import '../../widgets/retrieval_practice/retrieval_progress_widget.dart';
import 'retrieval_practice_completion_screen.dart';

class RetrievalPracticeSessionScreen extends StatefulWidget {
  final Course course;
  final Module module;
  final RetrievalPracticeSettings? customSettings;

  const RetrievalPracticeSessionScreen({
    super.key,
    required this.course,
    required this.module,
    this.customSettings,
  });

  @override
  State<RetrievalPracticeSessionScreen> createState() => _RetrievalPracticeSessionScreenState();
}

class _RetrievalPracticeSessionScreenState extends State<RetrievalPracticeSessionScreen>
    with WidgetsBindingObserver {
  late final RetrievalPracticeService _retrievalService;
  
  bool _isInitializing = true;
  String? _errorMessage;
  StudySessionAnalytics? _sessionAnalytics;
  RetrievalPracticeResults? _sessionResults;
  
  // Question timing
  DateTime? _questionStartTime;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _retrievalService = RetrievalPracticeService();
    _initializeSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retrievalService.dispose();
    super.dispose();
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

      // Initializing retrieval practice session
      
      await _retrievalService.initializeSession(
        userId: currentUser.id,
        module: widget.module,
        customSettings: widget.customSettings,
      );

      await _retrievalService.startSession();
      _startQuestionTimer();

      setState(() {
        _isInitializing = false;
      });

      // Session initialized successfully

    } catch (e) {
      // Failed to initialize session: $e
      setState(() {
        _errorMessage = 'Failed to initialize Retrieval Practice session: $e';
        _isInitializing = false;
      });
    }
  }

  void _startQuestionTimer() {
    _questionStartTime = DateTime.now();
  }

  Future<void> _onAnswerSubmitted({
    required String userAnswer,
    int? confidenceLevel,
    bool hintUsed = false,
  }) async {
    if (_questionStartTime == null) return;

    try {
      final responseTime = DateTime.now().difference(_questionStartTime!);
      
      await _retrievalService.submitAnswer(
        userAnswer: userAnswer,
        responseTimeSeconds: responseTime.inSeconds,
        confidenceLevel: confidenceLevel,
        hintUsed: hintUsed,
      );

      // Show immediate feedback if enabled
      if (_retrievalService.settings.showFeedbackAfterEach) {
        await _showQuestionFeedback();
      } else {
        await _moveToNextQuestion();
      }

    } catch (e) {
      // Failed to submit answer: $e
      _showErrorDialog('Failed to submit answer: $e');
    }
  }

  Future<void> _showQuestionFeedback() async {
    final currentQuestion = _retrievalService.currentQuestion;
    final lastAttempt = _retrievalService.sessionAttempts.lastOrNull;
    
    if (currentQuestion == null || lastAttempt == null) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              lastAttempt.isCorrect ? LucideIcons.checkCircle : LucideIcons.xCircle,
              color: lastAttempt.isCorrect ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(lastAttempt.isCorrect ? 'Correct!' : 'Incorrect'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question: ${currentQuestion.questionText}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text('Your Answer: "${lastAttempt.userAnswer}"'),
            const SizedBox(height: 8),
            Text(
              'Correct Answer: "${currentQuestion.correctAnswer}"',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (currentQuestion.conceptTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                children: currentQuestion.conceptTags.map((tag) => 
                  Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.blue.shade50,
                    side: BorderSide(color: Colors.blue.shade200),
                  ),
                ).toList(),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _moveToNextQuestion();
            },
            child: Text(_retrievalService.hasMoreQuestions ? 'Next Question' : 'Complete Session'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToNextQuestion() async {
    await _retrievalService.nextQuestion();
    
    if (_retrievalService.currentSession?.isCompleted == true) {
      await _onSessionComplete();
    } else {
      _startQuestionTimer();
    }
  }

  Future<void> _onSessionComplete() async {
    try {
      // Session completed, generating results
      
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
                  'Analyzing your retrieval practice performance',
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

      // Get session results
      _sessionResults = await _retrievalService.getSessionResults();
      
      // Generate comprehensive analytics
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _sessionAnalytics = await _retrievalService.generateSessionAnalytics(
        userId: authProvider.currentUser!.id,
        module: widget.module,
        course: widget.course,
      );
      
      // Close loading dialog and navigate to completion screen
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _navigateToCompletionScreen();
      }
      
    } catch (e) {
      // Failed to process session completion: $e
      
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
        builder: (context) => RetrievalPracticeCompletionScreen(
          course: widget.course,
          module: widget.module,
          sessionResults: _sessionResults!,
          sessionAnalytics: _sessionAnalytics,
          onBackToModule: () {
            Navigator.of(context).pop(); // Close completion screen
            Navigator.of(context).pop(); // Close session screen
          },
          onStudyAgain: () {
            Navigator.of(context).pop(); // Close completion screen
            _initializeSession(); // Start new session
          },
        ),
      ),
    );
  }

  Future<void> _stopSession() async {
    try {
      await _retrievalService.forceStopSession();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Failed to stop session: $e
      _showErrorDialog('Failed to stop session: $e');
    }
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
        title: const Text('Retrieval Practice'),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          // Stop session button
          if (!_isInitializing && _errorMessage == null)
            IconButton(
              onPressed: _stopSession,
              icon: const Icon(LucideIcons.x),
            ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorScreen()
              : _buildSessionContent(),
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
      listenable: _retrievalService,
      builder: (context, child) {
        final service = _retrievalService;
        final currentQuestion = service.currentQuestion;
        
        if (currentQuestion == null) {
          return const Center(
            child: Text('No questions available'),
          );
        }

        return Column(
          children: [
            // Progress widget
            RetrievalProgressWidget(
              retrievalService: service,
            ),
            
            const SizedBox(height: 16),
            
            // Question content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: RetrievalQuestionWidget(
                  question: currentQuestion,
                  onAnswerSubmitted: _onAnswerSubmitted,
                  allowHints: service.settings.allowHints,
                  requireConfidence: service.settings.requireConfidenceRating,
                  isProcessing: service.isProcessingAnswer,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}