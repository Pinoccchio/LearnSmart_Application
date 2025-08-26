import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/retrieval_practice_models.dart';

class RetrievalQuestionWidget extends StatefulWidget {
  final RetrievalPracticeQuestion question;
  final Function({
    required String userAnswer,
    int? confidenceLevel,
    bool hintUsed,
  }) onAnswerSubmitted;
  final bool allowHints;
  final bool requireConfidence;
  final bool isProcessing;

  const RetrievalQuestionWidget({
    super.key,
    required this.question,
    required this.onAnswerSubmitted,
    this.allowHints = false,
    this.requireConfidence = false,
    this.isProcessing = false,
  });

  @override
  State<RetrievalQuestionWidget> createState() => _RetrievalQuestionWidgetState();
}

class _RetrievalQuestionWidgetState extends State<RetrievalQuestionWidget> {
  final TextEditingController _answerController = TextEditingController();
  String? _selectedAnswer;
  int? _confidenceLevel;
  bool _hintUsed = false;
  bool _showHint = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RetrievalQuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reset state when question changes
    if (oldWidget.question.id != widget.question.id) {
      _resetState();
    }
  }

  void _resetState() {
    _answerController.clear();
    _selectedAnswer = null;
    _confidenceLevel = null;
    _hintUsed = false;
    _showHint = false;
  }

  void _submitAnswer() {
    String userAnswer;
    
    switch (widget.question.questionType) {
      case RetrievalQuestionType.multipleChoice:
      case RetrievalQuestionType.trueFalse:
        userAnswer = _selectedAnswer ?? '';
        break;
      case RetrievalQuestionType.shortAnswer:
      case RetrievalQuestionType.fillInBlank:
        userAnswer = _answerController.text.trim();
        break;
    }

    if (userAnswer.isEmpty) {
      _showSnackBar('Please provide an answer before submitting.', Colors.orange);
      return;
    }

    if (widget.requireConfidence && _confidenceLevel == null) {
      _showSnackBar('Please rate your confidence level.', Colors.orange);
      return;
    }

    widget.onAnswerSubmitted(
      userAnswer: userAnswer,
      confidenceLevel: _confidenceLevel,
      hintUsed: _hintUsed,
    );
  }


  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          _buildQuestionHeader(),
          
          const SizedBox(height: 20),
          
          // Question text
          _buildQuestionText(),
          
          const SizedBox(height: 24),
          
          // Answer input based on question type
          _buildAnswerInput(),
          
          const SizedBox(height: 20),
          
          // Hint section
          if (widget.allowHints) _buildHintSection(),
          
          // Confidence rating
          if (widget.requireConfidence) _buildConfidenceRating(),
          
          const SizedBox(height: 24),
          
          // Submit button
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildQuestionHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.question.difficultyColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.question.difficultyColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            widget.question.difficultyString,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.question.difficultyColor,
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            _getQuestionTypeLabel(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
        ),
        
        const Spacer(),
        
        if (widget.allowHints && !_showHint)
          IconButton(
            onPressed: () => setState(() {
              _showHint = true;
              _hintUsed = true;
            }),
            icon: const Icon(LucideIcons.helpCircle),
            tooltip: 'Show hint',
          ),
      ],
    );
  }

  Widget _buildQuestionText() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        widget.question.questionText,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildAnswerInput() {
    switch (widget.question.questionType) {
      case RetrievalQuestionType.multipleChoice:
        return _buildMultipleChoiceInput();
      case RetrievalQuestionType.trueFalse:
        return _buildTrueFalseInput();
      case RetrievalQuestionType.shortAnswer:
        return _buildShortAnswerInput();
      case RetrievalQuestionType.fillInBlank:
        return _buildFillInBlankInput();
    }
  }

  Widget _buildMultipleChoiceInput() {
    if (widget.question.options == null || widget.question.options!.isEmpty) {
      return const Text('No options available for this question.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select the correct answer:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.question.options!.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final optionLabel = String.fromCharCode(65 + index); // A, B, C, D
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedAnswer = option;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedAnswer == option 
                      ? AppColors.bgPrimary.withValues(alpha: 0.1)
                      : AppColors.grey100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedAnswer == option 
                        ? AppColors.bgPrimary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _selectedAnswer == option 
                            ? AppColors.bgPrimary
                            : AppColors.grey300,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          optionLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _selectedAnswer == option 
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedAnswer == option 
                              ? AppColors.bgPrimary
                              : AppColors.textPrimary,
                          fontWeight: _selectedAnswer == option 
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTrueFalseInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select True or False:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTrueFalseOption('True', Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTrueFalseOption('False', Colors.red),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrueFalseOption(String option, Color color) {
    final isSelected = _selectedAnswer == option;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedAnswer = option;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.grey100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              option == 'True' ? LucideIcons.check : LucideIcons.x,
              color: isSelected ? color : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              option,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortAnswerInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Write your answer:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _answerController,
          decoration: InputDecoration(
            hintText: 'Type your answer here...',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.grey300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.grey300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.bgPrimary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _buildFillInBlankInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fill in the blank:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _answerController,
          decoration: InputDecoration(
            hintText: 'Fill in the missing word or phrase...',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.grey300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.grey300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.bgPrimary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  Widget _buildHintSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showHint) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.lightbulb,
                  color: Colors.amber.shade700,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _generateHint(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildConfidenceRating() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'How confident are you in your answer?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final level = index + 1;
            final isSelected = _confidenceLevel == level;
            
            return InkWell(
              onTap: () {
                setState(() {
                  _confidenceLevel = level;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.bgPrimary
                      : AppColors.grey100,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected 
                        ? AppColors.bgPrimary
                        : AppColors.grey300,
                  ),
                ),
                child: Center(
                  child: Text(
                    level.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected 
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Very Low',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            Text(
              'Very High',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: widget.isProcessing ? null : _submitAnswer,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bgPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: widget.isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.send, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Submit Answer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _getQuestionTypeLabel() {
    switch (widget.question.questionType) {
      case RetrievalQuestionType.multipleChoice:
        return 'Multiple Choice';
      case RetrievalQuestionType.shortAnswer:
        return 'Short Answer';
      case RetrievalQuestionType.fillInBlank:
        return 'Fill in Blank';
      case RetrievalQuestionType.trueFalse:
        return 'True/False';
    }
  }

  String _generateHint() {
    // Generate a simple hint based on question type and concept tags
    final concepts = widget.question.conceptTags;
    
    if (concepts.isNotEmpty) {
      return 'Think about: ${concepts.first.replaceAll('_', ' ')}';
    }
    
    switch (widget.question.questionType) {
      case RetrievalQuestionType.multipleChoice:
        return 'Eliminate obviously wrong answers first.';
      case RetrievalQuestionType.shortAnswer:
        return 'Focus on the key concepts from the material.';
      case RetrievalQuestionType.fillInBlank:
        return 'Consider the context of the surrounding text.';
      case RetrievalQuestionType.trueFalse:
        return 'Look for absolute terms that might indicate false statements.';
    }
  }
}