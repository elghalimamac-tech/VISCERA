# VISCERA — architecture multi-hôpital (HUIM6 / HUICK)

## Déploiement réel — 04/11/2026 (phase 1)

La base Supabase VISCERA **qkupckqgczdqiwxozxko** a reçu les migrations
`20261104194818_viscera_two_hospitals_boundary_phase_one` et
`20261104195258_viscera_huim6_unread_notifications_scoped`.

- Deux établissements ont été créés : `huim6` actif, `huick` en maintenance.
- Les neuf tables principales (imports et interventions, dossiers et admissions,
  liens, notifications, préférences, appareils push) possèdent désormais
  `hospital_id`, initialisé à `huim6` pour **chaque ligne historique**.
- Les nouvelles appartenances `doctor_hospital_memberships` limitent les droits
  aux médecins approuvés. L'approbation classique des comptes HUIM6 continue
  à créer automatiquement l'appartenance HUIM6. Seul l'administrateur principal
  existant est initialement membre de HUICK.
- RLS **RESTRICTIVE** en lecture/écriture, contrôle des écritures y compris
  celles provenant de fonctions `SECURITY DEFINER`, et FK composites pour
  empêcher les liens patient/programme entre deux hôpitaux.
- Flutter **HUIM6** filtre explicitement `hospital_id='huim6'` pour les
  dossiers, imports, consultations du programme, notifications et dispositifs.
- Le compteur de notifications non lues est aussi restreint à HUIM6.
- Vérifications SQL : 44 lignes d'interventions et 40 dossiers opératoires
  sont restés HUIM6, aucun enregistré sous HUICK. Un utilisateur non approuvé
  ne lit rien. Une simulation réversible d'un membre HUICK sans accès HUIM6
  n'a révélé aucune ligne HUIM6 ; l'appartenance HUIM6 a été restaurée.

**Restent hors périmètre de cette phase :** l'activation clinique de HUICK,
les imports Gmail propres à HUICK, les plannings et services par hôpital,
la segmentation future des paramètres de notifications et l'ajout d'un
paramètre `hospital_id` explicite aux RPC de création/ingestion.
Il est interdit de basculer HUICK en `active` avant que ces flux soient
adaptés et les tests multi-utilisateurs réels terminés.

## État et contraintes de sécurité

- **HUIM6 Bouskoura** est l'établissement actif. Toute donnée enregistrée **avant** la mise en place du multi-hôpital lui appartient et doit demeurer inchangée.
- **HUICK Casablanca** est en travaux. L'écran de sélection est visible par tous ; seul l'administrateur principal approuvé peut voir l'espace de préparation. Aucun module de patient, lit, bloc, admission ni notification clinique n'est chargé dans HUICK tant que l'isolation serveur n'est pas opérationnelle.
- **Le partage porte sur le code et le design, jamais sur les dossiers.** Il n'y a ni copie HUIM6 → HUICK, ni test sur les patients réels.
- Un contrôle dans Flutter ne constitue **pas** une autorisation d'accès aux données. Les permissions doivent être appliquées côté PostgreSQL/RLS et aux fonctions RPC.
- **Version courante** : écran de sélection + verrouillage HUICK côté client. L'ouverture clinique de HUICK n'est pas implémentée.

## Parcours d'accès

### HUIM6

1. Lancement : splash VISCERA, initialisation Supabase, choix « HUIM6 Bouskoura ».
2. Connexion / inscription / récupération du mot de passe actuelles.
3. Validation de l'email puis contrôle du profil approuvé (`doctor_profiles.approval_status`, `approved_role`, `is_admin`).
4. Pour un médecin autorisé : `MainShell` existant (Accueil, Patients, Admission, Bloc, Lits ; menus Planning, Notifications, Archives, Administration si autorisé).
5. Les données existantes viennent des programmes de bloc et des dossiers d'admission manuelle, avec historique et documents cliniques conservés dans Supabase.

### HUICK (préparation)

1. Choix « HUICK Casablanca » ; affichage explicite « En travaux — accès administrateur uniquement ».
2. Seule la connexion existante est présentée (pas de création de compte HUICK).
3. Après authentification, le profil non administrateur reste sur un écran d'indisponibilité.
4. L'administrateur principal voit l'espace de préparation, sans `MainShell` ni requêtes patients.
5. Retour au choix d'établissement possible ; **aucun** patient HUIM6 n'est exposé via HUICK.

## Modèle de données cible avant l'ouverture de HUICK

Le modèle ci-dessous est une **spécification**, pas une migration déployée.

- `hospitals` : clés immuables `huim6` et `huick`, noms, statut `active` / `maintenance`.
- `doctor_hospital_memberships` : utilisateur authentifié, hôpital, rôle approuvé par l'administrateur, statut et droits. Les métadonnées utilisateur modifiables ne servent jamais à autoriser l'accès.
- `hospital_id` obligatoire sur chaque entité clinique et opérationnelle : admissions manuelles, imports de programmes, lignes de bloc, dossiers liés, associations manuel/bloc, consultations, astreintes, vacations, notifications, services, lits, paramétrage de l'équipe.
- Établir une rétrocompatibilité : les enregistrements existants reçoivent **uniquement** `hospital_id='huim6'` lors d'une migration contrôlée après sauvegarde et vérification des volumes ; ne pas supprimer/recréer les dossiers.
- Indexer les requêtes par établissement ; valider les FK entre entités du même hôpital (notamment programme → intervention → fiche clinique et association à l'admission manuelle).
- Les fonctions RPC d'admission, d'enregistrement clinique et de liaison au programme doivent dériver l'hôpital autorisé **côté serveur** et refuser toute liaison inter-hôpital. Ne pas faire confiance au seul `hospital_id` fourni par le client.
- Les politiques RLS sur SELECT / INSERT / UPDATE / DELETE doivent être séparées et garantir l'appartenance à l'établissement. Les écritures nécessitent `WITH CHECK`. Examiner les `SECURITY DEFINER` existants et les droits EXECUTE.
- Ne pas donner aux clients Flutter une clé `service_role`. Le compte administrateur principal est autorisé côté serveur, pas via un simple bouton masqué.

## Relations existantes à migrer

Tables identifiées dans les migrations et le code :

| Domaine | Tables actuelles |
| --- | --- |
| Médecins et autorisations | `doctor_profiles` |
| Bloc et import | `bloc_program_imports`, `bloc_program_entries` |
| Dossier de bloc | `bloc_patient_records` |
| Admission manuelle | `manual_patient_records` |
| Rapprochement manuel / programme | `manual_bloc_links` |
| Notifications et dispositifs | `push_devices` et tables de notifications selon la version serveur |

Les tables et fonctions du service doivent être vérifiées dans la base **réelle** avant de créer une migration. Le code est une source d'inventaire, pas une preuve de l'état de production.

## Conditions nécessaires avant d'ouvrir HUICK

1. Sauvegarde, inventaire des données et migration idempotente contrôlée vers `huim6`.
2. Tests RLS avec au moins trois profils réels de test : HUIM6, HUICK et administrateur principal. Chaque profil ne doit voir que les données autorisées.
3. Tests des RPC et des associations empêchant toute écriture/copie inter-hôpital.
4. Isolation complète de tous les flux d'import Gmail/programme, notifications, plannings et archives.
5. Préparation indépendante des services, boxes, médecins, astreintes et consultations de HUICK.
6. Activation de `MainShell` pour HUICK **uniquement après** validation de la séparation du backend ; squelette Flutter et design partagés.

### Engagement de compatibilité

Ni les identifiants patients, ni les dossiers cliniques HUIM6 existants, ni les liens vers le programme, ni l'historique des observations ne doivent être réécrits ou supprimés. La migration doit être **additive** et vérifiable avant l'ouverture de HUICK.
