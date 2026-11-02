/// Nomenclature unique pour les intitulés du programme opératoire VISCERA.
/// Une classification automatique est une proposition administrative,
/// jamais un diagnostic, une indication opératoire ou une autorisation de sortie.
class SurgeryClassification {
  const SurgeryClassification(this.label, this.shortStay, this.recognized);
  final String label;
  final bool shortStay;
  final bool recognized;
  int get standardReviewDays => shortStay ? 1 : 4;
}

String normalizeProcedure(String source) {
  var text = source.toLowerCase().trim();
  const accent = 'àâäáãåçèéêëìíîïñòóôöõùúûüýÿœ';
  const plain =  'aaaaaaceeeeiiiinooooouuuuyyoe';
  // « œ » est composé de deux caractères, traiter séparément.
  text = text.replaceAll('œ', 'oe').replaceAll('æ','ae');
  for (var i=0;i<accent.length-1;i++) {
    if (accent[i] != 'œ') text = text.replaceAll(accent[i], plain[i]);
  }
  return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _matches(String text, String pattern) => RegExp(pattern).hasMatch(text);

SurgeryClassification classifySurgery(String intervention) {
  final text = normalizeProcedure(intervention);
  if (text.isEmpty || text == 'a preciser' || text == 'autre intervention') {
    return const SurgeryClassification('À préciser', false, false);
  }
  // Toute opération complexe ou complication explicitement indiquée sort du
  // parcours J1, même si l'intitulé contient aussi « appendicite » ou « hernie ».
  final complex = _matches(text,
    r'\b(perfor|periton|abces|complic|gangren|sepsis|septique|strangul|'
    r'occlus|rese(c|q)|resection|colectom|hepat(e|o)ctom|pancreat|'
    r'hemicolectom|anastomos|laparotom|conversion|'
    r'spleno|exerese|dpc|tumeur|cancer|neoplas|carcinom|'
    r'fistul|reprise|isch(e|é)m|necros)\w*\b');

  final appendicectomy = _matches(text, r'\b(appendicite|appendicectomie|appendicecto)\b');
  final vesicle = _matches(text,
    r'\b(lv|lithiase vesiculaire|cholecystectomie|cholecystecto|'
    r'chol(ec|e)cystectomie)\b');
  final look = _matches(text, r'\blook\b.*\b(coelio|coelioscopie|laparoscop)')
    || _matches(text, r'\b(coelio|coelioscopie|laparoscop)\w*\b.*\b(explor|diagnostic)\w*\b');
  final hernia = _matches(text,
    r'\b(hid|hig|hernie|herniorraphie|hernioplastie|cure herniaire)\b');
  // Plusieurs gestes dans la même ligne : appliquer le parcours conservateur.
  final combined = text.contains(' + ') || text.contains(' et ');
  if (appendicectomy) {
    return SurgeryClassification('Appendicectomie', !complex && !combined, true);
  }
  if (vesicle) {
    return SurgeryClassification('Cholécystectomie / LV', !complex && !combined, true);
  }
  if (look) {
    return SurgeryClassification('Cœlioscopie exploratrice (look)', !complex && !combined, true);
  }
  if (hernia) {
    final side = _matches(text, r'\bhid\b|\binguinale droite\b|\bdrte\b') ? ' droite'
      : _matches(text, r'\bhig\b|\binguinale gauche\b|\bgche\b') ? ' gauche' : '';
    return SurgeryClassification('Cure de hernie$side', !complex && !combined, true);
  }
  if (_matches(text, r'\b(dpc|duodenopancreatectomie)\b')) {
    return const SurgeryClassification('Duodénopancréatectomie céphalique', false, true);
  }
  if (_matches(text, r'\b(hepatectomie|hepatotomie)\b')) {
    return const SurgeryClassification('Chirurgie hépatique', false, true);
  }
  if (_matches(text, r'\b(colectomie|colique|rectal|rectum)\b')) {
    return const SurgeryClassification('Chirurgie colorectale', false, true);
  }
  if (_matches(text, r'\b(pancreatectomie|pancreas|pancreatique)\b')) {
    return const SurgeryClassification('Chirurgie pancréatique', false, true);
  }
  if (_matches(text, r'\b(splenectomie|spleno)\b')) {
    return const SurgeryClassification('Chirurgie splénique', false, true);
  }
  if (_matches(text, r'\b(grele|grelique)\b')) {
    return const SurgeryClassification('Chirurgie du grêle', false, true);
  }
  return const SurgeryClassification('Autre chirurgie / à confirmer', false, false);
}

/// Révision de sortie : calcul uniquement après une admission et une chirurgie
/// terminée. L'équipe peut choisir une durée prévisionnelle plus longue.
DateTime proposedDischargeReviewDate(DateTime admitted, int physicianDays,
    SurgeryClassification type) {
  final days = physicianDays > type.standardReviewDays
      ? physicianDays : type.standardReviewDays;
  return DateTime(admitted.year,admitted.month,admitted.day + days);
}
