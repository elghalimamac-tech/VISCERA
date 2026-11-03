import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/store.dart';
import 'package:viscera/screens/patient_archives.dart';

PatientCase _patient({CaseStage stage = CaseStage.discharged}) => PatientCase(
  id: 'TEST-ARCHIVES',
  name: 'PATIENT ARCHIVE TEST',
  age: '52', origin: 'Consultation', insurance: 'CNSS',
  motive: 'Essai', history: '', exam: '', investigations: '', labs: '',
  immediatePlan: '', procedure: 'CHOLECYSTECTOMIE LAPAROSCOPIQUE',
  blockTiming: 'Différé', admissionTiming: 'Immédiate',
  beforeUnit: 'TC1', beforeBox: '01',
  afterUnit: 'TC2', afterBox: '02',
  expectedDays: 2, blockAt: DateTime(2026, 11, 1),
  admittedAt: DateTime(2026, 11, 1),
  stage: stage,
);

void main() {
  test('Un patient sorti est archivé immédiatement et encore visible pendant 48 h', () {
    final departure = DateTime(2026, 11, 3, 9, 30);
    final patient = _patient()..dischargeAt = departure;
    expect(patient.isArchived, isTrue);
    expect(patient.isVisibleInServiceOn(departure), isTrue);
    expect(patient.isVisibleInServiceOn(
      departure.add(const Duration(hours: 47, minutes: 59))), isTrue);
    expect(patient.isVisibleInServiceOn(
      departure.add(const Duration(hours: 48))), isFalse);
    expect(patient.isVisibleInServiceOn(
      departure.add(const Duration(days: 10))), isFalse);
    expect(patient.stage, CaseStage.discharged);
    expect(patient.dischargeAt, departure);
  });

  test('Une sortie sans horodatage ne retourne pas dans les listes du service', () {
    final patient = _patient();
    expect(patient.isArchived, isTrue);
    expect(patient.isVisibleInServiceOn(DateTime(2026, 11, 3)), isFalse);
    patient.stage = CaseStage.postoperative;
    expect(patient.isArchived, isFalse);
    expect(patient.isVisibleInServiceOn(DateTime(2030)), isTrue);
  });

  testWidgets('Le menu Archives affiche les dossiers sortis et leur intervention',
      (tester) async {
    final archived = _patient()
      ..dischargeAt = DateTime(2026, 11, 2, 14);
    final active = _patient(stage: CaseStage.postoperative)
      ..name = 'PATIENT ACTIF TEST';
    appStore.patients.addAll([archived, active]);
    addTearDown(() {
      appStore.patients.remove(archived);
      appStore.patients.remove(active);
    });
    await tester.pumpWidget(
      const MaterialApp(home: PatientArchivesPage()));
    expect(find.byKey(const Key('archives-patient-list')), findsOneWidget);
    expect(find.text('PATIENT ARCHIVE TEST'), findsOneWidget);
    expect(find.text('CHOLECYSTECTOMIE LAPAROSCOPIQUE'), findsOneWidget);
    expect(find.text('PATIENT ACTIF TEST'), findsNothing);
    await tester.enterText(find.byKey(const Key('archives-search-field')),
      'aucun résultat');
    await tester.pumpAndSettle();
    expect(find.text('PATIENT ARCHIVE TEST'), findsNothing);
  });
}
