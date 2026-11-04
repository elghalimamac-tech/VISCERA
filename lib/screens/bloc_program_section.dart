import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

/// Tableau opératoire natif : ne lit jamais le fichier source côté mobile.
/// Les actes du programme ne valent pas confirmation d'admission ou d'opération.
class BlocProgramSection extends StatefulWidget {
  const BlocProgramSection({super.key});
  @override
  State<BlocProgramSection> createState() => _BlocProgramSectionState();
}

class _BlocProgramSectionState extends State<BlocProgramSection> {
  late DateTime day;
  late Future<_BlocSnapshot?> pending;
  Timer? timer;
  bool visceralOnly = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    day = DateTime(now.year, now.month, now.day);
    pending = load(day);
    timer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) refresh();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  static String dateKey(DateTime d) =>
      d.year.toString().padLeft(4, '0') + '-' +
      d.month.toString().padLeft(2, '0') + '-' +
      d.day.toString().padLeft(2, '0');

  static String dateLabel(DateTime d) =>
      d.day.toString().padLeft(2, '0') + '/' +
      d.month.toString().padLeft(2, '0') + '/' + d.year.toString();

  static String value(Map<String, dynamic> row, String field) =>
      (row[field] ?? '').toString().trim();

  Future<_BlocSnapshot?> load(DateTime date) async {
    final api = Supabase.instance.client;
    final imports = await api.from('bloc_program_imports')
      .select('id,source_received_at')
      .eq('program_date', dateKey(date))
      .eq('is_current', true)
      .order('source_received_at', ascending: false)
      .limit(1);
    if (imports.isEmpty) return null;
    final importId = imports.first['id'];
    final all = await api.from('bloc_program_all_entries')
      .select('sequence_no,room,scheduled_time,source_service,patient_name,'
        'procedure_name,surgeon,assistant,nurse,anaesthetist,iar,'
        'source_status,is_visceral')
      .eq('import_id', importId)
      .order('sequence_no');
    if (all.isNotEmpty) {
      return _BlocSnapshot(
        all.map((r) => Map<String, dynamic>.from(r)).toList(), true);
    }
    // Versions antérieures : seules les opérations viscérales étaient stockées.
    final old = await api.from('bloc_program_entries')
      .select('sequence_no,room,scheduled_time,source_service,patient_name,'
        'procedure_name,surgeon,assistant,nurse,anaesthetist,iar,source_status')
      .eq('import_id', importId)
      .order('sequence_no');
    return _BlocSnapshot(old.map((r) => <String, dynamic>{
      ...Map<String, dynamic>.from(r), 'is_visceral': true,
    }).toList(), false);
  }

  void refresh() => setState(() => pending = load(day));
  void selectDay(DateTime next) => setState(() {
    day = DateTime(next.year, next.month, next.day);
    pending = load(day);
  });

  Future<void> chooseDay() async {
    final picked = await showDatePicker(
      context: context, initialDate: day,
      firstDate: DateTime(2025), lastDate: DateTime(2100),
      helpText: 'Date du programme opératoire',
    );
    if (picked != null && mounted) selectDay(picked);
  }

  Widget cell(String text, {double width = 140, bool bold = false}) =>
      SizedBox(width: width, child: Text(text.isEmpty ? '—' : text,
        softWrap: true, style: TextStyle(fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: bold ? VColors.ink : VColors.muted)));

  Widget roomTable(String room, List<Map<String, dynamic>> cases) {
    return Card(
      margin: const EdgeInsets.only(top: 11),
      key: ValueKey(dateKey(day) + '-' + room),
      color: const Color(0xFFF7FAF9),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFDDE9E5))),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.meeting_room_outlined, color: VColors.ink),
        title: Text('Salle ' + room,
          style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(cases.length.toString() + ' intervention(s)'),
        children: [
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: DataTable(
              headingRowHeight: 45,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 125,
              horizontalMargin: 12,
              columnSpacing: 16,
              columns: const [
                DataColumn(label: Text('Ordre / heure')),
                DataColumn(label: Text('Patient')),
                DataColumn(label: Text('Intervention')),
                DataColumn(label: Text('Chirurgien')),
                DataColumn(label: Text('Service')),
                DataColumn(label: Text('Équipe / statut')),
              ],
              rows: [
                for (var i = 0; i < cases.length; i++)
                  DataRow(cells: [
                    DataCell(cell((i + 1).toString() + ' · ' +
                      value(cases[i], 'scheduled_time'), width: 115, bold: true)),
                    DataCell(cell(value(cases[i], 'patient_name'),
                      width: 160, bold: true)),
                    DataCell(cell(value(cases[i], 'procedure_name'), width: 220)),
                    DataCell(cell(value(cases[i], 'surgeon'), width: 160)),
                    DataCell(cell(value(cases[i], 'source_service'), width: 105)),
                    DataCell(cell([
                      if (value(cases[i], 'assistant').isNotEmpty)
                        'Aide : ' + value(cases[i], 'assistant'),
                      if (value(cases[i], 'anaesthetist').isNotEmpty)
                        'Anesth. : ' + value(cases[i], 'anaesthetist'),
                      if (value(cases[i], 'iar').isNotEmpty)
                        'IAR : ' + value(cases[i], 'iar'),
                      if (value(cases[i], 'source_status').isNotEmpty)
                        value(cases[i], 'source_status'),
                    ].join('\n'), width: 200)),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDCE5E8))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.table_chart_outlined, color: VColors.ink),
        const SizedBox(width: 8),
        const Expanded(child: Text('Programme opératoire officiel · HUIM6',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
        IconButton(onPressed: refresh, tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh_rounded)),
      ]),
      Row(children: [
        IconButton(
          onPressed: () => selectDay(day.subtract(const Duration(days: 1))),
          tooltip: 'Jour précédent', icon: const Icon(Icons.chevron_left)),
        Expanded(child: OutlinedButton.icon(
          onPressed: chooseDay,
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: Text(dateLabel(day)))),
        IconButton(
          onPressed: () => selectDay(day.add(const Duration(days: 1))),
          tooltip: 'Jour suivant', icon: const Icon(Icons.chevron_right)),
        TextButton(onPressed: () => selectDay(DateTime.now()),
          child: const Text("Aujourd'hui")),
      ]),
      FutureBuilder<_BlocSnapshot?>(
        future: pending,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Padding(padding: EdgeInsets.only(top: 12),
              child: Text('Programme indisponible. Vérifiez la connexion '
                'et les droits du médecin.',
                style: TextStyle(fontSize: 12, color: VColors.muted)));
          }
          final data = snapshot.data;
          if (data == null) {
            return const Padding(padding: EdgeInsets.only(top: 12),
              child: Text('Aucun programme synchronisé pour cette date. '
                'Un programme antérieur ne lui est pas substitué.',
                style: TextStyle(fontSize: 12, color: VColors.muted)));
          }
          final rows = data.entries.where((r) =>
            !visceralOnly || r['is_visceral'] == true).toList();
          final rooms = <String, List<Map<String, dynamic>>>{};
          for (final row in rows) {
            final room = value(row, 'room').isEmpty
              ? 'Non attribuée' : value(row, 'room');
            rooms.putIfAbsent(room, () => <Map<String, dynamic>>[]).add(row);
          }
          final names = rooms.keys.toList()..sort((a, b) {
            final ai = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '');
            final bi = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '');
            if (ai != null && bi != null && ai != bi) return ai.compareTo(bi);
            return a.compareTo(b);
          });
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 7),
            Wrap(spacing: 8, runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(rows.length.toString() + ' intervention(s) · ' +
                names.length.toString() + ' salle(s)',
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: VColors.ink)),
              FilterChip(label: const Text('Viscérale uniquement'),
                selected: visceralOnly,
                onSelected: (v) => setState(() => visceralOnly = v)),
            ]),
            const Text('Tableau prévisionnel retranscrit. Défiler '
              'horizontalement pour voir les colonnes ; vérifier toute '
              'modification auprès de la coordination du bloc.',
              style: TextStyle(fontSize: 11, color: VColors.muted)),
            if (!data.complete)
              const Padding(padding: EdgeInsets.only(top: 6),
                child: Text('Ancien import : seules les interventions '
                  'de chirurgie viscérale sont disponibles.',
                  style: TextStyle(fontSize: 11, color: VColors.muted))),
            if (names.isEmpty) const Text('Aucune intervention dans ce filtre.'),
            for (final name in names) roomTable(name, rooms[name]!),
          ]);
        },
      ),
    ]),
  );
}

class _BlocSnapshot {
  const _BlocSnapshot(this.entries, this.complete);
  final List<Map<String, dynamic>> entries;
  final bool complete;
}
