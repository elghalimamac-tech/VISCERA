import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/store.dart';

PatientCase patientForTest(String id, {
  bool official = true,
  CaseStage stage = CaseStage.scheduled,
}) => PatientCase(
  id: id,
  name: 'PATIENT TEST',
  age: '—',
  origin: 'Consultation',
  insurance: 'À préciser',
  motive: '',
  history: '',
  exam: '',
  investigations: '',
  labs: '',
  immediatePlan: '',
  procedure: 'Intervention programmée',
  blockTiming: 'Différé',
  admissionTiming: official ? 'Non admis' : 'Le jour du bloc',
  beforeUnit: '',
  beforeBox: '',
  afterUnit: '',
  afterBox: '',
  expectedDays: 0,
  blockAt: DateTime(2099, 11, 2, 7, 30),
  admittedAt: null,
  stage: stage,
  fromBlocProgram: official,
  programRoom: '5',
  programSurgeon: 'Pr TEST',
  programScheduledTime: '07H30',
);

void main() {
  test('Aucune donnée patient fictive ne se charge au démarrage', () {
    final store = AppStore();
    expect(store.patients, isEmpty);
    expect(store.occupiedBoxes, 0);
  });

  test('Un patient du bloc est programmé et non admis', () {
    final store = AppStore();
    final patient = patientForTest('BLOC-1');
    store.replaceBlocProgramPatients([patient]);
    expect(store.programmed, hasLength(1));
    expect(store.patients.single.origin, 'Consultation');
    expect(store.patients.single.stage, CaseStage.scheduled);
    expect(store.patients.single.physicallyAdmitted, false);
    expect(store.active, isEmpty);
    expect(store.occupiedBoxes, 0);
    expect(store.theatre, hasLength(1));
    store.startTheatre(patient);
    expect(patient.stage, CaseStage.scheduled);
    store.finishTheatre(patient);
    expect(patient.stage, CaseStage.scheduled);
  });

  test('Les rafraîchissements remplacent les imports sans effacer les admissions', () {
    final store = AppStore();
    final manuallyCreated = patientForTest('LOCAL-1', official: false,
      stage: CaseStage.preoperative);
    store.add(manuallyCreated);
    store.replaceBlocProgramPatients([patientForTest('BLOC-1')]);
    expect(store.patients, hasLength(1)); // Même patient/date : pas de doublon.
    store.replaceBlocProgramPatients([patientForTest('BLOC-2')]);
    expect(store.patients, hasLength(1));
    expect(store.patients.single.id, 'LOCAL-1');
  });

  test('La déconnexion efface les dossiers de la session', () {
    final store = AppStore();
    store.replaceBlocProgramPatients([patientForTest('BLOC-1')]);
    store.clearAuthenticatedProfile();
    expect(store.patients, isEmpty);
  });
}
