# VISCERA — E-mails de confirmation et de récupération
**Application :** VISCERA · Chirurgie viscérale · HUIM6 Bouskoura

## 1. Personnaliser les modèles d'e-mails
Le connecteur Supabase disponible dans ChatGPT ne permet pas d'éditer directement les réglages SMTP et les modèles d'e-mails Auth ; cette opération doit être faite dans le Dashboard par le propriétaire du projet.

Aller dans :
https://supabase.com/dashboard/project/qkupckqgczdqiwxozxko/auth/templates

- **Confirm signup** : sujet **VISCERA — Confirmez votre adresse e-mail** ; coller intégralement `emails/confirmation.html`.
- **Reset password** : sujet **VISCERA — Définissez un nouveau mot de passe** ; coller intégralement `emails/recovery.html`.
- Enregistrer **les deux**.

Ces modèles utilisent `{{ .TokenHash }}` et des liens directs vers VISCERA. Le fragment de l'URL est lu côté Flutter puis échangé via `verifyOTP` ; aucune valeur de jeton ne doit être journalisée.
Ne pas remplacer le lien par `{{ .ConfirmationURL }}` si vous souhaitez éviter le domaine du fournisseur d'authentification dans l'URL apparente.

## 2. Domaine, expéditeur et réputation
Les modèles changent le corps des e-mails et le lien, **pas** l'expéditeur SMTP.
Dans Authentication > SMTP, configurer un SMTP dédié, idéalement sur un domaine vérifié appartenant au service, avec le nom d'expéditeur VISCERA. Ne pas utiliser de domaine institutionnel sans autorisation.
Configurer DNS SPF, DKIM et DMARC du domaine. Le SMTP intégré de Supabase est limité, non prévu pour un usage de production et peut conserver son identité d'expédition.

## 3. URL du site
https://elghalimamac-tech.github.io/VISCERA/
Vérifier dans Authentication > URL Configuration :
- Site URL : https://elghalimamac-tech.github.io/VISCERA/
- Redirect URLs : https://elghalimamac-tech.github.io/VISCERA/**

## 4. Parcours
**Inscription** : l'utilisateur reçoit le mail, clique sur « Confirmer mon adresse e-mail », VISCERA vérifie le jeton à usage unique, affiche « En attente » jusqu'à approbation.

**Mot de passe oublié** : l'utilisateur indique son adresse, reçoit le mail, clique sur « Définir un nouveau mot de passe », VISCERA vérifie le jeton puis affiche deux champs de nouveau mot de passe (12 caractères minimum). Après mise à jour, déconnexion et retour à la connexion.

## 5. Vérifications avant usage
- Tester avec une nouvelle adresse de médecin de test, pas avec un patient.
- Confirmer que le mail reçu a bien le titre, l'expéditeur, le domaine et le bouton corrects.
- Vérifier un jeton expiré / déjà utilisé, l'envoi répété et la déconnexion après changement.
- Un mail visuellement « VISCERA » envoyé par Supabase SMTP n'est **pas** totalement débrandé : un SMTP personnalisé est indispensable pour l'identité d'expédition.
- Les dossiers VISCERA sont des données fictives ; ne pas introduire de données cliniques réelles sans autorisation institutionnelle, hébergement conforme et revue de sécurité.
