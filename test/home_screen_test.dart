import 'dart:async';

import 'package:ekatimer/providers/settings_provider.dart';
import 'package:ekatimer/providers/timer_provider.dart';
import 'package:ekatimer/screens/home_screen.dart';
import 'package:ekatimer/services/translation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StartingTimer extends ChangeNotifier implements TimerProvider {
  int starts = 0;
  final started = Completer<void>();
  @override
  Future<void> startSession() {
    starts++;
    return started.future;
  }

  // Home configures sounds and duration; this fake holds startup pending to
  // reproduce a second tap while native alarm/audio setup is still busy.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Map<String, String>> translations;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    translations = await TranslationService.loadTranslations();
  });

  testWidgets('minus and plus step the duration slider by one minute', (
    tester,
  ) async {
    final timer = _StartingTimer();
    await tester.pumpWidget(
      TranslationService(
        translations: translations,
        locale: 'en',
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<TimerProvider>.value(value: timer),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: const MaterialApp(home: MeditationHomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    double sliderValue() => tester.widget<Slider>(find.byType(Slider)).value;
    final start = sliderValue();
    final plus = find.byTooltip('Plus 1 minute');
    final minus = find.byTooltip('Minus 1 minute');

    await tester.ensureVisible(plus);
    await tester.tap(plus);
    await tester.pump();
    expect(sliderValue(), start + 1);

    await tester.tap(minus);
    await tester.tap(minus);
    await tester.pump();
    expect(sliderValue(), start - 1);

    await tester.pumpWidget(const SizedBox());
    timer.dispose();
  });

  testWidgets('rapid Start taps only begin one session', (tester) async {
    final timer = _StartingTimer();
    await tester.pumpWidget(
      TranslationService(
        translations: translations,
        locale: 'en',
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<TimerProvider>.value(value: timer),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: const MaterialApp(home: MeditationHomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final start = find.byIcon(Icons.play_arrow_rounded);
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.tap(start);
    expect(timer.starts, 1);
    await tester.pumpWidget(const SizedBox());
    timer.started.complete();
    await tester.pump();
    timer.dispose();
    expect(tester.takeException(), isNull);
  });
}
