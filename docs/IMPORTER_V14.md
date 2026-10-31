# Import des sources VISCERA V14

Ce dépôt contient la configuration de compilation Android et le backend Supabase VISCERA, mais **les fichiers lib/*.dart ne sont pas encore publiés**. Le fichier source V14 disponible dans la conversation est `VISCERA_V14_sources_pour_GitHub.zip`.

Pour compléter le dépôt, extraire le ZIP puis transférer ses dossiers `lib/`, `test/` et `data/` à la racine (conserver `pubspec.yaml`, `tool/` et les workflows à jour). N'ajouter aucun secret ou donnée de patients.

La publication du code sur la branche `main` déclenchera GitHub Actions `VISCERA Android APK (debug)`. L'APK apparaît dans les artefacts de l'exécution si les tests et la compilation réussissent.

- Supabase : https://qkupckqgczdqiwxozxko.supabase.co
- Firebase : volontairement désactivé jusqu'à la configuration officielle FlutterFire/FCM.
- L'application n'est pas destinée à une utilisation clinique tant que les accès, les audits et l'approbation de l'établissement ne sont pas validés.
