import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/widgets.dart';

PatientCase caseForTest({
  DateTime? programme,
  DateTime? admitted,
  DateTime? consultation,
  bool fromProgramme = false,
  CaseStage stage = CaseStage.preoperative,
  DateTime? discharged,
}) => PatientCase(
  id:'TEST-JOUR', name:'DOSSIER FICTIF',
  age:'45',origin:'Consultation',insurance:'À préciser',
  motive:'Observation fictive',history:'',exam:'',investigations:'',
  labs:'',immediatePlan:'',procedure:'Intervention',blockTiming:'Différé',
  admissionTiming:fromProgramme?'Admission automatique · programme opératoire':'Confirmée',
  beforeUnit:'',beforeBox:'',afterUnit:'',afterBox:'',
  expectedDays:4,blockAt:programme??DateTime(2026,11,2,8),
  admittedAt:admitted,consultationAt:consultation,
  fromBlocProgram:fromProgramme,fromManualAdmission:!fromProgramme,
  stage:stage,dischargeAt:discharged,
);

void main() {
  test('Import programme : jour opératoire = J1, même si import avant', () {
    final p=caseForTest(fromProgramme:true,
      programme:DateTime(2026,11,5,19));
    expect(p.hospitalizationStartDate,DateTime(2026,11,5));
    expect(p.hospitalizationDayOn(DateTime(2026,11,4,23,59)),isNull);
    expect(p.hospitalizationDayOn(DateTime(2026,11,5,0,0)),1);
    expect(p.hospitalizationDayOn(DateTime(2026,11,5,23,59)),1);
    expect(p.hospitalizationDayOn(DateTime(2026,11,6,0,0)),2);
    expect(p.hospitalizationDayOn(DateTime(2026,11,8,15)),4);
  });

  test('Programme : la date source prévaut sur une date d admission différente',(){
    final p=caseForTest(fromProgramme:true,
      programme:DateTime(2026,11,2,8),admitted:DateTime(2026,11,1,16));
    expect(p.hospitalizationDayOn(DateTime(2026,11,2,19)),1);
    expect(p.hospitalizationStartDate,DateTime(2026,11,2));
  });

  test('Admission urgences : J1 = date réelle, même si admission 23h59',(){
    final p=caseForTest(admitted:DateTime(2026,11,2,23,59),
      programme:DateTime(2026,11,6,10));
    expect(p.hospitalizationStartDate,DateTime(2026,11,2));
    expect(p.hospitalizationDayOn(DateTime(2026,11,2,23,59)),1);
    expect(p.hospitalizationDayOn(DateTime(2026,11,3,0,0)),2);
  });

  test('Consultation : J1 = date admission, pas la consultation ni le bloc',(){
    final p=caseForTest(
      consultation:DateTime(2026,10,28,11),
      admitted:DateTime(2026,11,3,16),
      programme:DateTime(2026,11,5,8));
    expect(p.hospitalizationStartDate,DateTime(2026,11,3));
    expect(p.hospitalizationDayOn(DateTime(2026,11,3,19)),1);
    expect(p.hospitalizationDayOn(DateTime(2026,11,4,10)),2);
  });

  test('Consultation programmée sans arrivée confirmée : pas de faux J1',(){
    final p=caseForTest(
      stage:CaseStage.scheduled,
      consultation:DateTime(2026,10,29,11),
      programme:DateTime(2026,11,5,8));
    expect(p.hospitalizationStartDate,isNull);
    expect(p.hospitalizationDayOn(DateTime(2026,11,6)),isNull);
  });

  test('Différence en jours civils : mois, année et année bissextile',(){
    final p=caseForTest(admitted:DateTime(2024,2,28,23,59));
    expect(p.hospitalizationDayOn(DateTime(2024,2,29,9)),2);
    expect(p.hospitalizationDayOn(DateTime(2024,3,1,10)),3);
    final year=caseForTest(admitted:DateTime(2026,12,31,21));
    expect(year.hospitalizationDayOn(DateTime(2027,1,1,1)),2);
  });

  test('Sortie validée : le compteur se fige à J3',(){
    final p=caseForTest(admitted:DateTime(2026,11,2,14),
      stage:CaseStage.discharged,discharged:DateTime(2026,11,4,17));
    expect(p.hospitalizationDayOn(DateTime(2026,11,5)),3);
    expect(p.hospitalizationDayOn(DateTime(2028,11,7)),3);
  });

  test('Patient explicitement Non admis : aucun jour de séjour',(){
    final p=caseForTest(fromProgramme:true,
      stage:CaseStage.notAdmitted);
    expect(p.hospitalizationStartDate,isNull);
    expect(p.hospitalizationDayOn(DateTime(2026,11,5)),isNull);
  });

  testWidgets('Pastille J du patient et origine datée dans le détail',(tester) async {
    final p=caseForTest(fromProgramme:true,
      programme:DateTime(2026,11,2,11));
    await tester.pumpWidget(MaterialApp(
      home:Scaffold(body:HospitalizationDayCounter(
        patient:p,showStartDate:true)),
    ));
    expect(find.byKey(const Key('hospitalization-day-counter')),findsOneWidget);
    expect(find.text('Programme opératoire · 02/11/2026'),findsOneWidget);
    expect(find.textContaining('Jour d’hospitalisation'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
