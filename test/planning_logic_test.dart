import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/store.dart';

void main() {
  late AppStore store;
  setUp(() { store=AppStore(); });

  test('Référence mai 2026 : mercredi matin professeur, après-midi docteur', () {
    final morning=store.resolveProfessor('Consultation',DateTime(2026,5,6,10));
    expect(store.professorById(morning.professorId)?.name,'Pr GHADDOU');
    expect(morning.requiresSelection,false);
    final afternoon=store.resolveProfessor('Consultation',DateTime(2026,5,6,15));
    expect(afternoon.professorId,isNull);
    expect(afternoon.explanation,contains('Dr BENGHAIT'));
    expect(afternoon.requiresSelection,true);
  });

  test('Vacations hebdomadaires automatiques toute l’année et sur plusieurs années', () {
    for (final date in [DateTime(2026,1,2,10),DateTime(2026,10,30,10),DateTime(2027,1,1,10)]) {
      final result=store.resolveProfessor('Consultation',date);
      expect(store.professorById(result.professorId)?.name,'Pr NOURI');
      expect(result.mode,'Vacation hebdomadaire');
      expect(result.requiresSelection,false);
    }
    // Hors des plages habituelles, ne pas attribuer arbitrairement.
    final pause=store.resolveProfessor('Consultation',DateTime(2026,10,30,13,30));
    expect(pause.professorId,isNull);
    expect(pause.requiresSelection,true);
    final sunday=store.resolveProfessor('Consultation',DateTime(2026,11,1,10));
    expect(sunday.professorId,isNull);
  });

  test('Samedi de mai = médecin de garde non identifié', () {
    final result=store.resolveProfessor('Consultation',DateTime(2026,5,2,10));
    expect(result.professorId,isNull);
    expect(result.explanation,contains('Médecin de garde'));
  });

  test('Vacation datée personnalisée prévaut sur la grille annuelle', () {
    store.addProfessor('Pr Exception');
    final id=store.professors.firstWhere((p)=>p.name=='Pr Exception').id;
    store.addVacation(professorId:id,start:DateTime(2026,5,4,9),end:DateTime(2026,5,4,13));
    expect(store.resolveProfessor('Consultation',DateTime(2026,5,4,10)).professorId,id);
  });

  test('Une urgence est attribuée au senior du jour, jamais au junior', () {
    store.addProfessor('Pr Senior Test');
    store.addJunior('Dr Junior Test');
    final day=DateTime(2026,11,3,23,45);
    final professorId=store.professors.firstWhere((p)=>p.name=='Pr Senior Test').id;
    store.setDuty(day,seniorProfessorId:professorId,juniorId:store.juniors.first.id);
    final result=store.resolveProfessor('Urgences',day);
    expect(result.professorId,professorId);
    expect(result.mode,'Astreinte senior');
    expect(result.requiresSelection,false);
  });

  test('Import octobre 2026 : 31 médecins seniors, aucun junior', () {
    const source=['LAFKIH','GHADDOU','FAHSI','FAHSI','GHADDOU','LAABOULI','LAFKIH','LAABOULI','FAHSI','BENSAAD','BENSAAD','GHADDOU','LAFKIH','LAABOULI','FAHSI','LAFKIH','GHADDOU','GHADDOU','LAABOULI','GHADDOU','FAHSI','BENSAAD','LAFKIH','LAABOULI','LAABOULI','GHADDOU','LAABOULI','FAHSI','LAFKIH','BENSAAD','LAFKIH'];
    for(var d=1;d<=31;d++) {
      final duty=store.dutyOn(DateTime(2026,10,d));
      expect(duty?.seniorName,source[d-1]);
      expect(duty?.juniorId,isNull);
    }
    expect(store.dutyOn(DateTime(2026,11,1)),isNull);
  });

  test('Admission urgences : tout senior d’astreinte est responsable sans validation du grade', () {
    final unknown=store.resolveProfessor('Urgences',DateTime(2026,10,29,15));
    expect(store.responsibleById(unknown.professorId)?.name,'LAFKIH');
    expect(unknown.requiresSelection,false);
    expect(unknown.explanation,contains('LAFKIH'));
    final known=store.resolveProfessor('Urgences',DateTime(2026,10,30,15));
    expect(store.professorById(known.professorId)?.name,'Pr BENSAAD');
    expect(known.requiresSelection,false);
  });

  test('Aucune astreinte senior ne crée de fausse attribution', () {
    store.addProfessor('Pr A');
    final result=store.resolveProfessor('Urgences',DateTime(2026,11,5));
    expect(result.professorId,isNull);
    expect(result.requiresSelection,true);
  });

  test('Consultation attribuée selon le créneau, indépendamment du bloc', () {
    store.addProfessor('Pr Consultation');
    final id=store.professors.firstWhere((p)=>p.name=='Pr Consultation').id;
    store.addVacation(professorId:id,start:DateTime(2026,11,3,9),end:DateTime(2026,11,3,12));
    expect(store.resolveProfessor('Consultation',DateTime(2026,11,3,10,30)).professorId,id);
    expect(store.professorById(store.resolveProfessor('Consultation',DateTime(2026,11,3,12)).professorId)?.name,'Pr GHADDOU');
  });

  test('Chevauchement de deux professeurs oblige une sélection', () {
    store.addProfessor('Pr A');store.addProfessor('Pr B');
    store.addVacation(professorId:store.professors.firstWhere((p)=>p.name=='Pr A').id,start:DateTime(2026,11,3,9),end:DateTime(2026,11,3,13));
    store.addVacation(professorId:store.professors.firstWhere((p)=>p.name=='Pr B').id,start:DateTime(2026,11,3,11),end:DateTime(2026,11,3,15));
    final result=store.resolveProfessor('Consultation',DateTime(2026,11,3,12));
    expect(result.professorId,isNull);
    expect(result.requiresSelection,true);
    expect(result.mode,'Conflit de vacations');
  });

  test('Vacation avec fin avant le début est rejetée', () {
    store.addProfessor('Pr A');
    final ok=store.addVacation(professorId:store.professors.firstWhere((p)=>p.name=='Pr A').id,start:DateTime(2026,11,3,14),end:DateTime(2026,11,3,9));
    expect(ok,false);expect(store.vacations,isEmpty);
  });
}
