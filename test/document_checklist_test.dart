import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/document_checklist.dart';
import 'package:viscera/models.dart';
import 'package:viscera/store.dart';

void main() {
  PatientCase example() => PatientCase(
    id:'TEST-1',name:'Patient fictif',age:'40',origin:'Urgences',insurance:'FAR',
    motive:'Test',history:'',exam:'',investigations:'',labs:'',immediatePlan:'',
    procedure:'Autre intervention',blockTiming:'Immédiat',admissionTiming:'Immédiate',
    beforeUnit:'TC1',beforeBox:'01',afterUnit:'TC2',afterBox:'02',
    expectedDays:2,blockAt:DateTime(2026,10,30),admittedAt:DateTime(2026,10,30),
    stage:CaseStage.postoperative);

  test('Documents partagés bloc / sortie, cachet obligatoire', () {
    final patient=example(),store=AppStore();
    final cro=ClinicalDocuments.postBlock.first;
    store.updateDocument(patient,cro,verified:true);
    expect(patient.completedCount(ClinicalDocuments.postBlock),0);
    expect(patient.completedCount(ClinicalDocuments.discharge),0);
    store.updateDocument(patient,cro,stamped:false);
    expect(patient.completedCount(ClinicalDocuments.postBlock),0);
    store.updateDocument(patient,cro,stamped:true);
    expect(patient.completedCount(ClinicalDocuments.postBlock),1);
    expect(patient.completedCount(ClinicalDocuments.discharge),1);
  });

  test('Anapath peut être non applicable, contrairement au CRO', () {
    final patient=example(),store=AppStore();
    final anapath=ClinicalDocuments.postBlock.last;
    store.updateDocument(patient,anapath,notApplicable:true);
    expect(patient.check('anapath').notApplicable,isTrue);
    expect(patient.check('anapath').complete(anapath),isTrue);
    store.updateDocument(patient,ClinicalDocuments.postBlock.first,notApplicable:true);
    expect(patient.check('cro').notApplicable,isFalse);
  });

  test('Validation groupée : pièces applicables cachetées en un enregistrement', () async {
    final patient=example(),store=AppStore();
    patient.check('anapath').notApplicable=true;
    final previousAt=DateTime(2026,10,20);
    patient.check('cro')
      ..verified=true
      ..stamped=true
      ..checkedAt=previousAt;

    expect(await store.verifyAndStampAllDischargeDocuments(patient),isTrue);
    expect(patient.allChecked(ClinicalDocuments.discharge),isTrue);
    expect(patient.check('anapath').notApplicable,isTrue);
    expect(patient.check('anapath').verified,isFalse);
    expect(patient.check('cro').checkedAt,previousAt);
    expect(patient.check('rdv').verified,isTrue);
    expect(patient.check('rdv').stamped,isNull);
    expect(patient.check('ordonnance_sortie').stamped,isTrue);
    expect(patient.stage,CaseStage.postoperative);
    expect(patient.dischargeAt,isNull);
  });

  test('Action groupée interdite hors postopératoire ou sans admission', () async {
    final patient=example(),store=AppStore();
    patient.stage=CaseStage.preoperative;
    expect(await store.verifyAndStampAllDischargeDocuments(patient),isFalse);
    patient.stage=CaseStage.postoperative;
    patient.admittedAt=null;
    expect(await store.verifyAndStampAllDischargeDocuments(patient),isFalse);
    expect(patient.completedCount(ClinicalDocuments.discharge),0);
  });

  testWidgets('Le raccourci attend une attestation explicite', (tester) async {
    final patient=example();
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:Column(children: [
        DocumentChecklist(
          patient:patient,
          title:'Documents de sortie',
          requirements:ClinicalDocuments.discharge,
        ),
        DischargeDocumentsBulkAction(patient:patient),
      ])),
    )));
    final bulk=find.byKey(const Key('bulk-verify-discharge-documents'));
    expect(bulk,findsOneWidget);
    expect(find.descendant(
      of:find.byType(DocumentChecklist),
      matching:bulk,
    ),findsNothing);
    await tester.ensureVisible(bulk);
    await tester.tap(bulk);
    await tester.pumpAndSettle();
    expect(find.text('Valider les documents'),findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(patient.allChecked(ClinicalDocuments.discharge),isFalse);

    await tester.tap(bulk);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider les documents'));
    await tester.pumpAndSettle();
    expect(patient.allChecked(ClinicalDocuments.discharge),isTrue);
    expect(patient.stage,CaseStage.postoperative);
    expect(patient.dischargeAt,isNull);
    final button=tester.widget<FilledButton>(bulk);
    expect(button.onPressed,isNull);
  });

  test('Une sortie ne se confirme pas avant vérification documentaire', () {
    final patient=example(),store=AppStore();
    store.confirmDischarge(patient,prescription:'',report:'',operationReport:'');
    expect(patient.stage,CaseStage.postoperative);
    for(final requirement in ClinicalDocuments.discharge){
      if(requirement.optional){
        store.updateDocument(patient,requirement,notApplicable:true);
      }else{
        store.updateDocument(patient,requirement,verified:true);
        if(requirement.needsStamp){
          store.updateDocument(patient,requirement,stamped:true);
        }
      }
    }
    expect(patient.completedCount(ClinicalDocuments.discharge),11);
    store.confirmDischarge(patient,prescription:'',report:'',operationReport:'');
    expect(patient.stage,CaseStage.discharged);
  });
}
