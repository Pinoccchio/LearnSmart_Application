import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/feynman_models.dart';
import '../../models/study_analytics_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/feynman_service.dart';
import '../../widgets/feynman/feynman_progress_widget.dart';
import '../../widgets/feynman/explanation_input_widget.dart';
import '../../widgets/feynman/explanation_feedback_widget.dart';
import 'feynman_completion_screen.dart';

class FeynmanSessionScreen extends StatefulWidget {
  final Course course;
  final Module module;
  final String? initialTopic;

  const FeynmanSessionScreen({
    super.key,
    required this.course,
    required this.module,
    this.initialTopic,
  });

  @override
  State<FeynmanSessionScreen> createState() => _FeynmanSessionScreenState();
}

class _FeynmanSessionScreenState extends State<FeynmanSessionScreen>
    with WidgetsBindingObserver {
  late final FeynmanService _feynmanService;
  
  bool _isInitializing = true;
  String? _errorMessage;
  StudySessionAnalytics? _sessionAnalytics;
  FeynmanSessionResults? _sessionResults;
  
  // Topic selection
  final TextEditingController _topicController = TextEditingController();
  bool _topicSelected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _feynmanService = FeynmanService();
    _topicController.text = widget.initialTopic ?? '';
    _topicSelected = widget.initialTopic != null;
    
    // Listen for text changes to update button state in real-time
    _topicController.addListener(() {
      setState(() {});
    });
    
    if (_topicSelected) {
      _initializeSession();
    } else {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _topicController.dispose();
    _feynmanService.dispose();
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

      final topic = _topicController.text.trim();
      if (topic.isEmpty) {
        throw Exception('Please enter a topic to explain.');
      }

      print('🧠 [FEYNMAN SCREEN] Initializing Feynman session for ${widget.module.title}');
      
      await _feynmanService.initializeSession(
        userId: currentUser.id,
        module: widget.module,
        topic: topic,
      );

      setState(() {
        _isInitializing = false;
        _topicSelected = true;
      });

      print('✅ [FEYNMAN SCREEN] Session initialized successfully');

    } catch (e) {
      print('❌ [FEYNMAN SCREEN] Failed to initialize session: $e');
      setState(() {
        _errorMessage = 'Failed to initialize Feynman session: $e';
        _isInitializing = false;
      });
    }
  }

  Future<void> _startExplanationPhase() async {
    try {
      await _feynmanService.startExplanationPhase();
      print('🧠 [FEYNMAN SCREEN] Started explanation phase');
    } catch (e) {
      print('❌ [FEYNMAN SCREEN] Failed to start explanation phase: $e');
      _showErrorDialog('Failed to start explanation phase: $e');
    }
  }

  Future<void> _startReviewPhase() async {
    try {
      await _feynmanService.startReviewPhase();
      print('🧠 [FEYNMAN SCREEN] Started review phase');
    } catch (e) {
      print('❌ [FEYNMAN SCREEN] Failed to start review phase: $e');
      _showErrorDialog('Failed to start review phase: $e');
    }
  }

  Future<void> _completeSession() async {
    try {
      await _feynmanService.completeSession();
      print('🧠 [FEYNMAN SCREEN] Session completed');
      await _onSessionComplete();
    } catch (e) {
      print('❌ [FEYNMAN SCREEN] Failed to complete session: $e');
      _showErrorDialog('Failed to complete session: $e');
    }
  }

  Future<void> _onExplanationSubmitted() async {
    print('🧠 [FEYNMAN SCREEN] Explanation submitted');
    // The service will handle AI analysis automatically
    // We can optionally provide immediate feedback to the user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Explanation submitted! AI analysis in progress...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onSessionComplete() async {
    try {
      print('🎉 [FEYNMAN SCREEN] Session completed, generating results...');
      
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
                  'Analyzing your learning session',
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
      _sessionResults = await _feynmanService.getSessionResults();
      
      // Generate comprehensive analytics
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _sessionAnalytics = await _feynmanService.generateSessionAnalytics(
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
      print('❌ [FEYNMAN SCREEN] Failed to process session completion: $e');
      
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
        builder: (context) => FeynmanCompletionScreen(
          course: widget.course,
          module: widget.module,
          sessionResults: _sessionResults!,
          sessionAnalytics: _sessionAnalytics,
          onBackToModule: () {
            // Navigate back to module details by popping multiple screens:
            // 1st pop: Close completion screen
            // 2nd pop: Close Feynman session screen
            // 3rd pop: Close study technique selector modal
            Navigator.of(context).pop(); // Close completion screen
            Navigator.of(context).pop(); // Close Feynman screen
            Navigator.of(context).pop(); // Close technique selector modal
          },
          onStudyAgain: () {
            Navigator.of(context).pop(); // Close completion screen
            _resetSession(); // Start new session
          },
        ),
      ),
    );
  }

  Future<void> _resetSession() async {
    setState(() {
      _topicSelected = false;
      _errorMessage = null;
      _sessionAnalytics = null;
      _sessionResults = null;
    });
    _topicController.clear();
  }

  Future<void> _stopSession() async {
    try {
      await _feynmanService.forceStopSession();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('❌ [FEYNMAN SCREEN] Failed to stop session: $e');
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
        title: const Text('Feynman Technique'),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          // Materials access button
          IconButton(
            onPressed: _showMaterials,
            icon: const Icon(LucideIcons.bookOpen),
          ),
          
          // Stop session button
          if (_topicSelected)
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
              : !_topicSelected
                  ? _buildTopicSelectionScreen()
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
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _topicSelected = false;
                });
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicSelectionScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header
          Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.brain,
                        color: Colors.purple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Feynman Technique',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Learn by teaching: ${widget.module.title}',
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
                
                const SizedBox(height: 20),
                
                const Text(
                  'Choose a topic from this module that you want to master by explaining it in your own words.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Topic input
          Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What topic do you want to explain?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                TextField(
                  controller: _topicController,
                  decoration: InputDecoration(
                    hintText: 'e.g., "Machine Learning Algorithms", "Photosynthesis Process"',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.grey300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.grey300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                ),
                
                const SizedBox(height: 20),
                
                ElevatedButton(
                  onPressed: _topicController.text.trim().isNotEmpty
                      ? _initializeSession
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.play, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Start Feynman Session',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // How it works
          _buildHowItWorks(),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.helpCircle,
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'How the Feynman Technique Works',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildStep(
            1,
            'Explain',
            'Write your explanation as if teaching someone who knows nothing about the topic.',
            Colors.blue,
          ),
          
          _buildStep(
            2,
            'Get Feedback',
            'AI analyzes your explanation for clarity, completeness, and accuracy.',
            Colors.green,
          ),
          
          _buildStep(
            3,
            'Improve',
            'Identify knowledge gaps and refine your understanding through iteration.',
            Colors.purple,
          ),
          
          _buildStep(
            4,
            'Master',
            'Complete the session when you can explain the topic clearly and completely.',
            Colors.orange,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String title, String description, Color color, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  number.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (!isLast) ...[
              Container(
                width: 2,
                height: 40,
                color: color.withOpacity(0.3),
              ),
            ],
          ],
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (!isLast) const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionContent() {
    return ListenableBuilder(
      listenable: _feynmanService,
      builder: (context, child) {
        final session = _feynmanService.currentSession;
        
        if (session == null) {
          return const Center(child: Text('No active session'));
        }

        // Check if session is completed
        if (session.isCompleted && _sessionResults == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onSessionComplete();
          });
        }

        return Column(
          children: [
            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Progress widget
                    FeynmanProgressWidget(
                      feynmanService: _feynmanService,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Input widget (shown during explaining and reviewing phases)
                    if (session.status == FeynmanSessionStatus.explaining ||
                        session.status == FeynmanSessionStatus.reviewing) ...[
                      ExplanationInputWidget(
                        feynmanService: _feynmanService,
                        onExplanationSubmitted: _onExplanationSubmitted,
                        enabled: !_feynmanService.isProcessingExplanation,
                      ),
                      
                      const SizedBox(height: 20),
                    ],
                    
                    // Feedback widgets for each explanation
                    ..._feynmanService.sessionExplanations.map((explanation) {
                      final feedback = _feynmanService.sessionFeedback
                          .where((f) => f.explanationId == explanation.id)
                          .toList();
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: ExplanationFeedbackWidget(
                          explanation: explanation,
                          feedback: feedback,
                        ),
                      );
                    }).toList(),
                    
                    const SizedBox(height: 100), // Space for controls
                  ],
                ),
              ),
            ),
            
            // Controls at bottom
            SafeArea(
              child: _buildControls(session),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(FeynmanSession session) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back/Stop button
          OutlinedButton(
            onPressed: _stopSession,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.x, size: 16),
                const SizedBox(width: 8),
                const Text('Stop'),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Phase progression button
          Expanded(
            child: _buildPhaseButton(session),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseButton(FeynmanSession session) {
    switch (session.status) {
      case FeynmanSessionStatus.preparing:
        return ElevatedButton(
          onPressed: _startExplanationPhase,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.edit, size: 16),
              SizedBox(width: 8),
              Text('Start Explaining'),
            ],
          ),
        );
      
      case FeynmanSessionStatus.explaining:
        final hasExplanations = _feynmanService.sessionExplanations.isNotEmpty;
        return ElevatedButton(
          onPressed: hasExplanations ? _startReviewPhase : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.search, size: 16),
              SizedBox(width: 8),
              Text('Review Explanations'),
            ],
          ),
        );
      
      case FeynmanSessionStatus.reviewing:
        return ElevatedButton(
          onPressed: _completeSession,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.checkCircle, size: 16),
              SizedBox(width: 8),
              Text('Complete Session'),
            ],
          ),
        );
      
      case FeynmanSessionStatus.completed:
      case FeynmanSessionStatus.paused:
        return ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.arrowLeft, size: 16),
              SizedBox(width: 8),
              Text('Back to Module'),
            ],
          ),
        );
    }
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
                  'Reference materials for your explanation',
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
      
      // Show brief info message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(LucideIcons.bookOpen, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Opening ${material.fileName}'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
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