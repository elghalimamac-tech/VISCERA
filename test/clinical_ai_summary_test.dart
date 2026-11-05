import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/clinical_ai_summary.dart';
import 'package:viscera/clinical_ai_reports.dart';
import 'package:viscera/models.dart';
import 'package:viscera/screens/clinical_ai_page.dart';

PatientCase sample() => PatientCase(
  id:'MANUAL-123e4567-e89b-42d3-a456-426614174000',name:'TEST PATIENT',age:'62',origin:'Consultation',
  insurance:'',motive:'Douleur abdominale depuis 48 heures',
  history:'Diabète de type 2, joindre test@example.com',
  exam:'Sensibilité abdominale',
  investigations:'Échographie à discuter',
  labs:'',immediatePlan:'',procedure:'Colectomie',
  blockTiming:'Différé',admissionTiming:'Programmée',
  beforeUnit:'TC1',beforeBox:'',afterUnit:'TC1',afterBox:'',
  expectedDays:4,blockAt:DateTime(2026,11,3),
  admittedAt:DateTime(2026,11,3),fromManualAdmission:true,
  stage:CaseStage.postoperative,
);

void main() {
  test('Synthèse utile sans noms, dates exactes ni identifiants',(){
    final p=sample();
    p.dailyObservations.add(DailyObservation(
      date:DateTime(2026,11,4),symptoms:'Douleur légère',
      clinicalExam:'Pas de défense',
      biology:{'pct':0.56,'crp':75,'creatinine':176.8}));
    final text=buildClinicalAiSummary(p,
      referenceDate:DateTime(2026,11,5));
    expect(text,contains('Procalcitonine: 0.56 ng/mL'));
    expect(text,contains('Créatinine: 20 mg/L'));
    expect(text,contains('Observation J-1'));
    expect(text,contains('Sensibilité abdominale'));
    expect(text,contains('[e-mail masqué]'));
    expect(text.contains('62'),isFalse); // seulement tranche d'âge
    expect(text.contains(p.name),isFalse);
    expect(text.contains(p.id),isFalse);
    expect(text.contains('2026-11-04'),isFalse);
  });
  test('Synthèse avec score retrouvé : valeur, interprétation et phase',(){
    final p=sample();
    p.clinicalScores['caprini']={
      'value':'6',
      'interpretation':'Risque thromboembolique élevé à réévaluer',
      'assessedStage':'preoperative',
    };
    final text=buildClinicalAiSummary(p);
    expect(text,contains('Score caprini : 6'));
    expect(text,contains('Interprétation enregistrée pour caprini'));
    expect(text,contains('Phase de saisie du score caprini : preoperative'));
    expect(text.contains('Aucun score clinique formel enregistré.'),isFalse);
  });
  test('Si aucun score clinique, signaler explicitement les données manquantes',(){
    final p=sample();
    final text=buildClinicalAiSummary(p);
    expect(text,contains('Aucun score clinique formel enregistré.'));
    expect(text.contains('Score caprini :'),isFalse);
    expect(text.contains('Score news2 :'),isFalse);
  });

  test('La référence patient conserve le type de dossier partagé',(){
    final p=sample();
    expect(ClinicalAiReports.patientReference(p),{
      'kind':'manual',
      'id':'123e4567-e89b-42d3-a456-426614174000',
    });
    final draft=PatientCase(
      id:'LOCAL-1',name:'Brouillon',age:'—',origin:'Consultation',
      insurance:'',motive:'',history:'',exam:'',investigations:'',
      labs:'',immediatePlan:'',procedure:'Intervention',
      blockTiming:'Différé',admissionTiming:'Programmé',
      beforeUnit:'TC1',beforeBox:'',afterUnit:'TC1',afterBox:'',
      expectedDays:1,blockAt:DateTime(2026,11,5));
    expect(ClinicalAiReports.patientReference(draft),isNull);
  });

  test('Une analyse archivée conserve le contenu et la date de création',(){
    final result=ClinicalAiSavedReport.fromJson({
      'id':'123e4567-e89b-42d3-a456-426614174001',
      'created_at':'2026-11-05T18:30:00Z',
      'created_by_name':'Médecin Test',
      'model':'openai/gpt-oss-120b',
      'result':{'hypotheses':[{'possibility':'À confirmer'}],
        'assessed_scores':[], 'scores_to_consider':[],
        'labs_to_consider':[]},
      'reference_catalog':[{'id':'NEWS2_RCP','year':2017,
        'title':'National Early Warning Score 2',
        'url':'https://rcp.ac.uk'}],
      'bibliography_reviewed_at':'2026-11-05',
      'sources_live_verified':false,
    });
    expect(result.hypothesisCount,1);
    expect(result.createdAt.toUtc().year,2026);
    expect(result.references.single['id'],'NEWS2_RCP');
  });

  testWidgets('Une ancienne réponse s’ouvre sans nouvel appel GROQ',(tester)async{
    await tester.binding.setSurfaceSize(const Size(1080,1800));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    final report=ClinicalAiSavedReport.fromJson({
      'id':'123e4567-e89b-42d3-a456-426614174001',
      'created_at':'2026-11-05T18:30:00Z',
      'created_by_name':'Dr Archivage',
      'model':'openai/gpt-oss-120b',
      'result':{
        'hypotheses':[{'possibility':'Hypothèse archivée',
          'supporting_data':'Données disponibles',
          'data_to_verify':'À compléter',
          'source_ids':['NEWS2_RCP']}],
        'assessed_scores':[],
        'scores_to_consider':[],
        'labs_to_consider':[],
        'management_options_to_discuss':[],
        'assessments_to_discuss':[],
        'warning_signs':[],
        'limits':[],
      },
      'reference_catalog':[{'id':'NEWS2_RCP','year':2017,
        'title':'National Early Warning Score 2',
        'organization':'RCP','url':'https://rcp.ac.uk'}],
    });
    await tester.pumpWidget(MaterialApp(home:
      ClinicalAiPage(patient:sample(),savedReport:report)));
    expect(find.textContaining('Analyse archivée du dossier'),findsOneWidget);
    expect(find.byKey(const Key('clinical-ai-generate')),findsNothing);
    expect(find.byKey(const Key('clinical-ai-preview')),findsNothing);
    expect(tester.takeException(),isNull);
  });

  testWidgets('IA : aucun envoi sans relecture explicite',(tester)async{
    await tester.binding.setSurfaceSize(const Size(1080, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final p=sample();
    await tester.pumpWidget(MaterialApp(home:ClinicalAiPage(patient:p)));
    expect(find.byKey(const Key('clinical-ai-preview')),findsOneWidget);
    expect(find.byKey(const Key('clinical-ai-score-dashboard')),findsOneWidget);
    expect(find.textContaining('Scores et indices cliniques'),findsOneWidget);
    final button=tester.widget<FilledButton>(
      find.byKey(const Key('clinical-ai-generate')));
    expect(button.onPressed,isNull);
    expect(find.byKey(const Key('clinical-ai-consent')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
