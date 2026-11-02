import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

/// Alarmes de gardes personnelles : sans identifiant ni dossier patient.
class DutyAlarmPreferences {
  const DutyAlarmPreferences({
    this.enabled = true, this.previousDay = true, this.sameDay = true,
    this.previousHour = 18, this.sameDayHour = 7,
  });
  final bool enabled, previousDay, sameDay;
  final int previousHour, sameDayHour;

  DutyAlarmPreferences copyWith({
    bool? enabled, bool? previousDay, bool? sameDay,
    int? previousHour, int? sameDayHour,
  }) => DutyAlarmPreferences(
    enabled: enabled ?? this.enabled, previousDay: previousDay ?? this.previousDay,
    sameDay: sameDay ?? this.sameDay,
    previousHour: previousHour ?? this.previousHour,
    sameDayHour: sameDayHour ?? this.sameDayHour,
  );
}

String _alarmKey(String userId) => 'viscera_duty_alarms_v2_$userId';
bool get dutyAlarmSupported => !kIsWeb && Platform.isAndroid;

Future<DutyAlarmPreferences> loadDutyAlarmPreferences(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  final key = _alarmKey(userId);
  return DutyAlarmPreferences(
    enabled: prefs.getBool('${key}_enabled') ?? true,
    previousDay: prefs.getBool('${key}_previous') ?? true,
    sameDay: prefs.getBool('${key}_today') ?? true,
    previousHour: prefs.getInt('${key}_previousHour') ?? 18,
    sameDayHour: prefs.getInt('${key}_sameDayHour') ?? 7,
  );
}

Future<void> saveDutyAlarmPreferences(String userId, DutyAlarmPreferences settings) async {
  final prefs = await SharedPreferences.getInstance();
  final key = _alarmKey(userId);
  await prefs.setBool('${key}_enabled', settings.enabled);
  await prefs.setBool('${key}_previous', settings.previousDay);
  await prefs.setBool('${key}_today', settings.sameDay);
  await prefs.setInt('${key}_previousHour', settings.previousHour);
  await prefs.setInt('${key}_sameDayHour', settings.sameDayHour);
}

int dutyAlarmId(DateTime day, int slot) =>
    (day.year * 10000 + day.month * 100 + day.day) * 4 + slot;

List<DateTime> plannedDutyDays(DateTime month, bool Function(DateTime) isMyDuty) =>
    List<DateTime>.generate(DateTime(month.year, month.month + 1, 0).day,
      (index) => DateTime(month.year, month.month, index + 1))
        .where(isMyDuty).toList();

Future<FlutterLocalNotificationsPlugin> _notifications() async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@drawable/viscera_notification'),
  ));
  timezone_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Casablanca'));
  return plugin;
}

Future<String> scheduleDutyReminders(DateTime month, List<DateTime> dates, {
  DutyAlarmPreferences settings = const DutyAlarmPreferences(),
}) async {
  if (!dutyAlarmSupported) {
    return 'Alarmes locales Android uniquement. Les réglages restent disponibles.';
  }
  final plugin = await _notifications();
  final totalDays = DateTime(month.year, month.month + 1, 0).day;
  for (var day = 1; day <= totalDays; day++) {
    final date = DateTime(month.year, month.month, day);
    await plugin.cancel(dutyAlarmId(date, 0));
    await plugin.cancel(dutyAlarmId(date, 1));
    // Nettoyage des anciens IDs de rappel.
    await plugin.cancel((date.year * 10000 + date.month * 100 + date.day) * 2);
    await plugin.cancel((date.year * 10000 + date.month * 100 + date.day) * 2 + 1);
  }
  if (!settings.enabled || (!settings.previousDay && !settings.sameDay)) {
    return 'Alarmes de garde désactivées pour ce mois.';
  }
  final android = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (await android?.requestNotificationsPermission() != true) {
    return 'Autorisez les notifications de VISCERA dans les paramètres Android.';
  }
  bool exact = false;
  try {
    exact = await android?.requestExactAlarmsPermission() == true;
  } catch (_) {
    exact = false;
  }
  final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;
  const details = NotificationDetails(android: AndroidNotificationDetails(
    'viscera_service_duty_v2', 'Alarmes de garde',
    channelDescription: 'Gardes de service personnelles, sans données patient',
    importance: Importance.high, priority: Priority.high,
  ));
  final now = tz.TZDateTime.now(tz.local);
  var count = 0;
  for (final date in dates.toSet()) {
    if (date.year != month.year || date.month != month.month) continue;
    final previous = DateTime(date.year, date.month, date.day - 1);
    final before = tz.TZDateTime(tz.local, previous.year, previous.month,
        previous.day, settings.previousHour);
    final sameDay = tz.TZDateTime(tz.local, date.year, date.month,
        date.day, settings.sameDayHour);
    if (settings.previousDay && before.isAfter(now)) {
      await plugin.zonedSchedule(dutyAlarmId(date, 0), 'VISCERA · Garde demain',
          'Garde de service de 24 h prévue demain.', before, details,
          androidScheduleMode: mode);
      count++;
    }
    if (settings.sameDay && sameDay.isAfter(now)) {
      await plugin.zonedSchedule(dutyAlarmId(date, 1), 'VISCERA · Garde aujourd’hui',
          'Garde de service de 24 h prévue aujourd’hui.', sameDay, details,
          androidScheduleMode: mode);
      count++;
    }
  }
  if (count == 0) return 'Aucune garde future à rappeler ce mois.';
  return '$count rappels programmés${exact ? '' : ' (heures approximatives selon Android)'}.';
}

/// Nettoie les rappels de gardes VISCERA au changement de compte.
Future<void> cancelAllDutyReminders() async {
  if (!dutyAlarmSupported) return;
  final plugin = await _notifications();
  final requests = await plugin.pendingNotificationRequests();
  for (final request in requests) {
    if (request.title?.startsWith('VISCERA · Garde') == true) {
      await plugin.cancel(request.id);
    }
  }
}

/// Vérifie les permissions et le canal audio/visuel sur un téléphone réel.
Future<String> testDutyAlarm() async {
  if (!dutyAlarmSupported) return 'Test local disponible uniquement sur Android.';
  final plugin = await _notifications();
  final android = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (await android?.requestNotificationsPermission() != true) {
    return 'Autorisez les notifications VISCERA dans les paramètres Android.';
  }
  await plugin.show(30112026, 'VISCERA · Test des alarmes',
    'Vos alarmes de garde sont autorisées sur cet appareil.',
    const NotificationDetails(android: AndroidNotificationDetails(
      'viscera_service_duty_v2', 'Alarmes de garde',
      channelDescription: 'Rappels personnels de garde de service',
      importance: Importance.high, priority: Priority.high,
    )));
  return 'Notification de test envoyée à Android.';
}
