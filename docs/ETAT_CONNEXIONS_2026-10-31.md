# Etat réel des connexions — 31 octobre 2026

- Supabase `qkupckqgczdqiwxozxko` : actif, RLS vérifiée, tables `doctor_profiles` et `push_devices` déployées (toutes deux vides). Les modèles de patients / lits ne sont pas persistés.
- GitHub `elghalimamac-tech/VISCERA` : l’utilisateur est reconnu comme `elghalimamac-tech` mais le connecteur GitHub reçoit HTTP 404 sur ce dépôt et ne liste **aucune installation GitHub App**. Après passage éventuel en privé, autoriser l’application ChatGPT GitHub à ce dépôt dans GitHub > Settings > Applications > Installed GitHub Apps (ou reconnecter GitHub depuis ChatGPT). La confidentialité du dépôt n’a pas été directement confirmée : un HTTP 404 seul ne prouve pas qu’il est privé.
- Firebase : application ChatGPT Firebase annoncée disponible, mais non installée/connectée au moment du contrôle. Installation et autorisation nécessitent une action de l’utilisateur.
- Le SDK Flutter n’est pas disponible dans l’environnement de construction ; aucune compilation APK n’a été réalisée.
- Les workflows ne doivent pas envoyer de données de patients vers des services tiers sans validation institutionnelle.
