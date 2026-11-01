# VISCERA — Intégration de l'identité visuelle

La marque unique de VISCERA est utilisée par l'application Flutter Android/iOS, le Web
et les icônes natives de lancement.

## Sources versionnées

- assets/branding/viscera-symbol.svg : monogramme V bleu canard/turquoise (fonds clairs).
- assets/branding/viscera-symbol-light.svg : même monogramme V blanc/turquoise (fonds sombres).
- lib/branding.dart : VisceraMark, VisceraBrandLockup, VisceraPageTitle.
- lib/theme.dart : palette VISCERA.
- tool/apply_viscera_branding.py : génération des icônes natives depuis le même symbole.

Les SVG proviennent d'une vectorisation simplifiée du symbole validé dans le kit de marque.
Garder cette source commune pour tous les exports : ne pas dessiner une autre icône au fil des écrans.

## Compilation Android et Web (GitHub Actions)

La CI .github/workflows/android-apk.yml exécute :

1. flutter create --platforms=android,web --project-name viscera --org com.viscera .
2. python3 -m pip install cairosvg
3. python3 tool/apply_viscera_branding.py
4. Configuration Firebase, liens et rappels Android.
5. flutter pub get et flutter test.
6. flutter build apk --debug et flutter build web --release.

Les artefacts sont respectivement VISCERA-Android-debug-APK et VISCERA-Web-build.
L'APK est une **version de développement** ; il ne faut pas le distribuer comme application
hospitalière de production sans validation de sécurité et de déploiement.

Le dossier build/web contient le site à publier sur l'hébergement Web habituel.
**La CI crée les fichiers mais ne publie pas automatiquement le site.** Pour mettre à jour
une version Web déjà en ligne, déployer les fichiers reconstruits sur cet hébergeur.

## Développement local

Après création des plates-formes :

- python3 -m pip install cairosvg
- python3 tool/apply_viscera_branding.py
- flutter pub get
- flutter run -d chrome (Web) ou flutter run (Android)

Pour iOS (sur macOS) : flutter create --platforms=ios ., puis relancer
python3 tool/apply_viscera_branding.py avant flutter build ios.

## Éléments générés

- Android : mipmap de toutes densités, adaptive icon, round icon, écran de démarrage.
- iOS : toutes les tailles AppIcon standard (après flutter create).
- Web : favicon.png, apple-touch-icon.png, icônes 192/512 et maskables,
  manifest.json PWA et titre du navigateur.
- Écrans Flutter : widgets réutilisables, identiques sur Android, iOS et Web.

## Contrôles visuels après compilation

Vérifier l'icône sur l'écran d'accueil Android, la page de connexion, l'en-tête de chacun
des écrans, le tiroir de navigation et le favicon dans un navigateur.
Pour une PWA déjà installée, vider le cache de l'application et réinstaller si l'icône
précédente est encore affichée.

Ne jamais introduire de nom de patient ou de données cliniques dans le logo, les
captures publiques, le manifeste ou les métadonnées de l'application.
