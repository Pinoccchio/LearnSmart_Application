import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/pomodoro_models.dart';
import '../models/course_models.dart';
import '../models/study_analytics_models.dart';
import '../services/supabase_service.dart';
import '../services/study_analytics_service.dart';

class PomodoroService extends ChangeNotifier {
  static const int _defaultWorkDuration = 25; // minutes
  static const int _defaultShortBreakDuration = 5; // minutes
  static const int _defaultLongBreakDuration = 15; // minutes
  static const int _defaultTotalCycles = 4;

  // Callbacks
  final VoidCallback? onWorkCycleComplete;

  // Timer state
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  Duration _totalTime = Duration.zero;
  bool _isRunning = false;
  bool _awaitingFocusScore = false;
  
  // Session state
  PomodoroSession? _currentSession;
  PomodoroCycle? _currentCycle;
  List<PomodoroNote> _sessionNotes = [];
  StudySessionAnalytics? _sessionAnalytics;

  PomodoroService({
    this.onWorkCycleComplete,
  });
  
  // Getters
  PomodoroSession? get currentSession => _currentSession;
  PomodoroCycle? get currentCycle => _currentCycle;
  List<PomodoroNote> get sessionNotes => List.unmodifiable(_sessionNotes);
  StudySessionAnalytics? get sessionAnalytics => _sessionAnalytics;
  Duration get remainingTime => _remainingTime;
  Duration get totalTime => _totalTime;
  bool get isRunning => _isRunning;
  bool get isPaused => _currentSession != null && !_isRunning && _remainingTime.inSeconds > 0;
  bool get isAwaitingFocusScore => _awaitingFocusScore;
  
  double get progress {
    if (_totalTime.inSeconds == 0) return 0.0;
    final elapsed = _totalTime.inSeconds - _remainingTime.inSeconds;
    return (elapsed / _totalTime.inSeconds).clamp(0.0, 1.0);
  }

  String get currentPhaseTitle {
    final session = _currentSession;
    if (session == null) return 'Pomodoro Session';
    
    switch (session.status) {
      case PomodoroSessionStatus.preparing:
        return 'Preparing Session...';
      case PomodoroSessionStatus.active:
        return 'Work Time - Cycle ${session.currentCycle}/${session.totalCyclesPlanned}';
      case PomodoroSessionStatus.break_:
        final isLongBreak = session.currentCycle % 4 == 0;
        return isLongBreak ? 'Long Break' : 'Short Break';
      case PomodoroSessionStatus.completed:
        return 'Session Complete!';
      case PomodoroSessionStatus.paused:
        return 'Session Paused';
    }
  }

  String get currentPhaseDescription {
    final session = _currentSession;
    if (session == null) return 'Get ready to focus!';
    
    switch (session.status) {
      case PomodoroSessionStatus.preparing:
        return 'Setting up your Pomodoro session...';
      case PomodoroSessionStatus.active:
        return 'Focus on your studies. Take notes and minimize distractions.';
      case PomodoroSessionStatus.break_:
        final isLongBreak = session.currentCycle % 4 == 0;
        return isLongBreak 
            ? 'Take a longer break! Reflect on what you\'ve learned.'
            : 'Take a short break. Stretch, hydrate, or rest your eyes.';
      case PomodoroSessionStatus.completed:
        return 'Great work! Review your session analytics below.';
      case PomodoroSessionStatus.paused:
        return 'Session is paused. Resume when ready.';
    }
  }

  /// Initialize a new Pomodoro session
  Future<PomodoroSession> initializeSession({
    required String userId,
    required Module module,
    PomodoroSettings? customSettings,
    @Deprecated('Use customSettings parameter instead') 
    int? workDurationMinutes,
    @Deprecated('Use customSettings parameter instead')
    int? shortBreakDurationMinutes,
    @Deprecated('Use customSettings parameter instead')
    int? longBreakDurationMinutes,
    @Deprecated('Use customSettings parameter instead')
    int? totalCycles,
  }) async {
    try {
      print('🍅 [POMODORO] Initializing session for module: ${module.title}');
      
      // Resolve settings - use custom settings or load from database or use defaults
      PomodoroSettings settings;
      if (customSettings != null) {
        settings = customSettings;
        print('🍅 [POMODORO] Using provided custom settings: $settings');
      } else {
        // Try loading user settings, fall back to legacy parameters or defaults
        try {
          settings = await getUserPomodoroSettings(userId);
          print('🍅 [POMODORO] Loaded user settings: $settings');
        } catch (e) {
          print('⚠️ [POMODORO] Failed to load user settings, using defaults: $e');
          settings = PomodoroSettings.classic();
        }
        
        // Apply legacy parameters if provided (for backward compatibility)
        if (workDurationMinutes != null || shortBreakDurationMinutes != null || 
            longBreakDurationMinutes != null || totalCycles != null) {
          settings = PomodoroSettings(
            workDuration: Duration(minutes: workDurationMinutes ?? settings.workDuration.inMinutes),
            shortBreakDuration: Duration(minutes: shortBreakDurationMinutes ?? settings.shortBreakDuration.inMinutes),
            longBreakDuration: Duration(minutes: longBreakDurationMinutes ?? settings.longBreakDuration.inMinutes),
            totalCycles: totalCycles ?? settings.totalCycles,
            presetName: 'legacy',
          );
          print('🍅 [POMODORO] Applied legacy parameters: $settings');
        }
      }
      
      // Validate settings with detailed error messages
      final validationError = _validateSettings(settings);
      if (validationError != null) {
        throw Exception('Invalid Pomodoro settings: $validationError');
      }
      
      // Create session in database with Duration-based settings
      // Convert seconds to minutes, ensuring minimum 1 minute to satisfy database constraints
      final workMinutes = math.max(1, (settings.workDuration.inSeconds / 60.0).ceil());
      final shortBreakMinutes = math.max(1, (settings.shortBreakDuration.inSeconds / 60.0).ceil());
      final longBreakMinutes = math.max(1, (settings.longBreakDuration.inSeconds / 60.0).ceil());
      
      final sessionData = {
        'user_id': userId,
        'module_id': module.id,
        'status': PomodoroSessionStatus.preparing.value,
        'total_cycles_planned': settings.totalCycles,
        'work_duration_minutes': workMinutes,
        'short_break_duration_minutes': shortBreakMinutes,
        'long_break_duration_minutes': longBreakMinutes,
        'session_data': {
          'module_title': module.title,
          'total_materials': module.materials.length,
          'custom_settings': settings.toJson(), // Store full settings for analytics
        },
      };

      final response = await SupabaseService.client
          .from('pomodoro_sessions')
          .insert(sessionData)
          .select()
          .single();

      _currentSession = PomodoroSession.fromJson(response);
      _sessionNotes.clear();
      
      print('✅ [POMODORO] Session initialized with ID: ${_currentSession!.id}');
      notifyListeners();
      
      return _currentSession!;
      
    } catch (e) {
      print('❌ [POMODORO] Failed to initialize session: $e');
      rethrow;
    }
  }

  /// Start the first work cycle
  Future<void> startSession() async {
    if (_currentSession == null) {
      throw Exception('No session initialized');
    }

    try {
      print('🍅 [POMODORO] Starting first work cycle');
      
      // Update session status to active
      await _updateSessionStatus(PomodoroSessionStatus.active);
      
      // Start first work cycle
      await _startWorkCycle();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to start session: $e');
      rethrow;
    }
  }

  /// Start a work cycle
  Future<void> _startWorkCycle() async {
    if (_currentSession == null) return;

    try {
      print('🍅 [POMODORO] Starting work cycle ${_currentSession!.currentCycle}');
      
      // Get work duration from session settings
      final sessionData = _currentSession!.sessionData;
      final customSettings = sessionData?['custom_settings'] as Map<String, dynamic>?;
      final workDuration = customSettings != null 
          ? Duration(seconds: customSettings['work_duration_seconds'] ?? (_currentSession!.workDurationMinutes * 60))
          : Duration(minutes: _currentSession!.workDurationMinutes);
      
      // Create new cycle in database
      final cycleData = {
        'session_id': _currentSession!.id,
        'cycle_number': _currentSession!.currentCycle,
        'type': PomodoroCycleType.work.value,
        'duration_minutes': _currentSession!.workDurationMinutes,
      };

      final response = await SupabaseService.client
          .from('pomodoro_cycles')
          .insert(cycleData)
          .select()
          .single();

      _currentCycle = PomodoroCycle.fromJson(response);
      
      // Start timer with actual Duration object
      _startTimer(workDuration);
      
      print('✅ [POMODORO] Work cycle started with duration: ${workDuration.inMinutes}m ${workDuration.inSeconds % 60}s');
      notifyListeners();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to start work cycle: $e');
      rethrow;
    }
  }

  /// Start a break cycle
  Future<void> _startBreakCycle() async {
    if (_currentSession == null) return;

    try {
      // Determine break type
      final isLongBreak = _currentSession!.currentCycle % 4 == 0;
      final breakType = isLongBreak ? PomodoroCycleType.longBreak : PomodoroCycleType.shortBreak;
      
      // Get break duration from session settings
      final sessionData = _currentSession!.sessionData;
      final customSettings = sessionData?['custom_settings'] as Map<String, dynamic>?;
      
      Duration breakDuration;
      int durationMinutes;
      
      if (customSettings != null) {
        if (isLongBreak) {
          breakDuration = Duration(seconds: customSettings['long_break_duration_seconds'] ?? (_currentSession!.longBreakDurationMinutes * 60));
          durationMinutes = _currentSession!.longBreakDurationMinutes;
        } else {
          breakDuration = Duration(seconds: customSettings['short_break_duration_seconds'] ?? (_currentSession!.shortBreakDurationMinutes * 60));
          durationMinutes = _currentSession!.shortBreakDurationMinutes;
        }
      } else {
        durationMinutes = isLongBreak 
            ? _currentSession!.longBreakDurationMinutes 
            : _currentSession!.shortBreakDurationMinutes;
        breakDuration = Duration(minutes: durationMinutes);
      }

      print('🍅 [POMODORO] Starting ${isLongBreak ? 'long' : 'short'} break');

      // Update session status
      await _updateSessionStatus(PomodoroSessionStatus.break_);
      
      // Create break cycle in database
      final cycleData = {
        'session_id': _currentSession!.id,
        'cycle_number': _currentSession!.currentCycle,
        'type': breakType.value,
        'duration_minutes': durationMinutes,
      };

      final response = await SupabaseService.client
          .from('pomodoro_cycles')
          .insert(cycleData)
          .select()
          .single();

      _currentCycle = PomodoroCycle.fromJson(response);
      
      // Start timer with actual Duration object
      _startTimer(breakDuration);
      
      print('✅ [POMODORO] Break started with duration: ${breakDuration.inMinutes}m ${breakDuration.inSeconds % 60}s');
      notifyListeners();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to start break: $e');
      rethrow;
    }
  }

  /// Start the timer with given duration
  void _startTimer(Duration duration) {
    _stopTimer(); // Stop any existing timer
    
    _totalTime = duration;
    _remainingTime = duration;
    _isRunning = true;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds <= 0) {
        _onTimerComplete();
      } else {
        _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
        notifyListeners();
      }
    });
    
    notifyListeners();
  }

  /// Handle timer completion
  Future<void> _onTimerComplete() async {
    _stopTimer();
    
    // Check if this is a work cycle completion that needs focus scoring
    final isWorkCycle = _currentCycle?.type == PomodoroCycleType.work;
    
    if (isWorkCycle && onWorkCycleComplete != null) {
      // Work cycle completed - pause progression for focus scoring
      _awaitingFocusScore = true;
      notifyListeners();
      
      // Trigger the focus scoring dialog
      onWorkCycleComplete!();
      
      // Don't continue cycle progression here - wait for continueCycleProgression()
      return;
    }
    
    // Continue with normal cycle progression (for breaks or when no callback)
    await _continueCycleProgression();
  }
  
  /// Continue cycle progression after focus scoring is complete
  Future<void> continueCycleProgression() async {
    if (!_awaitingFocusScore) return;
    
    _awaitingFocusScore = false;
    notifyListeners();
    
    await _continueCycleProgression();
  }
  
  /// Internal method to handle the actual cycle progression logic
  Future<void> _continueCycleProgression() async {
    await _completeCurrent();
    
    if (_currentSession!.status == PomodoroSessionStatus.active) {
      // Work cycle completed, start break
      await _startBreakCycle();
    } else if (_currentSession!.status == PomodoroSessionStatus.break_) {
      // Break completed, either start next work cycle or complete session
      if (_currentSession!.currentCycle < _currentSession!.totalCyclesPlanned) {
        await _advanceToNextCycle();
        await _startWorkCycle();
      } else {
        await _completeSession();
      }
    }
  }

  /// Complete current cycle
  Future<void> _completeCurrent() async {
    if (_currentCycle == null) return;

    try {
      // Update cycle as completed
      await SupabaseService.client
          .from('pomodoro_cycles')
          .update({
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentCycle!.id);

      // If it was a work cycle, increment cycles completed
      if (_currentCycle!.type == PomodoroCycleType.work) {
        await SupabaseService.client
            .from('pomodoro_sessions')
            .update({
              'cycles_completed': _currentSession!.cyclesCompleted + 1,
            })
            .eq('id', _currentSession!.id);
        
        _currentSession = _currentSession!.copyWith(
          cyclesCompleted: _currentSession!.cyclesCompleted + 1,
        );
      }
      
      print('✅ [POMODORO] Cycle ${_currentCycle!.cycleNumber} completed');
      
    } catch (e) {
      print('❌ [POMODORO] Failed to complete cycle: $e');
    }
  }

  /// Advance to next cycle
  Future<void> _advanceToNextCycle() async {
    if (_currentSession == null) return;

    try {
      final nextCycle = _currentSession!.currentCycle + 1;
      
      await SupabaseService.client
          .from('pomodoro_sessions')
          .update({
            'current_cycle': nextCycle,
          })
          .eq('id', _currentSession!.id);

      _currentSession = _currentSession!.copyWith(currentCycle: nextCycle);
      await _updateSessionStatus(PomodoroSessionStatus.active);
      
      print('✅ [POMODORO] Advanced to cycle $nextCycle');
      
    } catch (e) {
      print('❌ [POMODORO] Failed to advance cycle: $e');
    }
  }

  /// Skip the current cycle (work or break)
  Future<void> skipCycle() async {
    if (_currentSession == null || _currentCycle == null) return;

    try {
      print('⏭️ [POMODORO] Skipping current cycle: ${_currentCycle!.cycleType.name}');
      
      // Stop the timer
      _timer?.cancel();
      _timer = null;
      
      // Mark current cycle as incomplete/skipped
      final updatedCycle = _currentCycle!.copyWith(
        completedAt: DateTime.now(),
        wasInterrupted: true,
      );
      
      // Update cycle in database
      await SupabaseService.client
          .from('pomodoro_cycles')
          .update({
            'completed_at': DateTime.now().toIso8601String(),
            'was_interrupted': true,
          })
          .eq('id', _currentCycle!.id);
      
      _currentCycle = updatedCycle;
      
      // If it was a work cycle, we might want to record a focus score
      // But we'll let the UI handle that decision
      
      // Advance to next cycle
      await _advanceToNextCycle();
      
      print('✅ [POMODORO] Cycle skipped and advanced to next');
      notifyListeners();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to skip cycle: $e');
      rethrow;
    }
  }

  /// Complete the entire session
  Future<void> _completeSession() async {
    if (_currentSession == null) return;

    try {
      await _updateSessionStatus(PomodoroSessionStatus.completed);
      
      await SupabaseService.client
          .from('pomodoro_sessions')
          .update({
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentSession!.id);

      _currentSession = _currentSession!.copyWith(
        status: PomodoroSessionStatus.completed,
        completedAt: DateTime.now(),
      );
      
      print('🎉 [POMODORO] Session completed!');
      notifyListeners();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to complete session: $e');
    }
  }

  /// Pause the current timer
  void pauseTimer() {
    if (_isRunning) {
      _stopTimer();
      print('⏸️ [POMODORO] Timer paused');
      notifyListeners();
    }
  }

  /// Resume the paused timer
  void resumeTimer() {
    if (!_isRunning && _remainingTime.inSeconds > 0) {
      _startTimer(_remainingTime);
      print('▶️ [POMODORO] Timer resumed');
    }
  }

  /// Stop and reset the timer
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  /// Update session status in database
  Future<void> _updateSessionStatus(PomodoroSessionStatus status) async {
    if (_currentSession == null) return;

    try {
      await SupabaseService.client
          .from('pomodoro_sessions')
          .update({'status': status.value})
          .eq('id', _currentSession!.id);

      _currentSession = _currentSession!.copyWith(status: status);
      notifyListeners();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to update session status: $e');
    }
  }

  /// Add a note to the current session
  Future<PomodoroNote> addNote({
    required String content,
    PomodoroNoteType noteType = PomodoroNoteType.studyNote,
  }) async {
    if (_currentSession == null) {
      throw Exception('No active session');
    }

    try {
      final noteData = {
        'session_id': _currentSession!.id,
        'cycle_id': _currentCycle?.id,
        'content': content,
        'note_type': noteType.value,
      };

      final response = await SupabaseService.client
          .from('pomodoro_notes')
          .insert(noteData)
          .select()
          .single();

      final note = PomodoroNote.fromJson(response);
      _sessionNotes.add(note);
      
      print('📝 [POMODORO] Note added: ${noteType.value}');
      notifyListeners();
      
      return note;
      
    } catch (e) {
      print('❌ [POMODORO] Failed to add note: $e');
      rethrow;
    }
  }

  /// Add focus score to current cycle
  Future<void> addFocusScore(int score) async {
    if (_currentCycle == null) return;

    try {
      await SupabaseService.client
          .from('pomodoro_cycles')
          .update({'focus_score': score})
          .eq('id', _currentCycle!.id);

      _currentCycle = _currentCycle!.copyWith(focusScore: score);
      
      print('⭐ [POMODORO] Focus score added: $score/10');
      notifyListeners();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to add focus score: $e');
    }
  }

  /// Mark current cycle as interrupted
  Future<void> markCurrentCycleAsInterrupted() async {
    if (_currentCycle == null || _currentCycle?.type != PomodoroCycleType.work) {
      print('⚠️ [POMODORO] Cannot mark interruption - no active work cycle');
      return;
    }

    try {
      print('⚠️ [POMODORO] Marking current work cycle as interrupted');
      
      // Update cycle in database
      await SupabaseService.client
          .from('pomodoro_cycles')
          .update({'was_interrupted': true})
          .eq('id', _currentCycle!.id);

      // Update local state
      _currentCycle = _currentCycle!.copyWith(wasInterrupted: true);
      
      // Pause timer to get user focus on interruption
      pauseTimer();
      
      // Trigger focus score dialog if callback is available
      if (onWorkCycleComplete != null) {
        _awaitingFocusScore = true;
        notifyListeners();
        onWorkCycleComplete!();
      }
      
      print('✅ [POMODORO] Interruption recorded for cycle ${_currentCycle!.cycleNumber}');
      notifyListeners();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to mark interruption: $e');
      rethrow;
    }
  }

  /// Get session results and analytics
  Future<PomodoroSessionResults> getSessionResults() async {
    if (_currentSession == null) {
      throw Exception('No session available');
    }

    try {
      // Fetch complete session data
      final sessionResponse = await SupabaseService.client
          .from('pomodoro_sessions')
          .select('''
            *,
            pomodoro_cycles(*),
            pomodoro_notes(*)
          ''')
          .eq('id', _currentSession!.id)
          .single();

      final session = PomodoroSession.fromJson(sessionResponse);
      
      // Extract cycles and notes from the response
      final cycles = (sessionResponse['pomodoro_cycles'] as List? ?? [])
          .map((c) => PomodoroCycle.fromJson(c))
          .toList();
      final notes = (sessionResponse['pomodoro_notes'] as List? ?? [])
          .map((n) => PomodoroNote.fromJson(n))
          .toList();
      
      return PomodoroSessionResults.calculate(
        session,
        cycles,
        notes,
      );
      
    } catch (e) {
      print('❌ [POMODORO] Failed to get session results: $e');
      rethrow;
    }
  }

  /// Generate comprehensive analytics for the session
  Future<StudySessionAnalytics?> generateSessionAnalytics({
    required String userId,
    required Module module,
    required Course course,
  }) async {
    if (_currentSession == null) return null;

    try {
      print('📊 [POMODORO ANALYTICS] Generating session analytics...');
      
      // Get session results with complete data
      final sessionResponse = await SupabaseService.client
          .from('pomodoro_sessions')
          .select('''
            *,
            pomodoro_cycles(*),
            pomodoro_notes(*)
          ''')
          .eq('id', _currentSession!.id)
          .single();

      final session = PomodoroSession.fromJson(sessionResponse);
      final cycles = (sessionResponse['pomodoro_cycles'] as List? ?? [])
          .map((c) => PomodoroCycle.fromJson(c))
          .toList();
      final notes = (sessionResponse['pomodoro_notes'] as List? ?? [])
          .map((n) => PomodoroNote.fromJson(n))
          .toList();
      
      // Use the existing StudyAnalyticsService with correct parameters
      final analyticsService = StudyAnalyticsService();
      
      // Generate analytics using the correct method signature
      _sessionAnalytics = await analyticsService.generatePomodoroAnalytics(
        sessionId: _currentSession!.id,
        userId: userId,
        moduleId: module.id,
        session: session,
        cycles: cycles,
        notes: notes,
        course: course,
        module: module,
      );
      
      print('✅ [POMODORO ANALYTICS] Analytics generated successfully');
      notifyListeners(); // Notify UI that analytics are available
      
      return _sessionAnalytics;
      
    } catch (e) {
      print('❌ [POMODORO ANALYTICS] Failed to generate analytics: $e');
      return null;
    }
  }

  /// Calculate work consistency metric
  double _calculateWorkConsistency(PomodoroSessionResults results) {
    // Simple metric based on completion rate and interruptions
    final baseScore = results.completionPercentage / 100.0;
    final interruptionPenalty = results.interruptionRate * 0.2;
    return (baseScore - interruptionPenalty).clamp(0.0, 1.0);
  }

  /// Calculate break adherence metric
  double _calculateBreakAdherence(PomodoroSessionResults results) {
    // Placeholder - in real implementation, compare actual break time to planned
    return results.averageFocusScore / 10.0;
  }

  /// Determine productivity pattern
  String _determineProductivityPattern(PomodoroSessionResults results) {
    if (results.completionPercentage >= 90 && results.averageFocusScore >= 8) {
      return 'high_focus_sustained';
    } else if (results.completionPercentage >= 75 && results.interruptionRate < 0.2) {
      return 'steady_productive';
    } else if (results.interruptionRate > 0.5) {
      return 'frequently_interrupted';
    } else if (results.averageFocusScore < 5) {
      return 'low_focus_struggling';
    } else {
      return 'moderate_performance';
    }
  }

  /// Save user Pomodoro settings to database
  Future<void> saveUserPomodoroSettings(String userId, PomodoroSettings settings) async {
    try {
      print('💾 [POMODORO SETTINGS] Saving settings for user: $userId');
      
      // Validate settings first
      final validationError = _validateSettings(settings);
      if (validationError != null) {
        throw ArgumentError('Invalid settings: $validationError');
      }
      
      // Validate user ID
      if (userId.isEmpty) {
        throw ArgumentError('User ID cannot be empty');
      }
      
      final settingsData = {
        'user_id': userId,
        ...settings.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Check if user settings exist
      final existingSettings = await SupabaseService.client
          .from('user_pomodoro_settings')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existingSettings != null) {
        // Update existing settings
        await SupabaseService.client
            .from('user_pomodoro_settings')
            .update(settingsData)
            .eq('user_id', userId);
        print('✅ [POMODORO SETTINGS] Settings updated for existing user');
      } else {
        // Insert new settings
        settingsData['created_at'] = DateTime.now().toIso8601String();
        await SupabaseService.client
            .from('user_pomodoro_settings')
            .insert(settingsData);
        print('✅ [POMODORO SETTINGS] Settings created for new user');
      }

      print('✅ [POMODORO SETTINGS] Settings saved successfully: ${settings.presetName}');
      
    } catch (e) {
      print('❌ [POMODORO SETTINGS] Failed to save settings: $e');
      
      // Provide more specific error messages
      if (e.toString().contains('check constraint')) {
        throw Exception('Settings contain invalid values that violate database constraints. Please adjust your settings.');
      } else if (e.toString().contains('foreign key')) {
        throw Exception('User not found. Please ensure you are logged in.');
      } else if (e.toString().contains('duplicate key')) {
        throw Exception('Settings conflict detected. Please try again.');
      } else if (e is ArgumentError) {
        rethrow; // Re-throw validation errors as-is
      } else {
        throw Exception('Failed to save settings. Please check your connection and try again.');
      }
    }
  }

  /// Load user Pomodoro settings from database
  Future<PomodoroSettings> getUserPomodoroSettings(String userId) async {
    try {
      print('📖 [POMODORO SETTINGS] Loading settings for user: $userId');
      
      final response = await SupabaseService.client
          .from('user_pomodoro_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        final settings = PomodoroSettings.fromJson(response);
        print('✅ [POMODORO SETTINGS] Settings loaded: $settings');
        return settings;
      } else {
        print('📝 [POMODORO SETTINGS] No saved settings found, using defaults');
        return PomodoroSettings.classic();
      }
      
    } catch (e) {
      print('❌ [POMODORO SETTINGS] Failed to load settings: $e, using defaults');
      return PomodoroSettings.classic();
    }
  }

  /// Create user settings table if it doesn't exist
  static Future<void> createUserSettingsTable() async {
    try {
      await SupabaseService.client.rpc('create_user_pomodoro_settings_table');
      print('✅ [POMODORO SETTINGS] User settings table created/verified');
    } catch (e) {
      print('❌ [POMODORO SETTINGS] Failed to create settings table: $e');
    }
  }

  /// Validate Pomodoro settings and return detailed error message if invalid
  String? _validateSettings(PomodoroSettings settings) {
    // Check work duration
    if (settings.workDuration < const Duration(seconds: 5)) {
      return 'Work duration must be at least 5 seconds';
    }
    if (settings.workDuration > const Duration(minutes: 90)) {
      return 'Work duration cannot exceed 90 minutes';
    }

    // Check short break duration
    if (settings.shortBreakDuration < const Duration(seconds: 5)) {
      return 'Short break duration must be at least 5 seconds';
    }
    if (settings.shortBreakDuration > const Duration(minutes: 30)) {
      return 'Short break duration cannot exceed 30 minutes';
    }

    // Check long break duration
    if (settings.longBreakDuration < const Duration(seconds: 5)) {
      return 'Long break duration must be at least 5 seconds';
    }
    if (settings.longBreakDuration > const Duration(minutes: 60)) {
      return 'Long break duration cannot exceed 60 minutes';
    }

    // Check total cycles
    if (settings.totalCycles < 1) {
      return 'Must have at least 1 cycle';
    }
    if (settings.totalCycles > 10) {
      return 'Cannot exceed 10 cycles';
    }

    // Check estimated session time
    if (settings.estimatedSessionTime > const Duration(hours: 8)) {
      return 'Total session time cannot exceed 8 hours';
    }

    // Check logical relationships - allow equal durations for micro-sessions
    if (settings.workDuration.inSeconds > 30 && settings.shortBreakDuration >= settings.workDuration) {
      return 'Short break should be shorter than work duration for sessions longer than 30 seconds';
    }
    if (settings.longBreakDuration > settings.workDuration * 2) {
      return 'Long break should not be more than twice the work duration';
    }

    return null; // Valid settings
  }

  /// Clean up resources
  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  /// Force stop session (for emergencies)
  Future<void> forceStopSession() async {
    _stopTimer();
    if (_currentSession != null) {
      await _updateSessionStatus(PomodoroSessionStatus.paused);
    }
    print('🛑 [POMODORO] Session force stopped');
  }
}