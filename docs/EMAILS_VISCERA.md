# VISCERA — Confirmation et récupération d'e-mail

## Correctif logiciel

Les inscriptions, renvois de confirmation et demandes de nouveau mot de passe
utilisent désormais **la même URL HTTPS**, ouvrable même si l'application
Android n'est pas installée :
`https://elghalimamac-tech.github.io/VISCERA/`

Les modèles HTML sont versionnés dans `emails/confirmation.html` et
`emails/recovery.html`. Ils utilisent `{{ .TokenHash }}` dans le fragment
`#token_hash=...&type=signup` ou `type=recovery` : le jeton n'est pas
transmis à l'hébergement de GitHub Pages. L'application le valide via
Supabase Auth (`verifyOTP`). Les anciens liens expirés peuvent demander un
renvoi depuis l'écran de confirmation.

**Attention : modifier un fichier dans GitHub ne modifie PAS les modèles ni
l'expéditeur actifs dans Supabase Auth. Les étapes suivantes sont obligatoires.**

## À terminer dans le Dashboard Supabase (administrateur du projet)

1. Ouvrir [Authentication → URL Configuration](https://supabase.com/dashboard/project/qkupckqgczdqiwxozxko/auth/url-configuration).
   - **Site URL** : `https://elghalimamac-tech.github.io/VISCERA/`
   - **Redirect URLs** : ajouter `https://elghalimamac-tech.github.io/VISCERA/`
     (et, uniquement si nécessaire, `https://elghalimamac-tech.github.io/VISCERA/**`).
   - Retirer tout ancien `localhost` utilisé comme Site URL de production.
   - Conserver éventuellement `viscera://auth-callback/**` pour compatibilité
     avec d'anciens liens, sans l'utiliser pour les nouveaux e-mails.
   **Attention Supabase 2026 :** sur certains projets Free créés après
   juin 2026, les modèles du SMTP fourni par défaut ne sont pas éditables.
   Dans ce cas, activer d'abord un SMTP personnalisé vérifié avant de
   pouvoir enregistrer les deux modèles ci-dessous.

2. Ouvrir [Authentication → Email Templates](https://supabase.com/dashboard/project/qkupckqgczdqiwxozxko/auth/templates).
   - **Confirm signup** : sujet « VISCERA — Confirmez votre adresse e-mail »,
     corps complet de `emails/confirmation.html`.
   - **Reset password** : sujet « VISCERA — Réinitialisation du mot de passe »,
     corps complet de `emails/recovery.html`.
   - Enregistrer les deux. Ne pas remplacer `{{ .TokenHash }}` par un
     code copié depuis un e-mail reçu.
3. Ouvrir [Authentication → SMTP](https://supabase.com/dashboard/project/qkupckqgczdqiwxozxko/auth/smtp).
   - Choisir un fournisseur SMTP transactionnel reconnu, via un domaine
     autorisé et **contrôlé** par le service ; définir `From` et
     `Sender name: VISCERA`.
   - Vérifier la propriété du domaine avec le fournisseur SMTP puis appliquer
     les enregistrements **SPF, DKIM et DMARC** qu'il fournit.
   - Éviter le serveur SMTP intégré de Supabase pour une application réelle,
     le suivi publicitaire des liens, les raccourcisseurs d'URL et
     l'utilisation sans autorisation d'un domaine institutionnel.
   - Les mots de passe SMTP restent uniquement dans Supabase ; jamais dans
     Flutter, GitHub, un e-mail ni un ticket de support.

Les filtres anti-spam des destinataires prennent en compte la réputation
d'expédition, le domaine et l'authentification du courriel. **Le seul
changement du modèle HTML ne garantit pas la sortie du dossier Spam.**

## Test de bout en bout (compte de démonstration sans données patient)

- Créer une inscription avec une adresse de test autorisée, puis ouvrir le
  dernier e-mail depuis Gmail mobile et bureau.
- Cliquer sur le bouton, confirmer l'ouverture dans le navigateur et vérifier
  l'affichage « Adresse e-mail confirmée » puis « Accès en attente ».
- Retester « Renvoyer l’e-mail de validation », un lien expiré et
  « Mot de passe oublié ».
- Vérifier dans les détails du message les statuts SPF, DKIM et DMARC ;
  mesurer la destination réelle du lien sans communiquer le jeton à autrui.
- Ne jamais désactiver la confirmation des e-mails pour contourner le problème.
