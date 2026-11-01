import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/screens/patient_detail.dart';

PatientCase dischargePatient({CaseStage stage = CaseStage.postoperative,
    DateTime? admittedAt}) => PatientCase(
  id:'TEST-DISCHARGE', name:'PATIENT TEST', age:'52',
  origin:'Consultation', insurance:'CNSS',
  motive:'Motif à vérifier', history:'', exam:'',
  investigations:'', labs:'', immediatePlan:'',
  procedure:'Intervention de test', blockTiming:'Différé',
  admissionTiming:'Immédiate', beforeUnit:'TC1', beforeBox:'02',
  afterUnit:'TC2', afterBox:'06', expectedDays:2,
  blockAt:DateTime(2026, 11, 1),
  admittedAt:admittedAt ?? DateTime(2026, 11, 1, 7),
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

  testWidgets('Pas de bouton rouge avant postopératoire',
      (tester) async {
    final patient=dischargePatient(stage:CaseStage.preoperative);
    await tester.pumpWidget(MaterialApp(home:PatientDetailPage(patient:patient)));
    expect(find.byKey(const Key('declare-discharge-fab')),findsNothing);
    expect(find.text('Observation clinique'),findsOneWidget);
  });
}
