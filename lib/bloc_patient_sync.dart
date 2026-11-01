import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'bloc_clinical_record.dart';
import 'store.dart';

/// Projections des patients issus des programmes officiels du bloc.
//// Le programme ne prouve ni une admission, ni une consultation à une heure connue.
/// Aucun diagnostic, lit, mutuelle ou compte rendu n'est inventé.
class BlocPatientSync {
  static String _str(dynamic value) => (value ?? '').toString().trim();

  static String _surgeonKey(String value) => value.toUpperCase()
    .replaceFirst(RegExp(r'^(PR|DR)\s+'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static DateTime? _scheduledAt(String date, String rawTime) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return null;
    final clock = RegExp(r'^(\d{1,2})\s*[Hh:]\s*(\d{2})$').firstMatch(rawTime);
    if (clock == null) return DateTime(parsed.year, parsed.month, parsed.day);
    final hours = int.tryParse(clock.group(1) ?? '');
    final minutes = int.tryParse(clock.group(2) ?? '');
    if (hours == null || minutes == null || hours > 23 || minutes > 59) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return DateTime(parsed.year, parsed.month, parsed.day, hours, minutes);
  }

  static Future<List<PatientCase>> fetch() async {
    final api = Supabase.instance.client;
    const pageSize = 500;
    final result = <PatientCase>[];
    var offset = 0;
    while (true) {
      // La relation INNER conserve seulement la version active de chaque date.
      // Les règles RLS des deux tables vérifient l'approbation médicale.
      final response = await api.from('bloc_program_entries').select(
        'id,room,scheduled_time,source_service,patient_name,procedure_name,surgeon,'
        'bloc_program_imports!inner(program_date,is_current)',
      ).eq('bloc_program_imports.is_current', true)
        .order('id', ascending: false).range(offset, offset + pageSize - 1);
      if (response.isEmpty) break;
      final ids = response.map((r) => r['id']).whereType<int>().toList();
      final clinical = <int, Map<String, dynamic>>{};
      if (ids.isNotEmpty) {
        final records = await api.from('bloc_patient_records')
          .select('entry_id,version,clinical_data').inFilter('entry_id', ids);
        for (final record in records) {
          final id = record['entry_id'];
          if (id is int) clinical[id] = Map<String, dynamic>.from(record);
        }
      }
      for (final raw in response) {
        final row = Map<String, dynamic>.from(raw);
        final program = row['bloc_program_imports'];
        if (program is! Map || program['is_current'] != true) continue;
        final date = _str(program['program_date']);
        final name = _str(row['patient_name']);
        final procedure = _str(row['procedure_name']);
        final surgeon = _str(row['surgeon']);
        final rowId = row['id'];
        if (name.isEmpty || procedure.isEmpty || surgeon.isEmpty || rowId == null) continue;
        final scheduledAt = _scheduledAt(date, _str(row['scheduled_time']));
        if (scheduledAt == null) continue;
        String? professorId;
        for (final clinician in appStore.professors) {
          if (_surgeonKey(clinician.name) == _surgeonKey(surgeon)) {
            professorId = clinician.id;
            break;
          }
        }
        final patient = PatientCase(
          id: 'BLOC-$rowId',
          name: name,
          age: '—',
          origin: 'Consultation',
          insurance: 'À préciser',
          motive: '',
          history: '',
          exam: '',
          investigations: '',
          labs: '',
          immediatePlan: '',
          procedure: procedure,
          blockTiming: 'Différé',
          admissionTiming: 'À confirmer',
          beforeUnit: '',
          beforeBox: '',
          afterUnit: '',
          afterBox: '',
          expectedDays: 0,
          blockAt: scheduledAt,
          admittedAt: null,
          professorId: professorId,
          assignmentMode: 'Programme officiel du bloc',
          assignmentExplanation: 'Provenance Consultation. Date de consultation inconnue.',
          stage: CaseStage.scheduled,
          fromBlocProgram: true,
          programRoom: _str(row['room']),
          programSurgeon: surgeon,
          programSourceService: _str(row['source_service']),
          programScheduledTime: _str(row['scheduled_time']),
        );
        final saved = clinical[rowId];
        if (saved != null && saved['clinical_data'] is Map) {
          BlocClinicalRecordService.apply(
            patient,
            Map<String, dynamic>.from(saved['clinical_data'] as Map),
            saved['version'] is int ? saved['version'] as int : 0,
          );
        }
        result.add(patient);
      }
      if (response.length < pageSize) break;
      offset += pageSize;
    }
    // Un même patient peut figurer dans plusieurs interventions : préserver
    // chaque ligne source au lieu de fusionner des homonymes par hypothèse.
    return result..sort((a, b) => b.blockAt.compareTo(a.blockAt));
  }
}
