import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/program_admission.dart';
import 'package:viscera/bloc_clinical_record.dart';
import 'package:viscera/store.dart';

PatientCase official(DateTime date, {String id='BLOC-123'})=>PatientCase(
  id:id,name:'DOSSIER FICTIF',age:'—',origin:'Consultation',
  insurance:'À préciser',motive:'',history:'',exam:'',investigations:'',
  labs:'',immediatePlan:'',procedure:'Appendicectomie sous cœlioscopie',
  blockTiming:'Différé',admissionTiming:'À confirmer',
  beforeUnit:'',beforeBox:'',afterUnit:'',afterBox:'',
  expectedDays:1,blockAt:date,admittedAt:null,
  stage:CaseStage.scheduled,fromBlocProgram:true,
);

void main(){
  test('Programme importé : admission automatique en préop avant le jour du bloc',(){
    final p=official(DateTime(2026,11,5,8));
    ProgramAdmission.apply(p,DateTime(2026,11,2,10));
    expect(p.stage,CaseStage.preoperative);
    expect(p.admittedAt,DateTime(2026,11,5));
    expect(p.isActive,isTrue);
    expect(p.isAutoAdmitted,isTrue);
    expect(p.physicallyAdmitted,isTrue);
    final store=AppStore()..replaceBlocProgramPatients([p]);
    expect(store.active,hasLength(1));
    expect(store.occupiedBoxes,0);
  });

  test('Jour du bloc : postopératoire automatique sans validation préalable',(){
    final p=official(DateTime(2026,11,2,14));
    ProgramAdmission.apply(p,DateTime(2026,11,2,7));
    expect(p.stage,CaseStage.postoperative);
    expect(p.admissionTiming,ProgramAdmission.source);
    expect(p.beforeBox,isEmpty);
    expect(p.afterBox,isEmpty);
    expect(p.stage,CaseStage.postoperative);
  });

  test('Exclusion persistée : non admis ne revient pas au prochain import',(){
    final p=official(DateTime(2026,11,2,8));
    ProgramAdmission.apply(p,DateTime(2026,11,2,8));
    ProgramAdmission.omit(p);
    expect(p.stage,CaseStage.notAdmitted);
    expect(p.isActive,isFalse);
    expect(p.physicallyAdmitted,isFalse);
    final saved=BlocClinicalRecordService.encode(p);
    final imported=official(DateTime(2026,11,2,8));
    ProgramAdmission.apply(imported,DateTime(2026,11,2,10));
    BlocClinicalRecordService.apply(imported,saved,2);
    ProgramAdmission.apply(imported,DateTime(2026,11,2,11));
    expect(imported.stage,CaseStage.notAdmitted);
    expect(imported.admittedAt,isNull);
    expect(imported.clinicalVersion,2);
    expect(imported.isActive,isFalse);
  });

  test('Rétablissement après non admission préserve les données cliniques',(){
    final p=official(DateTime(2026,11,2,8));
    p.motive='Note fictive avant exclusion';
    ProgramAdmission.apply(p,DateTime(2026,11,2,10));
    ProgramAdmission.omit(p);
    ProgramAdmission.restore(p,DateTime(2026,11,2,11));
    expect(p.isActive,isTrue);
    expect(p.isOmitted,isFalse);
    expect(p.motive,'Note fictive avant exclusion');
    expect(p.admittedAt,DateTime(2026,11,2));
    expect(p.stage,CaseStage.postoperative);
  });

  test('Ancien dossier programmé devient automatiquement actif après rechargement',(){
    final p=official(DateTime(2026,11,2,8));
    final data=BlocClinicalRecordService.encode(p);
    final next=official(DateTime(2026,11,2,8));
    ProgramAdmission.apply(next,DateTime(2026,11,2,13));
    BlocClinicalRecordService.apply(next,data,1);
    ProgramAdmission.apply(next,DateTime(2026,11,2,13));
    expect(next.stage,CaseStage.postoperative);
    expect(next.isAutoAdmitted,isTrue);
  });

  test('Admission confirmée et sortie validée ne sont pas écrasées par projection',(){
    final p=official(DateTime(2026,11,2,8));
    p.stage=CaseStage.discharged;
    p.admissionTiming='Confirmée';
    p.dischargeAt=DateTime(2026,11,5);
    ProgramAdmission.apply(p,DateTime(2026,11,8));
    expect(p.stage,CaseStage.discharged);
    expect(p.admissionTiming,'Confirmée');
  });
}
