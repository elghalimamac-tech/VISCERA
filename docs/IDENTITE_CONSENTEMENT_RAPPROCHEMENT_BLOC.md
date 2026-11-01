# VISCERA — identités, consentement et rapprochement du programme opératoire

## Champs ajoutés à l'admission
- **Date de naissance** : obligatoire, sélectionnée dans un calendrier ; l'âge peut être calculé depuis la date.
- **Type de chirurgie** : texte obligatoire, distinct de l'intervention prévue.
- **Date et heure prévues du bloc** : champ explicite du parcours, conservé dans la fiche et la base.
- **Consentement éclairé du patient** : case « fait/vérifié » dans la checklist des documents à l'admission, distincte du bulletin d'hospitalisation et du pli confidentiel ; il faut avoir vérifié le consentement signé avant de cocher.

## Une fiche continue du patient
1. Les admissions manuelles sont enregistrées dans `manual_patient_records` (sous RLS, médecins approuvés).
2. Le programme officiel reste source de vérité pour sa ligne d'intervention.
3. Si le programme contient le même nom et la même date que le dossier de consultation, l'application ne les fusionne **pas automatiquement** : le programme n'apporte pas la date de naissance et des homonymes peuvent exister.
4. Depuis le dossier d'admission **Consultation**, utiliser **Rapprocher avec le programme du bloc**. Le médecin compare l'identité réellement vérifiée (dont la date de naissance), le service, l'intervention et la date du programme avant de confirmer.
5. Supabase enregistre la relation dans `manual_bloc_links` (auteur/date de confirmation), et la ligne opératoire liée est retirée de la liste des fiches indépendantes. Le dossier manuel original conserve ses annotations, hospitalisation, checklist et observations.
6. Si le programme possède déjà des notes cliniques propres, l'association est bloquée ; une réconciliation supervisée est nécessaire pour ne pas écraser des données.
7. En cas de programme corrigé, les lignes peuvent changer d'identifiant ; le rapprochement doit être vérifié à nouveau.
8. Après rapprochement, la date de naissance vérifiée ne peut plus être modifiée directement sans révision de la liaison d'identité.

## Homonymes
La combinaison (nom normalisé, date de naissance, date prévue du bloc) permet de bloquer les tentatives de création identiques et d'éviter de confondre deux personnes au même nom. Une date de naissance **n'est toutefois pas un identifiant hospitalier universel** ; pour la production, prévoir la saisie d'un IPP hospitalier vérifié et un processus de correction d'identité.

## Protection
- Les tables des admissions et des liens ne permettent aucun accès anonyme et sont soumises à des règles RLS.
- Les fonctions de création et de rapprochement vérifient le profil médical approuvé côté serveur.
- Les champs médicaux ne sont jamais stockés dans le dépôt public.
- Avant utilisation clinique réelle, valider les procédures et obligations d'hébergement, de confidentialité, d'audit et de sauvegarde avec l'établissement.
