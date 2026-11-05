import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

/// Each successful AI response is an immutable, auditable patient report.
/// The server performs the write; Flutter is only allowed to read with RLS.
class ClinicalAiSavedReport {
  ClinicalAiSavedReport({
    required this.id,
    required this.createdAt,
    required this.createdByName,
    required this.model,
    required this.result,
    required this.references,
    this.bibliographyReviewedAt,
    required this.sourcesLiveVerified,
  });

  final String id;
  final DateTime createdAt;
  final String createdByName;
  final String model;
  final Map<String, dynamic> result;
  final List<Map<String, dynamic>> references;
  final String? bibliographyReviewedAt;
  final bool sourcesLiveVerified;

  static ClinicalAiSavedReport fromJson(Map<String, dynamic> json) {
    final response = json['result'];
    final bibliography = json['reference_catalog'];
    return ClinicalAiSavedReport(
      id: json['id'].toString(),
      createdAt: DateTime.tryParse(json['created_at'].toString())
        ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      createdByName: json['created_by_name']?.toString() ?? 'Médecin',
      model: json['model']?.toString() ?? '',
      result: response is Map ? Map<String, dynamic>.from(response) : {},
      references: bibliography is List
        ? bibliography.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[],
      bibliographyReviewedAt:
        json['bibliography_reviewed_at']?.toString(),
      sourcesLiveVerified: json['sources_live_verified'] == true,
    );
  }

  int get hypothesisCount {
    final hypotheses = result['hypotheses'];
    return hypotheses is List ? hypotheses.length : 0;
  }
}

class ClinicalAiReports {
  const ClinicalAiReports._();

  static Map<String, String>? patientReference(PatientCase patient) {
    if (patient.fromManualAdmission && patient.id.startsWith('MANUAL-')) {
      final id = patient.id.substring('MANUAL-'.length).trim();
      if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-'
        r'[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-'
        r'[0-9a-fA-F]{12}
        return {'kind': 'manual', 'id': id};
      }
    }
    if (patient.fromBlocProgram && patient.id.startsWith('BLOC-')) {
      final id = patient.id.substring('BLOC-'.length);
      final entry = int.tryParse(id);
      if (entry != null && entry > 0) {
        return {'kind': 'bloc', 'id': entry.toString()};
      }
    }
    return null;
  }

  /// RLS checks the doctor's approved hospital membership on every read.
  /// The record id is checked against the patient, not just the report UUID.
  static Future<List<ClinicalAiSavedReport>> list(
    PatientCase patient, {int limit = 40}) async {
    final reference = patientReference(patient);
    if (reference == null) return const [];
    final column = reference['kind'] == 'bloc'
      ? 'bloc_entry_id' : 'manual_patient_id';
    final value = reference['kind'] == 'bloc'
      ? int.parse(reference['id']!) : reference['id']!;
    final raw = await Supabase.instance.client
      .from('viscera_clinical_ai_reports')
      .select('id,created_at,created_by_name,model,result,'
        'reference_catalog,bibliography_reviewed_at,sources_live_verified')
      .eq(column, value)
      .order('created_at', ascending: false)
      .limit(limit.clamp(1, 100).toInt());
    return raw.map((item) =>
      ClinicalAiSavedReport.fromJson(Map<String, dynamic>.from(item))).toList();
  }
}
).hasMatch(id)) {
        return {'kind': 'manual', 'id': id};
      }
    }
    if (patient.fromBlocProgram && patient.id.startsWith('BLOC-')) {
      final id = patient.id.substring('BLOC-'.length);
      final entry = int.tryParse(id);
      if (entry != null && entry > 0) {
        return {'kind': 'bloc', 'id': entry.toString()};
      }
    }
    return null;
  }

  /// RLS checks the doctor's approved hospital membership on every read.
  /// The record id is checked against the patient, not just the report UUID.
  static Future<List<ClinicalAiSavedReport>> list(
    PatientCase patient, {int limit = 40}) async {
    final reference = patientReference(patient);
    if (reference == null) return const [];
    final column = reference['kind'] == 'bloc'
      ? 'bloc_entry_id' : 'manual_patient_id';
    final value = reference['kind'] == 'bloc'
      ? int.parse(reference['id']!) : reference['id']!;
    final raw = await Supabase.instance.client
      .from('viscera_clinical_ai_reports')
      .select('id,created_at,created_by_name,model,result,'
        'reference_catalog,bibliography_reviewed_at,sources_live_verified')
      .eq(column, value)
      .order('created_at', ascending: false)
      .limit(limit.clamp(1, 100).toInt());
    return raw.map((item) =>
      ClinicalAiSavedReport.fromJson(Map<String, dynamic>.from(item))).toList();
  }
}
