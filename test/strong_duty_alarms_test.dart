import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/duty_reminders.dart';
void main() {
  test('Alarme forte par défaut et heures historiques conservées', () {
    const prefs = DutyAlarmPreferences();
    expect(prefs.enabled, isTrue);
    expect(prefs.loudFullScreen, isTrue);
    expect(prefs.previousDay, isTrue);
    expect(prefs.sameDay, isTrue);
    expect(prefs.previousHour, 18);
    expect(prefs.sameDayHour, 7);
  });
  test('Le mode discret reste un choix explicite de chaque médecin', () {
    final reduced = const DutyAlarmPreferences().copyWith(
        loudFullScreen: false, sameDayHour: 6);
    expect(reduced.loudFullScreen, isFalse);
    expect(reduced.sameDayHour, 6);
    expect(reduced.previousHour, 18);
    expect(reduced.enabled, isTrue);
  });
  test('Identifiants indépendants pour les rappels de la veille et jour J', () {
    final day = DateTime(2026,11,4);
    expect(dutyAlarmId(day,0), isNot(dutyAlarmId(day,1)));
    expect(dutyAlarmId(day,1), isNot(dutyAlarmId(DateTime(2026,11,5),0)));
  });
}
