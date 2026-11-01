import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/screens/patient_detail.dart';
import 'package:viscera/models.dart';

void main() {
  testWidgets('Un dossier actif ouvre le formulaire depuis le bouton flottant',
      (tester) async {
    final patient = PatientCase(
      id: 'TEST-OBSERVATION', name: 'Patient de test', age: '45',
      origin: 'Consultation', insurance: 'À préciser', motive: 'Motif de test',
      history: '', exam: '', investigations: '', labs: '', immediatePlan: '',
      procedure: 'Intervention de test', blockTiming: 'Différé',
      admissionTiming: 'Immédiate', beforeUnit: 'TC1', beforeBox: '1',
      afterUnit: 'TC1', afterBox: '1', expectedDays: 1,
      blockAt: DateTime(2026, 11, 1), admittedAt: DateTime(2026, 11, 1),
    );
    await tester.pumpWidget(MaterialApp(home: PatientDetailPage(patient: patient)));
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Observation clinique'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrer l’observation'), findsOneWidget);
  });
}
