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
    'insurance': patient.insurance,
    'motive': patient.motive,
    'history': patient.history,
    'exam': patient.exam,
    'investigations': patient.investigations,
    'labs': patient.labs,
    'immediatePlan': patient.immediatePlan,
    'stage': patient.stage.name,
    'admissionTiming': patient.admissionTiming,
    'admittedAt': patient.admittedAt?.toIso8601String(),
    'consultationAt': patient.consultationAt?.toIso8601String(),
    'professorId': patient.professorId,
    'assignmentMode': patient.assignmentMode,
    'assignmentExplanation': patient.assignmentExplanation,
    'beforeUnit': patient.beforeUnit,
    'beforeBox': patient.beforeBox,
    'afterUnit': patient.afterUnit,
    'afterBox': patient.afterBox,
    'expectedDays': patient.expectedDays,
    'confidentialEnvelopeDone': patient.confidentialEnvelopeDone,
    'dischargeAt': patient.dischargeAt?.toIso8601String(),
    'dischargePrescription': patient.dischargePrescription,
    'dischargeReport': patient.dischargeReport,
    'operationReport': patient.operationReport,
    'documents': patient.documents.map((key, value) => MapEntry(key, {
      'verified': value.verified,
      'stamped': value.stamped,
      'notApplicable': value.notApplicable,
      'checkedAt': value.checkedAt?.toIso8601String(),
    })),
    'dailyObservations': patient.dailyObservations.map((note) => {
      'date': note.date.toIso8601String(),
      'vitals': note.vitals,
      'symptoms': note.symptoms,
      'clinicalExam': note.clinicalExam,
      'results': note.results,
      'plan': note.plan,
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
    patient.insurance = _text(data['insurance']).isEmpty
      ? 'À préciser' : _text(data['insurance']);
    patient.motive = _text(data['motive']);
    patient.history = _text(data['history']);
    patient.exam = _text(data['exam']);
    patient.investigations = _text(data['investigations']);
    patient.labs = _text(data['labs']);
    patient.immediatePlan = _text(data['immediatePlan']);
    final admitted = _date(data['admittedAt']);
    patient.admittedAt = admitted;
    patient.consultationAt = _date(data['consultationAt']);
    // Un dossier programmé n'acquiert pas le statut hospitalisé par la date du bloc.
    final requestedStage = _text(data['stage']);
    patient.stage = admitted == null ? CaseStage.scheduled :
      CaseStage.values.firstWhere(
        (value) => value.name == requestedStage,
        orElse: () => CaseStage.preoperative);
    patient.admissionTiming = admitted == null
      ? 'À confirmer' : _text(data['admissionTiming']);
    patient.professorId = data['professorId'] is String
      ? data['professorId'] as String : patient.professorId;
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
          ..checkedAt = _date(state['checkedAt']);
        patient.documents[item.key as String] = doc;
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

  Future<void> save(PatientCase patient) async {
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
        'p_clinical_data': encode(patient),
      },
    );
    if (result is! int) throw StateError('Enregistrement non confirmé.');
    patient.clinicalVersion = result;
  }
}
