import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart' show enableFirebasePush;
import 'web_push_bridge_stub.dart'
    if (dart.library.js_interop) 'web_push_bridge.dart' as webPush;

// VAPID public key: may safely be included in a browser build.
const _webVapidKey =
    'BJs9ZZznB-Qm8vnm0y9kcHwOcVI9FutA8ueRaQ-V0Cq39D2qm32-YX2ODwi6j4KIc8lobRXtyhYxZewMQi2Dvs8';

Future<void> unregisterCurrentPushDevice() async {
  if (!enableFirebasePush) return;
  try {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    if (kIsWeb) {
      final token = webPush.currentToken();
      if (token != null) {
        await client.from('push_devices')
            .delete().eq('user_id', user.id).eq('token', token);
      }
      await webPush.deleteToken();
    } else {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await client.from('push_devices')
            .delete().eq('user_id', user.id).eq('token', token);
      }
      await FirebaseMessaging.instance.deleteToken();
    }
  } catch (_) {
    // Logging out must not expose tokens or prevent the session from closing.
  }
}

class PushDeviceRegistration extends StatefulWidget {
  const PushDeviceRegistration({super.key, required this.child});
  final Widget child;

  @override
  State<PushDeviceRegistration> createState() =>
      _PushDeviceRegistrationState();
}

class _PushDeviceRegistrationState extends State<PushDeviceRegistration> {
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _foreground;
  final FlutterLocalNotificationsPlugin _systemNotifications =
      FlutterLocalNotificationsPlugin();
  bool _showWebOptIn = false;
  bool _requestingWebPermission = false;

  @override
  void initState() {
    super.initState();
    if (enableFirebasePush) unawaited(_register());
  }

  Future<void> _saveToken(String token, String platform) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || token.isEmpty) return;
    await client.from('push_devices').upsert({
      'token': token,
      'user_id': user.id,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  // FCM ne montre pas automatiquement la bannière Android au premier plan.
  // Les données cliniques sont absentes du payload serveur, et la visibilité
  // privée préserve le contenu de l'alerte sur l'écran verrouillé.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final notification = message.notification;
    if (notification == null) return;
    final identifier =
        message.data['notification_id'] ?? message.messageId ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final stableId = identifier.codeUnits.fold<int>(
      0, (hash, value) => (hash * 31 + value) & 0x7fffffff);
    try {
      await _systemNotifications.show(
        stableId,
        notification.title ?? 'VISCERA',
        notification.body ?? 'Nouvelle notification de service.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'viscera_events_v1',
            'Notifications VISCERA',
            channelDescription: 'Mises à jour du programme opératoire et du service',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.private,
          ),
        ),
      );
    } catch (_) {
      // Une notification impossible à afficher ne doit jamais bloquer l'app.
    }
  }

  Future<void> _register({bool interactive = false}) async {
    try {
      if (kIsWeb) {
        final permission = webPush.permission();
        if (permission == 'unsupported' || permission == 'denied') {
          // Browser permissions must be changed in the browser settings.
          return;
        }
        if (permission != 'granted' && !interactive) {
          if (mounted) setState(() => _showWebOptIn = true);
          return;
        }
        final token = await webPush.subscribe(_webVapidKey);
        if (token == null || token.isEmpty) {
          throw StateError('Le navigateur n\'a pas fourni de jeton FCM.');
        }
        await _saveToken(token, 'web');
        if (mounted) setState(() => _showWebOptIn = false);
        return;
      }

      final fm = FirebaseMessaging.instance;
      final settings =
          await fm.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (Platform.isIOS && await fm.getAPNSToken() == null) return;
      // Les anciennes installations Android possédaient des jetons
      // définitivement refusés par FCM (UNREGISTERED / HTTP 404).
      // Un seul renouvellement par compte et version de réparation :
      // ne jamais réinitialiser le jeton à chaque ouverture.
      String? token;
      if (Platform.isAndroid) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;
        final prefs = await SharedPreferences.getInstance();
        final marker = 'viscera_fcm_token_repair_20261103_v1_${user.id}';
        if (prefs.getBool(marker) != true) {
          await fm.deleteToken();
          token = await fm.getToken();
          if (token != null && token.isNotEmpty) {
            await _saveToken(token, 'android');
            await prefs.setBool(marker,true);
          }
        } else {
          token = await fm.getToken();
        }
      } else {
        token = await fm.getToken();
      }
      if (token != null && token.isNotEmpty) {
        await _saveToken(token, Platform.isIOS ? 'ios' : 'android');
      }
      _refresh = fm.onTokenRefresh.listen((token) =>
          unawaited(_saveToken(token, Platform.isIOS ? 'ios' : 'android')));
      if (Platform.isAndroid) {
        try {
          await _systemNotifications.initialize(
            const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            ),
          );
          await _systemNotifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(
                const AndroidNotificationChannel(
                  'viscera_events_v1',
                  'Notifications VISCERA',
                  description: 'Mises à jour du programme opératoire et du service',
                  importance: Importance.high,
                ),
              );
        } catch (_) {
          // Garder FCM et le dossier clinique utilisables même sans canal local.
        }
      }
      _foreground = FirebaseMessaging.onMessage.listen((message) {
        unawaited(_showForegroundNotification(message));
      });
    } catch (_) {
      // Web push errors must not block the medical app.
      if (interactive && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text(
            'Activation impossible. Vérifiez les autorisations du navigateur '
            'et la configuration Firebase, puis réessayez.',
          )),
        );
      }
    }
  }

  Future<void> _enableWebPush() async {
    if (_requestingWebPermission) return;
    setState(() => _requestingWebPermission = true);
    try {
      await _register(interactive: true);
    } finally {
      if (mounted) setState(() => _requestingWebPermission = false);
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _foreground?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (kIsWeb && enableFirebasePush && _showWebOptIn)
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Material(
              elevation: 5,
              borderRadius: BorderRadius.circular(12),
              child: FilledButton.icon(
                onPressed: _requestingWebPermission ? null : _enableWebPush,
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(_requestingWebPermission
                    ? 'Activation en cours…'
                    : 'Activer les notifications VISCERA'),
              ),
            ),
          ),
        ),
    ],
  );
}
