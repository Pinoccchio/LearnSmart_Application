import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/feynman_models.dart';
import '../../services/feynman_service.dart';

class ExplanationInputWidget extends StatefulWidget {
  final FeynmanService feynmanService;
  final VoidCallback? onExplanationSubmitted;
  final String? initialText;
  final bool enabled;

  const ExplanationInputWidget({
    super.key,
    required this.feynmanService,
    this.onExplanationSubmitted,
    this.initialText,
    this.enabled = true,
  });

  @override
  State<ExplanationInputWidget> createState() => _ExplanationInputWidgetState();
}

class _ExplanationInputWidgetState extends State<ExplanationInputWidget> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  
  bool _isSubmitting = false;
  String? _errorMessage;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    _controller.addListener(_updateWordCount);
    _updateWordCount();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateWordCount() {
    final text = _controller.text.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    setState(() {
      _wordCount = words;
    });
  }

  Future<void> _submitExplanation() async {
    final text = _controller.text.trim();
    
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your explanation';
      });
      return;
    }

    if (text.length < 50) {
      setState(() {
        _errorMessage = 'Your explanation seems too brief. Try adding more detail.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.feynmanService.submitExplanation(
        explanationText: text,
        explanationType: ExplanationType.text,
      );
      
      // Clear the text field after successful submission
      _controller.clear();
      
      // Call the callback
      widget.onExplanationSubmitted?.call();
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit explanation: $e';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _clearText() {
    _controller.clear();
    _focusNode.requestFocus();
    setState(() {
      _errorMessage = null;
    });
  }

  Color get _wordCountColor {
    if (_wordCount < 50) return Colors.red;
    if (_wordCount < 100) return Colors.orange;
    return Colors.green;
  }

  String get _wordCountLabel {
    if (_wordCount < 50) return 'Too brief';
    if (_wordCount < 100) return 'Good start';
    if (_wordCount < 200) return 'Good length';
    return 'Very detailed';
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.edit,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Explain the Topic',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                IconButton(
                  onPressed: widget.enabled ? _clearText : null,
                  icon: const Icon(
                    LucideIcons.x,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Clear text',
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Guidance text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.lightbulb,
                  size: 16,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Explain as if you\'re teaching someone who has never heard of this topic before. Use simple language, examples, and analogies.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Text input
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled && !_isSubmitting,
            maxLines: null,
            minLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Start explaining the topic in your own words...',
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
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
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: widget.enabled ? AppColors.white : AppColors.bgSecondary,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Word count and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Word count
              Row(
                children: [
                  Icon(
                    LucideIcons.fileText,
                    size: 14,
                    color: _wordCountColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_wordCount words • $_wordCountLabel',
                    style: TextStyle(
                      fontSize: 12,
                      color: _wordCountColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              // Submit button
              ElevatedButton(
                onPressed: widget.enabled && 
                           !_isSubmitting && 
                           _controller.text.trim().isNotEmpty &&
                           widget.feynmanService.canSubmitExplanation
                    ? _submitExplanation
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.send, size: 16),
                          const SizedBox(width: 8),
                          const Text('Submit'),
                        ],
                      ),
              ),
            ],
          ),
          
          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.alertTriangle,
                    size: 16,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Tips section
          const SizedBox(height: 16),
          
          ExpansionTile(
            leading: Icon(
              LucideIcons.helpCircle,
              size: 20,
              color: Colors.grey.shade600,
            ),
            title: Text(
              'Explanation Tips',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTip('Use simple, everyday language'),
                    _buildTip('Include concrete examples or analogies'),
                    _buildTip('Explain the "why" behind concepts'),
                    _buildTip('Identify any parts you\'re unsure about'),
                    _buildTip('Structure your explanation logically'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 8),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade500,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}