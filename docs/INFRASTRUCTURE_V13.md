# VISCERA V13 — Infrastructure séparée

## Avant toute mise en service

Le dépôt contient du code prêt pour configuration, **pas des comptes créés**. Les deux autres projets Supabase déjà accessibles n'ont pas été modifiés. Aucun utilisateur réel, aucune notification réelle et aucun APK n'ont été créés ou testés sur appareil par cette livraison. Ne pas saisir de données cliniques nominatives.

## Comptes et projets à créer

### 1 — Supabase
1. Se créer un compte indépendant via https://supabase.com/dashboard/sign-up (si souhaité) puis créer un **projet VISCERA** séparé. Ne réutiliser aucun projet GardeFlow/PlanningHM6.
2. Activer Authentication > Email > Confirm email et configurer SMTP externe de confiance (la version par défaut est limitée pour la production).
3. Configurer `viscera://auth-callback/**` dans les redirect URLs de Supabase, plus les liens natifs dans AndroidManifest.xml et Info.plist selon docs/AUTH_CONFIGURATION.md. Pour production, préférer un lien universel HTTPS de domaine contrôlé.
4. Exécuter dans SQL Editor `001_doctor_profiles.sql` puis `002_push_devices.sql`, après vérification des permissions.
5. Dans le projet, lire Project Settings > API : recopier **Project URL** et **publishable key seulement**. Ne jamais coller service_role, password, URL de DB, token d'accès dans un chat ou le code source.
6. Configurer la validation des nouveaux comptes : la catégorie junior/senior demandée à l'inscription ne confère **aucun droit**. Validation par administrateur requise.
7. Le projet ne contient pas encore de backend pour lits, blocs, planning ni dossiers patients : les données actuelles des écrans cliniques restent fictives et locales.

### 2 — Firebase Cloud Messaging
1. Se connecter à https://console.firebase.google.com/ via un **compte Google**, créer un projet `viscera-push` distinct et désactiver Analytics si inutile.
2. Enregistrer les applications Android/iOS avec des identifiants d'application fixes, par exemple `ma.viscera.viscera` (identifiant généré par `--org ma.viscera --project-name viscera` ; à confirmer avant publication).
3. Dans le dossier du projet Flutter, après création des plateformes natives :
   ```sh
   flutter create --platforms=android,ios --project-name viscera --org ma.viscera .
   flutter pub get
   dart pub global activate flutterfire_cli
   flutterfire configure --project=VOTRE_FIREBASE_PROJECT_ID --platforms=android,ios
   ```
4. Exécuter `python3 tool/setup_deep_links.py` après avoir créé les plateformes natives pour enregistrer le schéma `viscera://auth-callback/` sur Android et iOS. Le workflow Android le fait automatiquement.
5. Le code `main.dart` est déjà prêt à initialiser Firebase si `ENABLE_FIREBASE_PUSH=true`. La première compilation GitHub laisse les push OFF tant que le projet n'est pas configuré.
6. Pour Android 13+, obtenir l'autorisation d'afficher les notifications et vérifier les manifestes natifs produits/configurés. Pour iOS, Apple Developer + clé APNs `.p8`, capacités Push notifications et Background modes ; mettre la clé APNs dans la console Firebase, **jamais** dans GitHub public ou Flutter.
7. `push_devices` stocke les jetons des appareils liés au médecin approuvé dans Supabase. C'est **uniquement l'enregistrement**. Pour réellement envoyer des push : créer une Edge Function serveur authentifiée (ou un backend comparable) qui appelle FCM HTTP v1 ; la clé de service Google doit rester dans les secrets du serveur. Les notifications sur écran verrouillé ne doivent jamais contenir de nom de patient, résultat médical ou autre donnée de santé.
8. Après activation, tester sur un appareil Android et iOS réels. La présentation d'une notification reçue au premier plan et le nettoyage des jetons déconnectés restent à finaliser.

### 3 — GitHub et compilation
1. Créer un nouveau compte si désiré sur https://github.com/signup. Sinon une **nouvelle repository privée** suffit techniquement sur le compte GitHub existant.
2. Créer un dépôt privé `viscera-mobile` et charger le **contenu du dossier `viscera_flutter/` à la racine**. La confidentialité du dépôt est importante.
3. Dans Repository > Settings > Secrets and variables > Actions > **Variables**, créer `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY`. Ce sont des valeurs côté client, mais ne pas mettre de clés administrateur.
4. Menu Actions > `VISCERA — Android APK de test` > Run workflow. Le workflow génère la structure native Android manquante, résout les dépendances, lance les tests, puis produit `app-debug.apk` dans l'artifact `VISCERA-Android-debug-APK`.
5. Le workflow iOS manuel compile avec `--no-codesign` sur `macos-latest` mais **ne produit pas d'IPA installable**. Pour distribution iOS : compte Apple Developer, provisioning profile, certificats, signature et workflow séparé.
6. Si FCM est activé, conserver les fichiers natifs FlutterFire dans le dépôt privé et les adapter au workflow. Le workflow initial construit volontairement avec push désactivé. Ne jamais stocker une clé de compte de service Firebase ni un secret Supabase dans le code Flutter.

## Statut de la livraison
- Auth Supabase : code existant prêt pour les paramètres d'un nouveau projet, non connecté.
- Firebase : dépendances + listener de jetons FCM et enregistrement RLS préparés, mais aucun projet ni envoi réel.
- GitHub Actions : workflows APK debug et compilation iOS sans signature, non exécutés.
- Aucun APK compilé ici : Flutter SDK absent dans l'environnement de création.
- Prévoir revue juridique, autorisations institutionnelles, hébergement adapté et sécurité applicative avant de stocker toute information patient réelle.
