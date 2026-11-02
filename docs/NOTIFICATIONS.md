# VISCERA — Alarmes locales et notifications push

## Ce qui est opérationnel dans le code
- Écran **Alarmes et notifications** dans le menu latéral et depuis le planning.
- Deux rappels locaux facultatifs : la veille (18 h par défaut), jour J (7 h par défaut).
- Préférences par compte médical sur chaque appareil Android ; reprogrammation des 3 prochains mois.
- Suppression des anciens rappels à la déconnexion ou après modification des réglages.
- Centre de notifications personnel, lecture sécurisée par RLS.
- Push Firebase enregistré sur le téléphone Android, y compris rotation du jeton.
- Push foreground affiché en texte générique ; clic vers le centre de notifications.

## Événements du service qui produisent une notification
1. Un programme opératoire nouveau devient courant : médecins juniors/seniors approuvés, si activé.
2. Une admission manuelle des urgences/immediate est créée : seniors approuvés uniquement, si activé (sauf son auteur).
3. Un compte demande une validation : administrateurs approuvés.
4. Un compte reçoit un statut approuvé, rejeté ou désactivé : propriétaire du compte.

Le backend ne place **aucun nom, date de naissance, acte opératoire ni ID patient**
dans le titre, corps ou les données FCM. Une alerte sert à ouvrir l'application
et à consulter les détails après authentification.

Les notifications « dossier à compléter », « document de sortie manquant »
et « transfert de lit » ne sont volontairement PAS diffusées globalement :
la cible médicale responsable doit d'abord être identifiée de manière fiable,
et les états du dossier structurés. Ne jamais appeler une notification critique
une garantie de prise en charge : VISCERA n'est pas un système d'alarme clinique certifié.

## Activer l'expédition automatique FCM (configuration manquante)
Les événements sont enregistrés côté Supabase et visibles dans le centre de notifications.
Le worker Edge Function `viscera-push-dispatch` est déployé et protégé par JWT
service_role, mais il ne peut pas envoyer tant que les deux secrets suivants ne
sont pas configurés par l'administrateur :

1. **Supabase Edge Function Secrets** : `FIREBASE_SERVICE_ACCOUNT_JSON`.
   Créer un compte de service Firebase à privilèges minimaux autorisé à
   envoyer des messages FCM HTTP v1, puis fournir le JSON complet comme secret
   sur https://supabase.com/dashboard/project/qkupckqgczdqiwxozxko/functions/secrets.
   Ne jamais inclure sa clé dans GitHub, Flutter, le chat ou le dépôt public.
2. **GitHub repository > Settings > Secrets and variables > Actions** :
   `VISCERA_SUPABASE_SERVICE_ROLE_KEY`. Le workflow planifié
   `.github/workflows/viscera-push-dispatch.yml` utilise ce secret pour appeler
   l'Edge Function toutes les cinq minutes (GitHub schedule n'est pas garanti
   à la minute près). Le workflow schedule ne s'exécute que sur la branche par défaut
   après fusion du code.

Après configuration : déclencher le workflow GitHub manuellement,
vérifier les sorties sans token ni donnée patient, et envoyer une notification
de test non clinique à un utilisateur de test approuvé. Vérifier sur téléphone
physique qu'une notification arrive en arrière-plan et que le clic ouvre la boîte.

## Recommandations qualité
- La messagerie n'est pas garantie en temps réel : réseau et économie de batterie
  Android peuvent retarder les messages. En cas d'urgence vitale, utiliser
  les circuits hospitaliers d'appel habituels.
- En cas de changement de garde, le planning personnel local est resynchronisé
  lors de sa validation ; ne pas considérer une garde locale comme une attribution
  serveur confirmée par l'administrateur.
- Déployer le site Web et l'APK après les vérifications ; ne pas écrire
  d'identifiants patients dans les logs ni envoyer de notifications sans destinataires autorisés.
