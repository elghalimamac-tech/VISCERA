import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/patient_card.dart';

PatientCase patientCardFixture({
  CaseStage stage = CaseStage.postoperative,
  String box = '12',
}) => PatientCase(
  id:'CARD-100', name:'PATIENT FICTIF TEST',
  age:'64', origin:'Consultation', insurance:'CNSS',
  motive:'Douleur abdominale', history:'', exam:'',
  investigations:'', labs:'', immediatePlan:'',
  procedure:'Colectomie laparoscopique', blockTiming:'Différé',
  admissionTiming:'Confirmée', beforeUnit:'TC1', beforeBox:'07',
  afterUnit:'TC2', afterBox:box, expectedDays:4,
  blockAt:DateTime(2026,11,4), admittedAt:DateTime(2026,11,4),
  stage:stage, fromManualAdmission:true,
);

void main() {
  testWidgets('Chaque patient a une carte lisible et ouvrable sur mobile étroit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var tapped = 0;
    final patient = patientCardFixture();
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:Padding(
        padding:const EdgeInsets.all(12),
        child:PatientCard(patient:patient,onTap:()=>tapped++),
      )),
    )));
    expect(find.byKey(const Key('patient-card-CARD-100')),findsOneWidget);
    expect(find.text('PATIENT FICTIF TEST'),findsOneWidget);
    expect(find.text('Colectomie laparoscopique'),findsOneWidget);
    expect(find.text('Box 12'),findsOneWidget);
    expect(find.text('Box 07'),findsNothing,
        reason:'Un seul box courant doit apparaître.');
    expect(tester.takeException(),isNull);
    await tester.tap(find.byKey(const Key('patient-card-CARD-100')));
    expect(tapped,1);
  });

  testWidgets('La carte respecte la situation actuelle sans inventer un box',
      (tester) async {
    final patient = patientCardFixture(
      stage:CaseStage.preoperative, box:'',
    )..beforeUnit=''..beforeBox=''..age='—';
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:ListView(children:[PatientCard(patient:patient,onTap:() {})]),
    )));
    expect(find.text('Préopératoire'),findsOneWidget);
    expect(find.textContaining('Box '),findsNothing);
    expect(find.text('— ans'),findsNothing);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Urgences et réévaluation sortie ont un indicateur clair',
      (tester) async {
    final patient = patientCardFixture(
      stage:CaseStage.dischargeReady,
    );
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:ListView(children:[PatientCard(patient:patient,onTap:() {})]),
    )));
    expect(find.text('Sortie à valider'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
