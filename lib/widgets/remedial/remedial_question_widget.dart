import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/remedial_models.dart';

class RemedialQuestionWidget extends StatefulWidget {
  final RemedialFlashcard flashcard;
  final TextEditingController answerController;
  final Function(String) onAnswerChanged;
  final VoidCallback onSubmitAnswer;
  final bool showingFeedback;
  final bool lastAnswerCorrect;
  final bool isProcessing;

  const RemedialQuestionWidget({
    super.key,
    required this.flashcard,
    required this.answerController,
    required this.onAnswerChanged,
    required this.onSubmitAnswer,
    required this.showingFeedback,
    required this.lastAnswerCorrect,
    required this.isProcessing,
  });

  @override
  State<RemedialQuestionWidget> createState() => _RemedialQuestionWidgetState();
}

class _RemedialQuestionWidgetState extends State<RemedialQuestionWidget> 
    with SingleTickerProviderStateMixin {
  late AnimationController _feedbackAnimationController;
  late Animation<double> _feedbackAnimation;
  String? _selectedOption;

  @override
  void initState() {
    super.initState();
    _feedbackAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _feedbackAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _feedbackAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _feedbackAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RemedialQuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reset selected option when flashcard changes
    if (oldWidget.flashcard.id != widget.flashcard.id) {
      _selectedOption = null;
    }
    
    // Trigger feedback animation
    if (!oldWidget.showingFeedback && widget.showingFeedback) {
      _feedbackAnimationController.forward();
    } else if (oldWidget.showingFeedback && !widget.showingFeedback) {
      _feedbackAnimationController.reset();
    }
  }

  void _handleTextInputSubmit() {
    if (widget.answerController.text.trim().isNotEmpty) {
      widget.onSubmitAnswer();
    }
  }

  void _handleOptionSelected(String option) {
    setState(() {
      _selectedOption = option;
    });
    widget.answerController.text = option;
    widget.onAnswerChanged(option);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Type Badge
          _buildQuestionTypeBadge(),
          
          const SizedBox(height: 16),
          
          // Concept Focus
          _buildConceptFocus(),
          
          const SizedBox(height: 20),
          
          // Question Text
          _buildQuestionText(),
          
          const SizedBox(height: 24),
          
          // Answer Input Area
          _buildAnswerInput(),
          
          const SizedBox(height: 20),
          
          // Feedback Section
          if (widget.showingFeedback) _buildFeedbackSection(),
        ],
      ),
    );
  }

  Widget _buildQuestionTypeBadge() {
    final type = widget.flashcard.type;
    Color badgeColor;
    IconData badgeIcon;
    
    switch (type) {
      case RemedialQuestionType.identification:
        badgeColor = Colors.blue;
        badgeIcon = LucideIcons.search;
        break;
      case RemedialQuestionType.shortAnswer:
        badgeColor = Colors.green;
        badgeIcon = LucideIcons.edit;
        break;
      case RemedialQuestionType.fillInBlank:
        badgeColor = Colors.orange;
        badgeIcon = LucideIcons.type;
        break;
      case RemedialQuestionType.trueFalse:
        badgeColor = Colors.purple;
        badgeIcon = LucideIcons.checkSquare;
        break;
      case RemedialQuestionType.matching:
        badgeColor = Colors.indigo;
        badgeIcon = LucideIcons.link;
        break;
      case RemedialQuestionType.essay:
        badgeColor = Colors.red;
        badgeIcon = LucideIcons.fileText;
        break;
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: badgeColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, size: 16, color: badgeColor),
              const SizedBox(width: 6),
              Text(
                type.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.flashcard.difficulty.value.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConceptFocus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.target,
            size: 16,
            color: Colors.amber.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Focus Concept',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.flashcard.concept,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionText() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        widget.flashcard.question,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildAnswerInput() {
    switch (widget.flashcard.type) {
      case RemedialQuestionType.trueFalse:
        return _buildTrueFalseInput();
      case RemedialQuestionType.matching:
        return _buildMatchingInput();
      default:
        return _buildTextInput();
    }
  }

  Widget _buildTextInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: TextField(
        controller: widget.answerController,
        onChanged: widget.onAnswerChanged,
        onSubmitted: (_) => _handleTextInputSubmit(),
        maxLines: widget.flashcard.type == RemedialQuestionType.essay ? 4 : 1,
        textInputAction: TextInputAction.done,
        enabled: !widget.showingFeedback && !widget.isProcessing,
        decoration: InputDecoration(
          hintText: _getInputHintText(),
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTrueFalseInput() {
    return Column(
      children: [
        _buildOptionButton('True', LucideIcons.check),
        const SizedBox(height: 12),
        _buildOptionButton('False', LucideIcons.x),
      ],
    );
  }

  Widget _buildMatchingInput() {
    if (widget.flashcard.options.isEmpty) {
      return _buildTextInput(); // Fallback to text input if no options
    }
    
    return Column(
      children: widget.flashcard.options.map((option) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildOptionButton(option, LucideIcons.circle),
        );
      }).toList(),
    );
  }

  Widget _buildOptionButton(String option, IconData icon) {
    final isSelected = _selectedOption == option;
    
    return InkWell(
      onTap: widget.showingFeedback || widget.isProcessing 
          ? null 
          : () => _handleOptionSelected(option),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgPrimary.withOpacity(0.1) : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.bgPrimary : AppColors.grey200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? LucideIcons.checkCircle : icon,
              size: 20,
              color: isSelected ? AppColors.bgPrimary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.bgPrimary : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return AnimatedBuilder(
      animation: _feedbackAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _feedbackAnimation.value,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.lastAnswerCorrect 
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.lastAnswerCorrect 
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.lastAnswerCorrect 
                          ? LucideIcons.checkCircle
                          : LucideIcons.xCircle,
                      color: widget.lastAnswerCorrect ? Colors.green : Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.lastAnswerCorrect ? 'Correct!' : 'Not Quite Right',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.lastAnswerCorrect ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Correct answer
                if (!widget.lastAnswerCorrect) ...[
                  Text(
                    'Correct Answer:',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.flashcard.correctAnswer,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Explanation
                if (widget.flashcard.explanation.isNotEmpty) ...[
                  Text(
                    'Explanation:',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.flashcard.explanation,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _getInputHintText() {
    switch (widget.flashcard.type) {
      case RemedialQuestionType.identification:
        return 'Type your identification here...';
      case RemedialQuestionType.shortAnswer:
        return 'Write your short answer here...';
      case RemedialQuestionType.fillInBlank:
        return 'Fill in the blank...';
      case RemedialQuestionType.essay:
        return 'Write your essay response here...';
      default:
        return 'Type your answer here...';
    }
  }
}