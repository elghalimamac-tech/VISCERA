import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/clinical_ai_summary.dart';
import 'package:viscera/models.dart';
import 'package:viscera/screens/clinical_ai_page.dart';

PatientCase sample() => PatientCase(
  id:'MANUAL-SECRET-123',name:'TEST PATIENT',age:'62',origin:'Consultation',
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
  testWidgets('IA : aucun envoi sans relecture explicite',(tester)async{
    final p=sample();
    await tester.pumpWidget(MaterialApp(home:ClinicalAiPage(patient:p)));
    expect(find.byKey(const Key('clinical-ai-preview')),findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('clinical-ai-generate')),280,
      scrollable:find.byType(Scrollable).first);
    final button=tester.widget<FilledButton>(
      find.byKey(const Key('clinical-ai-generate')));
    expect(button.onPressed,isNull);
    expect(find.byKey(const Key('clinical-ai-consent')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
