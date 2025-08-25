import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/active_recall_models.dart';

class FlashcardWidget extends StatefulWidget {
  final ActiveRecallFlashcard flashcard;
  final Function(String answer, int responseTimeMs) onAnswerSubmitted;
  final bool isPreStudy;
  final VoidCallback? onShowHint;
  final VoidCallback? onSkip;

  const FlashcardWidget({
    super.key,
    required this.flashcard,
    required this.onAnswerSubmitted,
    this.isPreStudy = false,
    this.onShowHint,
    this.onSkip,
  });

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _shakeController;
  late Animation<double> _flipAnimation;
  late Animation<double> _shakeAnimation;
  
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _answerFocus = FocusNode();
  
  bool _hintsShown = false;
  DateTime? _startTime;
  
  @override
  void initState() {
    super.initState();
    
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _flipController, curve: Curves.easeInOut));
    
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));
    
    _startTime = DateTime.now();
    
    // Auto-focus answer field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _answerFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _shakeController.dispose();
    _answerController.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  void _submitAnswer() {
    if (_answerController.text.trim().isEmpty) {
      _shake();
      return;
    }
    
    final responseTime = _startTime != null 
        ? DateTime.now().difference(_startTime!).inMilliseconds
        : 0;
    
    widget.onAnswerSubmitted(_answerController.text.trim(), responseTime);
  }


  void _shake() {
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
  }

  void _showHints() {
    setState(() {
      _hintsShown = true;
    });
    widget.onShowHint?.call();
  }

  Color _getDifficultyColor() {
    switch (widget.flashcard.difficulty) {
      case FlashcardDifficulty.easy:
        return Colors.green;
      case FlashcardDifficulty.medium:
        return Colors.orange;
      case FlashcardDifficulty.hard:
        return Colors.red;
    }
  }

  IconData _getTypeIcon() {
    switch (widget.flashcard.type) {
      case FlashcardType.fillInBlank:
        return LucideIcons.edit3;
      case FlashcardType.definitionRecall:
        return LucideIcons.book;
      case FlashcardType.conceptApplication:
        return LucideIcons.lightbulb;
    }
  }

  String _getTypeDisplayName() {
    switch (widget.flashcard.type) {
      case FlashcardType.fillInBlank:
        return 'Fill in the Blank';
      case FlashcardType.definitionRecall:
        return 'Definition Recall';
      case FlashcardType.conceptApplication:
        return 'Concept Application';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Container(
            margin: const EdgeInsets.all(16),
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, child) {
                final isShowingFront = _flipAnimation.value < 0.5;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_flipAnimation.value * 3.14159),
                  child: isShowingFront
                      ? _buildFrontCard()
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(3.14159),
                          child: _buildBackCard(),
                        ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrontCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getDifficultyColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTypeIcon(),
                    color: _getDifficultyColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTypeDisplayName(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.flashcard.difficulty.value.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getDifficultyColor(),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isPreStudy)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Pre-Study',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Question
            Text(
              'Question',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.flashcard.question,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Answer input
            Text(
              'Your Answer',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _answerController,
              focusNode: _answerFocus,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Type your answer here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.bgPrimary, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              onSubmitted: (_) => _submitAnswer(),
            ),
            
            const SizedBox(height: 24),
            
            // Hints section
            if (widget.flashcard.hints.isNotEmpty) ...[
              if (!_hintsShown) ...[
                Center(
                  child: TextButton.icon(
                    onPressed: _showHints,
                    icon: const Icon(LucideIcons.helpCircle, size: 18),
                    label: const Text('Show Hints'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.helpCircle, 
                              size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Hints',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...widget.flashcard.hints.map((hint) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $hint',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
            
            // Action buttons
            Row(
              children: [
                if (widget.onSkip != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onSkip,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _submitAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bgPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Submit Answer',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Correct Answer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Answer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Text(
                widget.flashcard.answer,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
            
            if (widget.flashcard.explanation.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Explanation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.flashcard.explanation,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // This will be handled by the parent screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}