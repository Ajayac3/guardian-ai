import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_app/app.dart';

void main() {
  testWidgets('app shell renders SOS and disclosures', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GuardianApp()));
    await tester.pumpAndSettle();

    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('Guardian AI'), findsWidgets);
    expect(
      find.textContaining('NOT an emergency-service dispatch'),
      findsOneWidget,
    );
  });

  testWidgets('tapping SOS shows the recording indicator', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GuardianApp()));
    await tester.pumpAndSettle();

    expect(find.text('ACTIVE'), findsNothing);
    await tester.tap(find.text('SOS'));
    await tester.pump();

    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.textContaining('emergency session active'), findsOneWidget);
  });
}
