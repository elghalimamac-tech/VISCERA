# VISCERA V12 — Authentification sécurisée

## Statut actuel (important)

Les écrans Flutter sont branchés aux méthodes **réelles** de Supabase Auth. En revanche **aucun projet VISCERA n'a été configuré ou modifié** : les projets existants `GardeFlow-R6-Validation` et `PlanningHM6` sont indépendants et ont été laissés intacts. Sans une URL et une clé publique de **nouveau projet VISCERA**, aucune inscription ni email ne peut fonctionner. Le HTML est une démonstration visuelle sans serveur ni emails réels.

**Ne pas utiliser de vraies données de patients** : les modules cliniques V11 et plannings restent des prototypes locaux non synchronisés et non autorisés à stocker des données médicales réelles.

## Backend VISCERA à préparer

1. Dans [Supabase](https://supabase.com/dashboard), créer un projet distinct nommé `VISCERA` dans une région autorisée par l'établissement et approuvée pour l'hébergement de données de santé. La création du projet n'a pas été faite ici.
2. `Authentication → Providers → Email` : **Enable Email** et surtout **Confirm email** activés. Ne pas désactiver la confirmation. Configurer la longueur minimale des mots de passe à **12**, la protection contre les tentatives abusives, CAPTCHA si nécessaire, et la durée des sessions selon la politique de sécurité du CHU.
3. Configurer un fournisseur SMTP professionnel autorisé et les modèles « Confirm signup » et « Reset password » ; le serveur email par défaut n'est pas destiné à une utilisation en production.
4. `Authentication → URL Configuration` : ajouter **Additional Redirect URLs** : `viscera://auth-callback/**` et définir le `Site URL` approprié.
5. Dans **SQL Editor**, exécuter `supabase/migrations/001_doctor_profiles.sql` **seulement dans VISCERA**. Le script met en place le profil, les rôles demandés, l'approbation par administrateur et une politique RLS de lecture par le titulaire uniquement. Ne jamais exécuter dans PlanningHM6 ou GardeFlow.
6. Créer une procédure administrative de validation des médecins : vérifier identité, rattachement au service et statut junior/senior avant d'attribuer `approved_role`. Les métadonnées de l'inscription ne suffisent jamais.
7. Vérifier les politiques RLS de chaque table de l'application **avant** toute donnée réelle. Le script fourni ne publie aucune table de patients. Les écrans médicaux restent un prototype local.

## Lancement Flutter

La version Supabase Flutter `2.18.3` exige Dart `>=3.9`. Installer un Flutter récent, puis :

```bash
flutter create --platforms=android,ios .
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://VOTRE-REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_VOTRE_CLE
```

Ne jamais mettre dans Flutter une clé `service_role` / `secret`, un mot de passe SMTP, un mot de passe administrateur, ni des tokens personnels. La clé **publishable** est publique et les autorisations doivent être assurées par RLS côté base.

## Deep links à configurer

Le lien de vérification et de récupération doit revenir dans l'application.

**Android** : dans `android/app/src/main/AndroidManifest.xml`, sous `MainActivity`, ajouter :

```xml
<intent-filter android:autoVerify="false">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="viscera" android:host="auth-callback" />
</intent-filter>
```

**iOS** : dans `ios/Runner/Info.plist`, ajouter au dictionnaire racine :

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>viscera</string></array>
  </dict>
</array>
```

Pour une publication de production, préférer des **liens universels / app links validés par domaine** plutôt qu'un schéma URL générique, afin de réduire le risque d'interception.

## Parcours

- **S'inscrire** : nom, email, rôle demandé, mot de passe et confirmation. Appel à `auth.signUp`. Confirmation email requise ; aucun accès automatique au service.
- **Confirmer son email** : lien par email via Auth → deep link `viscera://auth-callback/` → session confirmée. Réexpédition possible.
- **Se connecter** : `auth.signInWithPassword`. La lecture de `doctor_profiles` impose `approval_status='approved'` et un `approved_role` défini par l'administrateur.
- **Mot de passe oublié** : `auth.resetPasswordForEmail`, message générique évitant de révéler si le compte existe.
- **Nouveau mot de passe** : événement `passwordRecovery` → saisie → `auth.updateUser` → déconnexion → nouvelle connexion.
- **Se déconnecter** : `auth.signOut` et suppression du profil actif local. Les anciens profils locaux V11 ne donnent plus accès.

## Tests à réaliser avant production

1. Inscription avec une adresse test ; email reçu réellement ; avant clic de confirmation, accès refusé.
2. Après confirmation, compte « en attente » ; aucun accès patient.
3. Approbation depuis SQL Editor par administrateur ; actualisation puis accès à l'interface fictive.
4. Tentative de sélectionner « senior » dans le formulaire sans approbation : aucun droit supplémentaire.
5. Un utilisateur A ne peut pas lire le profil B (politique RLS).
6. Mot de passe oublié sur appareil Android et iOS : lien ouvre le bon formulaire et le changement de mot de passe fonctionne.
7. Vérifier les cas d'email invalide, lien expiré, réseau interrompu, utilisateur désactivé, reconnexion et déconnexion.
8. Vérifier anti-bruteforce, SMTP, autorisations institutionnelles, traçabilité et chiffrement avant toute utilisation clinique.

## Limite actuelle

Cette livraison ne configure ni l'hébergement, ni le SMTP, ni les autorisations cliniques des autres tables, ni la synchronisation du planning. Les tests locaux se limitent aux fichiers et à l'interface HTML. Il n'y a **pas de preuve de réception de mails réels** tant qu'un projet Supabase VISCERA n'a pas été connecté et vérifié.
