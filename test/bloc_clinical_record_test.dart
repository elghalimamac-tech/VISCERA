import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/bloc_clinical_record.dart';

PatientCase fromProgram() => PatientCase(
  id: 'BLOC-124',
  name: 'PATIENT TEST',
  age: '—', origin: 'Consultation',
  insurance: 'À préciser',
  motive: '', history: '', exam: '', investigations: '', labs: '',
  immediatePlan: '', procedure: 'Intervention à préciser',
  blockTiming: 'Différé', admissionTiming: 'À confirmer',
  beforeUnit: '', beforeBox: '', afterUnit: '', afterBox: '',
  expectedDays: 0, blockAt: DateTime(2026, 11, 2, 7, 30),
  admittedAt: null, stage: CaseStage.scheduled,
  fromBlocProgram: true, programRoom: '5',
  programSurgeon: 'Pr GHADDOU',
);

void main() {
  test('Dossier officiel : champs cliniques préopératoires éditables', () {
    final patient = fromProgram();
    patient.motive = 'Motif vérifié';
    patient.history = 'Antécédents à confirmer';
    patient.age = '63';
    final check = patient.check('pli')
      ..verified = true
      ..stamped = false;
    expect(check.verified, isTrue);
    final encoded = BlocClinicalRecordService.encode(patient);
    expect(encoded['history'], 'Antécédents à confirmer');
    expect(encoded['stage'], 'scheduled');
    expect(encoded['admittedAt'], isNull);
    expect(encoded['documents'], contains('pli'));

    final reloaded = fromProgram();
    BlocClinicalRecordService.apply(reloaded, encoded, 2);
    expect(reloaded.age, '63');
    expect(reloaded.history, 'Antécédents à confirmer');
    expect(reloaded.stage, CaseStage.scheduled);
    expect(reloaded.physicallyAdmitted, false);
    expect(reloaded.check('pli').stamped, false);
    expect(reloaded.clinicalVersion, 2);
  });

  test('L'admission est explicitement confirmée, jamais déduite du bloc', () {
    final patient = fromProgram();
    final data = BlocClinicalRecordService.encode(patient);
    data['stage'] = 'preoperative';
    data['admittedAt'] = null;
    BlocClinicalRecordService.apply(patient, data, 1);
    expect(patient.stage, CaseStage.scheduled);
    expect(patient.physicallyAdmitted, false);

    data['admittedAt'] = '2026-11-02T06:15:00';
    BlocClinicalRecordService.apply(patient, data, 2);
    expect(patient.stage, CaseStage.preoperative);
    expect(patient.physicallyAdmitted, true);
    expect(patient.admittedAt?.hour, 6);
  });

  test('Les observations et vérifications survivent au rechargement', () {
    final patient = fromProgram();
    patient.dailyObservations.add(DailyObservation(
      date: DateTime(2026, 11, 1),
      clinicalExam: 'Examen documenté',
      plan: 'Bilan à confirmer',
    ));
    final encoded = BlocClinicalRecordService.encode(patient);
    final recovered = fromProgram();
    BlocClinicalRecordService.apply(recovered, encoded, 1);
    expect(recovered.dailyObservations, hasLength(1));
    expect(recovered.dailyObservations.single.plan, 'Bilan à confirmer');
  });
}
