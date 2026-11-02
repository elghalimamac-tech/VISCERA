import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/bloc_clinical_record.dart';
import 'package:viscera/preoperative_readiness.dart';

PatientCase sample({DateTime? blockAt,CaseStage stage=CaseStage.scheduled})=>
  PatientCase(
    id:'BLOC-TEST',name:'Dossier fictif',age:'—',origin:'Consultation',
    insurance:'À préciser',motive:'',history:'',exam:'',investigations:'',
    labs:'',immediatePlan:'',procedure:'LV',blockTiming:'Différé',
    admissionTiming:'À confirmer',beforeUnit:'',beforeBox:'',
    afterUnit:'',afterBox:'',expectedDays:1,
    blockAt:blockAt??DateTime(2026,11,2),stage:stage,
    fromBlocProgram:true,
  );

void main(){
  test('Jour de bloc : rubrique postop à confirmer, sans admission inventée',(){
    final p=sample();
    expect(p.isPostopReviewDay(DateTime(2026,11,2,7)),isTrue);
    expect(p.admittedAt,isNull);
    expect(p.stage,CaseStage.scheduled);
    expect(p.physicallyAdmitted,isFalse);
    expect(p.isPostopReviewDay(DateTime(2026,11,3)),isFalse);
    p.stage=CaseStage.postoperative;
    expect(p.isPostopReviewDay(DateTime(2026,11,2)),isFalse);
  });
  test('CPA, bilans et ordonnance facultative sauvegardés et relus',(){
    final p=sample();
    expect(p.cpaStatus,'a_verifier');
    expect(p.preopLabStatus,'a_verifier');
    expect(p.admissionPrescriptionStatus,'a_verifier');
    p.cpaStatus='ok';
    p.preopLabStatus='a_faire';
    p.admissionPrescriptionStatus='oui';
    p.admissionPrescriptionDetails='Note de test sans prescription réelle';
    final data=BlocClinicalRecordService.encode(p);
    final restored=sample();
    BlocClinicalRecordService.apply(restored,data,1);
    expect(restored.cpaStatus,'ok');
    expect(restored.preopLabStatus,'a_faire');
    expect(restored.admissionPrescriptionStatus,'oui');
    expect(restored.admissionPrescriptionDetails,p.admissionPrescriptionDetails);
    expect(restored.admittedAt,isNull);
  });
  testWidgets('Formulaire préop avec champ ordonnance facultatif',(tester)async{
    final p=sample();
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:PreoperativeReadinessCard(
        patient:p,onChanged:(){},
      )),
    )));
    expect(find.text('CPA : accord anesthésique obtenu ?'),findsOneWidget);
    expect(find.text('Bilans préopératoires'),findsOneWidget);
    await tester.tap(find.text('Oui'));
    await tester.pumpAndSettle();
    expect(p.admissionPrescriptionStatus,'oui');
    expect(find.text('Que prescrire ? (facultatif)'),findsOneWidget);
  });
}
