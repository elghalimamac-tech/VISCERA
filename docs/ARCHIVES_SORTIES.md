# VISCERA — Archives des patients sortis

## Fenêtre « Vérification avant sortie »
La carte d'identification affiche maintenant l'**intervention chirurgicale**
exactement telle qu'enregistrée dans le dossier / programme, au-dessus du
compteur de documents de sortie. Un libellé vide reste explicitement
« Non renseignée ».

## Sortie et archives
- Après une sortie validée et persistée sur Supabase, le dossier prend l'état
  `discharged`. Le lit/box est libéré immédiatement : l'archivage ne retarde
  jamais la libération réelle du lit.
- Le dossier est **accessible immédiatement** dans le menu latéral dédié
  **Archives** (recherche par patient, intervention ou identifiant).
- Dans les listes générales **Patients / service**, un dossier sorti reste
  visible durant les **48 heures** qui suivent `dischargeAt`, avec le badge
  « Archivé ». Cela facilite les vérifications administratives de fin de séjour.
- À H+48, il disparaît **automatiquement de cette liste**, même lorsque
  l'application est ouverte. L'actualisation est recalculée au retour à
  l'application et au prochain chargement des dossiers.
- Il reste consultable dans **Archives**, et les données cliniques ne sont
  **ni supprimées, ni déplacées, ni dupliquées** : elles restent dans leurs
  tables Supabase existantes sous les autorisations des médecins approuvés.
- Les archives historiques issues du bloc sont récupérées y compris après
  le remplacement d'un programme PDF officiel (import `is_current=false`).
  Les programmes non courants sans dossier sorti ne sont pas réintroduits
  artificiellement dans les patients actifs.

## Sécurité
Ce délai de 48 heures est uniquement une règle de **visibilité** dans la
liste générale du service, et non un délai de sortie médicale. Les
permissions RLS/Supabase existantes continuent de s'appliquer.

## Contrôles
Les tests `patient_archives_test.dart` couvrent les bornes de 48 heures,
l'archive immédiate et la recherche; `discharge_floating_verification_test.dart`
vérifie l'intervention dans la fenêtre de sortie.
