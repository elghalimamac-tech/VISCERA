import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/store.dart';

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
