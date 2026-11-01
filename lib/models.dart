class ServiceUnit {
  const ServiceUnit(this.code, this.label);
  final String code;
  final String label;
}

const hospitalUnits = <ServiceUnit>[
  ServiceUnit('TC1', 'TC1'),
  ServiceUnit('TC2', 'TC2'),
  ServiceUnit('HGO', 'HGO'),
  ServiceUnit('HDJCH 1', 'HDJCH 1'),
  ServiceUnit('HDJM 1', 'HDJM 1'),
  ServiceUnit('HDJM 0', 'HDJM 0'),
  ServiceUnit('REA ADULTE', 'Réanimation adulte'),
  ServiceUnit('REA POLY', 'Réanimation polyvalente'),
];

const procedures = <String>[
  'Appendicectomie sous cœlioscopie',
  'Cholécystectomie sous cœlioscopie',
  'Autre intervention',
  'À préciser',
];

const healthInsurances = <String>[
  'FAR', 'CNOPS', 'CNSS', 'Assurance privée', 'AMO / autre', 'Sans mutuelle', 'À préciser',
];

enum CaseStage { scheduled, preoperative, inTheatre, postoperative, dischargeReady, discharged }

extension CaseStageLabel on CaseStage {
  String get label => switch (this) {
    CaseStage.scheduled => 'Programmé',
    CaseStage.preoperative => 'Préopératoire',
    CaseStage.inTheatre => 'Au bloc',
    CaseStage.postoperative => 'Postopératoire',
    CaseStage.dischargeReady => 'Sortie à valider',
    CaseStage.discharged => 'Sorti',
  };
}

/// États séparés : document vérifié, cachet contrôlé, non applicable.
/// Les mêmes documents (CRO, prestations, honoraires, anatomopathologie)
/// sont partagés entre le contrôle postopératoire et la sortie.
class DocumentRequirement {
  const DocumentRequirement(this.key, this.title, {this.needsStamp = true, this.optional = false});
  final String key, title;
  final bool needsStamp, optional;
}

class DocumentCheck {
  bool verified = false;
  bool? stamped;
  bool notApplicable = false;
  DateTime? checkedAt;
  bool complete(DocumentRequirement requirement) => notApplicable && requirement.optional ||
      verified && (!requirement.needsStamp || stamped == true);
}

class ClinicalDocuments {
  static const admission = <DocumentRequirement>[
    DocumentRequirement('bulletin', 'Bulletin d’hospitalisation'),
    DocumentRequirement('pli', 'Pli confidentiel'),
    DocumentRequirement('consent', 'Consentement éclairé du patient', needsStamp:false),
  ];
  static const postBlock = <DocumentRequirement>[
    DocumentRequirement('cro', 'Compte rendu opératoire'),
    DocumentRequirement('prestations', 'Prestations'),
    DocumentRequirement('honoraires', 'Notes d’honoraires'),
    DocumentRequirement('anapath', 'Anatomopathologie', optional:true),
  ];
  static const discharge = <DocumentRequirement>[
    DocumentRequirement('ordonnance_medicale', 'Ordonnance médicale'),
    DocumentRequirement('ordonnance_sortie', 'Ordonnance de sortie'),
    DocumentRequirement('rapport', 'Rapport d’hospitalisation'),
    DocumentRequirement('cro', 'Compte rendu opératoire'),
    DocumentRequirement('prestations', 'Prestations'),
    DocumentRequirement('honoraires', 'Notes d’honoraires'),
    DocumentRequirement('rdv', 'Rendez-vous de contrôle', needsStamp:false),
    DocumentRequirement('anapath', 'Anatomopathologie', optional:true),
    DocumentRequirement('bilans', 'Bilans', optional:true),
    DocumentRequirement('imagerie', 'Imagerie', optional:true),
    DocumentRequirement('certificat', 'Certificat médical', optional:true),
  ];
}

/// Une observation par date civile et par dossier, modifiable au cours du séjour.
/// Magica et Sillage sont des attestations de REPORT MANUEL, sans synchronisation.
class DailyObservation {
  DailyObservation({required this.date, this.vitals = '', this.symptoms = '',
    this.clinicalExam = '', this.results = '', this.plan = '',
    this.reportedMagica = false, this.reportedSillage = false,
    this.reportedMagicaAt, this.reportedSillageAt, DateTime? updatedAt})
      : updatedAt = updatedAt ?? DateTime.now();
  final DateTime date;
  String vitals, symptoms, clinicalExam, results, plan;
  bool reportedMagica, reportedSillage;
  DateTime? reportedMagicaAt, reportedSillageAt;
  DateTime updatedAt;
  bool get hasContent => [vitals, symptoms, clinicalExam, results, plan].any((s) => s.trim().isNotEmpty);
  bool get fullyReported => reportedMagica && reportedSillage;
}

class PatientCase {
  PatientCase({
    required this.id,
    required this.name,
    required this.age,
    required this.origin,
    required this.insurance,
    required this.motive,
    required this.history,
    required this.exam,
    required this.investigations,
    required this.labs,
    required this.immediatePlan,
    required this.procedure,
    required this.blockTiming,
    required this.admissionTiming,
    required this.beforeUnit,
    required this.beforeBox,
    required this.afterUnit,
    required this.afterBox,
    required this.expectedDays,
    required this.blockAt,
    this.admittedAt,
    this.consultationAt,
    this.professorId,
    this.fromBlocProgram = false,
    this.fromManualAdmission = false,
    this.birthDate,
    this.surgeryType = '',
    this.linkedProgramEntryId,
    this.programRoom = '',
    this.programSurgeon = '',
    this.programSourceService = '',
    this.programScheduledTime = '',
    this.assignmentMode = 'Non attribué',
    this.assignmentExplanation = '',
    this.stage = CaseStage.preoperative,
    this.confidentialEnvelopeDone = false,
    this.dischargeAt,
    this.dischargePrescription = '',
    this.dischargeReport = '',
    this.operationReport = '',
  });

  final String id, name, origin;
  String age, insurance;
  DateTime? birthDate;
  String surgeryType;
  int? linkedProgramEntryId;
  String motive, history, exam;
  String investigations, labs, immediatePlan;
  final String procedure, blockTiming;
  String admissionTiming;
  String beforeUnit, beforeBox, afterUnit, afterBox;
  int expectedDays;
  final DateTime blockAt;
  DateTime? admittedAt;
  DateTime? consultationAt;
  int clinicalVersion = 0;
  /// Programme officiel uniquement, sans admission ni dossier clinique inventé.
  final bool fromBlocProgram;
  final bool fromManualAdmission;
  String programRoom, programSurgeon, programSourceService, programScheduledTime;
  /// ID interne du médecin responsable (professeur ou senior d’astreinte).
  String? professorId;
  String assignmentMode, assignmentExplanation;
  CaseStage stage;
  bool confidentialEnvelopeDone;
  final Map<String, DocumentCheck> documents = {};
  final List<DailyObservation> dailyObservations = [];
  DocumentCheck check(String key) => documents.putIfAbsent(key, DocumentCheck.new);
  int completedCount(List<DocumentRequirement> requirements) =>
      requirements.where((r) => check(r.key).complete(r)).length;
  bool allChecked(List<DocumentRequirement> requirements) =>
      completedCount(requirements) == requirements.length;

  DateTime? dischargeAt;
  String dischargePrescription, dischargeReport, operationReport;

  bool get isFar => insurance == 'FAR';
  bool get isActive => stage != CaseStage.discharged && stage != CaseStage.scheduled;
  bool get isProgrammed => stage == CaseStage.scheduled;
  bool get isPostOp => stage == CaseStage.postoperative || stage == CaseStage.dischargeReady;
  bool get physicallyAdmitted =>
      isActive && admittedAt != null;
  DateTime get expectedDischargeAt => DateTime(blockAt.year, blockAt.month, blockAt.day + expectedDays);
  bool get dischargeDue => expectedDays > 0 && isPostOp && !DateTime.now().isBefore(expectedDischargeAt);
  String get currentUnit => isPostOp ? afterUnit : beforeUnit;
  String get currentBox => isPostOp ? afterBox : beforeBox;
}
