import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/screens/patient_detail.dart';

PatientCase dischargePatient({CaseStage stage = CaseStage.postoperative,
    DateTime? admittedAt, DateTime? blockAt,
    bool fromBlocProgram = false}) => PatientCase(
  id:'TEST-DISCHARGE', name:'PATIENT TEST', age:'52',
  origin:'Consultation', insurance:'CNSS',
  motive:'Motif à vérifier', history:'', exam:'',
  investigations:'', labs:'', immediatePlan:'',
  procedure:'Intervention de test', blockTiming:'Différé',
  admissionTiming:'Immédiate', beforeUnit:'TC1', beforeBox:'02',
  afterUnit:'TC2', afterBox:'06', expectedDays:2,
  blockAt:blockAt ?? DateTime(2026, 11, 1),
  admittedAt:admittedAt ?? DateTime(2026, 11, 1, 7),
  fromBlocProgram:fromBlocProgram,
  stage:stage,
);

void completeAllDocuments(PatientCase patient) {
  for (final requirement in ClinicalDocuments.discharge) {
    final doc=patient.check(requirement.key);
    if (requirement.optional) {
      doc.notApplicable=true;
    } else {
      doc.verified=true;
      doc.stamped=requirement.needsStamp ? true : null;
    }
  }
}

void main() {
  test('Sortie impossible en préopératoire et sans documents', () {
    final patient=dischargePatient(stage:CaseStage.preoperative);
    completeAllDocuments(patient);
    expect(patient.canDeclareDischarge,isFalse);
    patient.stage=CaseStage.postoperative;
    expect(patient.canDeclareDischarge,isTrue);
    patient.check('cro').stamped=false;
    expect(patient.canDeclareDischarge,isFalse);
    patient.check('cro').stamped=true;
    expect(patient.canDeclareDischarge,isTrue);
    patient.admittedAt=null;
    expect(patient.canDeclareDischarge,isFalse);
  });

  testWidgets('Boutons flottants sortie rouge et observation clinique',
      (tester) async {
    final patient=dischargePatient();
    await tester.pumpWidget(MaterialApp(
      home:PatientDetailPage(patient:patient),
    ));
    expect(find.byKey(const Key('declare-discharge-fab')),findsOneWidget);
    expect(find.text('Observation clinique'),findsOneWidget);

    final redButton=tester.widget<FloatingActionButton>(
      find.byKey(const Key('declare-discharge-fab')));
    expect(redButton.backgroundColor,const Color(0xFFB4232F));

    await tester.tap(find.byKey(const Key('declare-discharge-fab')));
    await tester.pumpAndSettle();
    expect(find.text('Vérification avant sortie'),findsOneWidget);
    expect(find.text('0 / 11 documents vérifiés'),findsOneWidget);
    expect(find.text('DATE D’ADMISSION'),findsOneWidget);
    expect(find.byKey(const Key('discharge-admission-date')),findsOneWidget);
    expect(find.text('01/11/2026'),findsOneWidget);
    expect(find.text('Intervention chirurgicale'),findsOneWidget);
    expect(find.byKey(const Key('discharge-procedure-label')),findsOneWidget);
    expect(find.text('Intervention de test'),findsOneWidget);
    final bulk=find.byKey(const Key('bulk-verify-discharge-documents'));
    expect(bulk,findsOneWidget);
    // Le bouton est dans le pied de la fenêtre, pas parmi les documents.
    expect(find.ancestor(of:bulk,matching:find.byType(ListView)),findsNothing);
    expect(tester.widget<FilledButton>(bulk).onPressed,isNotNull);
    final pending=tester.widget<FilledButton>(
      find.widgetWithText(FilledButton,'Déclarer la sortie et libérer le box'));
    expect(pending.onPressed,isNull);
    expect(patient.stage,CaseStage.postoperative);
    expect(patient.dischargeAt,isNull);
  });

  testWidgets('Validation médicale également exigée après documents',
      (tester) async {
    final patient=dischargePatient();
    completeAllDocuments(patient);
    await tester.pumpWidget(MaterialApp(home:PatientDetailPage(patient:patient)));
    await tester.tap(find.byKey(const Key('declare-discharge-fab')));
    await tester.pumpAndSettle();
    expect(find.text('11 / 11 documents vérifiés'),findsOneWidget);
    final confirm=find.widgetWithText(
      FilledButton,'Déclarer la sortie et libérer le box');
    expect(tester.widget<FilledButton>(confirm).onPressed,isNull);
    expect(patient.stage,CaseStage.postoperative);
  });


  testWidgets('Les boutons flottants ne recouvrent pas le bouton non admis',
      (tester) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final patient = dischargePatient(fromBlocProgram: true);
    await tester.pumpWidget(MaterialApp(
      home: PatientDetailPage(patient: patient),
    ));

    final exclusion = find.byKey(const Key('omit-program-admission'));
    final discharge = find.byKey(const Key('declare-discharge-fab'));
    final observation = find.widgetWithText(
      FloatingActionButton, 'Observation clinique');

    expect(discharge, findsOneWidget);
    expect(observation, findsOneWidget);

    // Atteindre le bas réel de l'écran sur un téléphone étroit.
    await tester.scrollUntilVisible(
      exclusion, 350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first,
      const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(exclusion, findsOneWidget);
    final omitRect = tester.getRect(exclusion);
    final dischargeRect = tester.getRect(discharge);
    final observationRect = tester.getRect(observation);
    expect(omitRect.bottom, lessThan(dischargeRect.top - 8));
    expect(omitRect.bottom, lessThan(observationRect.top - 8));
    expect(omitRect.top, greaterThan(0));
  });

  testWidgets('Pas de bouton rouge avant postopératoire',
      (tester) async {
    final patient=dischargePatient(stage:CaseStage.preoperative);
    await tester.pumpWidget(MaterialApp(home:PatientDetailPage(patient:patient)));
    expect(find.byKey(const Key('declare-discharge-fab')),findsNothing);
    expect(find.text('Observation clinique'),findsOneWidget);
  });
  testWidgets('Date d’admission : programme officiel prioritaire sur admittedAt',
      (tester) async {
    final patient = dischargePatient(
      blockAt: DateTime(2026, 10, 30, 7),
      admittedAt: DateTime(2026, 11, 2, 18),
      fromBlocProgram: true,
    );
    await tester.pumpWidget(MaterialApp(
      home: PatientDetailPage(patient: patient),
    ));
    await tester.tap(find.byKey(const Key('declare-discharge-fab')));
    await tester.pumpAndSettle();
    expect(find.text('30/10/2026'), findsOneWidget);
    expect(find.text('02/11/2026'), findsNothing);
    expect(find.text('Date du programme opératoire · admission de suivi'),
      findsOneWidget);
  });

  testWidgets('Date d’admission manuelle : admis réel, pas date du bloc',
      (tester) async {
    final patient = dischargePatient(
      blockAt: DateTime(2026, 11, 3),
      admittedAt: DateTime(2026, 11, 1, 8),
    );
    await tester.pumpWidget(MaterialApp(
      home: PatientDetailPage(patient: patient),
    ));
    await tester.tap(find.byKey(const Key('declare-discharge-fab')));
    await tester.pumpAndSettle();
    expect(find.text('01/11/2026'), findsOneWidget);
    expect(find.text('Date d’admission enregistrée'), findsOneWidget);
  });

}
