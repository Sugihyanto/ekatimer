import 'package:ekatimer/models/meditation_session.dart';
import 'package:ekatimer/services/translation_service.dart';
import 'package:ekatimer/widgets/edit_session_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openEditor(
    WidgetTester tester,
    MeditationSession session,
    ValueChanged<MeditationSession?> onResult,
  ) async {
    await tester.pumpWidget(
      TranslationService(
        translations: const {
          'en': {
            'common.save': 'Save',
            'common.cancel': 'Cancel',
            'editSession.title': 'Edit Session',
          },
        },
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async =>
                      onResult(await showEditSessionDialog(context, session)),
                  child: const Text('Edit'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'editing notes preserves paused-session timestamps and precision',
    (tester) async {
      final start = DateTime(2026, 9, 1, 8, 0, 0, 123);
      final end = start.add(const Duration(minutes: 20));
      final session = MeditationSession(
        id: 'paused',
        startTime: start,
        endTime: end,
        durationSeconds: 600,
        quality: '3.5',
        notes: 'Original',
      );
      MeditationSession? result;
      await openEditor(tester, session, (value) => result = value);
      await tester.enterText(find.byType(TextField).last, 'Corrected note');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result!.notes, 'Corrected note');
      expect(result!.quality, '3.5');
      expect(result!.startTime, start);
      expect(result!.endTime, end);
      expect(result!.durationSeconds, 600);
    },
  );

  testWidgets('metadata-only save keeps a missing legacy end timestamp', (
    tester,
  ) async {
    MeditationSession? result;
    await openEditor(
      tester,
      MeditationSession(
        id: 'legacy',
        startTime: DateTime(2026, 9, 1, 8),
        durationSeconds: 60,
      ),
      (value) => result = value,
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result!.endTime, isNull);
  });

  for (final date in [
    DateTime(1995, 1, 1),
    DateTime(2100, 1, 1),
    DateTime(2026, 9, 1),
  ]) {
    testWidgets(
      'date picker opens for ${date.year} and permits earlier correction',
      (tester) async {
        await openEditor(
          tester,
          MeditationSession(
            id: 'imported',
            startTime: date,
            durationSeconds: 60,
          ),
          (_) {},
        );
        await tester.tap(find.byIcon(Icons.calendar_today));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final picker = tester.widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        );
        expect(picker.firstDate.isAfter(date), isFalse);
        expect(picker.lastDate.isBefore(date), isFalse);
        if (date.year >= 2000) expect(picker.firstDate.isBefore(date), isTrue);
      },
    );
  }
}
