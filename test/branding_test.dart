import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/branding.dart';

void main() {
  testWidgets('Marque VISCERA commune à tous les écrans', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            VisceraBrandLockup(),
            VisceraPageTitle('Dossier patient'),
            VisceraMark(onDark: true),
          ],
        ),
      ),
    ));
    expect(find.text('VISCERA'), findsOneWidget);
    expect(find.text('Dossier patient'), findsOneWidget);
    expect(find.byType(VisceraMark), findsNWidgets(3));
  });
}
