import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

/// Modifications cliniques liées à une ligne du programme officiel.
/// Le nom, l'intervention et le chirurgien du fichier source restent inchangés.
class BlocClinicalRecordService {
  const BlocClinicalRecordService();

  static String _text(dynamic value) => value is String ? value : '';
  static DateTime? _date(dynamic value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
  static bool _bool(dynamic value) => value == true;

  static Map<String, dynamic> encode(PatientCase patient) => {
    'age': patient.age,
    'birthDate': patient.birthDate == null ? null : '${patient.birthDate!.year.toString().padLeft(4,'0')}-${patient.birthDate!.month.toString().padLeft(2,'0')}-${patient.birthDate!.day.toString().padLeft(2,'0')}',
    'surgeryType': patient.surgeryType,
    'procedureOverride': patient.procedureOverride,
    'insurance': patient.insurance,
    'motive': patient.motive,
    'history': patient.history,
    'exam': patient.exam,
    'investigations': patient.investigations,
    'labs': patient.labs,
    'immediatePlan': patient.immediatePlan,
    'cfsScore': patient.cfsScore,
    'cfsBaselineDate': patient.cfsBaselineDate == null ? null :
      '${patient.cfsBaselineDate!.year.toString().padLeft(4,'0')}-${patient.cfsBaselineDate!.month.toString().padLeft(2,'0')}-${patient.cfsBaselineDate!.day.toString().padLeft(2,'0')}',
    'cfsAssessedAt': patient.cfsAssessedAt?.toIso8601String(),
    'asaClass': patient.asaClass,
    'comorbiditySummary': patient.comorbiditySummary,
    'nutritionAssessmentStatus': patient.nutritionAssessmentStatus,
    'geriatricAssessmentStatus': patient.geriatricAssessmentStatus,
    'clinicalScores': patient.clinicalScores,
    'cpaStatus': patient.cpaStatus,
    'preopLabStatus': patient.preopLabStatus,
    'admissionPrescriptionStatus': patient.admissionPrescriptionStatus,
    'admissionPrescriptionDetails': patient.admissionPrescriptionDetails,
    'stage': patient.stage.name,
    'admissionTiming': patient.admissionTiming,
    'admittedAt': patient.admittedAt?.toIso8601String(),
    'consultationAt': patient.consultationAt?.toIso8601String(),
    'professorId': patient.professorId,
    'blockResponsibleId': patient.blockResponsibleId,
    'assignmentMode': patient.assignmentMode,
    'assignmentExplanation': patient.assignmentExplanation,
    'beforeUnit': patient.beforeUnit,
    'beforeBox': patient.beforeBox,
    'afterUnit': patient.afterUnit,
    'afterBox': patient.afterBox,
    'expectedDays': patient.expectedDays,
    'confidentialEnvelopeDone': patient.confidentialEnvelopeDone,
    'dischargeAt': patient.dischargeAt?.toIso8601String(),
    'dischargeMedicalValidation': patient.dischargeMedicalValidated,
    'dischargeFarValidation': patient.dischargeFarValidated,
    'dischargePrescription': patient.dischargePrescription,
    'dischargeReport': patient.dischargeReport,
    'operationReport': patient.operationReport,
    'documents': patient.documents.map((key, value) => MapEntry(key, {
      'verified': value.verified,
      'stamped': value.stamped,
      'notApplicable': value.notApplicable,
      'checkedAt': value.checkedAt?.toIso8601String(),
      'fromProgram': value.fromProgram,
    })),
    'specialistOpinions': patient.specialistOpinions.map((opinion) => {
      'id': opinion.id,
      'service': opinion.service,
      'done': opinion.done,
      'requestedAt': opinion.requestedAt.toIso8601String(),
      'doneAt': opinion.doneAt?.toIso8601String(),
    }).toList(),
    'dailyObservations': patient.dailyObservations.map((note) => {
      'date': note.date.toIso8601String(),
      'vitals': note.vitals,
      'symptoms': note.symptoms,
      'clinicalExam': note.clinicalExam,
      'results': note.results,
      'plan': note.plan,
      'biology': note.biology,
      'reportedMagica': note.reportedMagica,
      'reportedSillage': note.reportedSillage,
      'reportedMagicaAt': note.reportedMagicaAt?.toIso8601String(),
      'reportedSillageAt': note.reportedSillageAt?.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
    }).toList(),
  };

  static void apply(PatientCase patient, Map<String, dynamic> data, int version) {
    patient.clinicalVersion = version;
    patient.age = _text(data['age']).isEmpty ? '—' : _text(data['age']);
    patient.birthDate = _date(data['birthDate']) ?? patient.birthDate;
    patient.surgeryType = _text(data['surgeryType']).isEmpty ? patient.surgeryType : _text(data['surgeryType']);
    patient.procedureOverride = _text(data['procedureOverride']);
    patient.insurance = _text(data['insurance']).isEmpty
      ? 'À préciser' : _text(data['insurance']);
    patient.motive = _text(data['motive']);
    patient.history = _text(data['history']);
    patient.exam = _text(data['exam']);
    patient.investigations = _text(data['investigations']);
    patient.labs = _text(data['labs']);
    patient.immediatePlan = _text(data['immediatePlan']);
    final score = data['cfsScore'];
    patient.cfsScore = score is int && score >= 1 && score <= 9 ? score : null;
    patient.cfsBaselineDate = _date(data['cfsBaselineDate']);
    patient.cfsAssessedAt = _date(data['cfsAssessedAt']);
    final asa = _text(data['asaClass']);
    patient.asaClass = const {'I','II','III','IV','V','VI'}.contains(asa) ? asa : '';
    patient.comorbiditySummary = _text(data['comorbiditySummary']);
    final nutrition = _text(data['nutritionAssessmentStatus']);
    patient.nutritionAssessmentStatus =
      const {'a_evaluer','faite','non_indiquee'}.contains(nutrition)
        ? nutrition : 'a_evaluer';
    final geriatrics = _text(data['geriatricAssessmentStatus']);
    patient.geriatricAssessmentStatus =
      const {'a_evaluer','faite','non_indiquee'}.contains(geriatrics)
        ? geriatrics : 'a_evaluer';
    final rawScores = data['clinicalScores'];
    patient.clinicalScores = rawScores is Map
      ? Map<String, dynamic>.from(rawScores)
      : <String, dynamic>{};
    patient.cpaStatus = _text(data['cpaStatus']).isEmpty ? 'a_verifier' : _text(data['cpaStatus']);
    patient.preopLabStatus = _text(data['preopLabStatus']).isEmpty ? 'a_verifier' : _text(data['preopLabStatus']);
    patient.admissionPrescriptionStatus = _text(data['admissionPrescriptionStatus']).isEmpty ? 'a_verifier' : _text(data['admissionPrescriptionStatus']);
    patient.admissionPrescriptionDetails = _text(data['admissionPrescriptionDetails']);
    final admitted = _date(data['admittedAt']);
    patient.consultationAt = _date(data['consultationAt']);
    final requestedStage = _text(data['stage']);
    if(patient.fromBlocProgram) {
      // L'exclusion est explicite et prévaut toujours sur le programme.
      // Les anciennes sauvegardes "scheduled" ne désactivent plus
      // l'admission de suivi automatique.
      if(requestedStage == CaseStage.notAdmitted.name) {
        patient.stage = CaseStage.notAdmitted;
        patient.admittedAt = null;
        patient.admissionTiming = 'Non admis · exclusion confirmée';
      } else {
        if(admitted != null) patient.admittedAt = admitted;
        if(requestedStage.isNotEmpty &&
           requestedStage != CaseStage.scheduled.name) {
          patient.stage = CaseStage.values.firstWhere(
            (stage)=>stage.name == requestedStage,
            orElse:()=>patient.stage);
        }
        final timing = _text(data['admissionTiming']);
        if(timing.isNotEmpty && timing != 'À confirmer') {
          patient.admissionTiming = timing;
        }
      }
    } else {
      patient.admittedAt = admitted;
      patient.stage = admitted == null ? CaseStage.scheduled :
        CaseStage.values.firstWhere(
          (stage)=>stage.name == requestedStage,
          orElse:()=>CaseStage.preoperative);
      patient.admissionTiming = admitted == null
        ? 'À confirmer' : _text(data['admissionTiming']);
    }
    patient.professorId = data['professorId'] is String
      ? data['professorId'] as String : patient.professorId;
    patient.blockResponsibleId = data['blockResponsibleId'] is String
      ? data['blockResponsibleId'] as String : patient.blockResponsibleId;
    patient.assignmentMode = _text(data['assignmentMode']);
    patient.assignmentExplanation = _text(data['assignmentExplanation']);
    patient.beforeUnit = _text(data['beforeUnit']);
    patient.beforeBox = _text(data['beforeBox']);
    patient.afterUnit = _text(data['afterUnit']);
    patient.afterBox = _text(data['afterBox']);
    patient.expectedDays = data['expectedDays'] is int
      ? data['expectedDays'] as int : 0;
    patient.confidentialEnvelopeDone = _bool(data['confidentialEnvelopeDone']);
    patient.dischargeAt = _date(data['dischargeAt']);
    patient.dischargeMedicalValidated = _bool(data['dischargeMedicalValidation']);
    patient.dischargeFarValidated = _bool(data['dischargeFarValidation']);
    patient.dischargePrescription = _text(data['dischargePrescription']);
    patient.dischargeReport = _text(data['dischargeReport']);
    patient.operationReport = _text(data['operationReport']);
    patient.documents.clear();
    if (data['documents'] is Map) {
      final docs = data['documents'] as Map;
      for (final item in docs.entries) {
        if (item.key is! String || item.value is! Map) continue;
        final state = Map<String, dynamic>.from(item.value as Map);
        final doc = DocumentCheck()
          ..verified = _bool(state['verified'])
          ..stamped = state['stamped'] is bool ? state['stamped'] as bool : null
          ..notApplicable = _bool(state['notApplicable'])
          ..checkedAt = _date(state['checkedAt'])
          ..fromProgram = _bool(state['fromProgram']);
        patient.documents[item.key as String] = doc;
      }
    }
    // Compatibilité : les anciens dossiers n'ont pas ce tableau.
    patient.specialistOpinions.clear();
    if (data['specialistOpinions'] is List) {
      final seenIds = <String>{};
      for (final raw in data['specialistOpinions'] as List) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final id = _text(item['id']);
        final service = _text(item['service']).trim();
        if (id.isEmpty || service.isEmpty || !seenIds.add(id)) continue;
        final done = _bool(item['done']);
        patient.specialistOpinions.add(SpecialistOpinion(
          id: id,
          service: service,
          done: done,
          requestedAt: _date(item['requestedAt']) ?? patient.blockAt,
          doneAt: done ? _date(item['doneAt']) : null,
        ));
      }
    }
    patient.dailyObservations.clear();
    if (data['dailyObservations'] is List) {
      for (final raw in data['dailyObservations'] as List) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final date = _date(item['date']);
        if (date == null) continue;
        patient.dailyObservations.add(DailyObservation(
          date: date,
          vitals: _text(item['vitals']),
          symptoms: _text(item['symptoms']),
          clinicalExam: _text(item['clinicalExam']),
          results: _text(item['results']),
          plan: _text(item['plan']),
          biology: item['biology'] is Map
            ? Map<String, double>.fromEntries(
                (item['biology'] as Map).entries.where(
                  (e) => e.key is String && e.value is num).map(
                    (e) => MapEntry(e.key as String,(e.value as num).toDouble())))
            : const {},
          reportedMagica: _bool(item['reportedMagica']),
          reportedSillage: _bool(item['reportedSillage']),
          reportedMagicaAt: _date(item['reportedMagicaAt']),
          reportedSillageAt: _date(item['reportedSillageAt']),
          updatedAt: _date(item['updatedAt']),
        ));
      }
    }
    patient.dailyObservations.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> save(PatientCase patient, {Map<String,dynamic>? clinicalData}) async {
    if (!patient.fromBlocProgram || !patient.id.startsWith('BLOC-')) {
      throw StateError('Le dossier ne provient pas du programme officiel.');
    }
    final entryId = int.tryParse(patient.id.substring('BLOC-'.length));
    if (entryId == null) throw StateError('Identifiant du programme invalide.');
    final result = await Supabase.instance.client.rpc(
      'viscera_save_bloc_patient_record',
      params: {
        'p_entry_id': entryId,
        'p_expected_version': patient.clinicalVersion,
        'p_clinical_data': clinicalData ?? encode(patient),
      },
    );
    if (result is! int) throw StateError('Enregistrement non confirmé.');
    patient.clinicalVersion = result;
  }
}
