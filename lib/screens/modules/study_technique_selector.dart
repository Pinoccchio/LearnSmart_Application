import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/course_models.dart';
import '../../models/pomodoro_models.dart';
import '../study/active_recall_session_screen.dart';
import '../study/pomodoro_session_screen.dart';
import '../study/feynman_session_screen.dart';
import '../study/retrieval_practice_session_screen.dart';
import '../../widgets/pomodoro/pomodoro_settings_widget.dart';
import '../../widgets/retrieval_practice/retrieval_settings_widget.dart';
import '../../models/retrieval_practice_models.dart';
import '../../services/retrieval_practice_service.dart';
import '../../models/active_recall_models.dart';
import '../../services/active_recall_service.dart';
import '../../services/pomodoro_service.dart';
import '../../widgets/active_recall/active_recall_settings_widget.dart';

class StudyTechniqueSelector extends StatefulWidget {
  final Course course;
  final Module module;

  const StudyTechniqueSelector({
    super.key,
    required this.course,
    required this.module,
  });

  @override
  State<StudyTechniqueSelector> createState() => _StudyTechniqueSelectorState();
}

class _StudyTechniqueSelectorState extends State<StudyTechniqueSelector> {
  String? selectedTechnique;
  PomodoroSettings? customPomodoroSettings;
  RetrievalPracticeSettings? customRetrievalSettings;
  ActiveRecallSettings? customActiveRecallSettings;

  @override
  void initState() {
    super.initState();
    _loadSavedRetrievalSettings();
    _loadSavedActiveRecallSettings();
    _loadSavedPomodoroSettings();
  }

  Future<void> _loadSavedRetrievalSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;
    
    if (userId == null) return;
    
    try {
      // Use the correct service method that queries user_retrieval_practice_settings table
      final retrievalService = RetrievalPracticeService();
      final savedSettings = await retrievalService.getUserRetrievalPracticeSettings(userId);
      
      if (mounted) {
        setState(() {
          customRetrievalSettings = savedSettings;
        });
        print('✅ [STUDY SELECTOR] Loaded retrieval settings: ${savedSettings.questionsPerSession} questions');
      }
    } catch (e) {
      print('⚠️ [STUDY SELECTOR] Failed to load retrieval settings: $e');
      // Use default settings on error
    }
  }

  Future<void> _loadSavedActiveRecallSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;
    
    if (userId == null) return;
    
    try {
      final activeRecallService = ActiveRecallService();
      final savedSettings = await activeRecallService.getUserActiveRecallSettings(userId);
      
      if (mounted) {
        setState(() {
          customActiveRecallSettings = savedSettings;
        });
        print('✅ [STUDY SELECTOR] Loaded active recall settings: ${savedSettings.flashcardsPerSession} flashcards');
      }
    } catch (e) {
      print('⚠️ [STUDY SELECTOR] Failed to load active recall settings: $e');
      // Use default settings on error
    }
  }

  Future<void> _loadSavedPomodoroSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;
    
    if (userId == null) return;
    
    try {
      final pomodoroService = PomodoroService();
      final savedSettings = await pomodoroService.getUserPomodoroSettings(userId);
      
      if (mounted) {
        setState(() {
          customPomodoroSettings = savedSettings;
        });
        print('✅ [STUDY SELECTOR] Loaded pomodoro settings: ${savedSettings.workDuration.inMinutes}m work, ${savedSettings.shortBreakDuration.inMinutes}m break');
      }
    } catch (e) {
      print('⚠️ [STUDY SELECTOR] Failed to load pomodoro settings: $e');
      // Use default settings on error
    }
  }

  @override
  Widget build(BuildContext context) {
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
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 24),
                Text(
                  'Select a study technique',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.module.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'from ${widget.course.title}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Study techniques list
          Flexible(
            child: Consumer<AppProvider>(
              builder: (context, appProvider, child) {
                final techniques = appProvider.studyTechniques;
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: techniques.length,
                  itemBuilder: (context, index) {
                    final technique = techniques[index];
                    final isSelected = selectedTechnique == technique.id;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedTechnique = technique.id;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AppColors.bgPrimary.withValues(alpha: 0.1)
                                : AppColors.grey100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected 
                                  ? AppColors.bgPrimary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? AppColors.bgPrimary
                                      : AppColors.textSecondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  technique.icon,
                                  color: AppColors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            technique.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected 
                                                  ? AppColors.bgPrimary
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        // Settings button for Active Recall
                                        if (technique.id == 'active_recall')
                                          GestureDetector(
                                            onTap: () => _showActiveRecallSettings(),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppColors.grey100,
                                                borderRadius: BorderRadius.circular(6),
                                                border: customActiveRecallSettings != null
                                                    ? Border.all(color: AppColors.bgPrimary, width: 1)
                                                    : null,
                                              ),
                                              child: Icon(
                                                Icons.settings,
                                                size: 16,
                                                color: customActiveRecallSettings != null
                                                    ? AppColors.bgPrimary
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        // Settings button for Pomodoro Technique
                                        if (technique.id == 'pomodoro_technique')
                                          GestureDetector(
                                            onTap: () => _showPomodoroSettings(),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppColors.grey100,
                                                borderRadius: BorderRadius.circular(6),
                                                border: customPomodoroSettings != null
                                                    ? Border.all(color: AppColors.bgPrimary, width: 1)
                                                    : null,
                                              ),
                                              child: Icon(
                                                Icons.settings,
                                                size: 16,
                                                color: customPomodoroSettings != null
                                                    ? AppColors.bgPrimary
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        // Settings button for Retrieval Practice
                                        if (technique.id == 'retrieval_practice')
                                          GestureDetector(
                                            onTap: () => _showRetrievalPracticeSettings(),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppColors.grey100,
                                                borderRadius: BorderRadius.circular(6),
                                                border: customRetrievalSettings != null
                                                    ? Border.all(color: AppColors.bgPrimary, width: 1)
                                                    : null,
                                              ),
                                              child: Icon(
                                                Icons.settings,
                                                size: 16,
                                                color: customRetrievalSettings != null
                                                    ? AppColors.bgPrimary
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      technique.description,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    // Show custom settings info for Active Recall
                                    if (technique.id == 'active_recall' && customActiveRecallSettings != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Custom: ${customActiveRecallSettings!.flashcardsPerSession} flashcards, ${customActiveRecallSettings!.preferredFlashcardTypes.length} types, ${customActiveRecallSettings!.studyMode.value.replaceAll('_', ' ')}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.bgPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    // Show custom settings info if configured
                                    if (technique.id == 'pomodoro_technique' && customPomodoroSettings != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Custom: ${customPomodoroSettings!.workDuration.inMinutes}m work, ${customPomodoroSettings!.shortBreakDuration.inMinutes}m break',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.bgPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    // Show custom settings info for Retrieval Practice
                                    if (technique.id == 'retrieval_practice' && customRetrievalSettings != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Custom: ${customRetrievalSettings!.questionsPerSession} questions, ${customRetrievalSettings!.preferredQuestionTypes.length} types${customRetrievalSettings!.allowHints ? ', Hints' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.bgPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: AppColors.bgPrimary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: AppColors.white,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Continue button
          Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: selectedTechnique != null 
                    ? () {
                        Navigator.of(context).pop();
                        _startStudySession();
                      }
                    : null,
                child: const Text(
                  'Continue',
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
  }

  void _startStudySession() {
    if (selectedTechnique == null) return;
    
    // Handle different study techniques
    switch (selectedTechnique) {
      case 'active_recall':
        _startActiveRecallSession();
        break;
      case 'pomodoro_technique':
        _startPomodoroSession();
        break;
      case 'feynman_technique':
        _startFeynmanSession();
        break;
      case 'retrieval_practice':
        _startRetrievalPracticeSession();
        break;
      default:
        _showComingSoonDialog('Selected technique');
    }
  }
  
  void _startActiveRecallSession() {
    // Navigate to Active Recall session screen with custom settings
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ActiveRecallSessionScreen(
          course: widget.course,
          module: widget.module,
          customSettings: customActiveRecallSettings,
        ),
      ),
    );
  }
  
  void _startPomodoroSession() {
    // Navigate to Pomodoro session screen with custom settings
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PomodoroSessionScreen(
          course: widget.course,
          module: widget.module,
          customSettings: customPomodoroSettings,
        ),
      ),
    );
  }
  
  void _startFeynmanSession() {
    // Navigate to Feynman session screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FeynmanSessionScreen(
          course: widget.course,
          module: widget.module,
        ),
      ),
    );
  }
  
  void _startRetrievalPracticeSession() {
    // Navigate to Retrieval Practice session screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RetrievalPracticeSessionScreen(
          course: widget.course,
          module: widget.module,
          customSettings: customRetrievalSettings,
        ),
      ),
    );
  }
  
  void _showPomodoroSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to customize settings')),
      );
      return;
    }

    final result = await showModalBottomSheet<PomodoroSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PomodoroSettingsWidget(
        userId: userId,
        initialSettings: PomodoroSettings.classic(), // Fallback only, widget will load saved settings
        onSettingsChanged: (settings) {
          if (mounted) {
            setState(() {
              customPomodoroSettings = settings;
            });
          }
        },
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        customPomodoroSettings = result;
      });
    }
  }

  void _showRetrievalPracticeSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to customize settings')),
      );
      return;
    }

    final result = await showModalBottomSheet<RetrievalPracticeSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RetrievalSettingsWidget(
        userId: userId,
        initialSettings: customRetrievalSettings ?? RetrievalPracticeSettings(),
        onSettingsChanged: (settings) {
          if (mounted) {
            setState(() {
              customRetrievalSettings = settings;
            });
          }
        },
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        customRetrievalSettings = result;
      });
    }
  }

  void _showActiveRecallSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to customize settings')),
      );
      return;
    }

    final result = await showModalBottomSheet<ActiveRecallSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ActiveRecallSettingsWidget(
        userId: userId,
        initialSettings: customActiveRecallSettings ?? const ActiveRecallSettings(),
        onSettingsChanged: (settings) {
          if (mounted) {
            setState(() {
              customActiveRecallSettings = settings;
            });
          }
        },
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        customActiveRecallSettings = result;
      });
    }
  }
  
  void _showComingSoonDialog(String techniqueName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: Text('$techniqueName is coming soon! For now, try Active Recall to experience our AI-powered study sessions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}