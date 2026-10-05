import 'dart:io';

import 'package:ekatimer/models/timer_mode.dart';
import 'package:ekatimer/providers/timer_provider.dart';
import 'package:ekatimer/services/persistence_service.dart';
import 'package:ekatimer/services/widget_action_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Timer extends TimerProvider {
  _Timer(this.currentState);
  TimerState currentState;
  int resets = 0;
  int starts = 0;
  int restores = 0;
  int? configuredDuration;
  Map<String, int>? restoredData;

  @override
  TimerState get state => currentState;
  @override
  void reset({bool cancelAlarms = true}) => resets++;
  @override
  Future<void> startSession() async {
    starts++;
  }

  @override
  Future<void> restoreSession(Map<String, int> data) async {
    restores++;
    restoredData = data;
  }

  @override
  void configure({
    TimerMode? mode,
    int? durationMinutes,
    int? endAtHour,
    int? endAtMinute,
  }) {
    configuredDuration = durationMinutes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final channel = MethodChannel(
    Platform.isAndroid
        ? 'org.tipitakapali.ekatimer/widget'
        : 'org.ekatimer.ios.gmlpub/widget',
  );
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  setUp(() async {
    await (await PersistenceService.prefs).clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'getWidgetAction'
              ? {'timerMode': 'timed', 'timerDuration': 15}
              : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<bool> tapWidget(WidgetTester tester, _Timer timer) async {
    late BuildContext context;
    await tester.pumpWidget(
      ChangeNotifierProvider<TimerProvider>.value(
        value: timer,
        child: MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return WidgetActionHandler.handleWidgetAction(context);
  }

  for (final state in [
    TimerState.running,
    TimerState.paused,
    TimerState.delaying,
  ]) {
    testWidgets('widget preserves a ${state.name} session', (tester) async {
      final timer = _Timer(state);
      expect(await tapWidget(tester, timer), isTrue);
      expect(timer.resets, 0);
      expect(timer.starts, 0);
      expect(timer.configuredDuration, isNull);
    });
  }

  testWidgets('widget restores persisted session instead of replacing it', (
    tester,
  ) async {
    await PersistenceService.saveActiveSession(
      startTime: 1000,
      durationSeconds: 5400,
      mode: 'timed',
      isPaused: true,
      pauseDuration: 50,
      endTime: 6400,
      profileId: 'default',
    );
    final timer = _Timer(TimerState.idle);
    expect(await tapWidget(tester, timer), isTrue);
    expect(timer.restores, 1);
    expect(timer.restoredData?['durationSeconds'], 5400);
    expect(timer.resets, 0);
    expect(timer.starts, 0);
  });

  testWidgets('widget starts requested duration when there is no session', (
    tester,
  ) async {
    final timer = _Timer(TimerState.idle);
    expect(await tapWidget(tester, timer), isTrue);
    expect(timer.starts, 1);
    expect(timer.configuredDuration, 15);
  });

  testWidgets('peeking preserves the alarm marker before action consumption', (
    tester,
  ) async {
    Map<String, dynamic>? pending = {
      'fromAlarm': true,
      'timerMode': 'timed',
      'timerDuration': 15,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final data = pending;
          if (call.method == 'getWidgetAction') pending = null;
          return data;
        });
    final marker = await WidgetActionHandler.getWidgetActionData();
    expect(marker?['fromAlarm'], isTrue);
    expect(pending, isNotNull);
    final timer = _Timer(TimerState.idle);
    expect(await tapWidget(tester, timer), isFalse);
    expect(pending, isNull);
    expect(timer.starts, 0);
    expect(timer.restores, 0);
    expect(marker?['fromAlarm'], isTrue);
  });
}
