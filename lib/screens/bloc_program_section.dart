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
    final rows = await api.from('bloc_program_entries')
      .select('sequence_no,room,scheduled_time,source_service,patient_name,'
        'procedure_name,surgeon,assistant,nurse,anaesthetist,iar,source_status')
      .eq('import_id', importId)
      .order('sequence_no');
    return _BlocSnapshot(
      rows.map((r) => Map<String, dynamic>.from(r)).toList(), true);
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

  Widget _caseRow(Map<String, dynamic> entry, int index) {
    final time = value(entry, 'scheduled_time');
    final service = value(entry, 'source_service');
    final surgeon = value(entry, 'surgeon');
    final assistant = value(entry, 'assistant');
    final iar = value(entry, 'iar');
    final anaesthetist = value(entry, 'anaesthetist');

    return Container(
      margin: const EdgeInsets.fromLTRB(11, 7, 11, 2),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EDE9))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: VColors.softMint,
              borderRadius: BorderRadius.circular(8)),
            child: Text(time.isEmpty ? 'Horaire à préciser' : time,
              style: const TextStyle(color: VColors.ink,
                fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('Intervention ' + (index + 1).toString(),
            style: const TextStyle(fontSize: 12, color: VColors.muted))),
        ]),
        const SizedBox(height: 9),
        Text(value(entry, 'patient_name'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
            color: VColors.ink)),
        const SizedBox(height: 5),
        Text(value(entry, 'procedure_name'),
          style: const TextStyle(fontSize: 13, height: 1.4)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.medical_services_outlined,
            size: 16, color: VColors.muted),
          const SizedBox(width: 7),
          Expanded(child: Text(surgeon,
            style: const TextStyle(fontSize: 12, color: VColors.muted))),
        ]),
        if (service.isNotEmpty && service != '*')
          Padding(padding: const EdgeInsets.only(top: 5),
            child: Text('Service : ' + service,
              style: const TextStyle(fontSize: 12, color: VColors.muted))),
        if ((assistant.isNotEmpty && assistant != '*') ||
            (iar.isNotEmpty && iar != '*') ||
            (anaesthetist.isNotEmpty && anaesthetist != '*'))
          Theme(data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              dense: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('Voir l’équipe opératoire',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              children: [
                if (assistant.isNotEmpty && assistant != '*')
                  Align(alignment: Alignment.centerLeft,
                    child: Text('Aide : ' + assistant)),
                if (anaesthetist.isNotEmpty && anaesthetist != '*')
                  Align(alignment: Alignment.centerLeft,
                    child: Text('Anesthésie : ' + anaesthetist)),
                if (iar.isNotEmpty && iar != '*')
                  Align(alignment: Alignment.centerLeft,
                    child: Text('IAR : ' + iar)),
              ],
            )),
      ]),
    );
  }

  Widget roomTable(String room, List<Map<String, dynamic>> cases) {
    return Card(
      key: ValueKey(dateKey(day) + '-' + room),
      margin: const EdgeInsets.only(top: 11),
      color: const Color(0xFFF4F8F6),
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
          for (var i = 0; i < cases.length; i++)
            _caseRow(cases[i], i),
          const SizedBox(height: 10),
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
        const Expanded(child: Text('Programme du bloc · Viscérale',
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
          final rows = data.entries;
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

            ]),
            const Text('Tableau prévisionnel retranscrit. chaque intervention est organisée par salle. Vérifier toute '
              'modification auprès de la coordination du bloc.',
              style: TextStyle(fontSize: 11, color: VColors.muted)),

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
