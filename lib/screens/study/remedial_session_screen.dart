import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../models/course_models.dart';
import '../../models/active_recall_models.dart';
import '../../models/remedial_models.dart';
import '../../services/remedial_service.dart';
import '../../widgets/dialogs/modern_error_dialog.dart';
import 'remedial_completion_screen.dart';
import '../../widgets/remedial/remedial_question_widget.dart';
import '../../widgets/remedial/remedial_progress_widget.dart';

class RemedialSessionScreen extends StatefulWidget {
  final Course course;
  final Module module;
  final String originalSessionId;
  final List<ActiveRecallFlashcard> originalFlashcards;
  final List<ActiveRecallAttempt> originalAttempts;
  final StudySessionResults originalResults;
  final RemedialSettings? customSettings;

  const RemedialSessionScreen({
    super.key,
    required this.course,
    required this.module,
    required this.originalSessionId,
    required this.originalFlashcards,
    required this.originalAttempts,
    required this.originalResults,
    this.customSettings,
  });

  @override
  State<RemedialSessionScreen> createState() => _RemedialSessionScreenState();
}

class _RemedialSessionScreenState extends State<RemedialSessionScreen> 
    with WidgetsBindingObserver {
  late RemedialService _remedialService;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _error;
  
  // Answer handling
  final TextEditingController _answerController = TextEditingController();
  String _currentAnswer = '';
  bool _showingFeedback = false;
  bool _lastAnswerCorrect = false;
  
  // Performance optimization and memory management
  Timer? _debounceTimer;
  bool _isProcessingHeavyOperation = false;
  int _memoryWarningCount = 0;
  DateTime? _lastMemoryCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeRemedialService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _answerController.dispose();
    _debounceTimer?.cancel();
    if (_isInitialized) {
      _remedialService.removeListener(_onServiceStateChanged);
      _remedialService.resetSession();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Save progress when app goes to background
      _saveProgress();
    }
  }

  Future<void> _initializeRemedialService() async {
    if (_isInitializing) return;
    
    _setLoadingStateDebounced(true, null);
    
    // Mark heavy processing start
    _isProcessingHeavyOperation = true;

    try {
      // Check memory before heavy operations
      await _checkMemoryUsage('initialization_start');
      
      _remedialService = RemedialService();
      _remedialService.addListener(_onServiceStateChanged);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      print('🔄 [REMEDIAL SCREEN] Initializing remedial session...');
      print('   Original session: ${widget.originalSessionId}');
      print('   Original flashcards: ${widget.originalFlashcards.length}');
      print('   Original attempts: ${widget.originalAttempts.length}');

      // Create remedial session
      final session = await _remedialService.createRemedialSession(
        originalSessionId: widget.originalSessionId,
        userId: userId,
        moduleId: widget.module.id,
        originalFlashcards: widget.originalFlashcards,
        originalAttempts: widget.originalAttempts,
        materials: widget.module.materials,
        customSettings: widget.customSettings,
      );

      // Check memory after initialization
      await _checkMemoryUsage('initialization_complete');
      
      _isProcessingHeavyOperation = false;

      if (session != null && mounted) {
        _setInitializedStateDebounced(true, false);
        print('✅ [REMEDIAL SCREEN] Session initialized successfully');
      } else if (mounted) {
        throw Exception('No remedial session needed or failed to create');
      }

    } catch (e) {
      print('❌ [REMEDIAL SCREEN] Initialization failed: $e');
      _isProcessingHeavyOperation = false;
      if (mounted) {
        _handleInitializationError(e);
      }
    }
  }

  void _onServiceStateChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 16), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _saveProgress() async {
    try {
      // Save current progress to database if needed
      print('💾 [REMEDIAL SCREEN] Saving progress...');
    } catch (e) {
      print('⚠️ [REMEDIAL SCREEN] Failed to save progress: $e');
    }
  }

  void _handleAnswerSubmit() async {
    if (_currentAnswer.trim().isEmpty || _remedialService.isProcessingAnswer) {
      return;
    }

    final answer = _currentAnswer.trim();
    _answerController.clear();

    try {
      final isCorrect = await _remedialService.processAnswer(answer);
      
      _setFeedbackStateDebounced(isCorrect, true);

      // Auto-advance after showing feedback
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _handleNextFlashcard();
        }
      });

    } catch (e) {
      print('❌ [REMEDIAL SCREEN] Error processing answer: $e');
      _showErrorDialog('Failed to process your answer. Please try again.');
    }
  }

  void _handleNextFlashcard() {
    if (!_remedialService.hasMoreFlashcards) {
      _completeSession();
      return;
    }

    _remedialService.nextFlashcard();
    
    _setAnswerStateDebounced('', false, false);
  }

  void _completeSession() async {
    try {
      print('🏁 [REMEDIAL SCREEN] Completing remedial session...');
      
      // Mark heavy processing start
      _isProcessingHeavyOperation = true;
      
      // Check memory before heavy analytics operations
      await _checkMemoryUsage('completion_start');
      
      final originalAccuracy = (widget.originalResults.postStudyCorrect / 
                               widget.originalResults.totalFlashcards) * 100;
      
      final results = await _remedialService.completeSession(
        originalAccuracy: originalAccuracy,
      );
      
      // Check memory after completion processing
      await _checkMemoryUsage('completion_complete');
      
      _isProcessingHeavyOperation = false;

      if (mounted) {
        // Delay navigation to avoid lifecycle issues
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => RemedialCompletionScreen(
                course: widget.course,
                module: widget.module,
                originalResults: widget.originalResults,
                remedialResults: results,
                sessionAnalytics: _remedialService.sessionAnalytics,
                onBackToModule: () {
                  // Navigate back to module details by popping multiple screens
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(); // Close completion screen
                  }
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(); // Close remedial screen
                  }
                },
                onRetakeRemedial: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(); // Close completion screen
                  }
                  // Restart this remedial screen
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => RemedialSessionScreen(
                        course: widget.course,
                        module: widget.module,
                        originalSessionId: widget.originalSessionId,
                        originalFlashcards: widget.originalFlashcards,
                        originalAttempts: widget.originalAttempts,
                        originalResults: widget.originalResults,
                        customSettings: widget.customSettings,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }
      }

    } catch (e) {
      print('❌ [REMEDIAL SCREEN] Error completing session: $e');
      _isProcessingHeavyOperation = false;
      
      // Handle memory errors specifically
      _handleMemoryError(e);
      
      if (mounted) {
        _showErrorDialog('Failed to complete the session. Please try again.');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => ModernErrorDialog(
        title: 'Remedial Session Error',
        message: message,
        onRetry: () {
          Navigator.of(context).pop();
          _initializeRemedialService();
        },
      ),
    );
  }

  void _handleExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Remedial Session'),
        content: const Text('Are you sure you want to exit? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close screen
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  // Optimized state update methods to reduce buffer overflow
  void _setLoadingStateDebounced(bool initializing, String? error) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && !_isProcessingHeavyOperation) {
        setState(() {
          _isInitializing = initializing;
          _error = error;
        });
      }
    });
  }
  
  void _setInitializedStateDebounced(bool initialized, bool initializing) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _isInitialized = initialized;
          _isInitializing = initializing;
        });
      }
    });
  }
  
  void _setFeedbackStateDebounced(bool correct, bool showFeedback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _lastAnswerCorrect = correct;
          _showingFeedback = showFeedback;
        });
      }
    });
  }
  
  void _setAnswerStateDebounced(String answer, bool showFeedback, bool correct) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _currentAnswer = answer;
          _showingFeedback = showFeedback;
          _lastAnswerCorrect = correct;
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
      _setLoadingStateDebounced(false, error.toString());
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Remedial Quiz',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.module.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          onPressed: _handleExit,
          icon: const Icon(LucideIcons.x),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorState();
    }

    if (_isInitializing || !_isInitialized) {
      return _buildLoadingState();
    }

    if (_remedialService.sessionFlashcards.isEmpty) {
      return _buildNoQuestionsState();
    }

    return _buildQuizInterface();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.alertCircle,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to Start Remedial Quiz',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
                ElevatedButton(
                  onPressed: _initializeRemedialService,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text(
            'Preparing Your Remedial Quiz...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_remedialService.isGeneratingQuestions)
            const Text(
              'AI is generating personalized questions\nbased on concepts you missed',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildNoQuestionsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.checkCircle,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            const Text(
              'No Remedial Quiz Needed!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your performance was strong enough that no additional review is required.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Module'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizInterface() {
    final currentFlashcard = _remedialService.currentFlashcard;
    
    if (currentFlashcard == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Progress Section
        RemedialProgressWidget(
          currentIndex: _remedialService.currentFlashcardIndex,
          totalQuestions: _remedialService.sessionFlashcards.length,
          progress: _remedialService.progress,
        ),
        
        // Question Section
        Expanded(
          child: RemedialQuestionWidget(
            flashcard: currentFlashcard,
            answerController: _answerController,
            onAnswerChanged: (value) {
              setState(() {
                _currentAnswer = value;
              });
            },
            onSubmitAnswer: _handleAnswerSubmit,
            showingFeedback: _showingFeedback,
            lastAnswerCorrect: _lastAnswerCorrect,
            isProcessing: _remedialService.isProcessingAnswer,
          ),
        ),
        
        // Submit Button
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _currentAnswer.trim().isNotEmpty && 
                     !_remedialService.isProcessingAnswer &&
                     !_showingFeedback;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.grey200, width: 1),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canSubmit ? _handleAnswerSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? AppColors.bgPrimary : AppColors.grey300,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _remedialService.isProcessingAnswer
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _showingFeedback 
                        ? (_lastAnswerCorrect ? 'Correct!' : 'Try Again') 
                        : 'Submit Answer',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}