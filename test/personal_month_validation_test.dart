import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viscera/store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Les tuiles de garde sont appliquées uniquement après validation', () async {
    final store=AppStore();
    store.activateAuthenticatedDoctor(id:'doctor-a',name:'Dr A',
      email:'a@example.com',role:'junior');
    final date=DateTime(2027,6,10);
    expect(store.isMyDuty(date),false);
    final result=await store.validatePersonalMonth(DateTime(2027,6),{10:'garde'});
    expect(result,isNull);
    expect(store.isMyDuty(date),true);
    expect(store.myServiceShift(date),'24h');

    final loaded=await SharedPreferences.getInstance();
    final raw=loaded.getString('viscera_demo_v8_planning');
    expect(raw,contains('doctor-a'));
  });

  test('La validation ne remplace pas la garde d’un autre junior', () async {
    final store=AppStore();
    store.addJunior('Dr Collègue');
    final colleague=store.juniors.first.id;
    final date=DateTime(2027,6,11);
    store.setDuty(date,juniorId:colleague);
    store.activateAuthenticatedDoctor(id:'doctor-a',name:'Dr A',
      email:'a@example.com',role:'junior');
    final result=await store.validatePersonalMonth(DateTime(2027,6),{11:'garde'});
    expect(result,contains('collègue'));
    expect(store.juniorOn(date)?.id,colleague);
  });

  test('Congé validé puis retiré en conservant les autres affectations', () async {
    final store=AppStore();
    store.activateAuthenticatedDoctor(id:'doctor-a',name:'Dr A',
      email:'a@example.com',role:'junior');
    final month=DateTime(2027,7);
    final date=DateTime(2027,7,14);
    expect(await store.validatePersonalMonth(month,{14:'conge'}),isNull);
    expect(store.myLeave(date),isNotNull);
    expect(await store.validatePersonalMonth(month,{14:null}),isNull);
    expect(store.myLeave(date),isNull);
    expect(store.seniorOnName(DateTime(2026,10,29)),'LAFKIH');
  });
}
