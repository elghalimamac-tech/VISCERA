import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/biological_followup.dart';
import 'package:viscera/screens/lab_results_page.dart';
import 'package:viscera/screens/clinical_scores_page.dart';
import 'package:viscera/clinical_scores.dart';
import 'package:viscera/clinical_score_specs.dart';

PatientCase patientForLabs() => PatientCase(
  id: 'BLOC-919', name: 'PATIENT FICTIF', age: '67',
  origin: 'Consultation', insurance: 'CNSS',
  motive: 'Chirurgie programmée', history: '', exam: '',
  investigations: '', labs: '', immediatePlan: '',
  procedure: 'Colectomie gauche', blockTiming: 'Différé',
  admissionTiming: 'Confirmée', beforeUnit: 'TC1', beforeBox: '01',
  afterUnit: 'TC1', afterBox: '01',
  expectedDays: 4, blockAt: DateTime(2026, 11, 5, 10),
  admittedAt: DateTime(2026, 11, 5, 7),
  fromBlocProgram: true, stage: CaseStage.preoperative,
);

void main() {
  testWidgets('La page expose la CRP et chacun des bilans avec une saisie distincte',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final patient = patientForLabs();
    await tester.pumpWidget(MaterialApp(home: LabResultsPage(patient: patient)));
    expect(find.byKey(const Key('lab-results-form')), findsOneWidget);
    expect(find.byKey(const Key('lab-result-crp')), findsOneWidget);
    expect(find.byKey(const Key('lab-result-wbc')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('lab-result-creatinine')), 280,
      scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('lab-result-creatinine')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('lab-result-idealWeightKg')), 280,
      scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('lab-result-idealWeightKg')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Accès aux bilans depuis les scores cliniques',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final patient = patientForLabs();
    await tester.pumpWidget(MaterialApp(
      home: ClinicalScoresPage(patient: patient)));
    final open = find.byKey(const Key('open-labs-from-scores'));
    expect(open, findsOneWidget);
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lab-results-form')), findsOneWidget);
    expect(find.byKey(const Key('lab-result-crp')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Le formulaire ARISCAT propose Hb préop et celui de RCRI créatinine',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final patient = patientForLabs();
    patient.dailyObservations.add(DailyObservation(
      date: DateTime(2026, 11, 5),
      biology: {'hb': 8.7, 'creatinine': 190, 'crp': 160, 'wbc': 16},
    ));
    final ariscat = clinicalScoreSpecs.singleWhere((x) => x.id == 'ariscat');
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: ClinicalScoreForm(
        patient: patient, spec: ariscat, initiallyExpanded: true,
      )),
    )));
    expect(find.textContaining('Hémoglobine préopératoire :'), findsOneWidget);
    expect(find.textContaining('8.7 g/dL'), findsOneWidget);

    final rcri = clinicalScoreSpecs.singleWhere((x) => x.id == 'rcri');
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: ClinicalScoreForm(
        patient: patient, spec: rcri, initiallyExpanded: true,
      )),
    )));
    expect(find.textContaining('Créatinine préopératoire'), findsOneWidget);
    expect(find.textContaining('21.493 mg/L'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bilans historiques : valeur stockée convertie à l affichage',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final patient = patientForLabs();
    patient.dailyObservations.add(DailyObservation(
      date: DateTime.now(),
      biology: {'creatinine': 176.8, 'bilirubin': 17.104,
        'lymphocytes': 1.2, 'platelets': 230},
    ));
    await tester.pumpWidget(MaterialApp(home: LabResultsPage(patient:patient)));
    await tester.scrollUntilVisible(find.byKey(const Key('lab-result-creatinine')),
      280, scrollable:find.byType(Scrollable).first);
    final creat= tester.widget<TextFormField>(
      find.byKey(const Key('lab-result-creatinine')));
    expect(creat.controller!.text, '20');
    await tester.scrollUntilVisible(find.byKey(const Key('lab-result-bilirubin')),
      280, scrollable:find.byType(Scrollable).first);
    final bilirubin=tester.widget<TextFormField>(
      find.byKey(const Key('lab-result-bilirubin')));
    expect(bilirubin.controller!.text, '10');
  });

  test('L’absence de CRP bloque le mDULK et les valeurs saisies restent datées', () {
    final patient = patientForLabs();
    expect(labSeries(patient, 'crp'), isEmpty);
    patient.dailyObservations.add(DailyObservation(
      date: DateTime(2026, 11, 5),
      biology: {'crp': 120, 'wbc': 11.2, 'albumin': 32},
    ));
    expect(labSeries(patient, 'crp').single.value, 120);
    expect(labSeries(patient, 'wbc').single.value, 11.2);
  });
}
