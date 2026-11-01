import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/store.dart';

void main() {
  test('Les tuiles personnelles SERVICE sont exclusivement en 24H et restent attribuées au médecin', () {
    final store=AppStore();
    store.activateAuthenticatedDoctor(id:'doctor-a',name:'Dr TEST',email:'test@example.com',role:'junior');
    final source=DateTime(2027,3,11);
    final target=DateTime(2027,3,12);
    expect(store.placePersonalEvent(source,kind:'garde',shift:'24h'),isNull);
    expect(store.myServiceShift(source),'24h');
    expect(store.placePersonalEvent(target,kind:'garde',from:source,shift:'24h'),isNull);
    expect(store.isMyDuty(source),isFalse);
    expect(store.myServiceShift(target),'24h');
    expect(store.placePersonalEvent(target,kind:'garde',shift:'jour'),isNotNull);
    expect(store.placePersonalEvent(target,kind:'garde',shift:'nuit'),isNotNull);
    expect(store.myServiceShift(target),'24h');
    store.removePersonalEvent(target,'garde');
    expect(store.myServiceShift(target),isNull);
  });

  test('Une tuile personnelle ne remplace pas une garde attribuée à un collègue', () {
    final store=AppStore();
    store.addJunior('Dr COLLEGUE');
    final colleagueId=store.juniors.first.id;
    final occupied=DateTime(2027,6,15);
    store.setDuty(occupied,juniorId:colleagueId);
    store.activateAuthenticatedDoctor(id:'doctor-a',name:'Dr TEST',email:'test@example.com',role:'junior');
    final refused=store.placePersonalEvent(occupied,kind:'garde',shift:'24h');
    expect(refused,contains('autre médecin'));
    expect(store.juniorOn(occupied)?.id,colleagueId);
  });

  test('Une tuile CONGÉ peut être déplacée sans perturber les autres mois', () {
    final store=AppStore();
    store.activateAuthenticatedDoctor(id:'doctor-a',name:'Dr TEST',email:'test@example.com',role:'junior');
    final original=DateTime(2027,7,4);
    final target=DateTime(2027,7,8);
    expect(store.placePersonalEvent(original,kind:'conge'),isNull);
    expect(store.myLeave(original),isNotNull);
    expect(store.placePersonalEvent(target,kind:'conge',from:original),isNull);
    expect(store.myLeave(original),isNull);
    expect(store.myLeave(target),isNotNull);
    expect(store.dutyOn(DateTime(2026,10,29))?.seniorName,'LAFKIH');
  });
}
