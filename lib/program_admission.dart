import 'models.dart';

/// Le programme officiel crée une ADMISSION DE SUIVI automatique.
/// Une date programmée ne prouve ni la présence physique ni la fin de
/// l'intervention : l'interface doit toujours afficher sa provenance.
class ProgramAdmission {
  static const source = 'Admission automatique · programme opératoire';

  static void apply(PatientCase patient, DateTime today) {
    if (!patient.fromBlocProgram || patient.stage == CaseStage.notAdmitted ||
        patient.stage == CaseStage.discharged) return;
    final date = patient.blockAt;
    final opDate = DateTime(date.year, date.month, date.day);
    final nowDate = DateTime(today.year, today.month, today.day);
    patient.admittedAt = opDate; // Date de référence, PAS heure réelle d'arrivée.
    patient.admissionTiming = source;
    patient.stage = opDate.isAfter(nowDate)
        ? CaseStage.preoperative
        : CaseStage.postoperative;
  }

  static void omit(PatientCase patient) {
    if (!patient.fromBlocProgram) {
      throw StateError('Exclusion réservée aux patients importés du bloc.');
    }
    patient.stage = CaseStage.notAdmitted;
    patient.admittedAt = null;
    patient.admissionTiming = 'Non admis · absence constatée par le médecin';
  }

  static void restore(PatientCase patient, DateTime today) {
    if (!patient.fromBlocProgram || patient.stage != CaseStage.notAdmitted) {
      throw StateError('Le patient ne possède pas une exclusion à rétablir.');
    }
    apply(patient, today);
  }
}
