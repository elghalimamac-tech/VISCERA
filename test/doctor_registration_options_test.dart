import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/doctor_registration_options.dart';

void main() {
  test('7 catégories juniors disponibles', () {
    expect(juniorCategories.length, 7);
    expect(juniorCategories['resident_5'], 'Résident 5e année');
  });

  test('Internes 1re année : seulement passages 1 et 2', () {
    expect(passagesForCategory('interne_1'), [1, 2]);
    expect(validateMedicalGrade(role: 'junior', juniorCategory: 'interne_1', internshipPassage: 2), isNull);
    expect(validateMedicalGrade(role: 'junior', juniorCategory: 'interne_1', internshipPassage: 3), isNotNull);
  });

  test('Internes 2e année : seulement passages 3 et 4', () {
    expect(passagesForCategory('interne_2'), [3, 4]);
    expect(validateMedicalGrade(role: 'junior', juniorCategory: 'interne_2', internshipPassage: 4), isNull);
  });

  test('Résidents de 1 à 5 ans sans passage', () {
    for (var year = 1; year <= 5; year++) {
      expect(validateMedicalGrade(role: 'junior', juniorCategory: 'resident_$year'), isNull);
    }
    expect(validateMedicalGrade(role: 'junior', juniorCategory: 'resident_1', internshipPassage: 1), isNotNull);
  });

  test('Seniors : titre Dr ou Pr obligatoire', () {
    expect(validateMedicalGrade(role: 'senior', seniorTitle: 'Dr'), isNull);
    expect(validateMedicalGrade(role: 'senior', seniorTitle: 'Pr'), isNull);
    expect(validateMedicalGrade(role: 'senior', seniorTitle: 'Mr'), isNotNull);
  });
}
