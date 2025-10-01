import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/onboarding_models.dart';
import '../../services/onboarding_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/onboarding/likert_scale_widget.dart';
import 'onboarding_results_screen.dart';

class OnboardingQuestionnaireScreen extends StatefulWidget {
  const OnboardingQuestionnaireScreen({super.key});

  @override
  State<OnboardingQuestionnaireScreen> createState() =>
      _OnboardingQuestionnaireScreenState();
}

class _OnboardingQuestionnaireScreenState
    extends State<OnboardingQuestionnaireScreen> {
  final OnboardingService _onboardingService = OnboardingService();
  late List<OnboardingQuestion> _questions;
  late Map<int, int> _responses; // questionNumber -> responseValue
  int _currentQuestionIndex = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _questions = OnboardingService.getOnboardingQuestions();
    _responses = {};
  }

  OnboardingQuestion get _currentQuestion => _questions[_currentQuestionIndex];
  int get _totalQuestions => _questions.length;
  bool get _isLastQuestion => _currentQuestionIndex == _totalQuestions - 1;
  bool get _isFirstQuestion => _currentQuestionIndex == 0;
  bool get _canProceed => _responses.containsKey(_currentQuestion.questionNumber);

  void _selectResponse(int value) {
    setState(() {
      _responses[_currentQuestion.questionNumber] = value;
    });
  }

  void _nextQuestion() {
    if (!_canProceed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an answer before continuing'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_isLastQuestion) {
      _submitResponses();
    } else {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (!_isFirstQuestion) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _submitResponses() async {
    if (_responses.length != _totalQuestions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please answer all ${_totalQuestions} questions (${_responses.length}/${_totalQuestions} answered)',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create response objects
      final responseObjects = _questions.map((question) {
        return OnboardingResponse(
          userId: userId,
          questionNumber: question.questionNumber,
          techniqueCategory: question.techniqueCategory,
          responseValue: _responses[question.questionNumber]!,
          isReverseCoded: question.isReverseCoded,
        );
      }).toList();

      // Save all responses
      await _onboardingService.saveAllResponses(responseObjects);

      // Calculate and save results
      final result = await _onboardingService.calculateAndSaveResults(userId);

      if (!mounted) return;

      // Navigate to results screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => OnboardingResultsScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting responses: $e'),
          backgroundColor: AppColors.error,
        ),
      );

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: _isFirstQuestion
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: _isSubmitting ? null : _previousQuestion,
              ),
        title: Text(
          'Learning Style Assessment',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _totalQuestions,
            backgroundColor: AppColors.grey200,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.bgPrimary),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator text
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.white,
              width: double.infinity,
              child: Text(
                'Question ${_currentQuestionIndex + 1} of $_totalQuestions',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getCategoryColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getCategoryName(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getCategoryColor(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Question text
                          Text(
                            _currentQuestion.questionText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Likert scale
                          LikertScaleWidget(
                            selectedValue: _responses[_currentQuestion.questionNumber],
                            onChanged: _isSubmitting ? (_) {} : _selectResponse,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (!_isFirstQuestion)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : _previousQuestion,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.grey300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Previous',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  if (!_isFirstQuestion) const SizedBox(width: 12),
                  Expanded(
                    flex: _isFirstQuestion ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : (_canProceed ? _nextQuestion : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bgPrimary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: AppColors.grey300,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.white,
                                ),
                              ),
                            )
                          : Text(
                              _isLastQuestion ? 'Submit' : 'Next',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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

  String _getCategoryName() {
    switch (_currentQuestion.techniqueCategory) {
      case 'active_recall':
        return 'Active Recall';
      case 'pomodoro':
        return 'Pomodoro';
      case 'feynman':
        return 'Feynman';
      case 'retrieval_practice':
        return 'Retrieval Practice';
      default:
        return '';
    }
  }

  Color _getCategoryColor() {
    switch (_currentQuestion.techniqueCategory) {
      case 'active_recall':
        return const Color(0xFF8B5CF6);
      case 'pomodoro':
        return const Color(0xFFEF4444);
      case 'feynman':
        return const Color(0xFF10B981);
      case 'retrieval_practice':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.bgPrimary;
    }
  }
}
