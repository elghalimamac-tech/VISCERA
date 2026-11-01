import 'package:supabase_flutter/supabase_flutter.dart';
import 'bloc_clinical_record.dart';
import 'models.dart';

/// Séjours créés manuellement par les médecins approuvés.
/// Le serveur est la source de vérité. Aucune identité patient n'est mise en cache.
class ManualAdmissionService {
  static String _str(dynamic x) => (x ?? '').toString();

  static PatientCase fromServer(Map<String, dynamic> row) {
    final blockAt = DateTime.tryParse(_str(row['block_at']))?.toLocal();
    if (blockAt == null) throw const FormatException('Date du bloc invalide');
    final data = row['clinical_data'];
    if (data is! Map) throw const FormatException('Dossier clinique invalide');
    final patient = PatientCase(
      id: 'MANUAL-${row['id']}',
      name: _str(row['name']),
      age: '—',
      origin: _str(row['origin']),
      insurance: 'À préciser',
      motive: '', history: '', exam: '', investigations: '', labs: '',
      immediatePlan: '',
      procedure: _str(row['procedure_name']),
      blockTiming: _str(row['block_timing']),
      admissionTiming: 'À confirmer',
      beforeUnit: '', beforeBox: '', afterUnit: '', afterBox: '',
      expectedDays: 0,
      blockAt: blockAt,
      admittedAt: null,
      fromManualAdmission: true,
      stage: CaseStage.scheduled,
    );
    BlocClinicalRecordService.apply(
      patient, Map<String, dynamic>.from(data),
      row['version'] is int ? row['version'] as int : 1,
    );
    return patient;
  }

  /// La creation est atomique : Supabase refuse les doublons, y compris
  /// un patient deja present dans le programme officiel du meme jour.
  Future<PatientCase> create(PatientCase draft) async {
    final isoDate = '${draft.blockAt.year.toString().padLeft(4,'0')}-'
      '${draft.blockAt.month.toString().padLeft(2,'0')}-'
      '${draft.blockAt.day.toString().padLeft(2,'0')}';
    final rawId = await Supabase.instance.client.rpc(
      'viscera_create_manual_patient',
      params: {
        'p_name': draft.name,
        'p_origin': draft.origin,
        'p_procedure': draft.procedure,
        'p_block_at': draft.blockAt.toUtc().toIso8601String(),
        'p_block_date': isoDate,
        'p_block_timing': draft.blockTiming,
        'p_clinical_data': BlocClinicalRecordService.encode(draft),
      },
    );
    if (rawId is! String || rawId.isEmpty) {
      throw StateError('La creation du dossier n’a pas été confirmée.');
    }
    final patient = PatientCase(
      id: 'MANUAL-$rawId',
      name: draft.name, age: draft.age,
      origin: draft.origin, insurance: draft.insurance,
      motive: draft.motive, history: draft.history, exam: draft.exam,
      investigations: draft.investigations, labs: draft.labs,
      immediatePlan: draft.immediatePlan,
      procedure: draft.procedure, blockTiming: draft.blockTiming,
      admissionTiming: draft.admissionTiming,
      beforeUnit: draft.beforeUnit, beforeBox: draft.beforeBox,
      afterUnit: draft.afterUnit, afterBox: draft.afterBox,
      expectedDays: draft.expectedDays, blockAt: draft.blockAt,
      admittedAt: draft.admittedAt, consultationAt: draft.consultationAt,
      professorId: draft.professorId,
      fromManualAdmission: true,
      assignmentMode: draft.assignmentMode,
      assignmentExplanation: draft.assignmentExplanation,
      stage: draft.stage,
    );
    BlocClinicalRecordService.apply(
      patient, BlocClinicalRecordService.encode(draft), 1,
    );
    return patient;
  }

  Future<List<PatientCase>> fetch() async {
    const pageSize = 300;
    var offset = 0;
    final patients = <PatientCase>[];
    while (true) {
      final rows = await Supabase.instance.client.from('manual_patient_records')
        .select('id,name,origin,procedure_name,block_at,block_date,block_timing,clinical_data,version')
        .order('created_at', ascending: false)
        .range(offset, offset + pageSize - 1);
      for (final row in rows) {
        patients.add(fromServer(Map<String, dynamic>.from(row)));
      }
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return patients;
  }

  Future<void> save(PatientCase patient) async {
    if (!patient.fromManualAdmission || !patient.id.startsWith('MANUAL-')) {
      throw StateError('Admission manuelle persistée requise.');
    }
    final id = patient.id.substring('MANUAL-'.length);
    final result = await Supabase.instance.client.rpc(
      'viscera_save_manual_patient_record',
      params: {
        'p_id': id,
        'p_expected_version': patient.clinicalVersion,
        'p_clinical_data': BlocClinicalRecordService.encode(patient),
      },
    );
    if (result is! int) throw StateError('Enregistrement non confirmé.');
    patient.clinicalVersion = result;
  }
}
