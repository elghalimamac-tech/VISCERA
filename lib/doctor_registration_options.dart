/// Catégories déclarées lors de l'inscription des médecins VISCERA.
/// Les déclarations ne remplacent pas la vérification par le responsable du service.
const juniorCategories = <String, String>{
  'interne_1': 'Interne 1re année',
  'interne_2': 'Interne 2e année',
  'resident_1': 'Résident 1re année',
  'resident_2': 'Résident 2e année',
  'resident_3': 'Résident 3e année',
  'resident_4': 'Résident 4e année',
  'resident_5': 'Résident 5e année',
};

const seniorTitles = <String>['Dr', 'Pr'];

List<int> passagesForCategory(String? category) => switch (category) {
  'interne_1' => const [1, 2],
  'interne_2' => const [3, 4],
  _ => const <int>[],
};

String? validateMedicalGrade({
  required String role,
  String? juniorCategory,
  int? internshipPassage,
  String? seniorTitle,
}) {
  if (role == 'junior') {
    if (!juniorCategories.containsKey(juniorCategory)) {
      return 'Sélectionnez votre catégorie de junior.';
    }
    final allowedPassages = passagesForCategory(juniorCategory);
    if (allowedPassages.isNotEmpty && !allowedPassages.contains(internshipPassage)) {
      return 'Sélectionnez votre passage d’internat.';
    }
    if (allowedPassages.isEmpty && internshipPassage != null) {
      return 'Aucun passage d’internat pour un résident.';
    }
    return null;
  }
  if (role == 'senior') {
    return seniorTitles.contains(seniorTitle) ? null : 'Sélectionnez Dr ou Pr.';
  }
  return 'Sélectionnez Junior ou Senior.';
}

String gradeLabel(String? category, int? passage) {
  final label = juniorCategories[category];
  if (label == null) return '';
  if (passage == null) return label;
  final suffix = switch (passage) {
    1 => '1er passage',
    2 => '2e passage',
    3 => '3e passage',
    4 => '4e passage',
    _ => '',
  };
  return suffix.isEmpty ? label : '$label — $suffix';
}
