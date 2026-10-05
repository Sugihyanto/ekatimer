import 'package:ekatimer/models/meditation_session.dart';
import 'package:ekatimer/models/timer_mode.dart';
import 'package:ekatimer/providers/timer_provider.dart';
import 'package:ekatimer/services/alarm_service.dart';
import 'package:ekatimer/services/audio_service.dart';
import 'package:ekatimer/services/persistence_service.dart';
import 'package:ekatimer/services/vibration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Audio implements AudioService {
  final playedSounds = <String>[];
  int stopCount = 0;

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> playSound(String soundName) async {
    if (soundName.isNotEmpty && soundName != 'none') {
      playedSounds.add(soundName);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Vibration implements VibrationService {
  final patterns = <String>[];
  int cancelCount = 0;

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  Future<void> vibrate(String pattern) async {
    if (pattern.isNotEmpty && pattern != 'none') patterns.add(pattern);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Alarms implements AlarmService {
  final scheduled = <({int id, DateTime end})>[];
  int cancelAllCount = 0;
  bool ringing = false;

  @override
  Future<bool> scheduleEndAlarm({
    required int id,
    required DateTime dateTime,
    double volume = 0.8,
    String? assetAudioPath,
    bool vibrate = true,
  }) async {
    scheduled.add((id: id, end: dateTime));
    return true;
  }

  @override
  Future<void> cancelAlarm(int id) async {}
  @override
  Future<void> cancelAllAlarms() async {
    cancelAllCount++;
    ringing = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late _Audio audio;
  late _Vibration vibration;
  late _Alarms alarms;
  late List<MeditationSession> saved;
  late TimerProvider timer;

  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  setUp(() async {
    await (await PersistenceService.prefs).clear();
    now = DateTime(2026, 9, 7, 8);
    audio = _Audio();
    vibration = _Vibration();
    alarms = _Alarms();
    saved = [];
    timer = TimerProvider(
      audioService: audio,
      vibrationService: vibration,
      alarmService: alarms,
      now: () => now,
      saveSession: (session) async => saved.add(session),
    );
  });
  void testTimer(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        // Cancel periodic timers before the binding checks invariants.
        timer.dispose();
      }
    });
  }

  Future<void> restore({
    required TimerMode mode,
    bool paused = true,
    int duration = 600,
  }) async {
    final start = now.subtract(const Duration(minutes: 30));
    await PersistenceService.saveActiveSession(
      startTime: start.millisecondsSinceEpoch,
      durationSeconds: mode == TimerMode.unlimited ? 0 : duration,
      mode: mode.asString,
      isPaused: paused,
      pauseDuration: 0,
      endTime: mode == TimerMode.unlimited
          ? 0
          : start.add(Duration(seconds: duration)).millisecondsSinceEpoch,
      profileId: 'retreat',
      pauseStartTime: paused
          ? start.add(const Duration(minutes: 2)).millisecondsSinceEpoch
          : null,
    );
    await timer.restoreSession((await PersistenceService.loadActiveSession())!);
  }

  testTimer('preparation countdown does not consume timed meditation', (
    tester,
  ) async {
    timer.configure(durationMinutes: 10);
    timer.sessionDelaySeconds = 5;
    await timer.startSession();
    expect(timer.state, TimerState.delaying);
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(timer.state, TimerState.running);
    expect(timer.startTime, now);
    expect(timer.endTime, now.add(const Duration(minutes: 10)));
    expect(timer.remainingSeconds, 600);
    expect(timer.elapsedSeconds, 0);
    expect(alarms.scheduled.single.end, timer.endTime);
  });

  testTimer('skipping preparation starts a full session at the tap', (
    tester,
  ) async {
    timer.configure(durationMinutes: 1);
    timer.sessionDelaySeconds = 10;
    await timer.startSession();
    now = now.add(const Duration(seconds: 3));
    await timer.skipDelay();
    expect(timer.startTime, now);
    expect(timer.endTime, now.add(const Duration(minutes: 1)));
    await tester.pump(const Duration(seconds: 10));
    expect(alarms.scheduled, hasLength(1));
  });

  testTimer('End At excludes preparation without moving the clock target', (
    tester,
  ) async {
    timer.configure(mode: TimerMode.endAt, endAtHour: 8, endAtMinute: 1);
    timer.sessionDelaySeconds = 5;
    final target = now.add(const Duration(minutes: 1));
    await timer.startSession();
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(timer.state, TimerState.running);
    expect(timer.startTime, now);
    expect(timer.endTime, target);
    expect(timer.totalDurationSeconds, 55);
    expect(timer.remainingSeconds, 55);
    expect(timer.elapsedSeconds, 0);
    expect(alarms.scheduled.single.end, target);
  });

  testTimer('skipping End At preparation preserves the original target', (
    tester,
  ) async {
    timer.configure(mode: TimerMode.endAt, endAtHour: 8, endAtMinute: 1);
    timer.sessionDelaySeconds = 10;
    final target = now.add(const Duration(minutes: 1));
    await timer.startSession();
    now = now.add(const Duration(seconds: 3));
    await timer.skipDelay();
    expect(timer.startTime, now);
    expect(timer.endTime, target);
    expect(timer.totalDurationSeconds, 57);
    expect(alarms.scheduled.single.end, target);
  });

  for (final lateSeconds in [0, 3]) {
    testTimer('End At reached during preparation completes at midnight '
        '($lateSeconds seconds late)', (tester) async {
      now = DateTime(2026, 9, 7, 23, 59, 58);
      final target = DateTime(2026, 9, 8);
      timer.configure(mode: TimerMode.endAt, endAtHour: 0, endAtMinute: 0);
      timer.sessionDelaySeconds = 10;
      timer.startSound = 'Bowl';
      timer.startVibration = 'short';
      timer.endVibration = 'medium';
      await timer.startSession();
      expect(timer.endTime, target);
      now = target.add(Duration(seconds: lateSeconds));
      await tester.pump(Duration(seconds: 2 + lateSeconds));
      expect(timer.state, TimerState.completed);
      expect(timer.delayRemainingSeconds, 0);
      expect(timer.startTime, target);
      expect(timer.endTime, target);
      expect(timer.remainingSeconds, 0);
      expect(saved.single.startTime, target);
      expect(saved.single.endTime, target);
      expect(saved.single.durationSeconds, 0);
      expect(saved.single.targetDurationSeconds, 0);
      expect(alarms.scheduled, isEmpty);
      expect(alarms.cancelAllCount, 1);
      expect(audio.playedSounds, ['ThreeBowl']);
      expect(vibration.patterns, ['medium']);
      expect(await PersistenceService.loadActiveSession(), isNull);
    });
  }

  testTimer('restored Unlimited pause resumes without an end alarm', (
    tester,
  ) async {
    await restore(mode: TimerMode.unlimited);
    expect(timer.endTime, isNull);
    expect(timer.elapsedSeconds, 120);
    expect(timer.remainingSeconds, -1);
    await timer.resumeSession();
    expect(alarms.scheduled.single.id, 1003);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(timer.state, TimerState.running);
    expect(timer.elapsedSeconds, 121);
    timer.onNativeAlarmFired(1003);
    await tester.pump();
    expect(saved, isEmpty);
  });

  for (final mode in [TimerMode.timed, TimerMode.endAt]) {
    testTimer('restored paused ${mode.name} keeps the frozen countdown', (
      tester,
    ) async {
      await restore(mode: mode);
      expect(timer.state, TimerState.paused);
      expect(timer.remainingSeconds, 480);
      expect(timer.displayTime, '08:00');
      expect(timer.elapsedSeconds, 120);
      await timer.resumeSession();
      expect(timer.endTime, now.add(const Duration(minutes: 8)));
    });
  }

  testTimer('restored running End At initializes the remaining display', (
    tester,
  ) async {
    await restore(mode: TimerMode.endAt, paused: false, duration: 3600);
    expect(timer.remainingSeconds, 1800);
    expect(timer.displayTime, '30:00');
  });

  testTimer('expired restore records the scheduled end and original profile', (
    tester,
  ) async {
    alarms.ringing = true;
    await restore(mode: TimerMode.timed, paused: false);
    expect(saved, hasLength(1));
    expect(saved.single.endTime, now.subtract(const Duration(minutes: 20)));
    expect(saved.single.durationSeconds, 600);
    expect(saved.single.profileId, 'retreat');
    expect(timer.remainingSeconds, 0);
    expect(alarms.scheduled, isEmpty);
    expect(alarms.cancelAllCount, 1);
    expect(alarms.ringing, isFalse);
    expect(audio.playedSounds, isEmpty);
    expect(vibration.patterns, isEmpty);
    expect(await PersistenceService.loadActiveSession(), isNull);
  });

  testTimer('timer waits for the actual deadline and saves only once', (
    tester,
  ) async {
    timer.configure(durationMinutes: 1);
    timer.endVibration = 'medium';
    await timer.startSession();
    now = now.add(const Duration(milliseconds: 59999));
    await tester.pump(const Duration(milliseconds: 500));
    expect(timer.state, TimerState.running);
    expect(timer.remainingSeconds, 1);
    expect(saved, isEmpty);
    now = now.add(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    timer.onNativeAlarmFired(1001);
    await timer.stopSession(completed: false);
    expect(saved, hasLength(1));
    expect(saved.single.durationSeconds, 60);
    expect(saved.single.completed, isTrue);
    expect(alarms.cancelAllCount, 1);
    expect(audio.playedSounds, ['ThreeBowl']);
    expect(vibration.patterns, ['medium']);
  });

  for (final mode in [TimerMode.timed, TimerMode.endAt]) {
    testTimer('native ${mode.name} completion preserves its ringing bell', (
      tester,
    ) async {
      timer.configure(
        mode: mode,
        durationMinutes: 1,
        endAtHour: 8,
        endAtMinute: 1,
      );
      timer.endVibration = 'medium';
      await timer.startSession();
      now = timer.endTime!;
      alarms.ringing = true;
      final alarmId = mode == TimerMode.timed ? 1001 : 1002;
      timer.onNativeAlarmFired(alarmId);
      await tester.pump();
      expect(timer.state, TimerState.completed);
      expect(saved.single.endTime, now);
      expect(alarms.cancelAllCount, 0);
      expect(alarms.ringing, isTrue);
      expect(audio.playedSounds, isEmpty);
      expect(vibration.patterns, isEmpty);
      expect(await PersistenceService.loadActiveSession(), isNull);

      timer.onNativeAlarmFired(alarmId);
      await tester.pump(const Duration(seconds: 1));
      expect(saved, hasLength(1));
      expect(alarms.cancelAllCount, 0);
    });
  }

  testTimer('leaving completion stops native and Flutter cues after reset', (
    tester,
  ) async {
    timer.configure(durationMinutes: 1);
    await timer.startSession();
    now = timer.endTime!;
    alarms.ringing = true;
    timer.onNativeAlarmFired(1001);
    await tester.pump();
    timer.reset(cancelAlarms: false);
    expect(alarms.ringing, isTrue);
    await timer.stopSounds();
    expect(alarms.ringing, isFalse);
    expect(audio.stopCount, 1);
    expect(vibration.cancelCount, 1);
    expect(saved, hasLength(1));
  });

  testTimer('unrelated and stale native alarms cannot finish the session', (
    tester,
  ) async {
    timer.configure(durationMinutes: 1);
    await timer.startSession();
    timer.onNativeAlarmFired(1001);
    timer.onNativeAlarmFired(1002);
    timer.onNativeAlarmFired(1003);
    await tester.pump();
    expect(timer.state, TimerState.running);
    now = timer.endTime!;
    timer.onNativeAlarmFired(1002);
    expect(timer.state, TimerState.running);
    timer.onNativeAlarmFired(1001);
    await tester.pump();
    expect(timer.state, TimerState.completed);
    expect(saved, hasLength(1));
  });

  testTimer('stopping while paused excludes the pause from duration', (
    tester,
  ) async {
    await timer.startSession();
    now = now.add(const Duration(seconds: 90));
    await timer.pauseSession();
    now = now.add(const Duration(minutes: 10));
    await timer.stopSession(completed: false);
    expect(saved.single.durationSeconds, 90);
    expect(saved.single.endTime, now);
    expect(saved.single.completed, isFalse);
  });
}
