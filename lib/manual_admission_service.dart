import 'package:supabase_flutter/supabase_flutter.dart';
import 'bloc_clinical_record.dart';
import 'models.dart';

/// Séjours créés manuellement par les médecins approuvés.
/// Le serveur est la source de vérité. Aucune identité patient n'est mise en cache.
class ManualAdmissionService {
  static String _str(dynamic x) => (x ?? '').toString();
  static String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';

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
      birthDate:DateTime.tryParse(_str(row['birth_date'])),
      surgeryType:_str(row['surgery_type']),
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
        'p_birth_date': draft.birthDate == null ? null : _isoDate(draft.birthDate!),
        'p_surgery_type': draft.surgeryType,
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
      birthDate:draft.birthDate, surgeryType:draft.surgeryType,
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
        .select('id,name,origin,procedure_name,block_at,block_date,block_timing,birth_date,surgery_type,clinical_data,version')
        .order('created_at', ascending: false)
        .range(offset, offset + pageSize - 1);
      for (final row in rows) {
        patients.add(fromServer(Map<String, dynamic>.from(row)));
      }
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    final byId = <String,PatientCase>{
      for (final p in patients) p.id.substring('MANUAL-'.length):p,
    };
    final links = <Map<String,dynamic>>[];
    for(var page=0;;page+=500){
      final fetched = await Supabase.instance.client.from('manual_bloc_links')
        .select('manual_id,entry_id').order('entry_id').range(page,page+499);
      links.addAll(fetched.map((row)=>Map<String,dynamic>.from(row)));
      if(fetched.length<500)break;
    }
    final entryIds = links.map((row)=>row['entry_id']).whereType<int>().toList();
    final entries = <int,Map<String,dynamic>>{};
    if(entryIds.isNotEmpty){
      const chunkSize=250;
      for(var start=0;start<entryIds.length;start+=chunkSize){
        final subset=entryIds.skip(start).take(chunkSize).toList();
        final fetched=await Supabase.instance.client.from('bloc_program_entries')
          .select('id,room,scheduled_time,surgeon,procedure_name')
          .inFilter('id',subset);
        for(final row in fetched){
          if(row['id'] is int) entries[row['id'] as int]=Map<String,dynamic>.from(row);
        }
      }
    }
    for(final link in links){
      final manual=byId[_str(link['manual_id'])];
      final entry=entries[link['entry_id']];
      if(manual==null || entry==null)continue;
      manual.linkedProgramEntryId=link['entry_id'] as int;
      manual.programRoom=_str(entry['room']);
      manual.programScheduledTime=_str(entry['scheduled_time']);
      manual.programSurgeon=_str(entry['surgeon']);
    }
    return patients;
  }

  /// Association volontaire après vérification par le soignant :
  /// le programme ne contient pas de date de naissance et ne permet
  /// donc aucune fusion automatique sur le seul nom.
  Future<void> linkToProgram(PatientCase manual,PatientCase programmed) async{
    if(!manual.fromManualAdmission || !programmed.fromBlocProgram ||
      manual.birthDate==null) throw StateError('Identité non vérifiée.');
    final id=int.tryParse(programmed.id.replaceFirst('BLOC-',''));
    if(id==null)throw StateError('Programme invalide.');
    final response=await Supabase.instance.client.rpc('viscera_link_manual_bloc_program',
      params:{
        'p_manual_id':manual.id.substring('MANUAL-'.length),
        'p_entry_id':id,
        'p_confirmed_birth_date':_isoDate(manual.birthDate!),
      });
    if(response!=true)throw StateError('Rapprochement non confirmé.');
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
