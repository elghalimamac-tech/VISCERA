import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/duty_reminders.dart';

void main() {
  test('Alarm identifiers are stable and separate for each date and reminder', () {
    final today = DateTime(2026, 11, 2);
    final tomorrow = DateTime(2026, 11, 3);
    expect(dutyAlarmId(today,0), isNot(dutyAlarmId(today,1)));
    expect(dutyAlarmId(today,1), isNot(dutyAlarmId(tomorrow,0)));
    expect(dutyAlarmId(today,0), greaterThan(40000000));
  });

  test('Only confirmed duty days of a month are selected', () {
    final days = plannedDutyDays(DateTime(2026,11), (d) => d.day == 2 || d.day == 27);
    expect(days.map((d) => d.day), [2, 27]);
    expect(days.every((d) => d.month == 11), isTrue);
  });

  test('Alarm settings preserve unchanged values', () {
    const original = DutyAlarmPreferences();
    final changed = original.copyWith(previousHour: 16, sameDay: false);
    expect(changed.previousHour, 16);
    expect(changed.sameDay, isFalse);
    expect(changed.sameDayHour, 7);
    expect(changed.enabled, isTrue);
  });
}
