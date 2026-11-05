# VISCERA — administration des comptes

## Périmètre

Le panneau « Tous les utilisateurs VISCERA » dans la page Administration
liste **toutes les identités Supabase Auth**, y compris les comptes sans
`doctor_profiles`. L'identification et la permission sont vérifiées
côté serveur à chaque action.

- **Propriétaire principal** : gestion des validations, attribution/retrait
  ADMIN, changement de mots de passe d'autres utilisateurs et suppression
  physique de comptes. Son propre compte est protégé.
- **ADMIN délégué** : accès à l'administration, lecture des utilisateurs,
  validation/désactivation des inscriptions médicales et gestion de l'équipe.
  Ni suppression définitive, ni changement de mots de passe d'autrui, ni
  attribution des droits ADMIN.
- **Médecin normal** : aucun accès aux informations des autres comptes.

Seuls les médecins **déjà approuvés** peuvent être promus ADMIN. Une nouvelle
connexion (ou actualisation des droits) peut être nécessaire pour voir le menu.

## Suppression définitive

La fenêtre oblige à retaper exactement `SUPPRIMER`. Le serveur refuse :
- toute action non émise par le propriétaire authentifié et approuvé ;
- toute suppression du propriétaire principal ;
- les comptes liés à des dossiers patients ou à des dossiers de bloc
  nécessitant une traçabilité médico-légale.

La suppression utilise `supabase.auth.admin.deleteUser(userId, false)`,
jamais la clé service_role dans Flutter. Les données liées en
`ON DELETE CASCADE` (profils, notifications, etc.) suivent la suppression.
Supabase refuse également la suppression d'un compte possédant des objets
Storage. Il faut traiter ces dépendances explicitement ; ne pas détruire des
dossiers patients pour contourner ce blocage.

## Modification de mot de passe

Seul le propriétaire peut imposer un nouveau mot de passe à un autre compte
(12 à 128 caractères, avec confirmation dans l'interface). Le mot de passe
est transféré à l'Edge Function `viscera-admin-users` sous HTTPS puis
appliqué avec `auth.admin.updateUserById`. Il ne doit jamais être journalisé,
stocké localement ou transmis dans un e-mail en clair. Informer l'utilisateur
par un canal professionnel sécurisé.

## Sécurité technique

- SQL : `viscera_admin_all_users()` et `viscera_admin_review_doctor()`.
  Leurs fonctions `SECURITY DEFINER` ont des gardes explicites sur
  `auth.uid()`, `is_admin`, `approval_status` et `approved_role`.
  Les appels anonymes n'ont pas de privilège EXECUTE.
- Edge Function : `viscera-admin-users` avec vérification JWT et
  identité du propriétaire ; opérations sensibles vérifiées sur serveur.
- L'Edge Function `viscera-send-approval-email` autorise les administrateurs
  approuvés à notifier un nouveau médecin approuvé (pas le propriétaire).
- Les droits liés à un ancien jeton d'accès peuvent rester actifs jusqu'à
  l'expiration de celui-ci. Pour une révocation urgente, prendre aussi
  les mesures de révocation des sessions appropriées et limiter la durée
  de validité des JWT.

Ne pas créer de compte test sans nécessité et ne jamais utiliser de données
de vrais patients pour vérifier les opérations administratives.
