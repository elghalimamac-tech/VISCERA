import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/auth_gate.dart';
import 'theme.dart';
import 'store.dart';

/// Sur Web, les push nécessitent une configuration FCM Web séparée.
/// Ne jamais initialiser Firebase sans cette configuration.
const enableFirebasePush =
    bool.fromEnvironment('ENABLE_FIREBASE_PUSH', defaultValue: false);

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

@pragma('vm:entry-point')
Future<void> _pushBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Ne jamais afficher ou journaliser de données cliniques.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Le premier écran doit être visible AVANT toute initialisation réseau.
  // Une erreur Supabase ne laisse plus le navigateur sur une page blanche.
  ErrorWidget.builder = (FlutterErrorDetails details) => const Material(
    color: Color(0xFFF5FAFB),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Une erreur d’affichage est survenue dans VISCERA. '
          'Rechargez la page pour réessayer.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF083B46), fontSize: 16),
        ),
      ),
    ),
  );
  runApp(const VisceraApp());
}

Future<void> _initializeViscera() async {
  await appStore.restorePlanning();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  if (!kIsWeb && enableFirebasePush) {
    // Les notifications ne doivent jamais empêcher l'accès aux dossiers.
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_pushBackgroundHandler);
    } catch (_) {
      // L'app reste accessible, même si Firebase n'est pas configuré.
    }
  }
}

class VisceraApp extends StatefulWidget {
  const VisceraApp({super.key});

  @override
  State<VisceraApp> createState() => _VisceraAppState();
}

class _VisceraAppState extends State<VisceraApp> {
  late final Future<void> _startup;

  @override
  void initState() {
    super.initState();
    _startup = supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty
        ? _initializeViscera()
        : Future<void>.value();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VISCERA — Chirurgie viscérale',
    debugShowCheckedModeBanner: false,
    theme: visceraTheme(),
    home: supabaseUrl.isEmpty || supabasePublishableKey.isEmpty
        ? const _StartupMessage(
            'Configuration VISCERA requise.\n\n'
            'Les paramètres de connexion ne sont pas présents dans '
            'cette version. Contactez l’administrateur.',
          )
        : FutureBuilder<void>(
            future: _startup,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _StartupMessage(
                  'Impossible de démarrer VISCERA.\n\n'
                  'Vérifiez la connexion, puis actualisez la page. '
                  'Si le problème persiste, contactez l’administrateur.',
                  isError: true,
                );
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text('Chargement sécurisé de VISCERA…'),
                      ],
                    ),
                  ),
                );
              }
              return const AuthGate();
            },
          ),
  );
}

class _StartupMessage extends StatelessWidget {
  const _StartupMessage(this.message, {this.isError = false});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_hospital_outlined,
                    size: 52, color: Color(0xFF083B46)),
                const SizedBox(height: 16),
                const Text('VISCERA',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                        color: Color(0xFF083B46))),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center),
                if (isError) ...[
                  const SizedBox(height: 16),
                  const Text('Aucune donnée patient n’a été chargée.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
