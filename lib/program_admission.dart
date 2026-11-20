import 'models.dart';

/// Admission administrative/de suivi à partir d'une ligne du programme.
/// N'atteste ni la présence réelle, ni la fin de l'intervention, ni un lit.
class ProgramAdmission {
  static const source = 'Admission automatique · programme opératoire';
  static const omission = 'Non admis · exclusion confirmée';

  static void apply(PatientCase patient, DateTime now) {
    if(!patient.fromBlocProgram ||
       patient.stage == CaseStage.notAdmitted ||
       patient.stage == CaseStage.discharged)return;
    final surgeryDay=DateTime(patient.blockAt.year,
      patient.blockAt.month,patient.blockAt.day);
    patient.admittedAt ??= surgeryDay;
    // Le service considère les trois pièces d'admission déjà présentes
    // pour les patients du programme. Ne jamais remplacer une correction
    // manuelle ou une pièce explicitement décochée après import.
    for (final requirement in ClinicalDocuments.admission) {
      if(patient.documents.containsKey(requirement.key))continue;
      patient.documents[requirement.key] = DocumentCheck()
        ..verified = true
        ..stamped = requirement.needsStamp ? true : null
        ..fromProgram = true;
    }
    if(patient.admissionTiming.isEmpty || patient.admissionTiming=='À confirmer'
        || patient.admissionTiming==source) {
      patient.admissionTiming=source;
    }
    // Les admissions issues du programme basculent directement dans le
    // parcours "bloc déjà passé" lorsque le créneau opératoire est écoulé.
    // Un programme futur reste préopératoire : on ne présume pas d'une
    // intervention qui n'a pas encore pu se dérouler. Si l'heure n'est pas
    // connue (00:00 par défaut), attendre le lendemain du jour programmé.
    final today = DateTime(now.year, now.month, now.day);
    final hasKnownTime = patient.blockAt.hour != 0 ||
        patient.blockAt.minute != 0;
    final afterProgram = hasKnownTime
        ? !now.isBefore(patient.blockAt)
        : today.isAfter(surgeryDay);
    if (patient.stage == CaseStage.scheduled ||
        patient.stage == CaseStage.preoperative) {
      patient.stage = afterProgram
          ? CaseStage.postoperative
          : CaseStage.preoperative;
    }
  }

  static void omit(PatientCase patient) {
    if(!patient.fromBlocProgram || patient.stage == CaseStage.discharged) {
      throw StateError('L’exclusion concerne un dossier importé non sorti.');
    }
    patient.stage=CaseStage.notAdmitted;
    patient.admittedAt=null;
    patient.admissionTiming=omission;
  }

  static void restore(PatientCase patient, DateTime now) {
    if(!patient.fromBlocProgram || patient.stage!=CaseStage.notAdmitted) {
      throw StateError('Aucune exclusion à annuler.');
    }
    patient.stage=CaseStage.scheduled;
    patient.admittedAt=null;
    patient.admissionTiming=source;
    apply(patient,now);
  }
}
