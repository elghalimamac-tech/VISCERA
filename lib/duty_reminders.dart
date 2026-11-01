import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

/// Alarmes locales des gardes de SERVICE 24H validées.
/// Programmées sur le téléphone Android (heure locale du service à Casablanca).
/// Ni patient, ni dossier clinique, ni adresse e-mail dans les notifications.
Future<String> scheduleDutyReminders(DateTime month, List<DateTime> dates) async {
  if(kIsWeb) {
    return 'Installez VISCERA sur Android pour recevoir les rappels hors du navigateur.';
  }
  if(!Platform.isAndroid) {
    return 'Les rappels automatiques sont disponibles sur Android.';
  }

  final notifications=FlutterLocalNotificationsPlugin();
  await notifications.initialize(
    const InitializationSettings(
      android:AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  final android=notifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  final allowed=await android?.requestNotificationsPermission()??false;
  if(!allowed)return 'Autorisez les notifications de VISCERA dans les paramètres Android.';

  bool exact=false;
  try {
    exact=await android?.requestExactAlarmsPermission()??false;
  } catch (_) {
    exact=false;
  }
  timezone_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Casablanca'));

  const settings=NotificationDetails(
    android:AndroidNotificationDetails(
      'viscera_gardes_24h_v1',
      'Rappels des gardes VISCERA',
      channelDescription:'Rappels avant les gardes de service de 24 heures',
      importance:Importance.high,
      priority:Priority.high,
    ),
  );

  // Une paire de notifications est attachée à chaque date du mois.
  // Seuls les rappels de CE mois sont remplacés à la validation.
  final end=DateTime(month.year,month.month+1,0).day;
  final scheduled=dates.map((x)=>x.day).toSet();
  var count=0;
  final mode=exact ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;
  final now=tz.TZDateTime.now(tz.local);
  for(var day=1;day<=end;day++){
    final identifier=(month.year*10000+month.month*100+day)*2;
    await notifications.cancel(identifier);
    await notifications.cancel(identifier+1);
    if(!scheduled.contains(day))continue;
    final duty=tz.TZDateTime(tz.local,month.year,month.month,day,7);
    final before=tz.TZDateTime(tz.local,month.year,month.month,day-1,18);
    if(before.isAfter(now)){
      await notifications.zonedSchedule(
        identifier,'VISCERA · Garde demain',
        'Vous avez une garde de service de 24 h demain.',
        before,settings,androidScheduleMode:mode,
      );
      count++;
    }
    if(duty.isAfter(now)){
      await notifications.zonedSchedule(
        identifier+1,'VISCERA · Garde aujourd’hui',
        'Rappel : garde de service de 24 h aujourd’hui.',
        duty,settings,androidScheduleMode:mode,
      );
      count++;
    }
  }
  if(count==0)return 'Aucune alarme future à programmer ce mois.';
  return exact
      ? '$count rappels programmés sur Android.'
      : '$count rappels programmés (heure approximative : autorisation des alarmes exactes non accordée).';
}
