import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/screens/patient_detail.dart';

PatientCase examplePatient() => PatientCase(
  id:'BLOC-9999', name:'PATIENT DE TEST', age:'58',
  origin:'Consultation', insurance:'CNSS',
  motive:'Hospitalisation test', history:'', exam:'',
  investigations:'', labs:'', immediatePlan:'',
  procedure:'Cholécystectomie', blockTiming:'Différé',
  admissionTiming:'Confirmée', beforeUnit:'TC1', beforeBox:'02',
  afterUnit:'TC1', afterBox:'02', expectedDays:2,
  blockAt:DateTime(2026,11,5,8),
  admittedAt:DateTime(2026,11,5,7),
  fromBlocProgram:true, stage:CaseStage.preoperative,
);

void main() {
  testWidgets('Les scores ont un accès direct et un vrai formulaire visible',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390,780));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    final patient=examplePatient();
    await tester.pumpWidget(MaterialApp(home:PatientDetailPage(patient:patient)));
    final open=find.byKey(const Key('open-clinical-score-forms'));
    expect(open,findsOneWidget);
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clinical-score-forms-page')),findsOneWidget);
    expect(find.byKey(const Key('clinical-scores-tile')),findsOneWidget);
    expect(find.byKey(const Key('score-nrs2002')),findsOneWidget);
    expect(find.byKey(const ValueKey('nrs2002-nutrition')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Un patient actif dispose du formulaire de transfert vers un service',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390,780));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    final patient=examplePatient();
    await tester.pumpWidget(MaterialApp(home:PatientDetailPage(patient:patient)));
    final transfer=find.byKey(const Key('transfer-patient-service'));
    expect(transfer,findsOneWidget);
    await tester.ensureVisible(transfer);
    await tester.tap(transfer);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transfer-destination-service')),findsOneWidget);
    expect(find.byKey(const Key('transfer-destination-box')),findsOneWidget);
    expect(find.byKey(const Key('transfer-reason')),findsOneWidget);
    expect(find.byKey(const Key('confirm-service-transfer-form')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
