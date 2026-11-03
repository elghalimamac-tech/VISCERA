import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/screens/auth_gate.dart';

void main() {
  testWidgets('Le rappel de spam est lisible sur écran Android étroit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(20),
          child: AuthEmailSpamReminder(),
        ),
      ),
    ));
    expect(find.textContaining('Vérifier vos spams.'), findsOneWidget);
    expect(find.textContaining('Courrier indésirable'), findsOneWidget);
    expect(find.byKey(const Key('auth-spam-reminder')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
