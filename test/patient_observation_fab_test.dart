import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/screens/patient_detail.dart';
import 'package:viscera/store.dart';

void main() {
  testWidgets('Un dossier actif ouvre le formulaire depuis le bouton flottant',
      (tester) async {
    final patient = AppStore().patients.first;
    await tester.pumpWidget(MaterialApp(home: PatientDetailPage(patient: patient)));
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Observation clinique'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrer l’observation'), findsOneWidget);
  });
}
