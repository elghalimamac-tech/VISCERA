import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'surgery_classification.dart';
import 'bloc_clinical_record.dart';
import 'program_admission.dart';
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
    final linkedIds = <int>{};
    for(var page=0;;page+=500){
      final links = await api.from('manual_bloc_links').select('entry_id').eq('hospital_id','huim6')
        .order('entry_id').range(page,page+499);
      linkedIds.addAll(links.map((r)=>r['entry_id']).whereType<int>());
      if(links.length<500)break;
    }
    final result = <PatientCase>[];
    var offset = 0;
    while (true) {
      // La relation INNER conserve seulement la version active de chaque date.
      // Les règles RLS des deux tables vérifient l'approbation médicale.
      final response = await api.from('bloc_program_entries').select(
        'id,room,scheduled_time,source_service,patient_name,procedure_name,surgeon,'
        'bloc_program_imports!inner(program_date,is_current)',
      ).eq('hospital_id','huim6').eq('bloc_program_imports.is_current', true)
        .order('id', ascending: false).range(offset, offset + pageSize - 1);
      if (response.isEmpty) break;
      final ids = response.map((r) => r['id']).whereType<int>().toList();
      final clinical = <int, Map<String, dynamic>>{};
      if (ids.isNotEmpty) {
        final records = await api.from('bloc_patient_records')
          .select('entry_id,version,clinical_data').eq('hospital_id','huim6').inFilter('entry_id', ids);
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
        if (name.isEmpty || procedure.isEmpty || rowId == null || linkedIds.contains(rowId)) continue;
        final scheduledAt = _scheduledAt(date, _str(row['scheduled_time']));
        if (scheduledAt == null) continue;
        // Le chirurgien du programme est proposé pour le bloc, même s'il
        // n'est pas professeur. Il ne détermine PAS le responsable admission.
        final blockResponsibleId = surgeon.isEmpty
          ? null : appStore.responsibleIdForName(surgeon);
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
          surgeryType: classifySurgery(procedure).label,
          blockTiming: 'Différé',
          admissionTiming: ProgramAdmission.source,
          beforeUnit: '',
          beforeBox: '',
          afterUnit: '',
          afterBox: '',
          expectedDays: 0,
          blockAt: scheduledAt,
          admittedAt: null,
          professorId: null,
          blockResponsibleId: blockResponsibleId,
          assignmentMode: 'Programme officiel du bloc',
          assignmentExplanation: 'Provenance Consultation. Responsable admission à attribuer selon la vacation réelle.',
          stage: CaseStage.scheduled,
          fromBlocProgram: true,
          programRoom: _str(row['room']),
          programSurgeon: surgeon,
          programSourceService: _str(row['source_service']),
          programScheduledTime: _str(row['scheduled_time']),
        );
        ProgramAdmission.apply(patient, DateTime.now());
        final saved = clinical[rowId];
        if (saved != null && saved['clinical_data'] is Map) {
          BlocClinicalRecordService.apply(
            patient,
            Map<String, dynamic>.from(saved['clinical_data'] as Map),
            saved['version'] is int ? saved['version'] as int : 0,
          );
        }
        ProgramAdmission.apply(patient, DateTime.now());
        result.add(patient);
      }
      if (response.length < pageSize) break;
      offset += pageSize;
    }
    // Les programmes remplacés ne sont plus « courants », mais leurs
    // dossiers VALIDÉS « Sorti » doivent rester retrouvables dans Archives.
    // Sans ce second chargement, un nouveau PDF du bloc effacerait
    // l'affichage des anciennes sorties (sans effacer la base Supabase).
    final loadedIds = result.map((p) => p.id).toSet();
    final archived = <int, Map<String, dynamic>>{};
    const archivePageSize = 400;
    for (var page = 0;; page += archivePageSize) {
      final rows = await api.from('bloc_patient_records')
          .select('entry_id,version,clinical_data')
          .eq('hospital_id','huim6').eq('clinical_data->>stage', CaseStage.discharged.name)
          .order('entry_id').range(page, page + archivePageSize - 1);
      for (final row in rows) {
        final entryId = row['entry_id'];
        if (entryId is int && !linkedIds.contains(entryId) &&
            !loadedIds.contains('BLOC-$entryId') &&
            row['clinical_data'] is Map) {
          archived[entryId] = Map<String, dynamic>.from(row);
        }
      }
      if (rows.length < archivePageSize) break;
    }
    final archiveIds = archived.keys.toList();
    const chunkSize = 250;
    for (var start = 0; start < archiveIds.length; start += chunkSize) {
      final ids = archiveIds.skip(start).take(chunkSize).toList();
      final entries = await api.from('bloc_program_entries').select(
        'id,room,scheduled_time,source_service,patient_name,procedure_name,'
        'surgeon,bloc_program_imports!inner(program_date)',
      ).eq('hospital_id','huim6').inFilter('id', ids);
      for (final raw in entries) {
        final row = Map<String, dynamic>.from(raw);
        final entryId = row['id'];
        final program = row['bloc_program_imports'];
        if (entryId is! int || program is! Map) continue;
        final caseData = archived[entryId];
        final date = _str(program['program_date']);
        final scheduledAt = _scheduledAt(date, _str(row['scheduled_time']));
        final name = _str(row['patient_name']);
        final procedure = _str(row['procedure_name']);
        if (caseData == null || scheduledAt == null ||
            name.isEmpty || procedure.isEmpty) continue;
        final surgeon = _str(row['surgeon']);
        final patient = PatientCase(
          id: 'BLOC-$entryId',
          name: name,
          age: '—',
          origin: 'Consultation',
          insurance: 'À préciser',
          motive: '', history: '', exam: '', investigations: '',
          labs: '', immediatePlan: '',
          procedure: procedure,
          surgeryType: classifySurgery(procedure).label,
          blockTiming: 'Différé',
          admissionTiming: ProgramAdmission.source,
          beforeUnit: '', beforeBox: '',
          afterUnit: '', afterBox: '',
          expectedDays: 0,
          blockAt: scheduledAt,
          admittedAt: null,
          blockResponsibleId: surgeon.isEmpty
              ? null : appStore.responsibleIdForName(surgeon),
          stage: CaseStage.scheduled,
          fromBlocProgram: true,
          programRoom: _str(row['room']),
          programSurgeon: surgeon,
          programSourceService: _str(row['source_service']),
          programScheduledTime: _str(row['scheduled_time']),
        );
        BlocClinicalRecordService.apply(patient,
          Map<String, dynamic>.from(caseData['clinical_data'] as Map),
          caseData['version'] is int ? caseData['version'] as int : 0);
        if (patient.isArchived) {
          result.add(patient);
          loadedIds.add(patient.id);
        }
      }
    }
    // Un même patient peut figurer dans plusieurs interventions : préserver
    // chaque ligne source au lieu de fusionner des homonymes par hypothèse.
    return result..sort((a, b) => b.blockAt.compareTo(a.blockAt));
  }
}
