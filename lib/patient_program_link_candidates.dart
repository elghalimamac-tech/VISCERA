import 'models.dart';

/// Candidats au rapprochement : jamais une preuve d'identité.
/// La décision finale appartient au soignant et au contrôle serveur.
class PatientProgramLinkCandidates {
  static String _nameKey(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool canLink(PatientCase manual, PatientCase programmed) {
    if (!manual.fromManualAdmission || !programmed.fromBlocProgram ||
        manual.birthDate == null ||
        manual.isOmitted || manual.isArchived ||
        programmed.isOmitted || programmed.isArchived ||
        _nameKey(manual.name) != _nameKey(programmed.name)) {
      return false;
    }
    final operativeDay = _day(programmed.blockAt);
    // Un séjour réellement commencé peut recevoir une programmation ultérieure,
    // quelle que soit la provenance (Urgences ou Consultation).
    final admission = manual.admittedAt;
    if (manual.isActive && admission != null) {
      return !operativeDay.isBefore(_day(admission));
    }
    // Compatibilité avec une consultation programmée, pas encore hospitalisée.
    return manual.origin == 'Consultation' && manual.isProgrammed &&
        operativeDay == _day(manual.blockAt);
  }

  static List<PatientCase> forManual(PatientCase manual,
          Iterable<PatientCase> officialCases) =>
      officialCases.where((p) => canLink(manual, p)).toList()
        ..sort((a, b) => a.blockAt.compareTo(b.blockAt));

  static List<PatientCase> forProgram(PatientCase programmed,
          Iterable<PatientCase> manualCases) =>
      manualCases.where((p) => canLink(p, programmed)).toList()
        ..sort((a, b) =>
            (b.admittedAt ?? b.blockAt).compareTo(a.admittedAt ?? a.blockAt));
}
