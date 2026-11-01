import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/store.dart';

void main() {
  test('Un médecin non administrateur ne peut pas ajouter à l’équipe', () {
    final store = AppStore();
    expect(store.canManageTeam, isFalse);
    expect(store.addProfessor('Pr NON AUTORISÉ'), isFalse);
    expect(store.addSenior('Dr NON AUTORISÉ'), isFalse);
    expect(store.addJunior('Junior non autorisé'), isFalse);

    store.activateAuthenticatedDoctor(
      id: 'doctor-non-admin',
      name: 'Dr Médecin',
      email: 'medecin@example.org',
      role: 'junior',
    );
    expect(store.canManageTeam, isFalse);
    expect(store.addProfessor('Pr NON AUTORISÉ'), isFalse);
    expect(store.addSenior('Dr NON AUTORISÉ'), isFalse);
    expect(store.addJunior('Junior non autorisé'), isFalse);
    expect(store.professors.any((x) => x.name == 'Pr NON AUTORISÉ'), isFalse);
    expect(store.juniors.any((x) => x.name == 'Junior non autorisé'), isFalse);
  });

  test('Seul le propriétaire approuvé peut ajouter un membre', () {
    final store = AppStore();
    store.activateAuthenticatedDoctor(
      id: '4fa3bd1b-6ee1-4b87-97eb-d18527025bc6',
      name: 'Dr Admin',
      email: 'admin@example.org',
      role: 'senior',
      isAdmin: true,
    );
    expect(store.canManageTeam, isTrue);
    expect(store.addProfessor('Pr Nouveau'), isTrue);
    expect(store.addSenior('Dr Nouveau'), isTrue);
    expect(store.addJunior('Dr Junior Nouveau'), isTrue);
    expect(store.addJunior('Dr Junior Nouveau'), isFalse);
  });
}
