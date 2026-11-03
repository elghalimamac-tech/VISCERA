import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/bloc_clinical_record.dart';
import 'package:viscera/screens/patient_detail.dart';

PatientCase patientSample() => PatientCase(
  id: 'BLOC-818', name: 'PATIENT FICTIF', age: '52',
  origin: 'Consultation', insurance: 'CNSS',
  motive: 'Motif de test', history: '', exam: '',
  investigations: '', labs: '', immediatePlan: '',
  procedure: 'RESECTION COLORECTALE', blockTiming: 'Différé',
  admissionTiming: 'Confirmée', beforeUnit: 'TC1', beforeBox: '03',
  afterUnit: 'HDJM 0', afterBox: '0105', expectedDays: 4,
  blockAt: DateTime(2026, 11, 3, 7, 30),
  admittedAt: DateTime(2026, 11, 3),
  fromBlocProgram: true,
  stage: CaseStage.postoperative,
);

void main() {
  test('Correction clinique du type de chirurgie et de l’intervention conservée', () {
    final patient = patientSample();
    final original = patient.procedure;
    patient.procedureOverride = 'Résection sigmoïdienne laparoscopique';
    patient.surgeryType = 'Chirurgie colorectale laparoscopique';

    final stored = BlocClinicalRecordService.encode(patient);
    final reloaded = patientSample();
    BlocClinicalRecordService.apply(reloaded, stored, 2);
    expect(reloaded.procedure, original);
    expect(reloaded.effectiveProcedure, 'Résection sigmoïdienne laparoscopique');
    expect(reloaded.standardizedSurgeryType, 'Chirurgie colorectale laparoscopique');
    expect(reloaded.clinicalVersion, 2);
  });

  test('Ancien dossier : intitulé original conservé sans correction', () {
    final p = patientSample();
    final data = BlocClinicalRecordService.encode(p)
      ..remove('procedureOverride');
    final restored = patientSample();
    BlocClinicalRecordService.apply(restored, data, 1);
    expect(restored.effectiveProcedure, 'RESECTION COLORECTALE');
    expect(restored.procedureOverride, isEmpty);
  });

  testWidgets('La modification de chirurgie est disponible sur le dossier',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final patient = patientSample();
    await tester.pumpWidget(MaterialApp(home:PatientDetailPage(patient:patient)));

    final edit=find.byKey(const Key('edit-surgery-details'));
    await tester.scrollUntilVisible(edit, 450,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('Modifier la chirurgie'), findsOneWidget);
    expect(find.byKey(const Key('surgery-type-input')), findsOneWidget);
    expect(find.byKey(const Key('procedure-correction-input')), findsOneWidget);
    expect(find.byKey(const Key('save-surgery-details')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Le bouton de sauvegarde du box reste visible sur Android',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final patient = patientSample();
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390,780),
          viewPadding: EdgeInsets.only(bottom:36),
          padding: EdgeInsets.only(bottom:36),
        ),
        child: PatientDetailPage(patient:patient),
      ),
    ));
    final edit=find.text('Modifier l’affectation');
    await tester.scrollUntilVisible(edit, 400,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(edit);
    await tester.pumpAndSettle();

    expect(find.text('Modifier l’unité postopératoire'), findsOneWidget);
    final save = find.byKey(const Key('save-bed-assignment'));
    expect(save, findsOneWidget);
    expect(tester.getBottomLeft(save).dy, lessThan(746),
      reason: 'Le bouton doit rester au-dessus de la barre système Android.');
    expect(tester.takeException(), isNull);
  });
}
