import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/store.dart';

PatientCase demoPatient() => PatientCase(
  id: 'TEST', name: 'Dossier démo', age: '40', origin: 'Urgences', insurance: 'FAR',
  motive: 'Douleur', history: '', exam: '', investigations: '', labs: '',
  immediatePlan: '', procedure: 'À préciser', blockTiming: 'Différé',
  admissionTiming: 'Immédiate', beforeUnit: 'TC1', beforeBox: '02',
  afterUnit: 'TC1', afterBox: '02', expectedDays: 2,
  blockAt: DateTime(2026, 10, 29), admittedAt: DateTime(2026, 10, 29),
);

void main() {
  test('une observation datée est modifiable sans duplication', () {
    final store = AppStore();
    final patient = demoPatient();
    final date = DateTime(2026, 10, 30);
    store.saveDailyObservation(patient, DailyObservation(date: date, clinicalExam: 'Abdomen souple'));
    expect(patient.dailyObservations, hasLength(1));
    store.saveDailyObservation(patient, DailyObservation(date: date, clinicalExam: 'Douleur provoquée'));
    expect(patient.dailyObservations, hasLength(1));
    expect(patient.dailyObservations.single.clinicalExam, 'Douleur provoquée');
  });

  test('Magica et Sillage sont des validations indépendantes et manuelles', () {
    final store = AppStore();
    final patient = demoPatient();
    final note = DailyObservation(date: DateTime(2026, 10, 30), plan: 'Surveillance clinique');
    store.saveDailyObservation(patient, note);
    store.setObservationReported(patient, note, magica: true);
    expect(note.reportedMagica, true);
    expect(note.reportedSillage, false);
    expect(note.fullyReported, false);
    store.setObservationReported(patient, note, sillage: true);
    expect(note.fullyReported, true);
  });

  test('certificat médical facultatif mais cachet à vérifier s’il est demandé', () {
    final cert = ClinicalDocuments.discharge.singleWhere((item) => item.key == 'certificat');
    final p = demoPatient();
    final checked = p.check('certificat');
    expect(cert.optional, true);
    checked.notApplicable = true;
    expect(checked.complete(cert), true);
    checked.notApplicable = false;
    checked.verified = true;
    expect(checked.complete(cert), false);
    checked.stamped = true;
    expect(checked.complete(cert), true);
  });
}
