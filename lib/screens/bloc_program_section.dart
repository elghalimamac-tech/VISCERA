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
  final Set<String> _expandedRows = <String>{};

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
      rows.map((r) => Map<String, dynamic>.from(r)).toList(),
      DateTime.tryParse(value(Map<String, dynamic>.from(imports.first), 'source_received_at')));
  }

  void refresh() => setState(() => pending = load(day));
  void selectDay(DateTime next) => setState(() {
    day = DateTime(next.year, next.month, next.day);
    pending = load(day);
    _expandedRows.clear();
  });

  Future<void> chooseDay() async {
    final picked = await showDatePicker(
      context: context, initialDate: day,
      firstDate: DateTime(2025), lastDate: DateTime(2100),
      helpText: 'Date du programme opératoire',
    );
    if (picked != null && mounted) selectDay(picked);
  }


  String _time(String input) {
    final cleaned = input.trim().toUpperCase();
    final matched = RegExp(r'^(\d{1,2})\s*[H:]\s*(\d{2})$')
        .firstMatch(cleaned);
    if (matched != null) {
      return matched.group(1)!.padLeft(2, '0') + ':' + matched.group(2)!;
    }
    return cleaned.isEmpty || cleaned == '*' ? '—' : cleaned;
  }

  Widget _detail(String label, String content) {
    if (content.trim().isEmpty || content.trim() == '*') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label + ' : ' + content,
        style: const TextStyle(fontSize: 12, color: VColors.muted)),
    );
  }

  Widget _caseRow(Map<String, dynamic> entry, String room, int index, bool last) {
    final surgeon = value(entry, 'surgeon');
    final service = value(entry, 'source_service');
    final details = <String, String>{
      'Aide opératoire': value(entry, 'assistant'),
      'Panseuse': value(entry, 'nurse'),
      'Anesthésiste': value(entry, 'anaesthetist'),
      'IAR': value(entry, 'iar'),
      'Arrivée hôpital': _time(value(entry, 'hospital_arrival')),
      'Arrivée bloc': _time(value(entry, 'theatre_arrival')),
      'Statut prévisionnel': value(entry, 'source_status'),
    };
    details.removeWhere((name, content) => content.isEmpty ||
      content == '*' || (name.startsWith('Arrivée') && content == '—'));
    final rowKey = dateKey(day) + '|' + room + '|' + index.toString();
    final expanded = _expandedRows.contains(rowKey);
    final canExpand = details.isNotEmpty;
    return Column(children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: !canExpand ? null : () => setState(() {
            if (expanded) {
              _expandedRows.remove(rowKey);
            } else {
              _expandedRows.add(rowKey);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 59,
                child: Column(children: [
                  Text(_time(value(entry, 'scheduled_time')),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w800, color: VColors.ink)),
                  const SizedBox(height: 5),
                  Text((index + 1).toString().padLeft(2, '0'),
                    style: const TextStyle(fontSize: 11, color: VColors.muted)),
                ]),
              ),
              const SizedBox(width: 9),
              Container(
                width: 3, height: 50,
                decoration: BoxDecoration(
                  color: VColors.mint,
                  borderRadius: BorderRadius.circular(6))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value(entry, 'patient_name'),
                      style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w800, color: VColors.ink)),
                    const SizedBox(height: 5),
                    Text(value(entry, 'procedure_name'),
                      style: const TextStyle(fontSize: 13,
                        height: 1.35, color: VColors.ink)),
                    const SizedBox(height: 7),
                    Text(
                      surgeon + (service.isNotEmpty && service != '*'
                        ? ' · ' + service : ''),
                      style: const TextStyle(fontSize: 12,
                        color: VColors.muted)),
                  ]),
              ),
              if (canExpand)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                    size: 21, color: VColors.muted),
                ),
            ]),
          ),
        ),
      ),
      if (expanded)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(94, 0, 10, 10),
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 6),
          decoration: BoxDecoration(
            color: VColors.background,
            borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Équipe et informations',
              style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w800, color: VColors.ink)),
            const SizedBox(height: 8),
            for (final item in details.entries) _detail(item.key, item.value),
          ]),
        ),
      if (!last)
        const Divider(height: 1, color: VColors.line, indent: 90),
    ]);
  }

  Widget roomTable(String room, List<Map<String, dynamic>> cases) {
    return Container(
      margin: const EdgeInsets.only(top: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: VColors.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          color: VColors.softMint,
          child: Row(children: [
            const Icon(Icons.meeting_room_outlined,
              color: VColors.ink, size: 19),
            const SizedBox(width: 9),
            Expanded(child: Text('Salle ' + room,
              style: const TextStyle(fontWeight: FontWeight.w800,
                color: VColors.ink, fontSize: 14))),
            Text(cases.length.toString() + ' intervention(s)',
              style: const TextStyle(fontWeight: FontWeight.w700,
                fontSize: 11, color: VColors.ink)),
          ]),
        ),
        for (var i = 0; i < cases.length; i++)
          _caseRow(cases[i], room, i, i == cases.length - 1),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Container(width: 39, height: 39,
          decoration: BoxDecoration(
            color: VColors.softMint,
            borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.event_note_rounded,
            color: VColors.ink, size: 21)),
        const SizedBox(width: 11),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Programme opératoire',
              style: TextStyle(fontSize: 17,
                fontWeight: FontWeight.w800, color: VColors.ink)),
            SizedBox(height: 2),
            Text('Chirurgie viscérale · HUIM6',
              style: TextStyle(fontSize: 12, color: VColors.muted)),
          ])),
        IconButton(onPressed: refresh, tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh_rounded, color: VColors.ink)),
      ]),
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: VColors.line)),
        child: Row(children: [
          IconButton(
            onPressed: () => selectDay(day.subtract(const Duration(days: 1))),
            tooltip: 'Jour précédent',
            icon: const Icon(Icons.chevron_left_rounded, color: VColors.ink)),
          Expanded(child: TextButton.icon(onPressed: chooseDay,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(dateLabel(day),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800)))),
          IconButton(
            onPressed: () => selectDay(day.add(const Duration(days: 1))),
            tooltip: 'Jour suivant',
            icon: const Icon(Icons.chevron_right_rounded, color: VColors.ink)),
        ]),
      ),
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
            const SizedBox(height: 13),
            Wrap(spacing: 8, runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(rows.length.toString() + ' intervention(s)',
                style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w800, color: VColors.ink)),
              Container(padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: VColors.softMint,
                  borderRadius: BorderRadius.circular(15)),
                child: Text(names.length.toString() + ' salle(s)',
                  style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: VColors.ink))),

            ]),
            if (data.receivedAt != null)
              Padding(padding: const EdgeInsets.only(top: 5),
                child: Text('Programme reçu le ' +
                  dateLabel(data.receivedAt!.toLocal()),
                  style: const TextStyle(fontSize: 11,
                    color: VColors.muted))),

            if (names.isEmpty) const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Aucune intervention viscérale programmée.',
                style: TextStyle(fontSize: 12, color: VColors.muted))),
            for (final name in names) roomTable(name, rooms[name]!),
            const SizedBox(height: 12),
            const Text('Programme prévisionnel : modifications à vérifier '
              'auprès de la coordination du bloc.',
              style: TextStyle(fontSize: 11, color: VColors.muted)),
          ]);
        },
      ),
    ]),
  );
}

class _BlocSnapshot {
  const _BlocSnapshot(this.entries, this.receivedAt);
  final List<Map<String, dynamic>> entries;
  final DateTime? receivedAt;
}
