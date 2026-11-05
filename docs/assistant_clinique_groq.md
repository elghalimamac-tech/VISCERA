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
- La synthèse et les réponses ne sont pas enregistrées par la fonction dans
  la base VISCERA. Ne pas coller de données directement identifiantes.

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
