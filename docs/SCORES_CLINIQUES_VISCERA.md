# Scores cliniques complémentaires — VISCERA

## Déjà intégré
CFS (1–9, autonomie de référence et signalement ≥5) et ASA existent dans le dossier et ne sont pas dupliqués.

## Modules nouveaux
- NRS-2002 : état nutritionnel 0–3, maladie 0–3, +1 si âge ≥70 ans. Seuil ≥3.
- Caprini 2013 : saisie du total calculé sur la grille complète ; aucun calcul partiel des facteurs.
- ARISCAT : âge, SpO₂, infection respiratoire récente, Hb <10, incision, durée et urgence. Risque faible <26, intermédiaire 26–44, élevé ≥45.
- RCRI : six critères, tous requis.
- NEWS2 : FR, SpO₂, supplément en oxygène, PAS, pouls, conscience/confusion nouvelle et température. Échelle 2 uniquement après décision d'un clinicien pour une cible 88–92 %.
- Clavien-Dindo : grade I à V, avec IIIa/IIIb et IVa/IVb attribués par le médecin.

Le volet est replié par défaut. Les données manquantes ne valent jamais zéro. Aucune décision de chirurgie, sortie ou prescription n'est automatique.

## Stockage
Les nouveaux scores utilisent la clé clinicalScores dans clinical_data des dossiers partagés, sans nouvelle table ni duplication du patient. Chaque évaluation contient ses paramètres, le résultat, la date UTC, la version du formulaire et l'identifiant de profil disponible. La sauvegarde utilise les RPC/RLS existants. En lecture seule pour les sorties archivées.

Cette version conserve le dernier résultat de chaque score ; un suivi longitudinal NEWS2 append-only devra faire l'objet d'une validation métier avant une évolution de schéma.

## Références cliniques
ESPEN NRS-2002 : https://www.espen.org/documents/Screening.pdf
Caprini : https://www.ncbi.nlm.nih.gov/books/NBK616080/
ARISCAT : https://pmc.ncbi.nlm.nih.gov/articles/PMC7047701/
RCRI : https://pmc.ncbi.nlm.nih.gov/articles/PMC7807823/
NEWS2 : https://www.rcp.ac.uk/resources/national-early-warning-score-news-2/

Une validation clinique locale et des tests Flutter restent obligatoires avant usage médical réel.
