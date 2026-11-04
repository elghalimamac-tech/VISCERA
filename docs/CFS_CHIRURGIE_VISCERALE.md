# Score CFS dans VISCERA

## Emplacement et saisie
Dossier patient → **Documents et vérifications** → **Admission et préparation opératoire** → **Fragilité clinique (CFS)**.
La rubrique est repliable pour préserver la lisibilité. Le score est choisi par un médecin (1 à 9) ; il n'est jamais déduit de l'âge, d'un diagnostic ou d'une intervention. CFS ≥ 5 déclenche un indicateur dans l'en-tête du dossier et une recommandation non bloquante d'évaluation nutritionnelle/gériatrique. Le CFS 9 correspond à une phase terminale et ne signifie pas systématiquement une fragilité sévère.

Date obligatoire pour tout score saisi : autonomie habituelle pré-épisode aigu, typiquement environ 2 semaines auparavant. Une saisie peut être effacée. Le formulaire accepte également ASA I–VI, une synthèse des comorbidités, et le statut des évaluations nutritionnelle/gériatrique (à évaluer, réalisée ou non indiquée).

## Enregistrement
Ces données sont stockées dans **clinical_data** (JSONB) des tables existantes `bloc_patient_records` et `manual_patient_records`, et sauvegardées par les fonctions RPC existantes avec contrôle de version, audit et RLS. Aucune nouvelle table, copie de patient ni permission supplémentaire n'est créée.

Clés structurées : `cfsScore` (entier 1..9 ou null), `cfsBaselineDate` (YYYY-MM-DD), `cfsAssessedAt` (ISO 8601), `asaClass` (I..VI ou ''), `comorbiditySummary`, `nutritionAssessmentStatus`, `geriatricAssessmentStatus`. Les paramètres chirurgicaux `procedureOverride`, `surgeryType`, `stage` et `expectedDays` sont conservés dans le même JSONB et analysables avec le CFS.

Exemple d'agrégation interne (à exécuter uniquement par un professionnel habilité) :

```sql
select
  clinical_data->>'asaClass' as classe_asa,
  (clinical_data->>'cfsScore')::int as cfs,
  count(*) as nb_dossiers
from public.manual_patient_records
where clinical_data->>'cfsScore' ~ '^[1-9]$'
group by 1, 2
order by 1, 2;
```

Il faut évaluer la fragilité dans l'état fonctionnel habituel avant maladie aiguë ; les scores ne doivent pas servir seuls à refuser une chirurgie, une réanimation ou à déterminer un protocole automatique. L'évaluation est davantage validée chez les patients de 65 ans et plus. Aucun score n'est attribué automatiquement lors d'une admission ou d'un import de programme.
