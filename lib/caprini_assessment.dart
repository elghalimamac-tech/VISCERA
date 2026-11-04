/// Modèle de Caprini 2013 : questions explicites, sans hypothèse
/// qu'une donnée manquante équivaut à une absence de risque.
/// Référence : Cronin et al. Clin Appl Thromb Hemost (2019).
class CapriniFactor {
  const CapriniFactor(this.id, this.label, this.points,
      {this.womenOnly = false, this.countable = false});
  final String id;
  final String label;
  final int points;
  final bool womenOnly;
  final bool countable;
}

const capriniFactors = <CapriniFactor>[
  CapriniFactor('minorSurgery', 'Chirurgie mineure prévue (< 45 min, anesthésie comprise)', 1),
  CapriniFactor('priorMajorSurgery', 'Chirurgie majeure (> 45 min) dans le dernier mois', 1),
  CapriniFactor('varicose', 'Varices visibles (non des télangiectasies)', 1),
  CapriniFactor('ibd', 'Maladie inflammatoire chronique intestinale (Crohn, RCH)', 1),
  CapriniFactor('legSwelling', 'Œdème actuel d’une ou des deux jambes', 1),
  CapriniFactor('bmi25', 'IMC > 25 kg/m²', 1),
  CapriniFactor('mi', 'Infarctus du myocarde dans le dernier mois', 1),
  CapriniFactor('heartFailure', 'Insuffisance cardiaque congestive active ou traitée', 1),
  CapriniFactor('seriousInfection', 'Infection grave nécessitant hospitalisation et antibiothérapie IV', 1),
  CapriniFactor('lungDisease', 'Pathologie pulmonaire chronique ou exploration fonctionnelle anormale', 1),
  CapriniFactor('mobilityUnder72', 'Mobilité réduite / alitement de moins de 72 h', 1),
  CapriniFactor('bmi40', 'IMC > 40 kg/m² (point supplémentaire)', 1),
  CapriniFactor('smoking', 'Tabagisme ou inhalation de substances fumées dans le dernier mois', 1),
  CapriniFactor('insulin', 'Diabète traité par insuline', 1),
  CapriniFactor('chemotherapy', 'Chimiothérapie en cours ou récente', 1),
  CapriniFactor('transfusion', 'Transfusion sanguine dans le dernier mois', 1),
  CapriniFactor('surgeryOver2h', 'Durée actuelle de chirurgie > 2 h, anesthésie comprise (hors prothèse hanche/genou)', 1),
  CapriniFactor('hormone', 'Contraception œstrogénique ou traitement hormonal pertinent', 1, womenOnly: true),
  CapriniFactor('pregnancy', 'Grossesse ou accouchement dans le dernier mois', 1, womenOnly: true),
  CapriniFactor('obstetricHistory', 'Mort fœtale inexpliquée, fausses couches récurrentes ou complication obstétricale spécifique', 1, womenOnly: true),
  CapriniFactor('cancer', 'Cancer actuel ou antérieur (hors cancer cutané non mélanome) — nombre d’épisodes distincts', 2, countable: true),
  CapriniFactor('majorPlanned', 'Chirurgie majeure prévue > 45 min, y compris cœlioscopie', 2),
  CapriniFactor('cast', 'Plâtre/attelle immobilisant la jambe dans le dernier mois', 2),
  CapriniFactor('centralLine', 'Voie veineuse centrale ou PICC dans le dernier mois', 2),
  CapriniFactor('mobilityOver72', 'Alitement / limitation importante de mobilité ≥ 72 h', 2),
  CapriniFactor('personalVte', 'Antécédents de TVP, EP ou thrombose veineuse superficielle — nombre d’épisodes distincts', 3, countable: true),
  CapriniFactor('familyVte', 'Antécédents familiaux de thrombose veineuse', 3),
  CapriniFactor('thrombophilia', 'Thrombophilies acquises/héréditaires documentées (patient ou famille) — nombre de marqueurs distincts', 3, countable: true),
  CapriniFactor('hipKnee', 'Arthroplastie élective de hanche ou genou — nombre de procédures', 5, countable: true),
  CapriniFactor('fracture', 'Fracture de hanche, bassin ou jambe dans le dernier mois', 5),
  CapriniFactor('trauma', 'Traumatisme grave dans le dernier mois', 5),
  CapriniFactor('spinal', 'Lésion médullaire avec paralysie dans le dernier mois', 5),
  CapriniFactor('recentStroke', 'AVC dans le dernier mois', 5),
];

class CapriniAssessment {
  static int? agePoints(int? age) {
    if (age == null || age < 0 || age > 125) return null;
    if (age >= 75) return 3;
    if (age >= 61) return 2;
    if (age >= 41) return 1;
    return 0;
  }

  static bool validAnswer(CapriniFactor factor, String? answer) {
    if (answer == null) return false;
    if (factor.countable) {
      final count = int.tryParse(answer);
      return count != null && count >= 0 && count <= 99;
    }
    return answer == 'yes' || answer == 'no' ||
        (factor.womenOnly && answer == 'na');
  }

  static int answeredCount(Map<String, String> answers) =>
      capriniFactors.where((f) => validAnswer(f, answers[f.id])).length;

  static String? conflict(Map<String, String> answers) {
    final minor = answers['minorSurgery'] == 'yes';
    final major = answers['majorPlanned'] == 'yes';
    final hip = (int.tryParse(answers['hipKnee'] ?? '') ?? 0) > 0;
    if (minor && (major || hip)) {
      return 'Chirurgie mineure et chirurgie majeure/arthroplastie prévues : vérifier le type de procédure.';
    }
    if (major && hip) {
      return 'Ne pas additionner la chirurgie majeure prévue et les 5 points de la même arthroplastie.';
    }
    if (hip && answers['surgeryOver2h'] == 'yes') {
      return 'La durée > 2 h ne s’additionne pas aux points de cette arthroplastie.';
    }
    if (answers['mobilityUnder72'] == 'yes' &&
        answers['mobilityOver72'] == 'yes') {
      return 'Choisir la durée correcte de limitation de mobilité (< 72 h ou ≥ 72 h).';
    }
    return null;
  }

  static int? calculate(Map<String, String> answers, {int? age}) {
    final ageScore = agePoints(age);
    if (ageScore == null || answeredCount(answers) != capriniFactors.length ||
        conflict(answers) != null) return null;
    var total = ageScore;
    for (final factor in capriniFactors) {
      final answer = answers[factor.id]!;
      total += factor.points * (factor.countable
          ? int.parse(answer)
          : answer == 'yes' ? 1 : 0);
    }
    return total;
  }

  static String interpretation(int points) {
    final group = points <= 1 ? 'faible (0–1)' :
        points == 2 ? 'modéré (2)' :
        points <= 4 ? 'élevé (3–4)' : 'très élevé (≥ 5)';
    return 'Risque thromboembolique $group ; prévention selon le protocole local et le risque hémorragique.';
  }
}
