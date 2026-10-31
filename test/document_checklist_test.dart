import 'package:flutter_test/flutter_test.dart';
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
