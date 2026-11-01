import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/store.dart';
import 'package:viscera/bloc_clinical_record.dart';
import 'package:viscera/manual_admission_service.dart';

PatientCase manualFixture({
  String name = 'PERSONNE TEST',
  CaseStage stage = CaseStage.preoperative,
  DateTime? admittedAt,
}) => PatientCase(
  id: 'DRAFT-TEST', name: name, age: '51', origin: 'Urgences',
  birthDate:DateTime(1975,3,15),surgeryType:'Chirurgie laparoscopique',
  insurance: 'CNSS', motive: 'Motif documenté',
  history: 'Antécédents', exam: 'Examen vérifié',
  investigations: 'Imagerie', labs: 'Biologie',
  immediatePlan: 'CAT vérifiée', procedure: 'Intervention choisie',
  blockTiming: 'Différé', admissionTiming: 'Immédiate',
  beforeUnit: 'TC1', beforeBox: '03',
  afterUnit: 'TC2', afterBox: '05',
  expectedDays: 2,
  blockAt: DateTime(2026, 11, 2, 9),
  admittedAt: admittedAt ?? DateTime(2026, 11, 1, 8),
  stage: stage,
);

void main() {
  test('Les admissions manuelles récupèrent toutes les données du dossier', () {
    final draft = manualFixture();
    draft.check('pli')
      ..verified=true
      ..stamped=true;
    draft.dailyObservations.add(DailyObservation(
      date: DateTime(2026, 11, 1), plan: 'Surveillance',
    ));
    final server = <String,dynamic>{
      'id':'af3b4a5e-39af-4f52-9c37-032c4223495d',
      'name':draft.name, 'origin':draft.origin,
      'procedure_name':draft.procedure,
      'block_at':draft.blockAt.toUtc().toIso8601String(),
      'block_timing':draft.blockTiming,
      'birth_date':'1975-03-15','surgery_type':draft.surgeryType,
      'clinical_data':BlocClinicalRecordService.encode(draft),
      'version':3,
    };
    final patient = ManualAdmissionService.fromServer(server);
    expect(patient.id,startsWith('MANUAL-'));
    expect(patient.fromManualAdmission,isTrue);
    expect(patient.fromBlocProgram,isFalse);
    expect(patient.origin,'Urgences');
    expect(patient.birthDate,DateTime(1975,3,15));
    expect(patient.surgeryType,'Chirurgie laparoscopique');
    expect(patient.stage,CaseStage.preoperative);
    expect(patient.admittedAt,isNotNull);
    expect(patient.motive,'Motif documenté');
    expect(patient.beforeBox,'03');
    expect(patient.check('pli').stamped,isTrue);
    expect(patient.dailyObservations.single.plan,'Surveillance');
    expect(patient.clinicalVersion,3);
  });

  test('Une programmation manuelle future ne simule pas une admission', () {
    final seed = manualFixture(stage:CaseStage.scheduled);
    final source = BlocClinicalRecordService.encode(seed);
    source['stage'] = 'scheduled';
    source['admittedAt'] = null;
    final record = ManualAdmissionService.fromServer({
      'id':'daeb7cf8-5692-4379-86a7-cf46befc8b1a',
      'name':seed.name,
      'origin':'Consultation',
      'procedure_name':seed.procedure,
      'block_at':seed.blockAt.toUtc().toIso8601String(),
      'block_timing':seed.blockTiming,
      'birth_date':'1975-03-15','surgery_type':seed.surgeryType,
      'clinical_data':source,
      'version':1,
    });
    expect(record.stage,CaseStage.scheduled);
    expect(record.physicallyAdmitted,isFalse);
    expect(record.origin,'Consultation');
  });

  test('Deux rafraîchissements ne dupliquent pas la même admission', () {
    final store = AppStore();
    final original = ManualAdmissionService.fromServer({
      'id':'af3b4a5e-39af-4f52-9c37-032c4223495d',
      'name':'PERSONNE TEST','origin':'Urgences',
      'procedure_name':'Intervention choisie',
      'block_at':DateTime(2026,11,2,9).toUtc().toIso8601String(),
      'block_timing':'Différé',
      'birth_date':'1975-03-15','surgery_type':'Chirurgie laparoscopique',
      'clinical_data':BlocClinicalRecordService.encode(manualFixture()),
      'version':1,
    });
    store.replaceManualPatients([original]);
    store.replaceManualPatients([original]);
    expect(store.patients,hasLength(1));
    expect(store.active,hasLength(1));
    expect(store.findDuplicateCase('  personne    TEST ',DateTime(2026,11,2)),isNotNull);
    expect(store.findDuplicateCase('PERSONNE TEST',DateTime(2026,11,3)),isNull);
    expect(store.findDuplicateCase('PERSONNE TEST',DateTime(2026,11,2),
      birthDate:DateTime(1975,3,15)),isNotNull);
    expect(store.findDuplicateCase('PERSONNE TEST',DateTime(2026,11,2),
      birthDate:DateTime(1990,8,9)),isNull);
    // Un programme sans naissance renseignée n'est pas une preuve d'identité.
    store.replaceBlocProgramPatients([PatientCase(
      id:'BLOC-7',name:'PERSONNE TEST',age:'—',origin:'Consultation',
      insurance:'À préciser',motive:'',history:'',exam:'',investigations:'',
      labs:'',immediatePlan:'',procedure:'Intervention programmée',
      blockTiming:'Différé',admissionTiming:'À confirmer',
      beforeUnit:'',beforeBox:'',afterUnit:'',afterBox:'',expectedDays:0,
      blockAt:DateTime(2026,11,2,9),fromBlocProgram:true,
      stage:CaseStage.scheduled,
    )]);
    expect(store.patients,hasLength(2));
    final imported=store.patients.firstWhere((p)=>p.fromBlocProgram);
    store.attachVerifiedProgram(original,imported);
    expect(store.patients,hasLength(1));
    expect(original.linkedProgramEntryId,7);
    expect(original.dailyObservations,isEmpty);
    store.clearAuthenticatedProfile();
    expect(store.patients,isEmpty);
  });
}
