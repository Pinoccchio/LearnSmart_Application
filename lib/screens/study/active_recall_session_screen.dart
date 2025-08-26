import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/active_recall_models.dart';
import '../../models/study_analytics_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/gemini_ai_service.dart';
import '../../services/supabase_service.dart';
import '../../services/study_analytics_service.dart';
import '../../widgets/flashcard/flashcard_widget.dart';
import '../../widgets/flashcard/flashcard_result_widget.dart';
import '../../widgets/analytics/performance_chart_widget.dart';
import '../../widgets/analytics/recommendations_widget.dart';
import '../../widgets/analytics/study_plan_widget.dart';
import 'active_recall_completion_screen.dart';

class ActiveRecallSessionScreen extends StatefulWidget {
  final Course course;
  final Module module;

  const ActiveRecallSessionScreen({
    super.key,
    required this.course,
    required this.module,
  });

  @override
  State<ActiveRecallSessionScreen> createState() => _ActiveRecallSessionScreenState();
}

class _ActiveRecallSessionScreenState extends State<ActiveRecallSessionScreen> {
  late final GeminiAIService _geminiService;
  late final StudyAnalyticsService _analyticsService;
  late final PageController _pageController;
  
  StudySessionStatus _currentStatus = StudySessionStatus.preparing;
  List<ActiveRecallFlashcard> _flashcards = [];
  Map<String, ActiveRecallAttempt> _preStudyAttempts = {};
  Map<String, ActiveRecallAttempt> _postStudyAttempts = {};
  
  int _currentFlashcardIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  String? _sessionId;
  
  // Analytics data
  StudySessionAnalytics? _sessionAnalytics;
  
  @override
  void initState() {
    super.initState();
    _geminiService = GeminiAIService();
    _analyticsService = StudyAnalyticsService();
    _pageController = PageController();
    _initializeSession();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeSession() async {
    try {
      // === SESSION LIFECYCLE: Initialization Start ===
      print('🚀 [ACTIVE RECALL] Starting session initialization');
      print('🔄 [SESSION LIFECYCLE] Phase 1: Content Generation & Preparation');
      print('📊 [SESSION LIFECYCLE] Course: ${widget.course.title}');
      print('📊 [SESSION LIFECYCLE] Module: ${widget.module.title}');
      print('📊 [SESSION LIFECYCLE] Materials: ${widget.module.materials.length} items');
      
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Session ID will be generated during database creation phase
      
      // Check for PDF materials and show appropriate loading message
      final pdfMaterials = widget.module.materials.where((m) => m.fileType.toLowerCase() == 'pdf').length;
      if (pdfMaterials > 0) {
        print('📄 [ACTIVE RECALL] Found $pdfMaterials PDF material(s), extracting content for better flashcards...');
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Analyzing PDF content to create better study questions...\nThis may take a moment.';
        });
      }
      
      // Generate flashcards from module materials (now with PDF content extraction)
      print('🧠 [ACTIVE RECALL] Generating flashcards for ${widget.module.materials.length} materials');
      final flashcards = await _geminiService.generateFlashcardsFromMaterials(
        widget.module.materials,
        widget.module.title,
      );

      if (flashcards.isEmpty) {
        throw Exception('No flashcards could be generated from the materials');
      }

      // === SESSION LIFECYCLE: Database Creation Phase ===
      print('🔄 [SESSION LIFECYCLE] Phase 2: Database Session Creation');
      final sessionCreated = await _createSessionInDatabase();
      
      // Log session creation outcome
      if (sessionCreated) {
        print('✅ [SESSION LIFECYCLE] Database session created successfully');
        print('📊 [SESSION LIFECYCLE] Session ID: $_sessionId (DATABASE)');
        print('🔄 [SESSION LIFECYCLE] Phase 3: Flashcard Database Storage');
        await _saveFlashcardsToDatabase(flashcards);
      } else {
        print('❌ [SESSION LIFECYCLE] Database session creation failed');
        print('📊 [SESSION LIFECYCLE] Session ID: $_sessionId (LOCAL FALLBACK)');
        print('⚠️ [ACTIVE RECALL] Skipping flashcard database save due to session creation failure');
        print('📝 [ACTIVE RECALL] Session will continue with local data only');
      }

      // === SESSION LIFECYCLE: Initialization Complete ===
      print('🔄 [SESSION LIFECYCLE] Phase 4: UI State Update');
      if (!mounted) return;
      setState(() {
        _flashcards = flashcards;
        _currentStatus = StudySessionStatus.preStudy;
        _isLoading = false;
        _errorMessage = null; // Clear any loading messages
      });

      print('✅ [ACTIVE RECALL] Session initialized with ${flashcards.length} flashcards');
      print('📊 [SESSION LIFECYCLE] Session ready - Mode: ${sessionCreated ? 'DATABASE + LOCAL' : 'LOCAL ONLY'}');

    } catch (e) {
      print('❌ [ACTIVE RECALL] Session initialization failed: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to generate study materials: $e';
        _isLoading = false;
      });
    }
  }

  void _handleAnswerSubmitted(String answer, int responseTimeMs) {
    final flashcard = _flashcards[_currentFlashcardIndex];
    final isCorrect = _evaluateAnswer(answer, flashcard.answer);
    final phase = _currentStatus == StudySessionStatus.preStudy ? 'PRE-STUDY' : 'POST-STUDY';
    
    print('🎯 [ACTIVE RECALL - $phase] Answer submitted for flashcard ${_currentFlashcardIndex + 1}/${_flashcards.length}');
    print('   Question: ${flashcard.question}');
    print('   User Answer: "$answer"');
    print('   Correct Answer: "${flashcard.answer}"');
    print('   Result: ${isCorrect ? '✅ CORRECT' : '❌ INCORRECT'}');
    print('   Response Time: ${(responseTimeMs / 1000).toStringAsFixed(1)}s');
    
    final attempt = ActiveRecallAttempt(
      id: '${_sessionId}_${flashcard.id}_${_currentStatus == StudySessionStatus.preStudy ? 'pre' : 'post'}',
      sessionId: _sessionId!,
      flashcardId: flashcard.id,
      userAnswer: answer,
      isCorrect: isCorrect,
      responseTimeSeconds: (responseTimeMs / 1000).round(),
      attemptedAt: DateTime.now(),
      isPreStudy: _currentStatus == StudySessionStatus.preStudy,
    );

    if (_currentStatus == StudySessionStatus.preStudy) {
      _preStudyAttempts[flashcard.id] = attempt;
      final preCorrect = _preStudyAttempts.values.where((a) => a.isCorrect).length;
      print('📊 [PRE-STUDY PROGRESS] $preCorrect/${_preStudyAttempts.length} correct so far');
    } else {
      _postStudyAttempts[flashcard.id] = attempt;
      final postCorrect = _postStudyAttempts.values.where((a) => a.isCorrect).length;
      print('📊 [POST-STUDY PROGRESS] $postCorrect/${_postStudyAttempts.length} correct so far');
    }

    // Save attempt to database
    _saveAttemptToDatabase(attempt);

    // Show result screen
    _showResultDialog(flashcard, answer, isCorrect, responseTimeMs);
  }

  bool _evaluateAnswer(String userAnswer, String correctAnswer) {
    // Simple evaluation - in a real app, you might use more sophisticated matching
    final userLower = userAnswer.toLowerCase().trim();
    final correctLower = correctAnswer.toLowerCase().trim();
    
    // Check for exact match
    if (userLower == correctLower) return true;
    
    // Check if user answer contains key words from correct answer
    final correctWords = correctLower.split(' ').where((w) => w.length > 3).toList();
    final userWords = userLower.split(' ');
    
    int matches = 0;
    for (final word in correctWords) {
      if (userWords.any((uw) => uw.contains(word) || word.contains(uw))) {
        matches++;
      }
    }
    
    // Consider correct if at least 60% of key words match
    return correctWords.isNotEmpty && (matches / correctWords.length) >= 0.6;
  }

  void _showResultDialog(
    ActiveRecallFlashcard flashcard,
    String userAnswer,
    bool isCorrect,
    int responseTimeMs,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: FlashcardResultWidget(
          flashcard: flashcard,
          userAnswer: userAnswer,
          isCorrect: isCorrect,
          responseTimeMs: responseTimeMs,
          onContinue: () {
            Navigator.of(context).pop();
            _moveToNextFlashcard();
          },
        ),
      ),
    );
  }

  void _moveToNextFlashcard() {
    if (_currentFlashcardIndex < _flashcards.length - 1) {
      if (!mounted) return;
      setState(() {
        _currentFlashcardIndex++;
      });
      
      // Safely navigate to next page
      if (_pageController.hasClients && _pageController.positions.isNotEmpty) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        print('⚠️ [ACTIVE RECALL] PageController not ready for nextPage');
      }
    } else {
      _completeCurrentPhase();
    }
  }

  void _completeCurrentPhase() {
    if (_currentStatus == StudySessionStatus.preStudy) {
      // Move to study phase
      if (!mounted) return;
      setState(() {
        _currentStatus = StudySessionStatus.studying;
      });
      _showStudyMaterialsScreen();
    } else if (_currentStatus == StudySessionStatus.postStudy) {
      // Start analytics generation phase
      if (!mounted) return;
      setState(() {
        _currentStatus = StudySessionStatus.generatingAnalytics;
      });
      _showSessionResults();
    }
  }

  void _showStudyMaterialsScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final topPadding = MediaQuery.of(context).padding.top;
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final maxHeight = screenHeight - topPadding - bottomPadding - keyboardHeight - 100; // 100px margin from top
        
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              minHeight: 400,
            ),
            child: Container(
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
                  Text(
                    'Review the materials, then test your memory again',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
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
            
            // Continue button
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 20 + MediaQuery.of(context).padding.bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _startPostStudyPhase();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ready for Memory Test',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
                ],
              ),
            ),
          ),
        );
      },
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
      print('🔗 [URL LAUNCHER] Attempting to open: ${material.fileUrl}');
      print('📄 [FILE INFO] Type: ${material.fileType}, Name: ${material.fileName}');
      
      final Uri url = Uri.parse(material.fileUrl);
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Opening ${material.fileName}...'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }
      
      // Try different launch modes for better compatibility
      bool launched = false;
      String? lastError;
      
      // Check if URL can be launched first
      bool canLaunch = await canLaunchUrl(url);
      print('🔍 [URL LAUNCHER] canLaunchUrl result: $canLaunch');
      
      if (!canLaunch) {
        print('⚠️ [URL LAUNCHER] canLaunchUrl returned false, but trying anyway...');
      }
      
      // First try: Platform default (recommended approach)
      try {
        await launchUrl(url, mode: LaunchMode.platformDefault);
        launched = true;
        print('✅ [URL LAUNCHER] Successfully launched with platformDefault mode');
      } catch (e) {
        lastError = e.toString();
        print('⚠️ [URL LAUNCHER] platformDefault mode failed: $e');
      }
      
      // Second try: External application (for PDFs, this opens in default PDF viewer)
      if (!launched) {
        try {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          launched = true;
          print('✅ [URL LAUNCHER] Successfully launched with externalApplication mode');
        } catch (e) {
          lastError = e.toString();
          print('⚠️ [URL LAUNCHER] externalApplication mode failed: $e');
        }
      }
      
      // Third try: In-app web view (fallback)
      if (!launched) {
        try {
          await launchUrl(url, mode: LaunchMode.inAppWebView);
          launched = true;
          print('✅ [URL LAUNCHER] Successfully launched with inAppWebView mode');
        } catch (e) {
          lastError = e.toString();
          print('⚠️ [URL LAUNCHER] inAppWebView mode failed: $e');
        }
      }
      
      if (!launched) {
        print('❌ [URL LAUNCHER] All launch attempts failed. Last error: $lastError');
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Could not open ${material.fileName}'),
                  const SizedBox(height: 4),
                  Text(
                    'No app found to handle PDF files. Please install a PDF reader.',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Copy URL',
                textColor: Colors.white,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: material.fileUrl));
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('URL copied to clipboard!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
          );
        }
      } else {
        // Hide loading indicator on success
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }
      
    } catch (e) {
      print('❌ [URL LAUNCHER ERROR] Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Error opening ${material.fileName}'),
                const SizedBox(height: 4),
                Text(
                  e.toString(),
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Copy URL',
              textColor: Colors.white,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: material.fileUrl));
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('URL copied to clipboard!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    }
  }

  void _startPostStudyPhase() {
    if (!mounted) return;
    setState(() {
      _currentStatus = StudySessionStatus.postStudy;
      _currentFlashcardIndex = 0;
    });
    
    // Wait for PageView to be built and PageController to be attached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && _pageController.positions.isNotEmpty) {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        // If PageController isn't ready, just jump to page 0 without animation
        print('⚠️ [ACTIVE RECALL] PageController not ready, using jumpToPage instead');
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      }
    });
  }

  Future<void> _showSessionResults() async {
    print('🏁 [SESSION COMPLETE] Calculating results and generating analytics...');
    print('📊 [DEBUG] Pre-study attempts: ${_preStudyAttempts.length}');
    print('📊 [DEBUG] Post-study attempts: ${_postStudyAttempts.length}');
    
    // Debug pre-study results
    final preCorrect = _preStudyAttempts.values.where((a) => a.isCorrect).length;
    print('📊 [PRE-STUDY FINAL] $preCorrect/${_preStudyAttempts.length} correct');
    
    // Debug post-study results  
    final postCorrect = _postStudyAttempts.values.where((a) => a.isCorrect).length;
    print('📊 [POST-STUDY FINAL] $postCorrect/${_postStudyAttempts.length} correct');
    
    final results = StudySessionResults.calculate(
      _flashcards,
      [..._preStudyAttempts.values, ..._postStudyAttempts.values],
    );
    
    print('📈 [RESULTS] Improvement: ${results.improvementPercentage.toStringAsFixed(1)}%');
    print('⏱️ [RESULTS] Avg response time: ${results.averageResponseTime}s');

    // Update session as completed in database
    _updateSessionStatus(StudySessionStatus.completed);

    // Generate comprehensive analytics first, then navigate to completion screen
    // === SESSION LIFECYCLE: Completion Phase ===
    print('🔄 [SESSION LIFECYCLE] Phase 5: Session Completion & Analytics Generation');
    print('📊 [SESSION LIFECYCLE] Generating analytics for session: $_sessionId');
    await _generateSessionAnalytics(results);

    // Now that analytics are ready, move to completed state and navigate to completion screen
    print('🔄 [SESSION LIFECYCLE] Phase 6: UI State Completion');
    if (mounted) {
      setState(() {
        _currentStatus = StudySessionStatus.completed;
      });
      
      // Small delay to allow UI to update before navigation
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ActiveRecallCompletionScreen(
              course: widget.course,
              module: widget.module,
              sessionResults: results,
              sessionAnalytics: _sessionAnalytics,
              onBackToModule: () {
                Navigator.of(context).pop(); // Go back to module details
              },
              onStudyAgain: () {
                Navigator.of(context).pop(); // Go back to module details
                // Navigate back to the original Active Recall session screen
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => ActiveRecallSessionScreen(
                      course: widget.course,
                      module: widget.module,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Widget _buildEnhancedResultsDialog(StudySessionResults results) {
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
            // Header with close button
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: results.improvementPercentage > 0 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      results.improvementPercentage > 0 
                          ? LucideIcons.trendingUp
                          : LucideIcons.brain,
                      color: results.improvementPercentage > 0 
                          ? Colors.green
                          : Colors.blue,
                      size: 28,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Complete!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Comprehensive learning analysis',
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
                    text: 'Performance',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.pieChart, size: 16),
                    text: 'Descriptive Analytics',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.target, size: 16),
                    text: 'Prescriptive Analytics',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.calendar, size: 16),
                    text: 'Study Techniques',
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
                    // Performance Tab
                    _buildPerformanceTab(results),
                    
                    // Descriptive Analytics Tab
                    _buildDescriptiveAnalyticsTab(),
                    
                    // Prescriptive Analytics Tab
                    _buildPrescriptiveAnalyticsTab(),
                    
                    // Study Plan Tab
                    _buildStudyPlanTab(),
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
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        _initializeSession(); // Restart session
                      },
                      icon: const Icon(LucideIcons.repeat, size: 16),
                      label: const Text('Study Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bgPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  Widget _buildPerformanceTab(StudySessionResults results) {
    if (_sessionAnalytics != null) {
      return SingleChildScrollView(
        child: PerformanceChartWidget(
          performanceMetrics: _sessionAnalytics!.performanceMetrics,
          showDetails: true,
        ),
      );
    }
    
    // Fallback to basic results
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildBasicPerformanceCard(results),
        ],
      ),
    );
  }

  Widget _buildBasicPerformanceCard(StudySessionResults results) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: [
          const Text(
            'Session Results',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Pre-Study',
                  '${results.preStudyCorrect}/${results.totalFlashcards}',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Post-Study',
                  '${results.postStudyCorrect}/${results.totalFlashcards}',
                  Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildStatCard(
            'Improvement',
            results.improvementPercentage > 0 
                ? '+${results.improvementPercentage.toStringAsFixed(1)}%'
                : '${results.improvementPercentage.toStringAsFixed(1)}%',
            results.improvementPercentage > 0 ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptiveAnalyticsTab() {
    // Show comprehensive descriptive analytics if available
    if (_sessionAnalytics != null) {
      return SingleChildScrollView(
        child: Column(
          children: [
            // Behavior Analysis Section
            _buildDescriptiveSection(
              title: 'Behavior Analysis',
              icon: LucideIcons.activity,
              content: _buildBehaviorAnalysisContent(),
            ),
            
            const SizedBox(height: 16),
            
            // Cognitive Analysis Section
            _buildDescriptiveSection(
              title: 'Cognitive Analysis',
              icon: LucideIcons.brain,
              content: _buildCognitiveAnalysisContent(),
            ),
            
            const SizedBox(height: 16),
            
            // Learning Patterns Section
            _buildDescriptiveSection(
              title: 'Learning Patterns',
              icon: LucideIcons.trendingUp,
              content: _buildLearningPatternsContent(),
            ),
          ],
        ),
      );
    }
    
    return _buildEmptyTab(
      'Descriptive Analytics Unavailable',
      'Unable to generate detailed learning analytics for this session.',
      LucideIcons.pieChart,
    );
  }

  Widget _buildPrescriptiveAnalyticsTab() {
    // Show prescriptive analytics: actionable recommendations
    if (_sessionAnalytics != null) {
      return SingleChildScrollView(
        child: Column(
          children: [
            // Actionable Recommendations Section
            if (_sessionAnalytics!.recommendations.isNotEmpty) ...[
              _buildPrescriptiveSection(
                title: 'Actionable Recommendations',
                icon: LucideIcons.target,
                content: RecommendationsWidget(
                  recommendations: _sessionAnalytics!.recommendations,
                ),
              ),
            ],
          ],
        ),
      );
    }
    
    return _buildEmptyTab(
      'Prescriptive Analytics Unavailable',
      'Unable to generate prescriptive analytics for this session.',
      LucideIcons.target,
    );
  }

  Widget _buildStudyPlanTab() {
    // Show recommended study techniques based on performance analysis
    if (_sessionAnalytics?.suggestedStudyPlan != null) {
      return SingleChildScrollView(
        child: StudyPlanWidget(
          studyPlan: _sessionAnalytics!.suggestedStudyPlan,
        ),
      );
    }
    
    return _buildEmptyTab(
      'Study Techniques Unavailable',
      'Unable to recommend study techniques for this session.',
      LucideIcons.calendar,
    );
  }

  Widget _buildLoadingTab(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
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
          Icon(
            icon,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods for building descriptive analytics content
  Widget _buildDescriptiveSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
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
              Icon(icon, size: 20, color: AppColors.bgPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
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
              Icon(icon, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildBehaviorAnalysisContent() {
    final behavior = _sessionAnalytics!.behaviorAnalysis;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnalyticsRow('Study Time', '${behavior.totalStudyTime.inMinutes} minutes'),
        _buildAnalyticsRow('Persistence Score', '${behavior.persistenceScore.toStringAsFixed(1)}/100'),
        _buildAnalyticsRow('Engagement Level', '${behavior.engagementLevel.toStringAsFixed(1)}/100'),
        if (behavior.commonErrorTypes.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Common Error Patterns:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          ...behavior.commonErrorTypes.map((error) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $error',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildCognitiveAnalysisContent() {
    final cognitive = _sessionAnalytics!.cognitiveAnalysis;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnalyticsRow('Processing Speed', '${cognitive.processingSpeed.toStringAsFixed(1)}/100'),
        _buildAnalyticsRow('Cognitive Load', '${cognitive.cognitiveLoadScore.toStringAsFixed(1)}/100'),
        _buildAnalyticsRow('Attention Span', '${cognitive.attentionSpan.toStringAsFixed(1)}/100'),
        if (cognitive.cognitiveStrengths.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Cognitive Strengths:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.green),
          ),
          const SizedBox(height: 4),
          ...cognitive.cognitiveStrengths.map((strength) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $strength',
              style: const TextStyle(fontSize: 12, color: Colors.green),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          )),
        ],
        if (cognitive.cognitiveWeaknesses.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Areas for Improvement:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.orange),
          ),
          const SizedBox(height: 4),
          ...cognitive.cognitiveWeaknesses.map((weakness) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $weakness',
              style: const TextStyle(fontSize: 12, color: Colors.orange),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildLearningPatternsContent() {
    final patterns = _sessionAnalytics!.learningPatterns;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnalyticsRow('Learning Pattern', patterns.patternType.name),
        _buildAnalyticsRow('Learning Velocity', '${patterns.learningVelocity.toStringAsFixed(2)}/question'),
        if (patterns.strongConcepts.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Strong Concepts:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.green),
          ),
          const SizedBox(height: 4),
          ...patterns.strongConcepts.map((concept) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $concept',
              style: const TextStyle(fontSize: 12, color: Colors.green),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          )),
        ],
        if (patterns.weakConcepts.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Weak Concepts:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.red),
          ),
          const SizedBox(height: 4),
          ...patterns.weakConcepts.map((concept) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $concept',
              style: const TextStyle(fontSize: 12, color: Colors.red),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildAnalyticsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsDialog(StudySessionResults results) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: results.improvementPercentage > 0 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                results.improvementPercentage > 0 
                    ? LucideIcons.trendingUp
                    : LucideIcons.brain,
                color: results.improvementPercentage > 0 
                    ? Colors.green
                    : Colors.blue,
                size: 40,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Session Complete!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Results stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Pre-Study',
                    '${results.preStudyCorrect}/${results.totalFlashcards}',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Post-Study',
                    '${results.postStudyCorrect}/${results.totalFlashcards}',
                    Colors.green,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildStatCard(
              'Improvement',
              results.improvementPercentage > 0 
                  ? '+${results.improvementPercentage.toStringAsFixed(1)}%'
                  : '${results.improvementPercentage.toStringAsFixed(1)}%',
              results.improvementPercentage > 0 ? Colors.green : Colors.red,
            ),
            
            const SizedBox(height: 32),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Go back to module details
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      _initializeSession(); // Restart session
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bgPrimary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Study Again',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getPhaseTitle() {
    switch (_currentStatus) {
      case StudySessionStatus.preparing:
        return 'Preparing Session...';
      case StudySessionStatus.preStudy:
        return 'Pre-Study Test';
      case StudySessionStatus.studying:
        return 'Study Materials';
      case StudySessionStatus.postStudy:
        return 'Memory Test';
      case StudySessionStatus.generatingAnalytics:
        return 'Analyzing Performance...';
      case StudySessionStatus.completed:
        return 'Session Complete';
      case StudySessionStatus.paused:
        return 'Session Paused';
    }
  }

  String _getPhaseDescription() {
    switch (_currentStatus) {
      case StudySessionStatus.preparing:
        return 'Generating flashcards from your materials...';
      case StudySessionStatus.preStudy:
        return 'Test your existing knowledge before studying';
      case StudySessionStatus.studying:
        return 'Review the materials carefully';
      case StudySessionStatus.postStudy:
        return 'Test your memory after studying';
      case StudySessionStatus.generatingAnalytics:
        return 'Generating comprehensive descriptive and prescriptive analytics...';
      case StudySessionStatus.completed:
        return 'Great work! Review your results below';
      case StudySessionStatus.paused:
        return 'Session is paused';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(
        title: Text(_getPhaseTitle()),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_currentStatus == StudySessionStatus.preStudy || 
              _currentStatus == StudySessionStatus.postStudy)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentFlashcardIndex + 1}/${_flashcards.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorScreen()
              : _buildSessionContent(),
    );
  }

  Widget _buildErrorScreen() {
    // Check if this is actually a loading message rather than an error
    final isLoadingMessage = _errorMessage?.contains('Analyzing PDF content') == true;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLoadingMessage ? LucideIcons.fileText : LucideIcons.alertTriangle,
              size: 64,
              color: isLoadingMessage ? Colors.blue : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              isLoadingMessage ? 'Processing Materials' : 'Session Error',
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
            if (isLoadingMessage) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Extracting text from PDF materials to generate\nhigh-quality, content-specific study questions',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeSession,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionContent() {
    if (_currentStatus == StudySessionStatus.preStudy || 
        _currentStatus == StudySessionStatus.postStudy) {
      return Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  _getPhaseDescription(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: (_currentFlashcardIndex + 1) / _flashcards.length,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _currentStatus == StudySessionStatus.preStudy 
                        ? Colors.orange 
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          
          // Flashcard content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _flashcards.length,
              itemBuilder: (context, index) {
                return FlashcardWidget(
                  flashcard: _flashcards[index],
                  onAnswerSubmitted: _handleAnswerSubmitted,
                  isPreStudy: _currentStatus == StudySessionStatus.preStudy,
                  onShowHint: () {
                    // Track hint usage if needed
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    if (_currentStatus == StudySessionStatus.generatingAnalytics) {
      return _buildAnalyticsLoadingScreen();
    }

    if (_currentStatus == StudySessionStatus.completed) {
      // This state should only show briefly, as the dialog should appear
      return _buildSessionCompleteScreen();
    }

    return const Center(
      child: Text('Invalid session state'),
    );
  }

  Widget _buildAnalyticsLoadingScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.brain,
                color: Colors.blue,
                size: 40,
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Analyzing Your Performance',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            Text(
              _getPhaseDescription(),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            const CircularProgressIndicator(),
            
            const SizedBox(height: 16),
            
            const Text(
              'This may take a moment...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCompleteScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.checkCircle,
                color: Colors.green,
                size: 40,
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Session Complete!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            const Text(
              'Your detailed results are ready to view.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Database persistence methods
  Future<bool> _createSessionInDatabase() async {
    try {
      print('💾 [DATABASE] Creating session in database...');
      
      // Get authenticated user
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not authenticated. Please log in to start study session.');
      }
      
      final userId = currentUser.id;
      print('💾 [DATABASE] Using authenticated user: ${currentUser.name} (${currentUser.email})');
      print('💾 [DATABASE] User ID: $userId');
      
      // Validate module exists
      final moduleExists = await _validateModuleExists(widget.module.id);
      if (!moduleExists) {
        throw Exception('Module ${widget.module.id} does not exist in database');
      }
      
      // Validate user exists in database (should exist since they're authenticated)
      final userExists = await _validateUserExists(userId);
      if (!userExists) {
        throw Exception('Authenticated user $userId not found in database');
      }
      
      final sessionData = {
        // Don't include 'id' - let database generate UUID
        'user_id': userId,
        'module_id': widget.module.id,
        'status': StudySessionStatus.preparing.name,
        'session_data': {
          'course_title': widget.course.title,
          'module_title': widget.module.title,
          'total_materials': widget.module.materials.length,
        },
      };
      
      print('💾 [DATABASE] Session data: $sessionData');
      
      final response = await SupabaseService.client
          .from('active_recall_sessions')
          .insert(sessionData)
          .select('id')
          .single();
      
      // Store the generated session ID and validate it
      final createdSessionId = response['id'];
      if (createdSessionId == null || createdSessionId.toString().isEmpty) {
        throw Exception('Database returned null or empty session ID');
      }
      
      _sessionId = createdSessionId.toString();
      print('✅ [DATABASE] Session created successfully with ID: $_sessionId');
      
      // Verify session was actually created by querying it back
      await _verifySessionExists(_sessionId!);
      
      print('✅ [DATABASE] Session existence verified in database');
      return true; // Success
      
    } catch (e) {
      print('❌ [DATABASE] Failed to create session: $e');
      
      // Provide specific error messages for debugging
      if (e.toString().contains('User not authenticated')) {
        print('💡 [AUTH] Error: User not logged in. Please log in to start study session.');
        _sessionId = null;
        if (mounted) {
          setState(() {
            _errorMessage = 'Please log in to start a study session';
            _isLoading = false;
          });
        }
        return false;
      } else if (e.toString().contains('active_recall_sessions_user_id_fkey')) {
        print('💡 [DATABASE] Error: Authenticated user ID not found in users table.');
        print('💡 [DATABASE] User may not have a corresponding record in the users table.');
      } else if (e.toString().contains('active_recall_sessions_module_id_fkey')) {
        print('💡 [DATABASE] Error: Module ID does not exist. Check modules table.');
        print('💡 [DATABASE] Module ${widget.module.id} may not be synced to database.');
      } else if (e.toString().contains('row-level security policy')) {
        print('💡 [DATABASE] Error: RLS policy blocked session creation.');
        print('💡 [DATABASE] User may not have permission to create sessions for this module.');
      } else if (e.toString().contains('Session existence verification failed')) {
        print('💡 [DATABASE] Error: Session was created but verification failed.');
        print('💡 [DATABASE] This could indicate a race condition or database inconsistency.');
      } else {
        print('💡 [DATABASE] Unexpected database error: ${e.toString()}');
      }
      
      // Generate fallback session ID for local tracking
      // Use timestamp + random component to ensure uniqueness
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (timestamp % 10000); // Last 4 digits for uniqueness
      _sessionId = 'local_${timestamp}_$random';
      print('⚠️ [DATABASE] Using fallback session ID: $_sessionId');
      print('⚠️ [DATABASE] Session will run locally - analytics will not be saved to database');
      
      return false; // Failed to create in database
    }
  }

  Future<void> _saveFlashcardsToDatabase(List<ActiveRecallFlashcard> flashcards) async {
    try {
      print('💾 [DATABASE] Saving ${flashcards.length} flashcards...');
      print('💾 [DATABASE] Module ID: ${widget.module.id}');
      
      // Validate all material IDs exist before saving flashcards
      for (final flashcard in flashcards) {
        final materialExists = await _validateMaterialExists(flashcard.materialId);
        if (!materialExists) {
          print('⚠️ [DATABASE] Material ${flashcard.materialId} does not exist, skipping flashcard ${flashcard.id}');
          continue;
        }
      }
      
      final flashcardData = flashcards.map((flashcard) {
        final json = flashcard.toJson();
        print('💾 [DATABASE] Flashcard: ${json['id']} for material ${json['material_id']}');
        return json;
      }).toList();
      
      // Insert flashcards in batches to handle large sets
      const batchSize = 10;
      for (int i = 0; i < flashcardData.length; i += batchSize) {
        final batch = flashcardData.skip(i).take(batchSize).toList();
        await SupabaseService.client
            .from('active_recall_flashcards')
            .insert(batch);
        print('💾 [DATABASE] Saved batch ${(i ~/ batchSize) + 1} of ${(flashcardData.length / batchSize).ceil()}');
      }
      
      print('✅ [DATABASE] All flashcards saved successfully');
    } catch (e) {
      print('❌ [DATABASE] Failed to save flashcards: $e');
      
      // Provide specific error messages
      if (e.toString().contains('duplicate key')) {
        print('💡 [DATABASE] Error: Duplicate flashcard IDs detected. Check ID generation logic.');
      } else if (e.toString().contains('active_recall_flashcards_material_id_fkey')) {
        print('💡 [DATABASE] Error: Material ID does not exist. Check course_materials table.');
      } else if (e.toString().contains('active_recall_flashcards_module_id_fkey')) {
        print('💡 [DATABASE] Error: Module ID does not exist. Check modules table.');
      } else if (e.toString().contains('row-level security policy')) {
        print('⚠️ [DATABASE] RLS policy blocked flashcard insert - user may not be enrolled in course');
      }
      
      // Don't throw - continue with local flashcards
    }
  }

  Future<void> _saveAttemptToDatabase(ActiveRecallAttempt attempt) async {
    try {
      print('💾 [DATABASE] Saving attempt: ${attempt.isCorrect ? 'CORRECT' : 'INCORRECT'} - ${attempt.isPreStudy ? 'PRE' : 'POST'}');
      print('💾 [DATABASE] Session ID: ${attempt.sessionId}');
      print('💾 [DATABASE] Flashcard ID: ${attempt.flashcardId}');
      
      final attemptData = attempt.toJson();
      // Remove the 'id' field - let database generate it
      attemptData.remove('id');
      
      await SupabaseService.client
          .from('active_recall_attempts')
          .insert(attemptData);
      
      print('✅ [DATABASE] Attempt saved successfully');
    } catch (e) {
      print('❌ [DATABASE] Failed to save attempt: $e');
      if (e.toString().contains('row-level security policy')) {
        print('⚠️ [DATABASE] RLS policy blocked attempt insert - session may not belong to user');
      }
      // Don't throw - continue with local tracking
    }
  }

  Future<void> _updateSessionStatus(StudySessionStatus status) async {
    if (_sessionId == null || _sessionId!.startsWith('local_')) {
      print('⚠️ [DATABASE] Skipping session status update - using local session ID');
      return;
    }
    
    try {
      print('💾 [DATABASE] Updating session status to: ${status.name}');
      print('💾 [DATABASE] Session ID: $_sessionId');
      
      final updateData = <String, dynamic>{
        'status': status.name,
      };
      
      if (status == StudySessionStatus.completed) {
        updateData['completed_at'] = DateTime.now().toIso8601String();
      }
      
      await SupabaseService.client
          .from('active_recall_sessions')
          .update(updateData)
          .eq('id', _sessionId!);
      
      print('✅ [DATABASE] Session status updated successfully');
    } catch (e) {
      print('❌ [DATABASE] Failed to update session status: $e');
      if (e.toString().contains('row-level security policy')) {
        print('⚠️ [DATABASE] RLS policy blocked session update - session may not belong to user');
      }
    }
  }

  /// Generate comprehensive session analytics
  Future<void> _generateSessionAnalytics(StudySessionResults results) async {
    if (_sessionId == null) {
      print('⚠️ [ANALYTICS] No session ID available, skipping analytics generation');
      return;
    }
    
    // Enhanced session validation before analytics generation
    print('📊 [ANALYTICS] Session ID source analysis: $_sessionId');
    print('📊 [ANALYTICS] Session ID type: ${_sessionId!.startsWith('local_') ? 'LOCAL FALLBACK' : 'DATABASE GENERATED'}');
    
    // Check if we're using a fallback session ID (session creation failed)
    if (_sessionId!.startsWith('local_')) {
      print('⚠️ [ANALYTICS] Using fallback session ID - session was not created in database');
      print('📊 [ANALYTICS] Reason: Original session creation failed, running in offline mode');
      print('📊 [ANALYTICS] Generating local analytics only (will not save to database)');
      
      // Generate fallback analytics for local use only
      if (mounted) {
        setState(() {
          _sessionAnalytics = _generateFallbackAnalytics(results);
        });
      }
      return;
    }
    
    // For database sessions, perform final validation
    try {
      print('🔍 [ANALYTICS] Performing final session validation before analytics generation...');
      await _verifySessionExists(_sessionId!);
      print('✅ [ANALYTICS] Final session validation passed - proceeding with analytics generation');
    } catch (e) {
      print('❌ [ANALYTICS] Final session validation failed: $e');
      print('⚠️ [ANALYTICS] Session may have been deleted or never properly created');
      print('📊 [ANALYTICS] Falling back to local analytics generation');
      
      // Generate fallback analytics when session validation fails
      if (mounted) {
        setState(() {
          _sessionAnalytics = _generateFallbackAnalytics(results);
        });
      }
      return;
    }
    
    try {
      print('📊 [ANALYTICS] Starting comprehensive analytics generation...');
      print('📊 [ANALYTICS] Session ID: $_sessionId (database session)');
      
      final allAttempts = [..._preStudyAttempts.values, ..._postStudyAttempts.values];
      
      final analytics = await _analyticsService.generateSessionAnalytics(
        sessionId: _sessionId!,
        userId: Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '',
        moduleId: widget.module.id,
        flashcards: _flashcards,
        attempts: allAttempts,
        course: widget.course,
        module: widget.module,
      );
      
      // Always set analytics, regardless of database save success
      if (mounted) {
        setState(() {
          _sessionAnalytics = analytics;
        });
      }
      
      print('✅ [ANALYTICS] Analytics generation completed successfully');
      
    } catch (e) {
      print('❌ [ANALYTICS] Failed to generate analytics: $e');
      
      // Check if this is the specific session reference error
      if (e.toString().contains('Invalid session_id for active_recall session type')) {
        print('💡 [ANALYTICS] Database constraint violation - session not found in active_recall_sessions table');
        print('💡 [ANALYTICS] This suggests the session creation failed earlier but was not properly handled');
      }
      
      // Set fallback analytics so tabs aren't completely empty
      if (mounted) {
        setState(() {
          _sessionAnalytics = _generateFallbackAnalytics(results);
        });
      }
    }
  }

  /// Generate fallback analytics when full generation fails
  StudySessionAnalytics _generateFallbackAnalytics(StudySessionResults results) {
    return StudySessionAnalytics(
      id: '', // Database will generate UUID if saved
      sessionId: _sessionId ?? 'fallback_session',
      userId: Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? 'unknown',
      moduleId: widget.module.id,
      analyzedAt: DateTime.now(),
      performanceMetrics: PerformanceMetrics(
        preStudyAccuracy: (results.preStudyCorrect / results.totalFlashcards) * 100,
        postStudyAccuracy: (results.postStudyCorrect / results.totalFlashcards) * 100,
        improvementPercentage: results.improvementPercentage,
        averageResponseTime: results.averageResponseTime.toDouble(),
        accuracyByDifficulty: 0.0,
        materialPerformance: {},
        conceptMastery: {},
        overallLevel: results.improvementPercentage > 20 ? PerformanceLevel.good : PerformanceLevel.average,
      ),
      learningPatterns: LearningPatterns(
        patternType: LearningPatternType.steadyProgression,
        learningVelocity: results.improvementPercentage / results.totalFlashcards,
        strongConcepts: [],
        weakConcepts: [],
        retentionRates: {},
        temporalPatterns: [],
      ),
      behaviorAnalysis: BehaviorAnalysis(
        totalStudyTime: Duration(seconds: results.averageResponseTime * results.totalFlashcards),
        hintUsageCount: 0,
        hintEffectiveness: 0.0,
        commonErrorTypes: ['Analysis unavailable'],
        questionAttemptPatterns: {
          'total': results.totalFlashcards,
          'correct': results.postStudyCorrect,
        },
        persistenceScore: 75.0,
        engagementLevel: results.improvementPercentage > 0 ? 80.0 : 60.0,
      ),
      cognitiveAnalysis: CognitiveAnalysis(
        cognitiveLoadScore: 50.0,
        memoryRetentionByType: {},
        processingSpeed: 100 / results.averageResponseTime,
        cognitiveStrengths: results.improvementPercentage > 20 ? ['Good learning improvement'] : [],
        cognitiveWeaknesses: results.improvementPercentage < 10 ? ['May need more study time'] : [],
        attentionSpan: 75.0,
      ),
      recommendations: [
        PersonalizedRecommendation(
          id: 'fallback_rec',
          type: RecommendationType.studyTiming,
          title: 'Continue Learning',
          description: results.improvementPercentage > 0 
              ? 'You showed good improvement in this session!'
              : 'Focus on reviewing the material again.',
          actionableAdvice: results.improvementPercentage > 20
              ? 'Keep up the excellent work with your study routine.'
              : 'Consider spending more time with the study materials before testing.',
          priority: 1,
          confidenceScore: 0.7,
          reasons: ['Basic performance analysis'],
        ),
      ],
      insights: [
        AnalyticsInsight(
          id: 'fallback_insight',
          category: InsightCategory.performance,
          title: 'Session Summary',
          insight: 'You improved by ${results.improvementPercentage.toStringAsFixed(1)}% from pre-study to post-study testing.',
          significance: 0.8,
          supportingData: [
            'Pre-study score: ${results.preStudyCorrect}/${results.totalFlashcards}',
            'Post-study score: ${results.postStudyCorrect}/${results.totalFlashcards}',
          ],
        ),
      ],
      suggestedStudyPlan: StudyPlan(
        id: 'fallback_plan',
        activities: [
          StudyActivity(
            type: 'review',
            description: 'Review the study materials again',
            duration: const Duration(minutes: 30),
            priority: 1,
            materials: ['Course materials'],
          ),
        ],
        estimatedDuration: const Duration(minutes: 30),
        focusAreas: {'improvement': 'Focus on understanding key concepts'},
        objectives: ['Improve retention', 'Build confidence'],
      ),
    );
  }

  // Database validation methods
  Future<bool> _validateUserExists(String userId) async {
    try {
      final response = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      
      final exists = response != null;
      print('🔍 [DATABASE] User $userId exists: $exists');
      return exists;
    } catch (e) {
      print('❌ [DATABASE] Error checking user existence: $e');
      return false;
    }
  }

  Future<bool> _validateModuleExists(String moduleId) async {
    try {
      final response = await SupabaseService.client
          .from('modules')
          .select('id')
          .eq('id', moduleId)
          .maybeSingle();
      
      final exists = response != null;
      print('🔍 [DATABASE] Module $moduleId exists: $exists');
      return exists;
    } catch (e) {
      print('❌ [DATABASE] Error checking module existence: $e');
      return false;
    }
  }

  Future<bool> _validateMaterialExists(String materialId) async {
    try {
      final response = await SupabaseService.client
          .from('course_materials')
          .select('id')
          .eq('id', materialId)
          .maybeSingle();
      
      final exists = response != null;
      print('🔍 [DATABASE] Material $materialId exists: $exists');
      return exists;
    } catch (e) {
      print('❌ [DATABASE] Error checking material existence: $e');
      return false;
    }
  }

  /// Verify that a created session actually exists in the database
  Future<void> _verifySessionExists(String sessionId) async {
    try {
      print('🔍 [DATABASE] Verifying session exists: $sessionId');
      
      final response = await SupabaseService.client
          .from('active_recall_sessions')
          .select('id, status, created_at')
          .eq('id', sessionId)
          .maybeSingle();
      
      if (response == null) {
        throw Exception('Session existence verification failed: Session $sessionId not found in active_recall_sessions table');
      }
      
      print('✅ [DATABASE] Session verified - ID: $sessionId, Status: ${response['status']}, Created: ${response['created_at']}');
      
    } catch (e) {
      print('❌ [DATABASE] Session verification failed: $e');
      throw Exception('Session existence verification failed: $e');
    }
  }
}