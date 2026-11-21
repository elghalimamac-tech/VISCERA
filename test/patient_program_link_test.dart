import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/patient_program_link_candidates.dart';
import 'package:viscera/store.dart';

PatientCase hospitalized({
  String id='MANUAL-uuid-1',
  String name='PATIENT FICTIF',
  String origin='Urgences',
  DateTime? birthday,
  DateTime? admission,
  CaseStage stage=CaseStage.preoperative,
}) => PatientCase(
  id:id,name:name,age:'45',origin:origin,
  insurance:'CNSS',motive:'Motif documenté',history:'Antécédent conservé',
  exam:'Examen clinique',investigations:'Imagerie',labs:'Biologie',
  immediatePlan:'CAT',procedure:'Intervention initiale',
  blockTiming:'Différé',admissionTiming:'Immédiate',
  beforeUnit:'TC1',beforeBox:'04',afterUnit:'TC1',afterBox:'04',
  expectedDays:5,blockAt:DateTime(2026,11,21,8),
  admittedAt:admission??DateTime(2026,11,20,9),
  birthDate:birthday??DateTime(1981,2,5),
  fromManualAdmission:true,stage:stage,
);

PatientCase programmed({
  String id='BLOC-200',
  String name='PATIENT FICTIF',
  DateTime? date,
}) => PatientCase(
  id:id,name:name,age:'—',origin:'Consultation',insurance:'À préciser',
  motive:'',history:'',exam:'',investigations:'',labs:'',immediatePlan:'',
  procedure:'Colectomie',blockTiming:'Différé',
  admissionTiming:'Programme officiel',beforeUnit:'',beforeBox:'',
  afterUnit:'',afterBox:'',expectedDays:0,
  blockAt:date??DateTime(2026,11,23,10),fromBlocProgram:true,
  stage:CaseStage.preoperative,programRoom:'2',
  programScheduledTime:'10H00',programSurgeon:'Dr X',
);

void main() {
  test('Urgences : séjour ouvert avant le bloc proposé pour rapprochement', () {
    final stay=hospitalized();
    final block=programmed();
    expect(PatientProgramLinkCandidates.forProgram(block,[stay]),[stay]);
    expect(PatientProgramLinkCandidates.forManual(stay,[block]),[block]);
  });

  test('Consultation déjà admise : intervention plusieurs jours après', () {
    final stay=hospitalized(origin:'Consultation');
    expect(PatientProgramLinkCandidates.canLink(stay,programmed()),isTrue);
  });

  test('Refuser les programmations antérieures à l’admission', () {
    final stay=hospitalized();
    final earlier=programmed(date:DateTime(2026,11,19,8));
    expect(PatientProgramLinkCandidates.canLink(stay,earlier),isFalse);
  });

  test('Pas de rapprochement pour sorti ou identité manuelle sans naissance', () {
    final block=programmed();
    final discharged=hospitalized(stage:CaseStage.discharged);
    final noBirth=hospitalized()..birthDate=null;
    expect(PatientProgramLinkCandidates.canLink(discharged,block),isFalse);
    expect(PatientProgramLinkCandidates.canLink(noBirth,block),isFalse);
  });

  test('Homonymes restent deux dossiers jusqu’à confirmation explicite', () {
    final one=hospitalized();
    final two=hospitalized(id:'MANUAL-uuid-2',birthday:DateTime(1990,9,9));
    final block=programmed();
    final store=AppStore();
    store.replaceManualPatients([one,two]);
    store.replaceBlocProgramPatients([block]);
    expect(store.patients,hasLength(3));
    expect(PatientProgramLinkCandidates.forProgram(block,store.patients),
      containsAll([one,two]));
    // Ce n'est qu'après une vérification humaine et une RPC réussie
    // que le dossier opératoire redondant disparaît des listes.
    store.attachVerifiedProgram(one,block);
    expect(store.patients,hasLength(2));
    expect(store.patients.map((p)=>p.id),containsAll([one.id,two.id]));
    expect(one.motive,'Motif documenté');
    expect(one.history,'Antécédent conservé');
    expect(one.beforeBox,'04');
    expect(one.admittedAt,DateTime(2026,11,20,9));
    expect(one.programBlockAt,DateTime(2026,11,23,10));
    expect(one.programProcedure,'Colectomie');
    expect(one.operativeAt,DateTime(2026,11,23,10));
    expect(one.linkedProgramEntryId,200);
    store.replaceBlocProgramPatients([block]);
    expect(store.patients,hasLength(2),
      reason:'Un rechargement obsolète ne doit pas recréer le doublon');
  });

  test('Détection d’hospitalisation en cours même si le bloc est plus tard', () {
    final stay=hospitalized();
    final store=AppStore()..replaceManualPatients([stay]);
    expect(store.findActiveHospitalization(' PATIENT  FICTIF ',
      DateTime(1981,2,5)),same(stay));
    expect(store.findActiveHospitalization('PATIENT FICTIF',
      DateTime(1977,2,5)),isNull);
  });

  test('Consultation non admise : association historique limitée au même jour', () {
    final stay=hospitalized(origin:'Consultation',stage:CaseStage.scheduled)
      ..admittedAt=null;
    expect(PatientProgramLinkCandidates.canLink(
      stay,programmed(date:DateTime(2026,11,21,16))),isTrue);
    expect(PatientProgramLinkCandidates.canLink(
      stay,programmed(date:DateTime(2026,11,23,16))),isFalse);
  });

  test('Patients différents par nom non associés', () {
    expect(PatientProgramLinkCandidates.canLink(
      hospitalized(),programmed(name:'UNE AUTRE PERSONNE')),isFalse);
  });
}
