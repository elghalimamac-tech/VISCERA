# VISCERA — dossiers modifiables des patients programmés

Les programmes officiels du bloc sont importés depuis Gmail en XLSX dans `bloc_program_imports` / `bloc_program_entries`. Chaque ligne importée (identifiant `BLOC-<entry_id>`) ouvre désormais la fiche `PatientDetailPage`, comme une admission manuelle.

## Utilisation clinique

- **À la programmation** : nom, intervention, chirurgien, salle et heure proviennent du fichier officiel. Provenance **Consultation** ; état **Programmé** ; aucune admission, lit, âge, mutuelle, consultation datée, bilan ou durée d'hospitalisation n'est présumé.
- **Avant admission** : le staff autorisé peut remplir âge, mutuelle, date de consultation, motif, antécédents, examen, bilans, examens complémentaires, CAT, checklists et observations préopératoires. L'édition de ces champs n'atteste pas une hospitalisation.
- **Admission réelle** : le médecin sélectionne la date/heure d'arrivée et confirme explicitement l'admission ; le dossier passe en **Préopératoire**. Les actions entrée au bloc, postopératoire et sortie restent séparées.
- **Boxes et durée** : aucune affectation fictive. La durée reste inconnue tant qu'elle n'est pas renseignée.
- **Enregistrement** : les modifications du programme officiel sont conservées dans `public.bloc_patient_records` (JSONB lié à `bloc_program_entries.id`) et chargées à la connexion du staff. Les mutations passent par une RPC à contrôle optimiste de version ; le document affiche le statut de sauvegarde et un bouton de nouvel essai.
- **Accès** : lecture/écriture réservées aux médecins approuvés via RLS ; audit privé indiquant l'ID de la ligne, le médecin, la version et la date de modification. Aucun secret ni donnée nominative n'est envoyé à GitHub.

## Vigilance et limites

- Une modification concurrente sur le même dossier provoque un conflit de version (ne pas écraser silencieusement les modifications de l'autre médecin).
- Si le bloc renvoie **une nouvelle version du programme** pour le même jour, les lignes d'import reçoivent de nouveaux identifiants. Les anciens compléments cliniques sont **conservés dans la base sur l'ancienne version**, mais **ne sont pas automatiquement transférés** au nouveau dossier : une réconciliation médicale des identités sera nécessaire avant une utilisation clinique continue.
- L'enregistrement partagé concerne **les patients du programme du bloc**. Les admissions manuelles hors programme de cette version continuent d'être seulement locales. Ne pas l'interpréter comme un dossier hospitalier complet de production.
- Les modifications des checklists représentent des vérifications à documenter et ne se synchronisent pas avec Magica ou Sillage.
- Avant la mise en service clinique, obtenir l'autorisation institutionnelle, contrôler l'hébergement, les sauvegardes, l'audit, la conformité et la restauration.

## Tests d'accès et de validation

`flutter test test/bloc_clinical_record_test.dart`, `flutter test test/programmed_patient_test.dart` et tests Flutter existants. Vérifier ensuite sur deux comptes du staff approuvés : modification/relecture et conflit d'édition ; un compte en attente ne doit rien lire ni modifier.
