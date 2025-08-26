import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/pomodoro_models.dart';
import '../../services/pomodoro_service.dart';
import '../dialogs/modern_error_dialog.dart';

class PomodoroSettingsWidget extends StatefulWidget {
  final PomodoroSettings initialSettings;
  final Function(PomodoroSettings) onSettingsChanged;
  final VoidCallback? onStartSession;
  final String userId;

  const PomodoroSettingsWidget({
    super.key,
    required this.initialSettings,
    required this.onSettingsChanged,
    required this.userId,
    this.onStartSession,
  });

  @override
  State<PomodoroSettingsWidget> createState() => _PomodoroSettingsWidgetState();
}

class _PomodoroSettingsWidgetState extends State<PomodoroSettingsWidget> {
  late PomodoroSettings _settings;
  late final PomodoroService _pomodoroService;
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _pomodoroService = PomodoroService();
    _loadUserSettings();
  }

  /// Load user's saved settings from database or use initial settings
  Future<void> _loadUserSettings() async {
    try {
      print('📖 [POMODORO SETTINGS] Loading user settings for: ${widget.userId}');
      
      // Try to load saved settings from database
      final savedSettings = await _pomodoroService.getUserPomodoroSettings(widget.userId);
      
      if (mounted) {
        setState(() {
          _settings = savedSettings;
          _isLoading = false;
        });
        
        print('✅ [POMODORO SETTINGS] Loaded saved settings: $savedSettings');
      }
    } catch (e) {
      print('⚠️ [POMODORO SETTINGS] Failed to load saved settings, using initial: $e');
      
      // Fall back to initial settings if loading fails
      if (mounted) {
        setState(() {
          _settings = widget.initialSettings;
          _isLoading = false;
        });
      }
    }
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
              // Header with drag handle
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
          // Header with loading indicator
          _buildHeader(),
          
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
                  'Retrieving your saved Pomodoro preferences',
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
          // Quick Presets
          _buildQuickPresets(),
          
          const SizedBox(height: 32),
          
          // Custom Settings
          _buildCustomSettings(),
          
          const SizedBox(height: 24),
          
          // Session Preview
          _buildSessionPreview(),
          
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
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.settings,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pomodoro Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Customize your focus sessions',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
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

  Widget _buildQuickPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Presets',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: PomodoroSettings.availablePresets.map((preset) {
            final presetSettings = PomodoroSettings.getPreset(preset);
            final isSelected = _settings.presetName == preset;
            
            return _buildPresetChip(
              preset,
              presetSettings,
              isSelected,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String preset, PomodoroSettings presetSettings, bool isSelected) {
    return InkWell(
      onTap: () => _updateSettings(presetSettings),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.withValues(alpha: 0.1) : AppColors.grey100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.red : AppColors.grey300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              PomodoroSettings.getPresetDisplayName(preset),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.red : AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              '${PomodoroSettings.formatDuration(presetSettings.workDuration)} work • '
              '${PomodoroSettings.formatDuration(presetSettings.shortBreakDuration)} break • '
              '${presetSettings.totalCycles} cycles',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.red.withValues(alpha: 0.7) : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Custom Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Work Duration
        _buildDurationSetting(
          'Work Duration',
          LucideIcons.clock,
          _settings.workDuration,
          Colors.red,
          (duration) => _updateSettings(_settings.copyWith(
            workDuration: duration,
            presetName: 'custom',
          )),
          minSeconds: 5,
          maxSeconds: 5400, // 90 minutes
        ),
        
        const SizedBox(height: 20),
        
        // Short Break Duration
        _buildDurationSetting(
          'Short Break',
          LucideIcons.coffee,
          _settings.shortBreakDuration,
          Colors.green,
          (duration) => _updateSettings(_settings.copyWith(
            shortBreakDuration: duration,
            presetName: 'custom',
          )),
          minSeconds: 5,
          maxSeconds: 1800, // 30 minutes
        ),
        
        const SizedBox(height: 20),
        
        // Long Break Duration
        _buildDurationSetting(
          'Long Break',
          LucideIcons.armchair,
          _settings.longBreakDuration,
          Colors.blue,
          (duration) => _updateSettings(_settings.copyWith(
            longBreakDuration: duration,
            presetName: 'custom',
          )),
          minSeconds: 5,
          maxSeconds: 3600, // 60 minutes
        ),
        
        const SizedBox(height: 20),
        
        // Total Cycles
        _buildCyclesSetting(),
      ],
    );
  }

  Widget _buildDurationSetting(
    String title,
    IconData icon,
    Duration currentDuration,
    Color color,
    Function(Duration) onChanged,
    {required int minSeconds, required int maxSeconds}
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  PomodoroSettings.formatDuration(currentDuration),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Duration Controls
          Row(
            children: [
              // Quick decrease
              _buildDurationButton(
                LucideIcons.minus,
                () {
                  final newDuration = Duration(
                    seconds: (currentDuration.inSeconds - _getDurationStep(currentDuration))
                        .clamp(minSeconds, maxSeconds),
                  );
                  onChanged(newDuration);
                },
                color,
              ),
              
              const SizedBox(width: 16),
              
              // Duration slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: color,
                    inactiveTrackColor: color.withValues(alpha: 0.2),
                    thumbColor: color,
                    overlayColor: color.withValues(alpha: 0.1),
                  ),
                  child: Slider(
                    value: currentDuration.inSeconds.toDouble().clamp(minSeconds.toDouble(), maxSeconds.toDouble()),
                    min: minSeconds.toDouble(),
                    max: maxSeconds.toDouble(),
                    divisions: _getDivisions(minSeconds, maxSeconds),
                    onChanged: (value) {
                      onChanged(Duration(seconds: value.round()));
                    },
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Quick increase
              _buildDurationButton(
                LucideIcons.plus,
                () {
                  final newDuration = Duration(
                    seconds: (currentDuration.inSeconds + _getDurationStep(currentDuration))
                        .clamp(minSeconds, maxSeconds),
                  );
                  onChanged(newDuration);
                },
                color,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationButton(IconData icon, VoidCallback onPressed, Color color) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildCyclesSetting() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(LucideIcons.repeat, color: Colors.purple, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Total Cycles',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_settings.totalCycles} cycles',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Cycle count selector
          Wrap(
            spacing: 8,
            children: List.generate(10, (index) {
              final cycleCount = index + 1;
              final isSelected = _settings.totalCycles == cycleCount;
              
              return InkWell(
                onTap: () => _updateSettings(_settings.copyWith(
                  totalCycles: cycleCount,
                  presetName: 'custom',
                )),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.purple : Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.purple.withValues(alpha: isSelected ? 1.0 : 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      cycleCount.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.purple,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPreview() {
    final estimatedTime = _settings.estimatedSessionTime;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.bgPrimary.withValues(alpha: 0.1),
            Colors.blue.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.bgPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.clock,
                  color: AppColors.bgPrimary,
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 16),
              
              const Expanded(
                child: Text(
                  'Session Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildPreviewItem(
                  'Total Time',
                  _formatLongDuration(estimatedTime),
                  LucideIcons.timer,
                  AppColors.bgPrimary,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildPreviewItem(
                  'Work Time',
                  _formatLongDuration(_settings.workDuration * _settings.totalCycles),
                  LucideIcons.zap,
                  Colors.red,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildPreviewItem(
                  'Break Time',
                  _formatLongDuration(estimatedTime - (_settings.workDuration * _settings.totalCycles)),
                  LucideIcons.coffee,
                  Colors.green,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildPreviewItem(
                  'Cycles',
                  '${_settings.totalCycles}',
                  LucideIcons.repeat,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isValid = _settings.isValid;
    
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        children: [
          if (!isValid) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.alertTriangle, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Settings are outside valid ranges. Please adjust.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          Row(
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
                  onPressed: isValid && !_isSaving ? () async {
                    await _saveSettingsAndStartSession();
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
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
        ],
      ),
    );
  }

  void _updateSettings(PomodoroSettings newSettings) {
    if (!mounted) return;
    setState(() {
      _settings = newSettings;
    });
  }

  int _getDurationStep(Duration duration) {
    if (duration.inSeconds < 60) {
      return 5; // 5-second steps for sub-minute durations
    } else if (duration.inMinutes < 10) {
      return 30; // 30-second steps for short durations
    } else {
      return 60; // 1-minute steps for longer durations
    }
  }

  int _getDivisions(int minSeconds, int maxSeconds) {
    final range = maxSeconds - minSeconds;
    if (range <= 120) return range ~/ 5; // 5-second steps
    if (range <= 600) return range ~/ 30; // 30-second steps
    return range ~/ 60; // 1-minute steps
  }

  String _formatLongDuration(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (minutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${minutes}m';
      }
    } else if (duration.inMinutes > 0) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      if (seconds == 0) {
        return '${minutes}m';
      } else {
        return '${minutes}m ${seconds}s';
      }
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Save settings to database and start session
  Future<void> _saveSettingsAndStartSession() async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isSaving = true;
      });

      print('💾 [POMODORO SETTINGS] Saving user settings: $_settings');
      
      // Save settings to database
      await _pomodoroService.saveUserPomodoroSettings(widget.userId, _settings);
      
      print('✅ [POMODORO SETTINGS] Settings saved successfully');
      
      // Notify parent of settings change
      widget.onSettingsChanged(_settings);
      
      // Close modal and return settings
      if (mounted) {
        Navigator.of(context).pop(_settings);
        
        // Start session if callback provided
        widget.onStartSession?.call();
      }
      
    } catch (e) {
      print('❌ [POMODORO SETTINGS] Failed to save settings: $e');
      
      if (mounted) {
        // Show modern error dialog with appropriate type and retry option
        _showModernErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Show modern error dialog with appropriate styling and retry option
  void _showModernErrorDialog(String errorMessage) {
    // Determine error type based on error message
    ErrorType errorType = ErrorType.general;
    String title = 'Settings Error';
    String message = errorMessage;

    if (errorMessage.contains('Invalid settings')) {
      errorType = ErrorType.validation;
      title = 'Invalid Settings';
      // Extract the specific validation message
      final parts = errorMessage.split(': ');
      if (parts.length > 1) {
        message = parts.skip(1).join(': ');
      }
    } else if (errorMessage.contains('connection') || errorMessage.contains('network')) {
      errorType = ErrorType.network;
      title = 'Connection Error';
      message = 'Unable to save settings. Please check your connection and try again.';
    } else if (errorMessage.contains('User not found') || errorMessage.contains('permission')) {
      errorType = ErrorType.permission;
      title = 'Permission Error';
      message = 'You don\'t have permission to save settings. Please log in again.';
    } else {
      // Clean up generic error messages
      if (errorMessage.contains('Exception:') || errorMessage.contains('Failed to save settings:')) {
        message = 'Unable to save your Pomodoro settings. Please try again.';
      }
    }

    showModernErrorDialog(
      context: context,
      title: title,
      message: message,
      type: errorType,
      onRetry: errorType != ErrorType.validation ? () {
        // Only show retry for non-validation errors
        _saveSettingsAndStartSession();
      } : null,
      retryButtonText: 'Save Again',
      dismissButtonText: errorType == ErrorType.validation ? 'Adjust Settings' : 'Cancel',
    );
  }
}