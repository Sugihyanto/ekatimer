import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/timer_mode.dart';
import '../models/meditation_session.dart';
import '../models/user_profile.dart';
import '../services/persistence_service.dart';
import '../services/audio_service.dart';
import '../services/vibration_service.dart';
import '../services/database_service.dart';
import '../services/alarm_service.dart';
import '../utils/constants.dart';

enum TimerState { idle, delaying, running, paused, completed }

enum _CompletionSource { timer, restored, nativeAlarm }

class TimerProvider extends ChangeNotifier {
  TimerProvider({
    AudioService? audioService,
    VibrationService? vibrationService,
    AlarmService? alarmService,
    DateTime Function()? now,
    Future<void> Function(MeditationSession)? saveSession,
  }) : _audioService = audioService ?? AudioService(),
       _vibrationService = vibrationService ?? VibrationService(),
       _alarmService = alarmService ?? AlarmService(),
       _now = now ?? DateTime.now,
       _saveSession = saveSession ?? DatabaseService.insertSession;

  final AudioService _audioService;
  final VibrationService _vibrationService;
  final AlarmService _alarmService;
  final DateTime Function() _now;
  final Future<void> Function(MeditationSession) _saveSession;

  TimerMode _timerMode = TimerMode.timed;
  int _durationMinutes = AppConstants.defaultTimerDurationMinutes;
  int _endAtHour = 0;
  int _endAtMinute = 0;

  TimerState _state = TimerState.idle;
  int _elapsedSeconds = 0;
  int _remainingSeconds = 0;
  int _totalDurationSeconds = 0;
  late DateTime _startTime;
  DateTime? _endTime;
  int _pauseDurationSeconds = 0;
  late DateTime _pauseStartTime;
  String? _currentSessionId;
  String _currentProfileId = UserProfile.defaultId;

  int _lastIntervalMinute = -1;
  int _lastVibrationIntervalMinute = -1;

  int intervalMinutes = 0;
  int vibrationIntervalMinutes = 0;
  String startSound = 'none';
  String endSound = 'ThreeBowl';
  String intervalSound = 'Bowl';
  String startVibration = 'none';
  String endVibration = 'none';
  String intervalVibration = 'none';
  int volume = 80;

  int sessionDelaySeconds = 0;
  int _delayRemainingSeconds = 0;
  Timer? _delayTimer;

  Timer? _tickTimer;
  bool _alarmFired = false;

  // Guards stopSession() and _onSessionComplete() against both running for
  // the same session (e.g. the user taps Stop the instant the native alarm
  // fires), which would otherwise insert two session rows sharing one id.
  bool _sessionFinalized = false;

  // Whether the most recently finalized session reached its target
  // naturally (via _onSessionComplete) rather than being stopped early
  // (via stopSession). TimerState alone can't tell CompleteScreen this:
  // `_state` is TimerState.completed either way, so comparing against it
  // is always true by the time anyone reads it.
  bool _lastSessionCompletedNaturally = true;

  TimerState get state => _state;
  TimerMode get timerMode => _timerMode;
  int get durationMinutes => _durationMinutes;
  int get elapsedSeconds => _elapsedSeconds;
  int get remainingSeconds => _remainingSeconds;
  int get totalDurationSeconds => _totalDurationSeconds;
  DateTime get startTime => _startTime;
  DateTime? get endTime => _endTime;
  int get pauseDurationSeconds => _pauseDurationSeconds;
  int get endAtHour => _endAtHour;
  int get endAtMinute => _endAtMinute;
  int get delayRemainingSeconds => _delayRemainingSeconds;
  String? get currentSessionId => _currentSessionId;
  bool get lastSessionCompletedNaturally => _lastSessionCompletedNaturally;

  void configure({
    TimerMode? mode,
    int? durationMinutes,
    int? endAtHour,
    int? endAtMinute,
  }) {
    if (mode != null) _timerMode = mode;
    if (durationMinutes != null) _durationMinutes = durationMinutes;
    if (endAtHour != null) _endAtHour = endAtHour;
    if (endAtMinute != null) _endAtMinute = endAtMinute;
    notifyListeners();
  }

  String get displayTime {
    switch (_state) {
      case TimerState.delaying:
      case TimerState.idle:
        if (_timerMode == TimerMode.timed) {
          final minutes = _durationMinutes;
          final hours = minutes ~/ 60;
          final mins = minutes % 60;
          if (hours > 0) {
            return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:00';
          }
          return '${mins.toString().padLeft(2, '0')}:00';
        } else if (_timerMode == TimerMode.endAt) {
          final hour = _endAtHour == 0
              ? 12
              : (_endAtHour > 12 ? _endAtHour - 12 : _endAtHour);
          final amPm = _endAtHour >= 12 ? 'PM' : 'AM';
          return '$hour:${_endAtMinute.toString().padLeft(2, '0')} $amPm';
        }
        return '--:--';
      case TimerState.running:
      case TimerState.paused:
      case TimerState.completed:
        if (_timerMode == TimerMode.timed) {
          final hours = _remainingSeconds ~/ 3600;
          final minutes = (_remainingSeconds % 3600) ~/ 60;
          final seconds = _remainingSeconds % 60;
          if (hours > 0) {
            return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
          }
          return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        } else if (_timerMode == TimerMode.endAt) {
          final hours = _remainingSeconds ~/ 3600;
          final minutes = (_remainingSeconds % 3600) ~/ 60;
          final seconds = _remainingSeconds % 60;
          if (hours > 0) {
            return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
          }
          return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        } else {
          final hours = _elapsedSeconds ~/ 3600;
          final minutes = (_elapsedSeconds % 3600) ~/ 60;
          final seconds = _elapsedSeconds % 60;
          if (hours > 0) {
            return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
          }
          return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        }
    }
  }

  String get elapsedDisplay {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> startSession() async {
    final requestedAt = _now();
    _currentSessionId = const Uuid().v4();
    // Captured once, here, not read again at save time: if the user
    // switches profile mid-session, this session must stay attributed to
    // whoever started it, not whoever is active when it finishes.
    _currentProfileId = await PersistenceService.loadActiveProfileId();
    _startTime = _now();
    _elapsedSeconds = 0;
    _pauseDurationSeconds = 0;
    _lastIntervalMinute = -1;
    _lastVibrationIntervalMinute = -1;
    _alarmFired = false;
    _sessionFinalized = false;
    _lastSessionCompletedNaturally = true;

    // End At names a clock time chosen when Start was pressed. Preparation
    // must not move that target to tomorrow if the clock passes it meanwhile.
    _endTime = null;
    if (_timerMode == TimerMode.endAt) {
      _endTime = DateTime(
        requestedAt.year,
        requestedAt.month,
        requestedAt.day,
        _endAtHour,
        _endAtMinute,
      );
      if (!_endTime!.isAfter(requestedAt)) {
        _endTime = DateTime(
          requestedAt.year,
          requestedAt.month,
          requestedAt.day + 1,
          _endAtHour,
          _endAtMinute,
        );
      }
    }

    // If a session delay is configured, enter the delaying state first.
    if (sessionDelaySeconds > 0) {
      _delayRemainingSeconds = sessionDelaySeconds;
      _state = TimerState.delaying;
      notifyListeners();
      _startDelayCountdown();
      return;
    }

    await _beginRunning();
  }

  /// Called after the delay countdown completes, or immediately if no delay.
  Future<void> _beginRunning() async {
    // Preparation time is not meditation time. Timed sessions get their full
    // duration from here; End At retains the clock target selected at Start.
    _startTime = _now();
    switch (_timerMode) {
      case TimerMode.timed:
        _totalDurationSeconds = _durationMinutes * 60;
        _remainingSeconds = _totalDurationSeconds;
        _endTime = _startTime.add(Duration(seconds: _totalDurationSeconds));
        break;
      case TimerMode.endAt:
        if (!_startTime.isBefore(_endTime!)) {
          // The target arrived during preparation: there was no meditation
          // time. Finish at that target without playing a start cue or
          // scheduling an alarm in the past.
          _startTime = _endTime!;
          _totalDurationSeconds = 0;
          _remainingSeconds = 0;
          await _onSessionComplete();
          return;
        }
        _totalDurationSeconds = _endTime!.difference(_startTime).inSeconds;
        _remainingSeconds = _remainingAt(_startTime);
        break;
      case TimerMode.unlimited:
        _totalDurationSeconds = 0;
        _remainingSeconds = -1;
        _endTime = null;
        break;
    }

    _state = TimerState.running;

    await _audioService.setVolume(volume / 100.0);
    await _audioService.playSound(startSound);
    await _vibrationService.vibrate(startVibration);

    if (_endTime != null) {
      final alarmId = _timerMode == TimerMode.timed ? 1001 : 1002;
      await _alarmService.scheduleEndAlarm(
        id: alarmId,
        dateTime: _endTime!,
        assetAudioPath: _assetPath(endSound),
        vibrate: endVibration != 'none',
        volume: volume / 100.0,
      );
    } else if (_timerMode == TimerMode.unlimited) {
      // Schedule a dummy keep-alive alarm far in the future so the alarm
      // package's iOS background audio keep-alive mechanism stays active.
      final dummyEndTime = _now().add(const Duration(hours: 72));
      await _alarmService.scheduleEndAlarm(
        id: 1003,
        dateTime: dummyEndTime,
        assetAudioPath: null,
        vibrate: false,
        volume: 0.0,
      );
    }

    await _persistSessionState();
    _startTick();
    notifyListeners();
  }

  void _startDelayCountdown() {
    _delayTimer?.cancel();
    _delayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _delayRemainingSeconds--;
      final endAtReached =
          _timerMode == TimerMode.endAt &&
          _endTime != null &&
          !_now().isBefore(_endTime!);
      if (_delayRemainingSeconds <= 0 || endAtReached) {
        _delayTimer?.cancel();
        _delayTimer = null;
        _delayRemainingSeconds = 0;
        _beginRunning();
      } else {
        notifyListeners();
      }
    });
  }

  /// Skip the delay and start the session immediately.
  /// The user can call this by tapping the start button again.
  Future<void> skipDelay() async {
    if (_state != TimerState.delaying) return;
    _delayTimer?.cancel();
    _delayTimer = null;
    _delayRemainingSeconds = 0;
    await _beginRunning();
  }

  Future<void> pauseSession() async {
    if (_state != TimerState.running) return;
    _state = TimerState.paused;
    _pauseStartTime = _now();
    _elapsedSeconds = _calculateElapsedSeconds(_pauseStartTime);
    _remainingSeconds = _remainingAt(_pauseStartTime);
    _stopTick();
    if (_timerMode == TimerMode.unlimited) {
      await _alarmService.cancelAlarm(1003);
    } else {
      final alarmId = _timerMode == TimerMode.timed ? 1001 : 1002;
      await _alarmService.cancelAlarm(alarmId);
    }
    await _persistSessionState();
    notifyListeners();
  }

  Future<void> resumeSession() async {
    if (_state != TimerState.paused) return;
    final pauseDuration = _now().difference(_pauseStartTime);
    _pauseDurationSeconds += pauseDuration.inSeconds;

    if (_endTime != null) {
      _endTime = _endTime!.add(pauseDuration);
    }

    _state = TimerState.running;
    _alarmFired = false;

    if (_endTime != null) {
      final alarmId = _timerMode == TimerMode.timed ? 1001 : 1002;
      await _alarmService.scheduleEndAlarm(
        id: alarmId,
        dateTime: _endTime!,
        assetAudioPath: _assetPath(endSound),
        vibrate: endVibration != 'none',
        volume: volume / 100.0,
      );
    } else if (_timerMode == TimerMode.unlimited) {
      // Re-schedule keep-alive dummy alarm on resume
      final dummyEndTime = _now().add(const Duration(hours: 72));
      await _alarmService.scheduleEndAlarm(
        id: 1003,
        dateTime: dummyEndTime,
        assetAudioPath: null,
        vibrate: false,
        volume: 0.0,
      );
    }

    _startTick();
    await _persistSessionState();
    notifyListeners();
  }

  Future<void> stopSession({bool completed = true}) async {
    if (_sessionFinalized) return;
    _sessionFinalized = true;
    // [completed] says whether this stop still counts as finishing the
    // session. The only caller today is the End button, which passes false,
    // so the completion screen reports "ended early" rather than "complete".
    _lastSessionCompletedNaturally = completed;

    _stopTick();

    final now = _now();
    _elapsedSeconds = _calculateElapsedSeconds(now);
    _state = TimerState.completed;

    await _alarmService.cancelAllAlarms();

    // When user stops early (completed: false), skip end sound/vibration
    // so they can leave quietly (e.g., in a group meditation).
    if (completed) {
      await _audioService.playSound(endSound);
      await _vibrationService.vibrate(endVibration);
    }

    final session = MeditationSession(
      id: _currentSessionId ?? const Uuid().v4(),
      profileId: _currentProfileId,
      startTime: _startTime,
      endTime: now,
      durationSeconds: _elapsedSeconds,
      targetDurationSeconds: _totalDurationSeconds,
      timerMode: _timerMode.asString,
      completed: completed,
    );
    await _saveSession(session);

    await PersistenceService.clearActiveSession();

    notifyListeners();
  }

  int _calculateElapsedSeconds(DateTime now) {
    final totalElapsed = now.difference(_startTime).inSeconds;
    int currentPause = 0;
    if (_state == TimerState.paused) {
      currentPause = now.difference(_pauseStartTime).inSeconds;
    }
    return totalElapsed - _pauseDurationSeconds - currentPause;
  }

  Future<void> restoreSession(Map<String, int> sessionData) async {
    final settings = await PersistenceService.loadSettings();
    sessionDelaySeconds = settings.sessionDelaySeconds;
    intervalMinutes = settings.soundConfig.intervalMinutes;
    vibrationIntervalMinutes = settings.vibrationConfig.intervalMinutes;
    startSound = settings.soundConfig.startSound;
    endSound = settings.soundConfig.endSound;
    intervalSound = settings.soundConfig.intervalSound;
    startVibration = settings.vibrationConfig.startVibration;
    endVibration = settings.vibrationConfig.endVibration;
    intervalVibration = settings.vibrationConfig.intervalVibration;
    volume = settings.soundConfig.volume;

    final startTimeMs = sessionData['startTime']!;
    final durationSeconds = sessionData['durationSeconds']!;
    final pauseDuration = sessionData['pauseDuration'] ?? 0;
    final endTimeMs = sessionData['endTime']!;
    final pauseStartTimeMs = sessionData['pauseStartTime'] ?? 0;

    _startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
    _endTime = endTimeMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(endTimeMs)
        : null;
    _totalDurationSeconds = durationSeconds;
    _pauseDurationSeconds = pauseDuration;
    _currentSessionId = const Uuid().v4();
    _currentProfileId = await PersistenceService.loadActiveSessionProfileId();
    _alarmFired = false;
    _sessionFinalized = false;
    _lastSessionCompletedNaturally = true;

    final modeStr = await PersistenceService.loadActiveSessionMode();
    _timerMode = TimerMode.fromString(modeStr ?? 'timed');
    if (_timerMode == TimerMode.timed) {
      _durationMinutes = durationSeconds ~/ 60;
    } else if (_timerMode == TimerMode.unlimited) {
      _endTime = null;
    }

    final isPaused = await PersistenceService.loadActiveSessionIsPaused();
    _state = isPaused ? TimerState.paused : TimerState.running;

    if (isPaused) {
      if (pauseStartTimeMs > 0) {
        _pauseStartTime = DateTime.fromMillisecondsSinceEpoch(pauseStartTimeMs);
      } else {
        _pauseStartTime = _now();
      }
    }

    final now = _now();
    _elapsedSeconds = _calculateElapsedSeconds(now);
    // A paused countdown stays frozen while the app is closed. End At uses
    // the same remaining-time display and existing pause extension policy.
    _remainingSeconds = _remainingAt(isPaused ? _pauseStartTime : now);

    _lastIntervalMinute = -1;
    _lastVibrationIntervalMinute = -1;

    if (!isPaused) {
      if (_endTime != null) {
        if (!_endTime!.isAfter(now)) {
          await _onSessionComplete(source: _CompletionSource.restored);
          return;
        }

        final alarmId = _timerMode == TimerMode.timed ? 1001 : 1002;
        await _alarmService.scheduleEndAlarm(
          id: alarmId,
          dateTime: _endTime!,
          assetAudioPath: _assetPath(endSound),
          vibrate: endVibration != 'none',
          volume: volume / 100.0,
        );
      } else if (_timerMode == TimerMode.unlimited) {
        // Re-schedule keep-alive dummy alarm when restoring a running session
        final dummyEndTime = _now().add(const Duration(hours: 72));
        await _alarmService.scheduleEndAlarm(
          id: 1003,
          dateTime: dummyEndTime,
          assetAudioPath: null,
          vibrate: false,
          volume: 0.0,
        );
      }
      _startTick();
    }

    notifyListeners();
  }

  Future<void> _persistSessionState() async {
    await PersistenceService.saveActiveSession(
      startTime: _startTime.millisecondsSinceEpoch,
      durationSeconds: _totalDurationSeconds,
      mode: _timerMode.asString,
      isPaused: _state == TimerState.paused,
      pauseDuration: _pauseDurationSeconds,
      endTime: _endTime?.millisecondsSinceEpoch ?? 0,
      profileId: _currentProfileId,
      pauseStartTime: _state == TimerState.paused
          ? _pauseStartTime.millisecondsSinceEpoch
          : null,
    );
  }

  void _startTick() {
    _stopTick();
    _tickTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.timerTickIntervalMs),
      (_) => _onTick(),
    );
  }

  void _stopTick() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void _onTick() {
    if (_alarmFired || _state != TimerState.running) return;

    final now = _now();
    final previousElapsed = _elapsedSeconds;
    final previousRemaining = _remainingSeconds;
    _elapsedSeconds = _calculateElapsedSeconds(now);
    _remainingSeconds = _remainingAt(now);

    switch (_timerMode) {
      case TimerMode.timed:
      case TimerMode.endAt:
        if (_endTime != null && !now.isBefore(_endTime!)) {
          _onSessionComplete();
          return;
        }
        break;
      case TimerMode.unlimited:
        _remainingSeconds = -1;
        break;
    }

    _checkIntervalSounds(now);
    // The tick runs twice a second so the deadline and interval bells land on
    // time, but everything on screen is whole seconds. Notifying on a tick
    // that changed nothing rebuilt the timer screens for no visible change.
    if (_elapsedSeconds != previousElapsed ||
        _remainingSeconds != previousRemaining) {
      notifyListeners();
    }
  }

  int _remainingAt(DateTime now) {
    if (_timerMode == TimerMode.unlimited) return -1;
    final remaining = _endTime?.difference(now).inMicroseconds ?? 0;
    if (remaining <= 0) return 0;
    // Display the last second until the actual deadline, rather than
    // rounding it down to zero and finishing up to one second early.
    return (remaining + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
  }

  /// Convert a bare sound name (e.g. "ThreeBowl") to the asset path
  /// expected by [AlarmService].
  String? _assetPath(String soundName) {
    if (soundName.isEmpty || soundName == 'none') return null;
    return 'assets/sounds/$soundName.wav';
  }

  void _checkIntervalSounds(DateTime now) {
    final currentMinute = (_elapsedSeconds ~/ 60);

    // Do not play interval sounds at the very start (minute 0).
    // They should only play after the configured interval has elapsed
    // (e.g., a 3-minute interval first plays at minute 3, not minute 0).
    if (currentMinute == 0) return;

    // Check sound interval
    if (intervalMinutes > 0) {
      // Auto-disable: interval won't fire if it's >= total session duration (timed mode).
      if (!(_timerMode == TimerMode.timed &&
          _durationMinutes > 0 &&
          intervalMinutes >= _durationMinutes)) {
        final interval = currentMinute ~/ intervalMinutes;
        if (interval > _lastIntervalMinute &&
            currentMinute % intervalMinutes == 0) {
          _lastIntervalMinute = interval;
          _audioService.playSound(intervalSound);
        }
      }
    }

    // Check vibration interval
    if (vibrationIntervalMinutes > 0) {
      if (!(_timerMode == TimerMode.timed &&
          _durationMinutes > 0 &&
          vibrationIntervalMinutes >= _durationMinutes)) {
        final vibInterval = currentMinute ~/ vibrationIntervalMinutes;
        if (vibInterval > _lastVibrationIntervalMinute &&
            currentMinute % vibrationIntervalMinutes == 0) {
          _lastVibrationIntervalMinute = vibInterval;
          _vibrationService.vibrate(intervalVibration);
        }
      }
    }
  }

  Future<void> _onSessionComplete({
    _CompletionSource source = _CompletionSource.timer,
  }) async {
    if (_alarmFired || _sessionFinalized) return;
    _alarmFired = true;
    _sessionFinalized = true;
    // Reaching here — the tick loop hit zero, the native alarm fired, or a
    // restored session's end time had already passed — always means the
    // session ran its full course, so CompleteScreen should say "complete".
    _lastSessionCompletedNaturally = true;

    _stopTick();

    _state = TimerState.completed;

    final completedAt = _endTime ?? _now();
    _elapsedSeconds = _totalDurationSeconds;
    _remainingSeconds = 0;

    // A native callback arrives when the bell starts, so canceling its alarm
    // here would cut the one-shot bell short. Expired restores still clear
    // stale alarms, while foreground completion replaces them with its cue.
    if (source != _CompletionSource.nativeAlarm) {
      await _alarmService.cancelAllAlarms();
    }
    if (source == _CompletionSource.timer) {
      await _audioService.playSound(endSound);
      await _vibrationService.vibrate(endVibration);
    }

    final session = MeditationSession(
      id: _currentSessionId ?? const Uuid().v4(),
      profileId: _currentProfileId,
      startTime: _startTime,
      endTime: completedAt,
      durationSeconds: _elapsedSeconds,
      targetDurationSeconds: _totalDurationSeconds,
      timerMode: _timerMode.asString,
      completed: true,
    );
    await _saveSession(session);

    await PersistenceService.clearActiveSession();

    notifyListeners();
  }

  Future<bool> hasActiveSession() async {
    final session = await PersistenceService.loadActiveSession();
    return session != null;
  }

  void reset({bool cancelAlarms = true}) {
    _delayTimer?.cancel();
    _delayTimer = null;
    _stopTick();
    if (cancelAlarms) {
      _alarmService.cancelAllAlarms();
    }
    _state = TimerState.idle;
    _elapsedSeconds = 0;
    _remainingSeconds = 0;
    _totalDurationSeconds = 0;
    _pauseDurationSeconds = 0;
    _delayRemainingSeconds = 0;
    _currentSessionId = null;
    _lastIntervalMinute = -1;
    _lastVibrationIntervalMinute = -1;
    _alarmFired = false;
    _sessionFinalized = false;
    _lastSessionCompletedNaturally = true;
    notifyListeners();
  }

  Future<void> stopSounds() async {
    // Completion keeps the native cue playing until the user leaves.
    // AudioService only owns Flutter playback, not the native alarm player.
    await _alarmService.cancelAllAlarms();
    await _audioService.stop();
    await _vibrationService.cancel();
  }

  /// Called when the alarm package fires (Alarm.ringing stream).
  /// The alarm package handles audio & vibration natively — just record completion.
  void onNativeAlarmFired(int requestCode) {
    debugPrint('TimerProvider: Native alarm fired with code $requestCode');

    final expectedCode = switch (_timerMode) {
      TimerMode.timed => 1001,
      TimerMode.endAt => 1002,
      TimerMode.unlimited => null,
    };
    if (_state == TimerState.running &&
        requestCode == expectedCode &&
        _endTime != null &&
        !_now().isBefore(_endTime!)) {
      _onSessionComplete(source: _CompletionSource.nativeAlarm);
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _delayTimer = null;
    _stopTick();
    _alarmService.cancelAllAlarms();
    super.dispose();
  }
}
