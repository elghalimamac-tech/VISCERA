# VISCERA — assistant clinique GROQ

## Fonctionnement

- Courbes CRP et procalcitonine (PCT en ng/mL) dans le dossier et les observations.
- Bouton **Assistant clinique GROQ · hypothèses** dans le dossier patient.
- Synthèse préparée localement à partir de la phase clinique, tranche d'âge,
  intervention, scores, bilans biologiques et cinq observations récentes.
- Aperçu éditable obligatoire ; **aucune transmission automatique**.
- Checkbox de vérification de la désidentification et de l'autorisation locale.
- Envoi vers l'Edge Function `viscera-clinical-assist` uniquement après action
  manuelle d'un médecin approuvé (junior/senior). Le serveur valide sa session.
- Réponse structurée en français : hypothèses différentielles, éléments à vérifier,
  examens/évaluations à discuter, options de conduite à tenir, signes d'alerte,
  limites. Aucune prescription, aucun acte ou changement de dossier automatique.
- Les **réponses GROQ réussies** et leurs sources sont enregistrées
  automatiquement dans la table sécurisée `viscera_clinical_ai_reports`,
  rattachées au dossier patient (bloc ou admission manuelle), avec la date,
  le médecin initiateur et le modèle utilisé. Les synthèses envoyées à GROQ
  ne sont pas conservées dans cette table.
- Dans chaque dossier patient, **Analyses cliniques enregistrées** affiche
  les derniers rapports ; l’historique permet de retrouver les anciens
  et de relire chacun sans recontacter GROQ.
- Les anciens rapports ne sont jamais remplacés par une nouvelle réponse :
  l’historique est append-only. Les dossiers sont accessibles uniquement aux
  médecins habilités de l’établissement, selon les politiques RLS.
- Si l’enregistrement échoue, le serveur renvoie
  `clinical_report_save_failed` au lieu de prétendre avoir sauvegardé
  le rapport. Aucun dossier brouillon non partagé ne peut recevoir une
  analyse qui serait ensuite introuvable.
- Ne jamais coller d’identifiants directs dans les synthèses transmises
  à GROQ ; la relecture et l’autorisation restent obligatoires.

## Recommandations sourcées (catalogue du 05/11/2026)

Le modèle **n'a pas d'accès web en direct**. Le serveur lui transmet une
bibliographie institutionnelle vérifiée le 5 novembre 2026. Les citations de
réponse sont des identifiants préautorisés ; l'Edge Function rejette les
références inconnues et retire les propositions sans source du catalogue.

- **SSC 2026** : https://sccm.org/survivingsepsiscampaign/guidelines-and-resources/surviving-sepsis-campaign-adult-guidelines
- **WSES PCT 2026** : https://pubmed.ncbi.nlm.nih.gov/42938782/
- **ERAS colorectal 2025** : https://pubmed.ncbi.nlm.nih.gov/40783294/
- **ESPEN nutrition chirurgie 2025** : https://doi.org/10.1016/j.clnu.2025.08.029
- **IDSA 2024** : https://www.idsociety.org/practice-guideline/intra-abdominal-infections/
- **SIS 2024** : https://sisna.org/the-surgical-infection-society-guidelines-on-the-management-of-intra-abdominal-infection-2024-update/
- **ASA 2026** : https://doi.org/10.1097/ao9.0000000000000002
- **NEWS2 / RCP 2017** : https://rcp.ac.uk/resources/national-early-warning-score-news-2/

**Attention :** les identifiants cités par le modèle ne prouvent pas à eux
seuls que la proposition est conforme au texte original. Une revue humaine
de la phrase et des recommandations est indispensable ; ne jamais qualifier
le catalogue d'actualisé en temps réel. Planifier un contrôle périodique des
publications et des recommandations institutionnelles, particulièrement en
cas de publication d'une nouvelle version ou de changement des pratiques.

L'écran patient comprend un bouton d'analyse mis en évidence, et l'écran
GROQ montre les **scores enregistrés et indices disponibles** en premier.
Les hypothèses et options de prise en charge comportent chacune des liens
vers les sources, suivies de la bibliographie consultable.

## Scores enregistrés, scores recommandés et bilans ciblés

Depuis la version 7 de l'Edge Function `viscera-clinical-assist` :

- Les scores saisis par le médecin sont extraits de la synthèse qu'il a relue.
  L'IA doit expliquer **valeur, interprétation, limites, éventuel changement
  de surveillance ou de coordination** et source correspondante. Le serveur
  élimine une valeur proposée par le modèle si elle ne correspond pas
  exactement à une valeur enregistrée dans le texte transmis.
- Si aucun score clinique formel n'est enregistré, GROQ peut suggérer les
  scores adaptés à la phase du patient. Pour chacun, il précise le motif
  clinique, les critères requis, les éventuels examens biologiques
  réellement nécessaires et l'utilité attendue pour la prise en charge.
- Les suggestions couvrent notamment ASA, CFS, NRS-2002, Caprini, RCRI,
  ARISCAT (préopératoire) ; NEWS2 (surveillance) ; DULK/mDULK, ISREC et
  Clavien-Dindo (postopératoire, dans leurs indications respectives).
- Les indices biologiques mGPS, CAR, PNI, GNRI, ALBI peuvent être recensés
  dans la synthèse, mais leur application pratique n'est jamais considérée
  comme une recommandation universelle. Les scores sans références
  spécifiques doivent signaler le manque d'étayage.
- Pour les examens à discuter, la réponse doit indiquer *indication clinique,
  moment/condition, score éventuel et conséquence possible*. Les bilans
  manquants ne sont **jamais interprétés comme normaux** et les scores
  incomplets ne sont **jamais calculés artificiellement**.
- Le modèle ne doit pas recommander systématiquement CRP, PCT, lactate,
  troponine ou bilan de coagulation sans contexte clinique.
- Aucun traitement n'est prescrit ni aucune demande de bilan exécutée
  automatiquement. Toute interprétation et conduite à tenir doivent être
  vérifiées par l'équipe médicale.

L'ensemble repose sur un catalogue documentaire daté, non sur une
actualisation web en temps réel. Les références de définition de scores
anciens (par exemple ISREC 2010 et Clavien-Dindo 2004) restent utiles à
l'interprétation, **sans être présentées comme les recommandations de
prise en charge les plus récentes**.

## Activation serveur

1. Créer une clé API GROQ : https://console.groq.com/keys
2. Dans le projet Supabase **qkupckqgczdqiwxozxko**, ouvrir
   **Edge Functions > Secrets**.
3. Ajouter le secret **GROQ_API_KEY** avec la valeur de la clé (ne jamais la placer
   dans GitHub, dans Flutter, ni dans un `.env` commité).
4. L'Edge Function déployée utilise le modèle `openai/gpt-oss-120b`.
5. Vérifier les autorisations institutionnelles, les contrats de sous-traitance,
   les règles CNDP de transfert international et les paramètres GROQ **Zero Data
   Retention** avant tout emploi de données cliniques réelles.
6. Effectuer un essai avec un dossier fictif strictement non identifiable.

Sans `GROQ_API_KEY` côté serveur, l'assistant affiche une erreur de
configuration ; il **ne contacte pas GROQ**.

## Sécurité et limites

L'anonymisation automatique est partielle ; elle ne peut garantir l'absence
d'identifiants dans les textes libres ou les pathologies rares. Le médecin
doit relire et corriger le texte avant transmission. L'outil n'est pas un
dispositif médical validé et n'est pas autorisé à se substituer au jugement
clinique, aux procédures locales ou aux recommandations de sociétés savantes.
Les résultats nécessitent une revue médicale indépendante.

Références :
- https://console.groq.com/docs/your-data
- https://supabase.com/docs/guides/functions/secrets
- https://www.cndp.ma/transfert-de-donnees-a-letranger/
