import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart' show enableFirebasePush;

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
      _foreground = FirebaseMessaging.onMessage.listen((message) {
        // Aucune donnée clinique dans la notification.
      });
    } catch (_) {
      // L'indisponibilité du push ne bloque pas l'application.
    }
  }

  @override
  void dispose() { _refresh?.cancel(); _foreground?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) => widget.child;
}
