# VISCERA — admissions manuelles enregistrées dans Supabase

La création d'un patient depuis **Admission (+)** est désormais une opération serveur, pas une insertion temporaire dans le navigateur.

## Parcours
1. Saisir identité, origine (Urgences ou Consultation), médecin responsable, clinique, intervention, dates et affectations.
2. Choisir **Immédiate** uniquement si le patient est effectivement admis. L'option **Le jour du bloc** crée un patient **Programmé**, qui ne compte pas comme hospitalisé avant confirmation réelle.
3. Vérifier le récapitulatif puis **Enregistrer dans VISCERA**.
4. Le dossier apparaît dans Patients **uniquement si Supabase confirme la création**.
5. Au retour dans l'app ou sur un autre appareil, les admissions manuelles et les programmes officiels sont récupérés du serveur.
6. La fiche, ses observations, checklists, transferts et sorties utilisent la sauvegarde versionnée. En cas de conflit concurrent, afficher l'échec et actualiser avant de recommencer.

## Sécurité et doublons
- Nouvelle table : `public.manual_patient_records`. RLS SELECT réservée aux profils `doctor_profiles` approuvés, de rôle junior/senior. Aucun INSERT/UPDATE direct depuis l'application.
- Seules les RPC `viscera_create_manual_patient` et `viscera_save_manual_patient_record` modifient les données, après vérification serveur de l'authentification et de l'approbation.
- Contrôle automatique sur **nom normalisé + date de bloc** contre les admissions manuelles existantes et les lignes **actuelles** des programmes officiels. L'utilisateur doit alors compléter le dossier existant plutôt que créer un doublon.
- Enregistrement atomique, versions anti-écrasement, historique privé des modifications.
- Aucun nom de patient n'est ajouté aux fichiers du dépôt GitHub public.

## Limites et précautions
- Les admissions précédemment créées **uniquement en mémoire** ne peuvent pas être récupérées automatiquement.
- La comparaison nom/date est une protection de premier niveau ; une identité clinique robuste (IPP/identifiant hospitalier vérifié) reste nécessaire pour les homonymes, plusieurs séjours le même jour et les reprises opératoires.
- La réconciliation automatique des dossiers historiques avec de nouveaux fichiers officiels corrigés reste un chantier distinct.
- Aucun statut d'admission n'est déduit du fait qu'un patient figure sur un programme.
- Vérifier les autorisations de l'établissement, l'hébergement des données de santé, la conservation, la traçabilité et la gestion des droits avant usage clinique.

## Test
Le pipeline CI exécute `test/manual_admission_persistence_test.dart` et les tests existants. Un test de bout en bout avec deux comptes de médecins approuvés et un compte non approuvé reste requis.
