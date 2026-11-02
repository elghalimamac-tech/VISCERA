import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart' show enableFirebasePush;
import 'screens/notification_inbox.dart';

Future<void> unregisterCurrentPushDevice() async {
  if (!enableFirebasePush) return;
  try {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await client.from('push_devices').delete().eq('user_id',user.id).eq('token',token);
    }
    await FirebaseMessaging.instance.deleteToken();
  } catch (_) {
    // Les notifications ne doivent jamais contenir de données patient.
  }
}

class PushDeviceRegistration extends StatefulWidget {
  const PushDeviceRegistration({super.key, required this.child});
  final Widget child;
  @override State<PushDeviceRegistration> createState() => _PushDeviceRegistrationState();
}

class _PushDeviceRegistrationState extends State<PushDeviceRegistration> {
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  @override void initState() {
    super.initState();
    if (enableFirebasePush) unawaited(_register());
  }

  Future<void> _saveToken(String token) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || token.isEmpty) return;
    await client.from('push_devices').upsert({
      'token': token,
      'user_id': user.id,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  Future<void> _register() async {
    try {
      final fm = FirebaseMessaging.instance;
      final settings = await fm.requestPermission(alert:true, badge:true, sound:true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (Platform.isIOS && await fm.getAPNSToken() == null) return;
      final token = await fm.getToken();
      if (token != null) await _saveToken(token);
      _refresh = fm.onTokenRefresh.listen((token) => unawaited(_saveToken(token)));
      await _local.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      _foreground = FirebaseMessaging.onMessage.listen((message) async {
        // Le texte est choisi localement, jamais le payload du serveur (pas de PHI).
        final kind = message.data['kind'];
        const title = 'VISCERA · Nouvelle notification';
        final text = switch (kind) {
          'urgent_admissions' => 'Une admission urgente est à vérifier dans VISCERA.',
          'program_updates' => 'Le programme opératoire a été actualisé.',
          'access_updates' => 'Consultez le statut de votre compte VISCERA.',
          _ => 'Consultez le centre de notifications VISCERA.',
        };
        try {
          await _local.show(
            DateTime.now().millisecondsSinceEpoch.remainder(100000000),
            title, text,
            const NotificationDetails(android: AndroidNotificationDetails(
              'viscera_push_v1', 'Notifications VISCERA',
              importance: Importance.high, priority: Priority.high)),
          );
        } catch (_) {
          // Le centre de notifications reste accessible même si l'OS bloque l'alerte.
        }
      });
      _opened = FirebaseMessaging.onMessageOpenedApp.listen((_) => _openInbox());
      final launchMessage = await fm.getInitialMessage();
      if (launchMessage != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openInbox());
      }
    } catch (_) {
      // L'indisponibilité du push ne bloque pas l'application.
    }
  }

  void _openInbox() {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const NotificationInboxPage()));
  }

  @override
  void dispose() { _refresh?.cancel(); _foreground?.cancel(); _opened?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) => widget.child;
}
