import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/store.dart';

void main() {
  test('Les astreintes sont modifiables date par date et mois par mois', () {
    final store = AppStore();
    final historical = DateTime(2026, 10, 29);
    final november = DateTime(2026, 11, 5);
    expect(store.seniorOnName(historical), 'LAFKIH');
    expect(store.seniorOnName(november), isNull);

    expect(store.addJunior('Résident Démo'), isTrue);
    final juniorId = store.juniors.single.id;
    store.setDuty(november, seniorName: 'FAHSI', juniorId: juniorId);
    expect(store.seniorOnName(november), 'FAHSI');
    expect(store.juniorOn(november)?.name, 'Résident Démo');
    expect(store.resolveProfessor('Urgences', DateTime(2026, 11, 5, 10)).professorId, 'SENIOR-FAHSI');
    expect(store.seniorOnName(historical), 'LAFKIH');

    store.setDuty(november, seniorName: 'LAABOULI', juniorId: juniorId);
    expect(store.resolveProfessor('Urgences', DateTime(2026, 11, 5, 10)).professorId, 'SENIOR-LAABOULI');

    store.setDuty(november);
    expect(store.seniorOnName(november), isNull);
    expect(store.juniorOn(november), isNull);
  });

  test('Les consultations annuelles restent inchangées', () {
    final store = AppStore();
    final match = store.resolveProfessor('Consultation', DateTime(2027, 2, 5, 10));
    expect(match.mode, 'Vacation hebdomadaire');
    expect(store.professorById(match.professorId)?.name, 'Pr NOURI');
  });
}
