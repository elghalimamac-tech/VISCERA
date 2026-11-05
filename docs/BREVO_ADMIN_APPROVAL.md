# VISCERA — validation administrative et Brevo

## Parcours (05 novembre 2026)
- Les deux hôpitaux partagent la même marque VISCERA. Le sous-titre commun est « CHIRURGIE VISCÉRALE · DEUX HÔPITAUX ».
- Après inscription : **Vérification par un admin nécessaire**. Pas d'écran de confirmation e-mail ni de bouton de renvoi de confirmation.
- Le compte reste sans accès aux patients tant que `doctor_profiles.approval_status` n'est pas `approved` avec un `approved_role` autorisé.
- Sur l'écran Administration, une approbation effective appelle l'Edge Function `viscera-send-approval-email`, qui vérifie à nouveau l'admin, confirme si nécessaire les anciens comptes Supabase Auth et envoie « Votre compte a été validé » via Brevo.
- La file d'envoi `viscera_approval_email_jobs` est ajoutée au moment exact de la transition `pending/disabled → approved`. Elle n'envoie jamais pour un compte non approuvé. Elle conserve les tentatives non envoyées ; l'admin a un bouton « Réessayer le mail ».
- Brevo est toujours appelé depuis l'Edge Function. **Ne jamais exposer la clé API Brevo ni la clé service-role dans Flutter ou GitHub.**

## Étape de paramétrage nécessaire dans Supabase Auth
Dans le projet VISCERA `qkupckqgczdqiwxozxko`, ouvrir
**Authentication → Sign In / Providers → Email**, puis **désactiver « Confirm email »** et enregistrer.
Cette option est un réglage Auth hébergé : elle n'est pas remplacée par la migration SQL.
La désactivation signifie que l'adresse e-mail déclarée n'est plus prouvée par un lien ; l'admin doit donc vérifier l'identité et la qualité de médecin avec une procédure indépendante.

## Configuration Brevo
1. Dans Brevo, créer et vérifier un expéditeur institutionnel. Authentifier le domaine d'envoi (SPF/DKIM/DMARC) pour éviter les spams. Ne pas utiliser le login SMTP comme adresse d'expédition.
2. Dans Brevo **SMTP & API**, créer une **clé API v3** pour l'Edge Function d'approbation. Ne pas la coller dans les sources de l'application.
3. Dans Supabase **Edge Functions → Secrets**, enregistrer :
   - `BREVO_API_KEY` : la clé API v3 Brevo ;
   - `BREVO_SENDER_EMAIL` : adresse expéditrice vérifiée ;
   - `BREVO_SENDER_NAME` : VISCERA (facultatif).
4. Pour les e-mails Supabase Auth de récupération de mot de passe, configurer séparément **Authentication → SMTP Settings** :
   - Host `smtp-relay.brevo.com` ;
   - Port `587` ;
   - Username : identifiant SMTP fourni par Brevo ;
   - Password : **clé SMTP Brevo**, différente de la clé API v3 ;
   - Sender email : la même adresse vérifiée ; Sender name : VISCERA.
5. Tester avec un compte de test (aucune donnée patient) : inscription → en attente → approbation admin → e-mail « Votre compte a été validé » → connexion fonctionnelle ; puis mot de passe oublié via SMTP.
6. Si un e-mail échoue, vérifier les journaux de `viscera-send-approval-email`, la clé API, le domaine et la liste `viscera_approval_email_jobs`. L'approbation reste acquise et le bouton de reprise ne crée pas de deuxième approbation.

## Restrictions de sécurité
- Uniquement l'admin principal peut valider un médecin ou demander le mail de validation.
- La vérification et les droits sont contrôlés côté serveur, jamais via `raw_user_meta_data` ou un simple champ du formulaire.
- La table de file d'envoi est sous RLS et inaccessible aux rôles client `anon/authenticated`.
- Aucun secret Brevo dans le code ou les URL ; les envois ne démarrent réellement qu'une fois les secrets et l'expéditeur renseignés.
