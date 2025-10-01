import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/pre_assessment_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/pre_assessment_service.dart';
import 'pre_assessment_results_screen.dart';

class PreAssessmentQuizScreen extends StatefulWidget {
  final Course course;
  final String attemptId;
  final List<PreAssessmentQuestion> questions;

  const PreAssessmentQuizScreen({
    super.key,
    required this.course,
    required this.attemptId,
    required this.questions,
  });

  @override
  State<PreAssessmentQuizScreen> createState() => _PreAssessmentQuizScreenState();
}

class _PreAssessmentQuizScreenState extends State<PreAssessmentQuizScreen> {
  final PreAssessmentService _service = PreAssessmentService();

  int _currentQuestionIndex = 0;
  Map<int, String> _answers = {}; // questionNumber → selected option (A/B/C/D)
  Map<int, DateTime> _questionStartTimes = {};
  bool _isSubmitting = false;
  PreAssessmentAttempt? _currentAttempt;

  @override
  void initState() {
    super.initState();
    _loadAttempt();
    _startQuestionTimer();
  }

  Future<void> _loadAttempt() async {
    try {
      final attempt = await _service.getAttempt(widget.attemptId);
      if (attempt != null) {
        setState(() {
          _currentAttempt = attempt;
          // Load existing answers
          for (var answer in attempt.answers) {
            _answers[answer.questionNumber] = answer.userAnswer;
          }
        });
      }
    } catch (e) {
      print('Error loading attempt: $e');
    }
  }

  void _startQuestionTimer() {
    _questionStartTimes[_currentQuestion.questionNumber] = DateTime.now();
  }

  PreAssessmentQuestion get _currentQuestion => widget.questions[_currentQuestionIndex];

  bool get _hasSelectedAnswer => _answers.containsKey(_currentQuestion.questionNumber);

  String? get _selectedAnswer => _answers[_currentQuestion.questionNumber];

  double get _progress => ((_currentQuestionIndex + 1) / widget.questions.length);

  Future<void> _submitAnswer() async {
    if (!_hasSelectedAnswer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an answer'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final questionStartTime = _questionStartTimes[_currentQuestion.questionNumber];
      final timeTaken = questionStartTime != null
          ? DateTime.now().difference(questionStartTime).inSeconds
          : 0;

      final answer = PreAssessmentAnswer(
        questionNumber: _currentQuestion.questionNumber,
        moduleName: _currentQuestion.moduleName,
        userAnswer: _selectedAnswer!,
        correctAnswer: _currentQuestion.correctAnswer,
        isCorrect: _selectedAnswer! == _currentQuestion.correctAnswer,
        timeTakenSeconds: timeTaken,
      );

      if (_currentAttempt != null) {
        _currentAttempt = await _service.saveAnswer(
          attemptId: widget.attemptId,
          answer: answer,
          currentAttempt: _currentAttempt!,
        );
      }

      if (_currentQuestionIndex < widget.questions.length - 1) {
        // Move to next question
        setState(() {
          _currentQuestionIndex++;
          _isSubmitting = false;
        });
        _startQuestionTimer();
      } else {
        // Complete the assessment
        await _completeAssessment();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting answer: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _completeAssessment() async {
    if (_currentAttempt == null) return;

    try {
      final result = await _service.completeAttempt(
        attemptId: widget.attemptId,
        attempt: _currentAttempt!,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PreAssessmentResultsScreen(
            course: widget.course,
            result: result,
            attempt: _currentAttempt!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing assessment: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
      _startQuestionTimer();
    }
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Assessment?'),
        content: const Text(
          'Are you sure you want to exit? Your progress has been saved and you can resume later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Exit'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgSecondary,
        appBar: AppBar(
          backgroundColor: AppColors.bgPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.white),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            widget.course.title,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.white),
            ),
          ),
        ),
        body: Column(
          children: [
            // Progress header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: AppColors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_currentQuestionIndex + 1} of ${widget.questions.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.bgPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.bgPrimary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _currentQuestion.moduleName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.bgPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_answers.length} answered',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Question content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question text
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _currentQuestion.questionText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Options
                    _buildOption('A', _currentQuestion.optionA),
                    const SizedBox(height: 12),
                    _buildOption('B', _currentQuestion.optionB),
                    const SizedBox(height: 12),
                    _buildOption('C', _currentQuestion.optionC),
                    const SizedBox(height: 12),
                    _buildOption('D', _currentQuestion.optionD),
                  ],
                ),
              ),
            ),

            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentQuestionIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousQuestion,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.bgPrimary,
                          side: const BorderSide(color: AppColors.bgPrimary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Previous',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (_currentQuestionIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bgPrimary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                              ),
                            )
                          : Text(
                              _currentQuestionIndex < widget.questions.length - 1
                                  ? 'Next'
                                  : 'Complete',
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

  Widget _buildOption(String letter, String text) {
    final isSelected = _selectedAnswer == letter;

    return InkWell(
      onTap: _isSubmitting ? null : () {
        setState(() {
          _answers[_currentQuestion.questionNumber] = letter;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.bgPrimary.withValues(alpha: 0.1)
              : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.bgPrimary
                : AppColors.grey300,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.bgPrimary.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.bgPrimary
                    : AppColors.grey200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppColors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
