import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/auth_gate.dart';
import 'theme.dart';
import 'branding.dart';
import 'store.dart';

/// Activer avec --dart-define=ENABLE_FIREBASE_PUSH=true UNIQUEMENT après flutterfire configure.
const enableFirebasePush = bool.fromEnvironment('ENABLE_FIREBASE_PUSH', defaultValue: false);

@pragma('vm:entry-point')
Future<void> _pushBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Pas de contenu clinique, pas de logs contenant des identifiants patient.
}

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appStore.restorePlanning();
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  }
  if (enableFirebasePush) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_pushBackgroundHandler);
  }
  runApp(const VisceraApp());
}

class VisceraApp extends StatelessWidget {
  const VisceraApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'VISCERA — Chirurgie',debugShowCheckedModeBanner:false,theme:visceraTheme(),
    home: supabaseUrl.isEmpty || supabasePublishableKey.isEmpty
      ? const Scaffold(body:Center(child:Padding(padding:EdgeInsets.all(24),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            VisceraBrandLockup(markSize:56),SizedBox(height:24),
            Text('Configuration VISCERA requise.\n\nAjoutez SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY lors du lancement Flutter.\n\nVoir docs/AUTH_CONFIGURATION.md.',textAlign:TextAlign.center)]))))
      : const AuthGate(),
  );
}
