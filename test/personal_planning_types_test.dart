import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/store.dart';

void main() {
  test('Le planning personnel autorise uniquement SERVICE 24H et CONGÉ', () {
    final store=AppStore();
    store.activateAuthenticatedDoctor(
      id:'doctor-test',name:'Dr Test',email:'test@example.com',role:'junior');
    final date=DateTime(2026,11,17);
    expect(store.placePersonalEvent(date,kind:'garde',shift:'jour'),isNotNull);
    expect(store.placePersonalEvent(date,kind:'garde',shift:'nuit'),isNotNull);
    expect(store.isMyDuty(date),false);
    expect(store.placePersonalEvent(date,kind:'garde'),isNull);
    expect(store.myServiceShift(date),'24h');
    expect(store.placePersonalEvent(date,kind:'conge'),isNotNull);
    store.removePersonalEvent(date,'garde');
    expect(store.isMyDuty(date),false);
    expect(store.placePersonalEvent(date,kind:'conge'),isNull);
    expect(store.myLeave(date),isNotNull);
  });

  test('Une garde de service se déplace sans créer de jour ou nuit', () {
    final store=AppStore();
    store.activateAuthenticatedDoctor(
      id:'doctor-test',name:'Dr Test',email:'test@example.com',role:'junior');
    final a=DateTime(2026,11,18),b=DateTime(2026,11,19);
    expect(store.placePersonalEvent(a,kind:'garde'),isNull);
    expect(store.placePersonalEvent(b,kind:'garde',from:a),isNull);
    expect(store.myServiceShift(a),isNull);
    expect(store.myServiceShift(b),'24h');
  });
}
