import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

/// Alarmes de gardes personnelles : sans identifiant ni dossier patient.
class DutyAlarmPreferences {
  const DutyAlarmPreferences({
    this.enabled = true, this.previousDay = true, this.sameDay = true,
    this.previousHour = 18, this.sameDayHour = 7,
    this.loudFullScreen = true,
  });
  final bool enabled, previousDay, sameDay, loudFullScreen;
  final int previousHour, sameDayHour;

  DutyAlarmPreferences copyWith({
    bool? enabled, bool? previousDay, bool? sameDay, bool? loudFullScreen,
    int? previousHour, int? sameDayHour,
  }) => DutyAlarmPreferences(
    enabled: enabled ?? this.enabled, previousDay: previousDay ?? this.previousDay,
    sameDay: sameDay ?? this.sameDay,
    loudFullScreen: loudFullScreen ?? this.loudFullScreen,
    previousHour: previousHour ?? this.previousHour,
    sameDayHour: sameDayHour ?? this.sameDayHour,
  );
}

const _native = MethodChannel('viscera/duty_alarm');
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
    loudFullScreen: prefs.getBool('${key}_loud') ?? true,
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
  await prefs.setBool('${key}_loud', settings.loudFullScreen);
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

Future<Map<String,dynamic>> dutyAlarmDeviceStatus() async {
  if(!dutyAlarmSupported)return {'supported':false};
  return await _native.invokeMapMethod<String,dynamic>('status') ?? {};
}

Future<void> openDutyFullScreenSettings() async {
  if(dutyAlarmSupported)await _native.invokeMethod<void>('fullScreenSettings');
}
Future<void> openDutyAlarmVolumeSettings() async {
  if(dutyAlarmSupported)await _native.invokeMethod<void>('volumeSettings');
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
  final ym = month.year.toString()+'-'+month.month.toString().padLeft(2,'0');
  if(!settings.enabled || !settings.loudFullScreen) {
    await _native.invokeMethod<int>('syncMonth',{'month':ym,'alarms':[]});
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
  final now=tz.TZDateTime.now(tz.local);
  final nativeRows=<Map<String,dynamic>>[];
  var count=0;
  for(final date in dates.toSet()){
    if(date.year!=month.year || date.month!=month.month)continue;
    final previous=DateTime(date.year,date.month,date.day-1);
    final before=tz.TZDateTime(tz.local,previous.year,previous.month,
      previous.day,settings.previousHour);
    final today=tz.TZDateTime(tz.local,date.year,date.month,
      date.day,settings.sameDayHour);
    if(settings.previousDay && before.isAfter(now)){
      nativeRows.add({'id':dutyAlarmId(date,0),
        'time':before.millisecondsSinceEpoch,
        'title':'VISCERA · Garde demain'});
    }
    if(settings.sameDay && today.isAfter(now)){
      nativeRows.add({'id':dutyAlarmId(date,1),
        'time':today.millisecondsSinceEpoch,
        'title':'VISCERA · Garde aujourd’hui'});
    }
  }
  if(settings.loudFullScreen){
    count=await _native.invokeMethod<int>('syncMonth',{
      'month':ym,'alarms':nativeRows,
    }) ?? 0;
    final device=await dutyAlarmDeviceStatus();
    final alerts=<String>[];
    if(device['fullScreen']!=true)alerts.add('autorisation plein écran requise');
    if(device['exact']!=true)alerts.add('horaires approximatifs');
    if((device['volume'] as num? ?? 0)==0)alerts.add('volume Alarme à zéro');
    return count.toString()+' alarme(s) forte(s) programmée(s)'
        +(alerts.isEmpty ? '.' : ' — '+alerts.join(', ')+'.');
  }
  final details=const NotificationDetails(android:AndroidNotificationDetails(
    'viscera_service_duty_v2','Alarmes de garde discrètes',
    channelDescription:'Notifications de garde sans sonnerie prolongée',
    importance:Importance.high,priority:Priority.high));
  for(final row in nativeRows){
    final at=tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,row['time'] as int);
    await plugin.zonedSchedule(row['id'] as int,row['title'] as String,
      'Garde de 24 h prévue.',at,details,
      androidScheduleMode:exact?AndroidScheduleMode.exactAllowWhileIdle:
        AndroidScheduleMode.inexactAllowWhileIdle);
    count++;
  }
  return count.toString()+' rappel(s) discret(s) programmé(s).';
}

/// Nettoie les rappels de gardes VISCERA au changement de compte.
Future<void> cancelAllDutyReminders() async {
  if (!dutyAlarmSupported) return;
  await _native.invokeMethod<void>('cancelAll');
  final plugin = await _notifications();
  final requests = await plugin.pendingNotificationRequests();
  for (final request in requests) {
    if (request.title?.startsWith('VISCERA · Garde') == true) {
      await plugin.cancel(request.id);
    }
  }
}

/// Lance sur ce téléphone le vrai service d'alarme et l'écran plein écran.
Future<String> testDutyAlarm() async {
  if(!dutyAlarmSupported)return 'Test disponible uniquement sur Android.';
  final plugin=await _notifications();
  final android=plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if(await android?.requestNotificationsPermission()!=true){
    return 'Autorisez les notifications de VISCERA sur Android.';
  }
  await _native.invokeMethod<void>('test');
  final status=await dutyAlarmDeviceStatus();
  if((status['volume'] as num? ?? 0)==0){
    return 'Test lancé mais volume Alarme à zéro : augmentez-le dans Android.';
  }
  return 'Test lancé. Appuyez sur ARRÊTER pour couper la sonnerie.';
}
