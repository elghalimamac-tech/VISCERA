import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/store.dart';
import 'package:viscera/patient_service_groups.dart';

PatientCase caseForHome(String id, CaseStage stage, DateTime day) =>
    PatientCase(
      id: id,
      name: id,
      age: '42',
      origin: 'Consultation',
      insurance: 'CNSS',
      motive: 'Essai de priorité accueil',
      history: '',
      exam: '',
      investigations: '',
      labs: '',
      immediatePlan: '',
      procedure: 'Chirurgie de test',
      blockTiming: 'Différé',
      admissionTiming: 'Confirmée',
      beforeUnit: 'TC1',
      beforeBox: '01',
      afterUnit: 'TC2',
      afterBox: '02',
      expectedDays: 3,
      blockAt: day,
      admittedAt: day,
      stage: stage,
    );

void main() {
  test('Patients regroupés par service réel, sans inventer de box', () {
    final today=DateTime(2026,11,3);
    final preop=caseForHome('PREOP TC2',CaseStage.preoperative,today)
      ..beforeUnit='TC2'..beforeBox='07';
    final postop=caseForHome('POSTOP TC1',CaseStage.postoperative,today)
      ..afterUnit='TC1'..afterBox='04';
    final without=caseForHome('SANS SERVICE',CaseStage.preoperative,today)
      ..beforeUnit=''..beforeBox=''..afterUnit=''..afterBox='';
    final archived=caseForHome('ANCIEN HDJM',CaseStage.discharged,today)
      ..beforeUnit='TC1'..afterUnit='HDJM 0';
    final unadmitted=caseForHome('NON ADMIS',CaseStage.notAdmitted,today);

    final groups=patientsByService([
      without,preop,archived,postop,unadmitted,
    ]);
    expect(groups.keys.toList(),[
      'TC1','TC2','HDJM 0',unassignedPatientService,
    ]);
    expect(groups['TC1']!.single.id,'POSTOP TC1');
    expect(groups['TC2']!.single.id,'PREOP TC2');
    expect(groups['HDJM 0']!.single.id,'ANCIEN HDJM');
    expect(groups[unassignedPatientService]!.map((p)=>p.id),
      ['SANS SERVICE','NON ADMIS']);
    expect(without.currentBox,isEmpty);
  });

  test('Accueil : dossiers actifs uniquement, du séjour récent au plus ancien', () {
    final store = AppStore();
    store.patients.addAll([
      caseForHome('SORTI', CaseStage.discharged, DateTime(2026, 11, 3)),
      caseForHome('ACTIF ANCIEN', CaseStage.preoperative, DateTime(2026, 11, 1)),
      caseForHome('PROGRAMME', CaseStage.scheduled, DateTime(2026, 11, 5)),
      caseForHome('NON ADMIS', CaseStage.notAdmitted, DateTime(2026, 11, 3)),
      caseForHome('ACTIF RECENT', CaseStage.postoperative, DateTime(2026, 11, 3)),
      caseForHome('SORTIE A VALIDER', CaseStage.dischargeReady, DateTime(2026, 11, 2)),
    ]);

    expect(store.homeActive.map((p) => p.id), [
      'ACTIF RECENT',
      'SORTIE A VALIDER',
      'ACTIF ANCIEN',
    ]);
    expect(store.homeActive.every((p) => p.isActive), isTrue);
    expect(store.homeActive.any((p) => p.stage == CaseStage.discharged), isFalse);
    expect(store.homeActive.any((p) => p.isProgrammed), isFalse);
    expect(store.homeActive.any((p) => p.isOmitted), isFalse);
  });
}
