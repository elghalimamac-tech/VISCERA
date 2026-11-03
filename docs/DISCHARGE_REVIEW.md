# VISCERA — Types de chirurgie et propositions de sortie

## Uniformisation des libellés

La colonne **Intervention** du programme officiel reste inchangée :
elle conserve la preuve de la programmation initiale. Le type de chirurgie est
inféré à partir de cette colonne, y compris les abréviations du programme :
`LV`, `LV SOUS COELIO`, `HID`, `HIG`, `LOOK COELIO`, hernie inguinale,
appendicectomie, DPC, hépatectomie, résection du grêle, chirurgie colorectale
et pancréatique. Les interventions inconnues restent « Autre / à confirmer ».

Par prudence, une chirurgie associée (+), une complication ou une opération
majeure n'a **pas** le seuil J1, même si le libellé contient un geste simple.

## Proposition de sortie — règles du service

- J1 après admission **réelle** pour appendicectomie simple,
  cholécystectomie / LV simple, look cœlioscopique simple, cure de hernie simple (HID/HIG).
- Dès J4 après admission réelle pour les autres opérations.
- Une durée plus longue spécifiée dans le dossier est respectée.
- Exclusion des patients seulement programmés, préopératoires, au bloc,
  déjà sortis, ou en réanimation.
- Les alertes ne remplacent pas une évaluation clinique, les protocoles
  locaux ou la validation des documents. Le bouton de sortie garde toutes ses vérifications.

Les fenêtres sont affichées à l'ouverture de l'application après synchronisation,
puis à l'ouverture d'un dossier concerné. Aucune donnée patient n'est stockée
pour ce mécanisme dans les préférences locales ; les dossiers restent sur Supabase.

## Push

Une fonction Supabase dédiée `viscera-discharge-review` lit les dossiers hospitalisés,
calcule le seuil et enfile un message **générique** par médecin approuvé, une fois par
jour. Le message n'inclut aucun nom, identifiant patient, acte, date de naissance,
diagnostic ni unité. Les préférences `discharge_review` autorisent la désactivation
des rappels push.

Le workflow GitHub `.github/workflows/viscera-daily-discharge-push.yml` appelle
la fonction puis le dispatcher FCM. Il est actif après fusion du code dans main,
mais l'envoi vers les appareils **nécessite** :

- un secret GitHub Actions `VISCERA_SUPABASE_SERVICE_ROLE_KEY` (stocké dans
  Settings > Secrets and variables > Actions) ;
- un secret de fonction Supabase `FIREBASE_SERVICE_ACCOUNT_JSON` autorisant
  FCM HTTP v1 (configuré exclusivement dans Supabase Functions > Secrets) ;
- une autorisation système de notifications et un jeton FCM enregistré pour
  chaque utilisateur destinataire.

Le serveur est configuré pour ne rien envoyer si ces éléments sont absents.
Les push ne constituent **pas** des alarmes vitales ou un moyen garanti
de joindre l'équipe. Les communications hospitalières habituelles restent nécessaires.

## Validation

Les tests unitaires Dart contrôlent la nomenclature réelle du programme, les
seuils J1/J4, les combinaisons de gestes, l'admission réelle et l'arrêt des
rappels après sortie. Vérifier les builds GitHub Actions Android et Web
avant toute diffusion aux équipes.

## Raccourci « Tous les documents vérifiés et cachetés »

Le bouton de validation groupée est positionné **en bas de l'écran de préparation de sortie**, après la checklist et les consignes, **juste au-dessus** de « Valider la sortie et libérer le box ». Il figure aussi **dans le pied fixe de la fenêtre « Vérification avant sortie »**, sous la checklist défilante et au-dessus du bouton rouge de déclaration de sortie. Cette action exige une attestation
explicite du médecin après contrôle **réel** des documents et des cachets.

- Valide d'un seul coup les documents obligatoires et les pièces facultatives
  présentes, avec `checkedAt` ; les pièces facultatives déjà marquées
  « Non applicable » restent dans cet état.
- Les documents déjà complets gardent leur horodatage.
- Une seule sauvegarde partagée est effectuée, et l'état antérieur est
  restauré si l'enregistrement échoue.
- Le bouton ne crée, ne signe et ne cachette aucun document ; il atteste
  exclusivement un contrôle humain.
- Il ne déclenche **jamais** la sortie : la validation clinique,
  la confirmation FAR si applicable et la confirmation finale restent requises.
- Il n'est pas accessible avant le postopératoire avec admission réelle.
