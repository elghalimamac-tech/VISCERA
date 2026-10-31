import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/store.dart';

void main(){
  LocalDoctorProfile make(String id,{bool admin=false}) =>
    LocalDoctorProfile(id:id,name:'Dr Test',email:'test@example.org',
      role:'junior',memberId:'J-1',isAdmin:admin);
  test('Seul le propriétaire approuvé voit son espace administration',(){
    expect(make('4fa3bd1b-6ee1-4b87-97eb-d18527025bc6',admin:true).isVisceraOwner,isTrue);
    expect(make('4fa3bd1b-6ee1-4b87-97eb-d18527025bc6').isVisceraOwner,isFalse);
    expect(make('00000000-0000-4000-8000-000000000012',admin:true).isVisceraOwner,isFalse);
  });
}
