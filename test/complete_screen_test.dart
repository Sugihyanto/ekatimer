import 'package:ekatimer/models/meditation_session.dart';
import 'package:ekatimer/providers/session_provider.dart';
import 'package:ekatimer/providers/settings_provider.dart';
import 'package:ekatimer/providers/timer_provider.dart';
import 'package:ekatimer/screens/complete_screen.dart';
import 'package:ekatimer/services/translation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Timer extends ChangeNotifier implements TimerProvider {
  int stopCount = 0;
  @override
  Future<void> stopSounds() async {
    stopCount++;
  }

  @override
  void reset({bool cancelAlarms = true}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends SettingsProvider {
  @override
  bool get showQuotes => false;
}

class _Sessions extends SessionProvider {
  MeditationSession session = MeditationSession(
    id: 'complete',
    startTime: DateTime(2026, 9, 7, 8),
    durationSeconds: 600,
  );
  @override
  List<MeditationSession> get sessions => [session];
  @override
  Future<void> updateSession(MeditationSession value) async {
    session = value;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Map<String, String>> translations;
  setUpAll(() async {
    translations = await TranslationService.loadTranslations();
  });
  for (final systemBack in [true, false]) {
    testWidgets(
      'completion saves and stops cues on ${systemBack ? "system back" : "home button"}',
      (tester) async {
        final timer = _Timer();
        final sessions = _Sessions();
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          TranslationService(
            translations: translations,
            locale: 'en',
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<TimerProvider>.value(value: timer),
                ChangeNotifierProvider<SettingsProvider>(
                  create: (_) => _Settings(),
                ),
                ChangeNotifierProvider<SessionProvider>.value(value: sessions),
              ],
              child: MaterialApp(
                navigatorKey: navigator,
                home: const Scaffold(body: Text('QC home')),
              ),
            ),
          ),
        );
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const CompleteScreen(
              durationSeconds: 600,
              sessionId: 'complete',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('quality-number-input')),
          '4.5',
        );
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          final button = find.text('Back to Home');
          await tester.ensureVisible(button);
          await tester.tap(button);
        }
        await tester.pumpAndSettle();
        expect(find.text('QC home'), findsOneWidget);
        expect(sessions.session.quality, '4.5');
        expect(timer.stopCount, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        sessions.dispose();
        timer.dispose();
      },
    );
  }
  testWidgets('completion duration refreshes after editing the saved session', (
    tester,
  ) async {
    final sessions = _Sessions();
    await tester.pumpWidget(
      TranslationService(
        translations: translations,
        locale: 'en',
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<TimerProvider>(create: (_) => _Timer()),
            ChangeNotifierProvider<SettingsProvider>(
              create: (_) => _Settings(),
            ),
            ChangeNotifierProvider<SessionProvider>.value(value: sessions),
          ],
          child: const MaterialApp(
            home: CompleteScreen(durationSeconds: 600, sessionId: 'complete'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('10:00'), findsOneWidget);
    final edit = find.text(translations['en']!['editSession.title']!);
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    // Exercise the actual route result and persistence callback for a new duration.
    final sheetContext = tester.element(find.byType(BottomSheet));
    Navigator.of(
      sheetContext,
    ).pop(sessions.session.copyWith(durationSeconds: 1200));
    await tester.pumpAndSettle();
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('10:00'), findsNothing);
    expect(sessions.session.durationSeconds, 1200);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    sessions.dispose();
  });
}
