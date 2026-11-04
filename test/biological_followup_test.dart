import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/biological_followup.dart';
import 'package:viscera/models.dart';
import 'package:viscera/bloc_clinical_record.dart';
import 'package:viscera/clinical_score_engine.dart';

PatientCase testPatient()=>PatientCase(
  id:'BLOC-22',name:'FICTIF',age:'74',origin:'Consultation',
  insurance:'',motive:'',history:'',exam:'',investigations:'',
  labs:'',immediatePlan:'',procedure:'Colectomie gauche',
  blockTiming:'Différé',admissionTiming:'Programmée',
  beforeUnit:'TC1',beforeBox:'',afterUnit:'TC2',afterBox:'',
  expectedDays:4,blockAt:DateTime(2026,11,3),
  admittedAt:DateTime(2026,11,3),fromBlocProgram:true,
  stage:CaseStage.postoperative,
);
void main() {
  test('Sans biologie, aucun indice ni CRP calculé',(){
    final p=testPatient();
    expect(BioIndices.compute(p),isEmpty);
    final trend=CrpKinetics(labSeries(p,'crp'));
    expect(trend.points,isEmpty);
    expect(trend.delta,isNull);
    expect(trend.secondaryRise,false);
  });
  test('CRP enregistrées sur plusieurs jours avec vraie réascension',(){
    final p=testPatient();
    p.dailyObservations.addAll([
      DailyObservation(date:DateTime(2026,11,5),
        biology:{'crp':140,'wbc':10}),
      DailyObservation(date:DateTime(2026,11,3),
        biology:{'crp':200,'wbc':12}),
      DailyObservation(date:DateTime(2026,11,4),
        biology:{'crp':120,'wbc':11}),
    ]);
    final t=CrpKinetics(labSeries(p,'crp'));
    expect(t.points.map((v)=>v.value).toList(),[200,120,140]);
    expect(t.delta,20);
    expect(t.secondaryRise,true);
  });
  test('mGPS CAR PNI calculés uniquement avec les éléments présents',(){
    final p=testPatient();
    p.dailyObservations.add(DailyObservation(date:DateTime(2026,11,3),
      biology:{'crp':55,'albumin':30,'lymphocytes':1.2}));
    final values={for(final v in BioIndices.compute(p))v.name:v.value};
    expect(values['mGPS'],'2');
    expect(values['CAR'],'1.83');
    expect(values['PNI'],'36.0');
    expect(values.containsKey('ALBI'),false);
    expect(values.containsKey('GNRI'),false);
  });
  test('Aucune donnée manquante inventée et validation des unités',(){
    final field=biologyFields.first;
    expect(parseBiology('',field),isNull);
    expect(parseBiology('17,5',field),17.5);
    expect(()=>parseBiology('-4',field),throwsFormatException);
    expect(()=>parseBiology('err',field),throwsFormatException);
    final p=testPatient();
    p.dailyObservations.add(DailyObservation(date:DateTime(2026,11,3),
      biology:{'wbc':12}));
    expect(BioIndices.compute(p),isEmpty);
  });
  test('Bilans datés et événements postop sauvegardés dans clinical_data',(){
    final p=testPatient();
    p.dailyObservations.add(DailyObservation(
      date:DateTime(2026,11,3),
      biology:{'crp':100,'wbc':13},clinicalExam:'Examen effectué'));
    p.postoperativeEvents.add({
      'id':'evt1','date':'2026-11-03T12:00:00',
      'type':'Reprise chirurgicale','status':'Confirmée',
      'details':'Reprise constatée','treatment':'Geste décrit'
    });
    final encoded=BlocClinicalRecordService.encode(p);
    final copy=testPatient();
    BlocClinicalRecordService.apply(copy,encoded,1);
    expect(copy.dailyObservations.single.biology['crp'],100);
    expect(copy.dailyObservations.single.biology['wbc'],13);
    expect(copy.postoperativeEvents,hasLength(1));
    expect(copy.postoperativeEvents.single['type'],'Reprise chirurgicale');
  });
  test('mDULK et ISREC exigent la totalité des critères',(){
    expect(ClinicalScoring.compute('mdulk',{
      'rr':'23','crp':'260','deterioration':'1','abdominalPain':'1'
    })?.value,'4');
    expect(ClinicalScoring.compute('mdulk',{
      'rr':'23','deterioration':'1','abdominalPain':'1'
    }),isNull);
    expect(ClinicalScoring.compute('isrec',{
      'confirmed':'no','grade':'C'
    }),isNull);
    expect(ClinicalScoring.compute('isrec',{
      'confirmed':'yes','grade':'C'
    })?.value,'C');
  });
  testWidgets('Graphique CRP vide affiche état clair sans valeurs inventées',
      (tester)async{
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:CrpTrendCard(patient:testPatient())))));
    expect(find.byKey(const Key('patient-crp-chart')),findsOneWidget);
    expect(find.textContaining('Aucune CRP saisie'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
