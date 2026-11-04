class ClinicalChoice {
  const ClinicalChoice(this.value, this.label);
  final String value, label;
}
class ClinicalQuestion {
  const ClinicalQuestion(this.id, this.title, this.choices);
  final String id, title;
  final List<ClinicalChoice> choices;
}
class ClinicalScoreSpec {
  const ClinicalScoreSpec(this.id, this.title, this.period, this.questions);
  final String id, title, period;
  final List<ClinicalQuestion> questions;
}
const _yesNo = [ClinicalChoice('0','Non · 0'), ClinicalChoice('1','Oui · 1')];
const clinicalScoreSpecs = <ClinicalScoreSpec>[
  ClinicalScoreSpec('nrs2002','NRS-2002 · Nutrition','Préopératoire',[
    ClinicalQuestion('nutrition','Altération nutritionnelle',[
      ClinicalChoice('0','0 · Aucune'),
      ClinicalChoice('1','1 · Légère : perte >5 % sur 3 mois ou apports 50–75 %'),
      ClinicalChoice('2','2 · Modérée : perte >5 % sur 2 mois, IMC 18,5–20,5 avec altération ou apports 25–50 %'),
      ClinicalChoice('3','3 · Sévère : perte >5 % sur 1 mois, IMC <18,5 avec altération ou apports <25 %'),
    ]),
    ClinicalQuestion('disease','Gravité de la maladie (besoins métaboliques)',[
      ClinicalChoice('0','0 · Aucune'),
      ClinicalChoice('1','1 · Légère : maladie chronique avec complication aiguë'),
      ClinicalChoice('2','2 · Modérée : chirurgie abdominale majeure, AVC…'),
      ClinicalChoice('3','3 · Sévère : maladie critique en réanimation…'),
    ]),
  ]),
  ClinicalScoreSpec('caprini','Caprini · Risque thrombotique','Préopératoire',[]),
  ClinicalScoreSpec('ariscat','ARISCAT · Risque pulmonaire','Préopératoire',[
    ClinicalQuestion('spo2','SpO₂ préopératoire',[
      ClinicalChoice('0','≥96 % · 0'),
      ClinicalChoice('8','91–95 % · 8'),
      ClinicalChoice('24','≤90 % · 24'),
    ]),
    ClinicalQuestion('infection','Infection respiratoire dans le dernier mois',[
      ClinicalChoice('0','Non · 0'),ClinicalChoice('17','Oui · 17'),
    ]),
    ClinicalQuestion('hb','Hémoglobine préopératoire <10 g/dL',[
      ClinicalChoice('0','Non · 0'),ClinicalChoice('11','Oui · 11'),
    ]),
    ClinicalQuestion('incision','Site opératoire',[
      ClinicalChoice('0','Périphérique / autre · 0'),
      ClinicalChoice('15','Abdominal supérieur · 15'),
      ClinicalChoice('24','Intrathoracique · 24'),
    ]),
    ClinicalQuestion('duration','Durée opératoire prévue',[
      ClinicalChoice('0','<2 h · 0'),
      ClinicalChoice('16','2 à 3 h · 16'),
      ClinicalChoice('23','>3 h · 23'),
    ]),
    ClinicalQuestion('emergency','Chirurgie urgente',[
      ClinicalChoice('0','Non · 0'),ClinicalChoice('8','Oui · 8'),
    ]),
  ]),
  ClinicalScoreSpec('rcri','RCRI (Lee) · Risque cardiaque','Préopératoire',[
    ClinicalQuestion('surgery','Chirurgie à risque élevé (intrapéritonéale, intrathoracique ou vasculaire supra-inguinale)',_yesNo),
    ClinicalQuestion('ischemia','Cardiopathie ischémique',_yesNo),
    ClinicalQuestion('heartFailure','Insuffisance cardiaque',_yesNo),
    ClinicalQuestion('stroke','AVC ou AIT',_yesNo),
    ClinicalQuestion('insulin','Diabète traité par insuline',_yesNo),
    ClinicalQuestion('creatinine','Créatininémie >2 mg/dL (177 µmol/L)',_yesNo),
  ]),
  ClinicalScoreSpec('news2','NEWS2 · Surveillance','Hospitalisation',[
    ClinicalQuestion('scale','Échelle SpO₂ (2 sur décision clinique uniquement)',[
      ClinicalChoice('1','Échelle 1 usuelle'),
      ClinicalChoice('2','Échelle 2 : cible 88–92 % prescrite'),
    ]),
    ClinicalQuestion('oxygen','Oxygène supplémentaire',[
      ClinicalChoice('no','Air ambiant'),ClinicalChoice('yes','Oxygène'),
    ]),
    ClinicalQuestion('conscious','Conscience / confusion nouvelle',[
      ClinicalChoice('alert','Alerte'),
      ClinicalChoice('confusion','Confusion nouvelle'),
      ClinicalChoice('voice','Réponse à la voix'),
      ClinicalChoice('pain','Réponse à la douleur'),
      ClinicalChoice('unresponsive','Sans réponse'),
    ]),
  ]),
  ClinicalScoreSpec('clavien','Clavien-Dindo · Complications','Postopératoire',[
    ClinicalQuestion('grade','Grade médical de la complication',[
      ClinicalChoice('I','I · Soins simples'),
      ClinicalChoice('II','II · Médicaments, transfusion ou nutrition parentérale'),
      ClinicalChoice('IIIa','IIIa · Intervention sans anesthésie générale'),
      ClinicalChoice('IIIb','IIIb · Intervention sous anesthésie générale'),
      ClinicalChoice('IVa','IVa · Défaillance d’un organe, soins intensifs'),
      ClinicalChoice('IVb','IVb · Défaillance multiviscérale, soins intensifs'),
      ClinicalChoice('V','V · Décès'),
    ]),
  ]),
];
