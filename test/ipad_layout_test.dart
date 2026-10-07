import 'package:ekatimer/models/meditation_session.dart';
import 'package:ekatimer/providers/session_provider.dart';
import 'package:ekatimer/providers/settings_provider.dart';
import 'package:ekatimer/providers/timer_provider.dart';
import 'package:ekatimer/screens/home_screen.dart';
import 'package:ekatimer/screens/settings_screen.dart';
import 'package:ekatimer/screens/stats_screen.dart';
import 'package:ekatimer/services/translation_service.dart';
import 'package:ekatimer/utils/responsive.dart';
import 'package:ekatimer/widgets/adaptive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Logical sizes of the devices the layouts are built for.
const _iPadLandscape = Size(1366, 1024);
const _iPadPortrait = Size(1024, 1366);
const _iPadMiniPortrait = Size(744, 1133);
const _phonePortrait = Size(390, 844);

class _Sessions extends SessionProvider {
  @override
  List<MeditationSession> get sessions => const [];
  @override
  Future<void> loadSessions({String? profileId}) async {}
  @override
  Future<List<WeeklyDataPoint>> getWeeklyData({int weeks = 8}) async => [];
  @override
  Future<List<MonthlyDataPoint>> getMonthlyData({int months = 12}) async => [];
  @override
  Future<List<YearlyDataPoint>> getYearlyData() async => [];
}

class _IdleTimer extends ChangeNotifier implements TimerProvider {
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

  group('WindowSize', () {
    test('classifies the widths the layouts switch on', () {
      expect(WindowSize.fromWidth(390), WindowSize.compact);
      expect(WindowSize.fromWidth(599.9), WindowSize.compact);
      expect(WindowSize.fromWidth(600), WindowSize.medium);
      expect(WindowSize.fromWidth(744), WindowSize.medium);
      expect(WindowSize.fromWidth(839.9), WindowSize.medium);
      expect(WindowSize.fromWidth(840), WindowSize.expanded);
      expect(WindowSize.fromWidth(1366), WindowSize.expanded);
    });

    test('only the expanded class splits into two panes', () {
      expect(WindowSize.compact.canSplit, isFalse);
      expect(WindowSize.medium.canSplit, isFalse);
      expect(WindowSize.expanded.canSplit, isTrue);
    });

    test('leaves phone widths unconstrained and caps the rest', () {
      expect(WindowSize.compact.contentMaxWidth, double.infinity);
      expect(WindowSize.medium.contentMaxWidth, lessThan(600));
      expect(WindowSize.expanded.contentMaxWidth, lessThan(700));
    });

    testWidgets('reads the width of the nearest MediaQuery', (tester) async {
      late WindowSize seen;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: _iPadLandscape),
          child: Builder(
            builder: (context) {
              seen = context.windowSize;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, WindowSize.expanded);
    });
  });

  /// Pumps [child] at [size], restoring the surface afterwards.
  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    Widget child, {
    TimerProvider? timer,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      TranslationService(
        translations: translations,
        locale: 'en',
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<TimerProvider>.value(
              value: timer ?? _IdleTimer(),
            ),
            ChangeNotifierProvider<SessionProvider>(create: (_) => _Sessions()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(home: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('home screen', () {
    testWidgets('keeps one column on a phone', (tester) async {
      await pumpAt(tester, _phonePortrait, const MeditationHomeScreen());

      expect(find.byType(TwoPaneLayout), findsNothing);
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps one column on an iPad mini in portrait', (tester) async {
      // 744pt is medium, not expanded: too narrow for two readable panes.
      await pumpAt(tester, _iPadMiniPortrait, const MeditationHomeScreen());

      expect(find.byType(TwoPaneLayout), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('splits on an iPad, with Start on screen', (tester) async {
      await pumpAt(tester, _iPadLandscape, const MeditationHomeScreen());

      expect(find.byType(TwoPaneLayout), findsOneWidget);
      // The point of the split: the picker and Start are both visible at once,
      // rather than Start sitting a screen below the fold.
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('caps the column width on a medium window', (tester) async {
      await pumpAt(tester, _iPadMiniPortrait, const MeditationHomeScreen());

      final column = tester.widget<ContentColumn>(
        find.byType(ContentColumn).first,
      );
      expect(column.maxWidth, isNull); // takes the window class's own limit
      final box = tester.renderObject<RenderBox>(find.byType(Slider));
      expect(box.size.width, lessThan(_iPadMiniPortrait.width));
      expect(tester.takeException(), isNull);
    });
  });

  group('settings screen', () {
    testWidgets('lists every section in one column on a phone', (tester) async {
      await pumpAt(tester, _phonePortrait, const SettingsScreen());

      expect(find.byType(TwoPaneLayout), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('puts the sections in a sidebar on an iPad', (tester) async {
      await pumpAt(tester, _iPadPortrait, const SettingsScreen());

      expect(find.byType(TwoPaneLayout), findsOneWidget);
      final sidebar = find.descendant(
        of: find.byType(ListView).first,
        matching: find.byType(ListTile),
      );
      expect(tester.widgetList<ListTile>(sidebar).length, 9);
      expect(tester.takeException(), isNull);
    });

    testWidgets('selecting a section moves the selection', (tester) async {
      await pumpAt(tester, _iPadPortrait, const SettingsScreen());

      final sidebar = find.descendant(
        of: find.byType(ListView).first,
        matching: find.byType(ListTile),
      );
      List<bool> selection() =>
          tester.widgetList<ListTile>(sidebar).map((t) => t.selected).toList();

      expect(selection().indexOf(true), 0);
      await tester.tap(sidebar.at(5));
      await tester.pumpAndSettle();

      expect(selection().indexOf(true), 5);
      expect(selection().where((selected) => selected).length, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('stats screen', () {
    testWidgets('keeps the tab strip on a phone', (tester) async {
      await pumpAt(tester, _phonePortrait, const StatsScreen());

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TwoPaneLayout), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trades the tab strip for a report sidebar on an iPad', (
      tester,
    ) async {
      await pumpAt(tester, _iPadLandscape, const StatsScreen());

      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(TwoPaneLayout), findsOneWidget);

      final sidebar = find.descendant(
        of: find.byType(ListView).first,
        matching: find.byType(ListTile),
      );
      expect(tester.widgetList<ListTile>(sidebar).length, 5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('choosing a report selects it', (tester) async {
      await pumpAt(tester, _iPadLandscape, const StatsScreen());

      final sidebar = find.descendant(
        of: find.byType(ListView).first,
        matching: find.byType(ListTile),
      );
      List<bool> selection() =>
          tester.widgetList<ListTile>(sidebar).map((t) => t.selected).toList();

      expect(selection().indexOf(true), 0);
      await tester.tap(sidebar.at(2));
      await tester.pumpAndSettle();

      expect(selection().indexOf(true), 2);
      expect(tester.takeException(), isNull);
    });
  });
}
