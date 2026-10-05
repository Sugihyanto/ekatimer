import 'dart:io';
import 'dart:ui' as ui;

import 'package:ekatimer/services/translation_service.dart';
import 'package:ekatimer/widgets/session_card.dart';
import 'package:ekatimer/widgets/timer_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final fontDir = Platform.environment['EKATIMER_QC_FONT_DIR'];
    if (fontDir == null) return;
    for (final font in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(font.key);
      loader.addFont(
        File(
          '$fontDir/${font.value}',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    }
  });
  Widget app(Widget child, {double textScale = 2}) => TranslationService(
    translations: const {
      'en': {'history.stopped': 'Stopped', 'meditation.paused': 'PAUSED'},
    },
    locale: 'en',
    child: MaterialApp(
      theme: ThemeData(
        fontFamily: Platform.environment.containsKey('EKATIMER_QC_FONT_DIR')
            ? 'Roboto'
            : null,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );

  testWidgets(
    'session duration and Quality fit a narrow screen with large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 750));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final boundaryKey = GlobalKey();
      var edits = 0;
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: boundaryKey,
            child: SingleChildScrollView(
              child: SessionCard(
                id: 'long-session',
                startTime: DateTime(2026, 9, 7, 8),
                durationSeconds: 13 * 3600 + 25 * 60,
                completed: false,
                quality: '3.5',
                notes: 'A complete note remains readable on a small screen.',
                onEdit: () => edits++,
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('13h 25m'), findsOneWidget);
      expect(find.text('3.5'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('session-edit-button')));
      expect(edits, 1);
      await _capture(tester, boundaryKey, 'session-card-large-text');
    },
  );

  testWidgets('paused timer contents fit a small landscape circle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      app(
        Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: const TimerDisplay(
              timeText: '12:34:56',
              subtitleLabel: 'Elapsed',
              subtitleValue: '11:22:33',
              size: 160,
              isPaused: true,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, boundaryKey, 'paused-timer-large-text');
  });
}

// Opt-in visual evidence; normal test runs do not write image files.
Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!Platform.environment.containsKey('EKATIMER_QC_SCREENSHOTS')) return;
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/qc/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
