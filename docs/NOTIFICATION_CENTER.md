# Notifications — centre VISCERA sur l'accueil

Sur Android et sur Web, la cloche en haut à droite de l'accueil ouvre le centre des
notifications du **compte médecin connecté**. Un badge turquoise donne le nombre
de messages non lus (99+ au-delà de 99).

## Centre de notifications

- Affiche toutes les notifications **enregistrées sur Supabase**, toutes catégories
  confondues : programme opératoire, urgences, validation des accès, révision
  des sorties et **sorties confirmées avec le nom du validateur**.
  Le nom de l'utilisateur est lu du profil médical authentifié par la base
  lors de la validation, jamais saisi par le client. Aucune donnée patient
  n'est exposée dans les notifications push.
- Affiche le titre générique, le contenu, la date et l'heure.
- Filtre `Toutes / Non lues`, pagination et actualisation.
- Toucher une notification non lue la marque comme lue.
- Bouton `Tout effacer` **réservé aux administrateurs VISCERA approuvés**,
  avec confirmation : archive uniquement les notifications personnelles de
  l'administrateur, sur ses appareils, sans limite de 80 éléments.
- Les juniors, résidents et seniors non administrateurs peuvent consulter
  leurs notifications et les marquer comme lues, mais ne peuvent les effacer.
- Une notification archivée n'apparaît plus, et son badge disparaît.
  Le serveur FCM ignore également les alertes en attente déjà archivées.

## Sécurité

L'action `Tout effacer` met seulement à jour `dismissed_at` sur les lignes
appartenant au compte identifié par Supabase Auth. Le rôle administrateur est
vérifié depuis `doctor_profiles.is_admin` et `approval_status='approved'`.
Un déclencheur SQL refuse toute modification de `dismissed_at` par un
non-administrateur, même si l'utilisateur contourne l'interface Flutter. Les lignes restent conservées
en base pour audit. Les droits RLS empêchent la suppression des notifications
des collègues. Les données patients ne sont jamais modifiées.

**Important :** les alarmes Android de garde planifiées sont des notifications
locales de l'OS et ne sont **pas** supprimées par `Tout effacer`.
Elles restent gérées dans `Alarmes et notifications`.

Le compteur est actualisé à l'ouverture de l'accueil, au retour de l'app, au retour
de la boîte et toutes les 40 secondes pendant que l'application est ouverte.
Une panne du réseau ne doit pas bloquer les dossiers médicaux.
