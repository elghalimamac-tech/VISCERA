import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/caprini_assessment.dart';
import 'package:viscera/clinical_score_engine.dart';

Map<String, String> reviewedAbsent() => {
  for (final factor in capriniFactors)
    factor.id: factor.countable ? '0' :
      factor.womenOnly ? 'na' : 'no',
};

void main() {
  test('Caprini 2013 n’assimile pas les données manquantes à des absences', () {
    expect(CapriniAssessment.calculate({}, age: 57), isNull);
    final replies = reviewedAbsent()..remove('ibd');
    expect(CapriniAssessment.calculate(replies, age: 57), isNull);
    expect(CapriniAssessment.answeredCount(replies),
      capriniFactors.length - 1);
  });

  test('Points d’âge exclusifs et factuels', () {
    final replies = reviewedAbsent();
    expect(CapriniAssessment.calculate(replies, age: 30), 0);
    expect(CapriniAssessment.calculate(replies, age: 57), 1);
    expect(CapriniAssessment.calculate(replies, age: 61), 2);
    expect(CapriniAssessment.calculate(replies, age: 75), 3);
    expect(CapriniAssessment.calculate(replies), isNull);
  });

  test('Caprini additionne facteurs indépendants et épisodes documentés', () {
    final replies = reviewedAbsent()
      ..['bmi25'] = 'yes'
      ..['majorPlanned'] = 'yes'
      ..['personalVte'] = '2'
      ..['cancer'] = '1';
    // 57 ans (1) + IMC (1) + chirurgie majeure (2)
    // + 2 épisodes de thrombose (6) + malignité (2) = 12
    expect(CapriniAssessment.calculate(replies, age: 57), 12);
    final result = ClinicalScoring.compute('caprini', replies, age: 57);
    expect(result?.value, '12');
    expect(result?.interpretation, contains('très élevé'));
  });

  test('Procédures incompatibles et données invalides bloquent le total', () {
    final replies = reviewedAbsent()
      ..['minorSurgery'] = 'yes'
      ..['majorPlanned'] = 'yes';
    expect(CapriniAssessment.conflict(replies), isNotNull);
    expect(CapriniAssessment.calculate(replies, age: 57), isNull);
    replies['minorSurgery'] = 'no';
    replies['personalVte'] = '-1';
    expect(CapriniAssessment.calculate(replies, age: 57), isNull);
    replies['personalVte'] = '0';
    replies['hipKnee'] = '1';
    expect(CapriniAssessment.calculate(replies, age: 57), isNull);
  });

  test('Anciens totaux Caprini restent lisibles sans fausse précision', () {
    final result = ClinicalScoring.compute('caprini', {'total': '8'});
    expect(result?.value, '8');
    expect(result?.interpretation, contains('Ancien total'));
  });
}
