import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/surgery_classification.dart';
import 'package:viscera/models.dart';

PatientCase _case(String procedure, {
  DateTime? admittedAt,
  int expectedDays = 0,
  CaseStage stage = CaseStage.postoperative,
}) => PatientCase(
  id:'TEST-CASE',name:'Dossier test',age:'—',
  origin:'Consultation',insurance:'À préciser',motive:'',
  history:'',exam:'',investigations:'',labs:'',immediatePlan:'',
  procedure:procedure,blockTiming:'Différé',admissionTiming:'Immédiate',
  beforeUnit:'TC1',beforeBox:'1',afterUnit:'TC1',afterBox:'1',
  expectedDays:expectedDays,
  blockAt:DateTime(2026,11,1,12),
  admittedAt:admittedAt,
  stage:stage,
);

void main() {
  test('Interventions réelles du programme harmonisées', () {
    final short = {
      'LV':'Cholécystectomie / LV',
      'LV SOUS COELIO':'Cholécystectomie / LV',
      'HID':'Cure de hernie droite',
      'HIG':'Cure de hernie gauche',
      'HERNIE INGUINALE DRTE':'Cure de hernie droite',
      'HERNIE OMBILICALE':'Cure de hernie',
      'Appendicectomie sous cœlioscopie':'Appendicectomie',
      'LOOK COELIO':'Cœlioscopie exploratrice (look)',
    };
    for (final entry in short.entries) {
      final classified = classifySurgery(entry.key);
      expect(classified.label,entry.value,reason:entry.key);
      expect(classified.standardReviewDays,1,reason:entry.key);
    }
    for (final procedure in ['DPC','HEPATECTOMIE','COLECTOMIE TOTALE',
         'RESECTION GRELIQUE SEGMENTAIRE','TUMEUR COLIQUE','ADK RECTAL',
         'SPLENO PANCREATECTOMIE CAUDALE','MASSE RETROPERITONEALE']) {
      expect(classifySurgery(procedure).standardReviewDays,4,reason:procedure);
    }
    expect(classifySurgery('HERNIE INGUINO-SCROTALE+HERNIE LIGNE BLANCHE')
        .standardReviewDays,4);
    expect(classifySurgery('LOOK COELIO + BIOPSIE').standardReviewDays,4);
    expect(classifySurgery('Appendicite perforée').standardReviewDays,4);
  });

  test('Seules les admissions réelles postopératoires ont un rappel', () {
    final admission = DateTime(2026,11,1,15);
    final scheduled = _case('LV',stage:CaseStage.scheduled);
    expect(scheduled.dischargeReviewAt,isNull);
    expect(scheduled.dischargeReviewDueOn(DateTime(2026,11,3)),isFalse);
    final preop = _case('LV',admittedAt:admission,stage:CaseStage.preoperative);
    expect(preop.dischargeReviewDueOn(DateTime(2026,11,3)),isFalse);
    final post = _case('LV',admittedAt:admission);
    expect(post.dischargeReviewAt,DateTime(2026,11,2));
    expect(post.dischargeReviewDueOn(DateTime(2026,11,1)),isFalse);
    expect(post.dischargeReviewDueOn(DateTime(2026,11,2)),isTrue);
    post.stage=CaseStage.discharged;
    expect(post.dischargeReviewDueOn(DateTime(2026,11,3)),isFalse);
  });

  test('Autres interventions J4 et durée médicale plus longue conservée', () {
    final admission = DateTime(2026,11,1,18);
    final complex = _case('COLECTOMIE TOTALE',admittedAt:admission);
    expect(complex.dischargeReviewAt,DateTime(2026,11,5));
    expect(complex.dischargeReviewDueOn(DateTime(2026,11,4)),isFalse);
    expect(complex.dischargeReviewDueOn(DateTime(2026,11,5)),isTrue);
    final longer = _case('LV',admittedAt:admission,expectedDays:6);
    expect(longer.dischargeReviewAt,DateTime(2026,11,7));
    final shorter = _case('DPC',admittedAt:admission,expectedDays:1);
    expect(shorter.dischargeReviewAt,DateTime(2026,11,5));
  });
}
