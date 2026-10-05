import 'package:flutter_test/flutter_test.dart';
import 'package:ekatimer/app.dart';

void main() {
  testWidgets('Meditation Timer app initializes', (WidgetTester tester) async {
    await tester.pumpWidget(const MeditationTimerApp());
    // App shows splash screen on initialization
    expect(find.text('Meditation Timer'), findsOneWidget);
  });
}
