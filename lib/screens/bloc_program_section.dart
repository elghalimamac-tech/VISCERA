import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

/// Programme officiel prévisionnel, distinct des dossiers patients locaux.
class BlocProgramSection extends StatefulWidget {
  const BlocProgramSection({super.key});
  @override State<BlocProgramSection> createState() => _BlocProgramSectionState();
}

class _BlocProgramSectionState extends State<BlocProgramSection> {
  late Future<_BlocSnapshot?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BlocSnapshot?> _load() async {
    final api = Supabase.instance.client;
    final documents = await api.from('bloc_program_imports')
      .select('id,program_date,imported_at')
      .eq('is_current', true)
      .order('program_date', ascending: false)
      .limit(1);
    if (documents.isEmpty) return null;
    final doc = Map<String, dynamic>.from(documents.first);
    final entries = await api.from('bloc_program_entries')
      .select('room,scheduled_time,hospital_arrival,theatre_arrival,source_service,'
        'patient_name,procedure_name,surgeon,assistant,nurse,anaesthetist,iar,source_status')
      .eq('import_id', doc['id'])
      .order('sequence_no');
    return _BlocSnapshot(
      date: doc['program_date'] as String? ?? '',
      importedAt: doc['imported_at'] as String? ?? '',
      entries: entries.map((e) => Map<String,dynamic>.from(e)).toList(),
    );
  }

  void _refresh() => setState(() => _future = _load());

  static String _date(String iso) {
    final parts = iso.split('-');
    return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : iso;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_BlocSnapshot?>(
    future: _future,
    builder: (context, snapshot) {
      final error = snapshot.hasError;
      final program = snapshot.data;
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE5E8)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.event_note_outlined, color: VColors.ink),
            const SizedBox(width: 8),
            const Expanded(child: Text('Programme HUIM6 · Chirurgie viscérale',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
            IconButton(tooltip: 'Actualiser le programme reçu par e-mail',
              onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 6),
          if (snapshot.connectionState != ConnectionState.done)
            const Padding(padding: EdgeInsets.all(10), child: LinearProgressIndicator())
          else if (error)
            const Text('Programme indisponible. Vérifiez votre connexion ou vos droits.',
              style: TextStyle(fontSize: 12, color: VColors.muted))
          else if (program == null)
            const Text('Aucun programme synchronisé pour le moment.',
              style: TextStyle(fontSize: 12, color: VColors.muted))
          else ...[
            Text('Programme prévisionnel du ${_date(program.date)} · '
              '${program.entries.length} intervention(s) de viscérale',
              style: const TextStyle(fontSize: 12, color: VColors.muted)),
            const SizedBox(height: 4),
            const Text('Source : planning du bloc. Vérifier les changements auprès de la coordination.',
              style: TextStyle(fontSize: 11, color: VColors.muted)),
            if (program.entries.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 12),
                child: Text('Aucune intervention viscérale identifiée dans ce fichier.')),
            ...program.entries.map((entry) {
              String value(String key) => (entry[key] ?? '').toString().trim();
              return Container(
                margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8F6), borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('Salle ${value('room')}  •  ${value('scheduled_time')}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                    const Icon(Icons.medical_services_outlined, size: 18, color: VColors.ink),
                  ]),
                  const SizedBox(height: 6),
                  Text(value('patient_name'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(value('procedure_name'), style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 5),
                  Text('Chirurgien : ${value('surgeon')}',
                    style: const TextStyle(color: VColors.muted, fontSize: 12)),
                  if (value('assistant').isNotEmpty)
                    Text('Aide opératoire : ${value('assistant')}',
                      style: const TextStyle(color: VColors.muted, fontSize: 12)),
                  if (value('source_service').isNotEmpty)
                    Text('Service : ${value('source_service')}',
                      style: const TextStyle(color: VColors.muted, fontSize: 12)),
                ]),
              );
            }),
          ],
        ]),
      );
    },
  );
}

class _BlocSnapshot {
  const _BlocSnapshot({required this.date, required this.importedAt, required this.entries});
  final String date;
  final String importedAt;
  final List<Map<String, dynamic>> entries;
}
