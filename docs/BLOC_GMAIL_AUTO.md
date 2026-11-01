# VISCERA — synchronisation sécurisée du programme opératoire HUIM6

## État de déploiement

- Base Supabase VISCERA : tables `bloc_program_imports` / `bloc_program_entries` et RPC atomique créées.
- Endpoint Edge Function actif : `https://qkupckqgczdqiwxozxko.supabase.co/functions/v1/bloc-gmail-ingest`.
- Endpoint volontairement **verrouillé** tant que le secret `VISCERA_BLOC_INGEST_KEY` n'est pas défini.
- Écran Flutter `Programme du bloc` : tableau des interventions viscérales importées, sous connexion médecin approuvé.
- **Pas d'activation automatique dans le Gmail à ce stade** : le propriétaire du compte doit autoriser un script Google Apps Script.

## Réglages uniques à effectuer (propriétaire du compte Google)

1. Obtenir l'autorisation d'exploitation de ces programmes nominatifs dans VISCERA conformément aux règles de l'établissement.
2. Dans [Supabase du projet](https://supabase.com/dashboard/project/qkupckqgczdqiwxozxko), définir un secret Edge Function `VISCERA_BLOC_INGEST_KEY` d'au moins 32 caractères aléatoires. **Ne pas partager ce secret dans GitHub ou dans un chat.**
3. Ouvrir [Google Apps Script](https://script.google.com/) connecté à `elghali.araqi@gmail.com`, créer un projet et coller `google-apps-script/viscera_bloc_sync.gs`.
4. Dans Paramètres du projet > Propriétés du script, enregistrer :
   - `VISCERA_BLOC_ENDPOINT` = `https://qkupckqgczdqiwxozxko.supabase.co/functions/v1/bloc-gmail-ingest`
   - `VISCERA_BLOC_INGEST_KEY` = même secret que dans Supabase
5. Exécuter `installVisceraSync` une seule fois et accepter les autorisations Gmail / requêtes externes. Le script installe une vérification toutes les 15 minutes.
6. Vérifier dans VISCERA, onglet Bloc, que le programme prévisionnel du jour suivant apparaît après synchronisation.

## Critères

- Expéditeur autorisé : `bloc.operatoire@hm6.ma`.
- Objet : `PROGRAMME OPERATOIR...`.
- Pièce jointe : `PROGRAMME PREVU DU JJ-MM-AAAA.xlsx`.
- Filtre des chirurgiens viscéraux : GHADDOU, BENSAAD, LAABOULI, LAFKIH, FAHSI (configurable via le secret/environnement `VISCERA_BLOC_SURGEONS`).
- Lecture directe XLSX côté serveur (pas d'OCR) ; pas d'analyse d'autres pièces jointes.
- Contrôle date dans le nom du fichier ET le contenu ; rejet des formats non reconnus.
- Idempotence par message + nom du fichier ; un programme reçu plus ancien ne remplace pas une version récente.
- Seuls les profils `doctor_profiles` avec `approval_status='approved'` et `approved_role` valide possèdent une autorisation SELECT RLS sur les deux tables.
- Aucune possibilité de modifier les programmes depuis le client mobile.
- Aucun nom de patient, fichier Excel original ou secret n'est stocké dans GitHub.
- Les programmes sont prévisionnels, **ne créent pas de dossier d'hospitalisation** et ne remplacent pas la validation par le bloc.

## Test de sécurité

Tester avec un compte junior/senior approuvé et un compte en attente. Le compte en attente ne doit lire ni les imports ni les interventions. Sans secret d'import l'endpoint retourne HTTP 503. Avec un secret invalide il retourne HTTP 401 (après configuration).

## Limitations connues

- L'app est un prototype de développement : l'APK/web actualisé doit être compilé/déployé.
- La connexion Gmail de ChatGPT ne constitue pas une autorisation d'exécution autonome de Google Apps Script.
- Il faut vérifier sur un deuxième fichier réel que la structure du classeur est stable avant de considérer l'import comme robuste pour la pratique clinique.
- Les données patient dans Supabase exigent la conformité institutionnelle et une validation des règles d'hébergement, de confidentialité et des durées de conservation.
