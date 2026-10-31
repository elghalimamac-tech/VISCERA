# VISCERA

Application mobile Flutter de coordination du service de chirurgie viscérale (prototype de développement).

## Architecture

- Flutter : application Android/iOS
- Supabase VISCERA : authentification, profils junior/senior, approbation administrative, jetons des appareils
- Firebase Cloud Messaging : notifications push, à configurer
- GitHub Actions : compilation d'un APK de développement

## État du projet

Le dépôt privé est initialisé pour recevoir les sources complètes V14. Elles ne sont PAS ENCORE importées. Le workflow Android est manuel et nécessite tous les fichiers Flutter (lib/, pubspec.yaml, test/, etc.).

Projet Supabase : qkupckqgczdqiwxozxko
URL Supabase : https://qkupckqgczdqiwxozxko.supabase.co

Les tables doctor_profiles et push_devices sont créées, avec RLS activée. La synchronisation des gardes/congés et la connexion Firebase nécessitent un travail supplémentaire.

## Confidentialité et sécurité

Ne jamais committer de clé service_role, token Firebase Admin, mot de passe ou dossier patient réel. L'utilisation clinique nécessite audit et autorisations institutionnelles.

## Compilation

Après import des fichiers Flutter complets : Actions > VISCERA Android APK (manuel) > Run workflow. Le workflow teste le projet et produit un APK de débogage (non destiné à une distribution hospitalière).
