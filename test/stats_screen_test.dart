import 'package:ekatimer/models/meditation_session.dart';
import 'package:ekatimer/providers/session_provider.dart';
import 'package:ekatimer/providers/settings_provider.dart';
import 'package:ekatimer/screens/stats_screen.dart';
import 'package:ekatimer/services/translation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Sessions extends SessionProvider {
  _Sessions(this.records);
  final List<MeditationSession> records;
  @override
  List<MeditationSession> get sessions => records;
  @override
  Future<void> loadSessions({String? profileId}) async {}
  @override
  Future<List<WeeklyDataPoint>> getWeeklyData({int weeks = 8}) async => [];
  @override
  Future<List<MonthlyDataPoint>> getMonthlyData({int months = 12}) async => [];
  @override
  Future<List<YearlyDataPoint>> getYearlyData() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Map<String, String>> translations;
  setUpAll(
    () async => translations = await TranslationService.loadTranslations(),
  );

  Future<void> openSessions(
    WidgetTester tester,
    List<MeditationSession> sessions,
  ) async {
    await tester.pumpWidget(
      TranslationService(
        translations: translations,
        locale: 'en',
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionProvider>(
              create: (_) => _Sessions(sessions),
            ),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: const MaterialApp(home: StatsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(1);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'empty filtered history retains both date controls and can reveal older sessions',
    (tester) async {
      final now = DateUtils.dateOnly(DateTime.now());
      final oldDate = now.subtract(const Duration(days: 30));
      await openSessions(tester, [
        MeditationSession(id: 'old', startTime: oldDate, durationSeconds: 600),
      ]);
      final pickers = find.byIcon(Icons.calendar_today);
      expect(pickers, findsNWidgets(2));
      await tester.tap(pickers.first);
      await tester.pumpAndSettle();
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.firstDate, oldDate);
      // Return a selected date through the real dialog route, then verify the
      // history filter rebuilds rather than trapping the user in the empty view.
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop(oldDate);
      await tester.pumpAndSettle();
      expect(find.text('10m'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'From picker opens when the first session is newer than the default range',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      await openSessions(tester, [
        MeditationSession(id: 'first', startTime: today, durationSeconds: 600),
      ]);
      await tester.tap(find.byIcon(Icons.calendar_today).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.firstDate.isAfter(dialog.initialDate!), isFalse);
    },
  );
}
