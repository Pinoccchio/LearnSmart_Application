import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/retrieval_practice_models.dart';
import '../../services/retrieval_practice_service.dart';

class RetrievalSettingsWidget extends StatefulWidget {
  final String userId;
  final RetrievalPracticeSettings initialSettings;
  final Function(RetrievalPracticeSettings)? onSettingsChanged;

  const RetrievalSettingsWidget({
    super.key,
    required this.userId,
    required this.initialSettings,
    this.onSettingsChanged,
  });

  @override
  State<RetrievalSettingsWidget> createState() => _RetrievalSettingsWidgetState();
}

class _RetrievalSettingsWidgetState extends State<RetrievalSettingsWidget> {
  late RetrievalPracticeSettings _currentSettings;
  late final RetrievalPracticeService _retrievalService;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.initialSettings;
    _retrievalService = RetrievalPracticeService();
    _loadSavedSettings();
  }

  /// Load user's saved settings from database or use initial settings
  Future<void> _loadSavedSettings() async {
    try {
      print('📖 [RETRIEVAL SETTINGS] Loading user settings for: ${widget.userId}');
      
      // Try to load saved settings from database
      final savedSettings = await _retrievalService.getUserRetrievalPracticeSettings(widget.userId);
      
      if (mounted) {
        setState(() {
          _currentSettings = savedSettings;
          _isLoading = false;
        });
        
        // Notify parent of loaded settings
        widget.onSettingsChanged?.call(savedSettings);
        print('✅ [RETRIEVAL SETTINGS] Loaded saved settings: $savedSettings');
      }
    } catch (e) {
      print('⚠️ [RETRIEVAL SETTINGS] Failed to load saved settings, using initial: $e');
      
      // Fall back to initial settings if loading fails
      if (mounted) {
        setState(() {
          _currentSettings = widget.initialSettings;
          _isLoading = false;
        });
      }
    }
  }

  /// Save settings to database
  Future<void> _saveSettings() async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isSaving = true;
      });

      print('💾 [RETRIEVAL SETTINGS] Saving user settings: $_currentSettings');
      
      // Save settings to database
      await _retrievalService.saveUserRetrievalPracticeSettings(widget.userId, _currentSettings);
      
      print('✅ [RETRIEVAL SETTINGS] Settings saved successfully');
      
    } catch (e) {
      print('❌ [RETRIEVAL SETTINGS] Failed to save settings: $e');
      
      if (mounted) {
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _updateSettings(RetrievalPracticeSettings newSettings) {
    setState(() {
      _currentSettings = newSettings;
    });
    widget.onSettingsChanged?.call(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = screenHeight - topPadding - bottomPadding - keyboardHeight - 100;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          minHeight: 500,
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
              _buildHeader(),
              
              // Content
              Flexible(
                child: _isLoading ? _buildLoadingState() : _buildScrollableContent(),
              ),
              
              // Action Buttons
              if (!_isLoading) _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 400,
      child: Column(
        children: [
          const Spacer(),
          
          // Loading spinner
          Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.bgPrimary),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                const Text(
                  'Loading your settings...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                const Text(
                  'Retrieving your saved Retrieval Practice preferences',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Bottom padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildScrollableContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionsPerSessionSection(),
          const SizedBox(height: 24),
          _buildQuestionTypesSection(),
          const SizedBox(height: 24),
          _buildFeaturesSection(),
          const SizedBox(height: 24),
          _buildPreviewSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.settings,
                  color: AppColors.bgPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Retrieval Practice Settings',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Customize your study session preferences',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsPerSessionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Questions per Session',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose how many questions you want to practice',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '5',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${_currentSettings.questionsPerSession} Questions',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.bgPrimary,
                    ),
                  ),
                  const Text(
                    '20',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Slider(
                value: _currentSettings.questionsPerSession.toDouble(),
                min: 5,
                max: 20,
                divisions: 15,
                activeColor: AppColors.bgPrimary,
                inactiveColor: AppColors.grey300,
                onChanged: (value) {
                  _updateSettings(_currentSettings.copyWith(
                    questionsPerSession: value.round(),
                  ));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionTypesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Question Types',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select which types of questions to include',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        ...RetrievalQuestionType.values.map((type) => _buildQuestionTypeToggle(type)),
      ],
    );
  }

  Widget _buildQuestionTypeToggle(RetrievalQuestionType type) {
    final isEnabled = _currentSettings.preferredQuestionTypes.contains(type);
    final iconData = _getQuestionTypeIcon(type);
    final title = _getQuestionTypeTitle(type);
    final description = _getQuestionTypeDescription(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          final updatedTypes = List<RetrievalQuestionType>.from(_currentSettings.preferredQuestionTypes);
          if (isEnabled && updatedTypes.length > 1) {
            updatedTypes.remove(type);
          } else if (!isEnabled) {
            updatedTypes.add(type);
          }
          _updateSettings(_currentSettings.copyWith(
            preferredQuestionTypes: updatedTypes,
          ));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isEnabled 
                ? AppColors.bgPrimary.withValues(alpha: 0.1)
                : AppColors.grey100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEnabled ? AppColors.bgPrimary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isEnabled ? AppColors.bgPrimary : AppColors.grey300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  iconData,
                  color: Colors.white,
                  size: 20,
                ),
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
                        fontWeight: FontWeight.w600,
                        color: isEnabled ? AppColors.bgPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isEnabled ? AppColors.bgPrimary : Colors.transparent,
                  border: Border.all(
                    color: isEnabled ? AppColors.bgPrimary : AppColors.grey300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isEnabled
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Features',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enable additional study features',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        _buildFeatureToggle(
          title: 'Allow Hints',
          description: 'Show contextual hints for difficult questions',
          icon: LucideIcons.lightbulb,
          value: _currentSettings.allowHints,
          onChanged: (value) => _updateSettings(_currentSettings.copyWith(allowHints: value)),
        ),
        _buildFeatureToggle(
          title: 'Confidence Rating',
          description: 'Rate your confidence level after each answer',
          icon: LucideIcons.target,
          value: _currentSettings.requireConfidenceRating,
          onChanged: (value) => _updateSettings(_currentSettings.copyWith(requireConfidenceRating: value)),
        ),
        _buildFeatureToggle(
          title: 'Immediate Feedback',
          description: 'Show correct answers after each question',
          icon: LucideIcons.messageCircle,
          value: _currentSettings.showFeedbackAfterEach,
          onChanged: (value) => _updateSettings(_currentSettings.copyWith(showFeedbackAfterEach: value)),
        ),
        _buildFeatureToggle(
          title: 'Adaptive Difficulty',
          description: 'Adjust question difficulty based on performance',
          icon: LucideIcons.trendingUp,
          value: _currentSettings.adaptiveDifficulty,
          onChanged: (value) => _updateSettings(_currentSettings.copyWith(adaptiveDifficulty: value)),
        ),
      ],
    );
  }

  Widget _buildFeatureToggle({
    required String title,
    required String description,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value ? AppColors.bgPrimary.withValues(alpha: 0.1) : AppColors.grey100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: value ? AppColors.bgPrimary : AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.bgPrimary,
            inactiveThumbColor: AppColors.grey300,
            inactiveTrackColor: AppColors.grey200,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.eye,
                color: AppColors.bgPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Session Preview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_currentSettings.questionsPerSession} questions • ${_currentSettings.preferredQuestionTypes.length} question types',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (_currentSettings.allowHints) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(LucideIcons.lightbulb, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Text('Hints enabled', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
          if (_currentSettings.requireConfidenceRating) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(LucideIcons.target, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Text('Confidence rating required', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
          if (_currentSettings.showFeedbackAfterEach) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(LucideIcons.messageCircle, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Text('Immediate feedback', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.grey300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(0, 48),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: !_isSaving ? () async {
                await _saveSettings();
                if (mounted) {
                  Navigator.of(context).pop(_currentSettings);
                }
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.grey300,
                disabledForegroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(0, 48),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Apply Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getQuestionTypeIcon(RetrievalQuestionType type) {
    switch (type) {
      case RetrievalQuestionType.multipleChoice:
        return LucideIcons.list;
      case RetrievalQuestionType.trueFalse:
        return LucideIcons.checkCircle;
      case RetrievalQuestionType.shortAnswer:
        return LucideIcons.edit;
      case RetrievalQuestionType.fillInBlank:
        return LucideIcons.underline;
    }
  }

  String _getQuestionTypeTitle(RetrievalQuestionType type) {
    switch (type) {
      case RetrievalQuestionType.multipleChoice:
        return 'Multiple Choice';
      case RetrievalQuestionType.trueFalse:
        return 'True/False';
      case RetrievalQuestionType.shortAnswer:
        return 'Short Answer';
      case RetrievalQuestionType.fillInBlank:
        return 'Fill in Blank';
    }
  }

  String _getQuestionTypeDescription(RetrievalQuestionType type) {
    switch (type) {
      case RetrievalQuestionType.multipleChoice:
        return 'Choose from multiple options';
      case RetrievalQuestionType.trueFalse:
        return 'Select true or false statements';
      case RetrievalQuestionType.shortAnswer:
        return 'Write brief text responses';
      case RetrievalQuestionType.fillInBlank:
        return 'Complete missing parts';
    }
  }
}