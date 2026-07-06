import 'package:flutter_test/flutter_test.dart';
import 'package:weddingapp/app.dart';

void main() {
  testWidgets('Wedding app shows splash then login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WeddingApp());

    expect(find.text('PASSPORT'), findsOneWidget);
    expect(find.text('Aija & Abhi'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Welcome aboard'), findsOneWidget);
    expect(find.text('Enter Wedding App'), findsOneWidget);
  });
}
