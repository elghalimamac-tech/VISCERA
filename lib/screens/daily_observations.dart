import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../voice_dictation.dart';

String _obsDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class DailyObservationsPage extends StatefulWidget {
  const DailyObservationsPage({super.key, required this.patient});
  final PatientCase patient;
  @override State<DailyObservationsPage> createState() => _DailyObservationsPageState();
}

class _DailyObservationsPageState extends State<DailyObservationsPage> {
  PatientCase get p => widget.patient;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Observations quotidiennes'), backgroundColor: VColors.background),
    body: AnimatedBuilder(animation: appStore, builder: (context, _) => ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
      children: [
        VCard(color: VColors.ink, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 7),
          Text('${p.currentUnit} · Box ${p.currentBox}', style: const TextStyle(color: Colors.white70)),
        ])),
        const SizedBox(height: 14),
        VCard(color: VColors.softMint, child: const Text(
          'Une observation par jour. Dictée vocale disponible dans chaque champ clinique. Relisez le texte avant enregistrement. Les cases Magica/Sillage attestent uniquement d’une ressaisie MANUELLE dans ces logiciels.',
          style: TextStyle(fontSize: 12.5))),
        const SizedBox(height: 15),
        if (p.isActive) ElevatedButton.icon(
          onPressed: () => _editObservation(context),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Observation du jour / autre date'),
        ),
        SectionHeading('Suivi de l’hospitalisation'),
        if (p.dailyObservations.isEmpty)
          const VCard(child: Text('Aucune observation quotidienne renseignée.')),
        ...p.dailyObservations.map((obs) => Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: VCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(_obsDate(obs.date), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              if (p.isActive) TextButton.icon(onPressed: () => _editObservation(context, existing: obs),
                icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Modifier')),
            ]),
            if (obs.vitals.trim().isNotEmpty) _line('Constantes', obs.vitals),
            if (obs.symptoms.trim().isNotEmpty) _line('Symptômes / évolution', obs.symptoms),
            if (obs.clinicalExam.trim().isNotEmpty) _line('Examen', obs.clinicalExam),
            if (obs.results.trim().isNotEmpty) _line('Bilans / imagerie', obs.results),
            if (obs.plan.trim().isNotEmpty) _line('CAT', obs.plan),
            const Divider(height: 21),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Reporté manuellement sur Magica'),
              value: obs.reportedMagica,
              onChanged: p.isActive ? (v) => appStore.setObservationReported(p, obs, magica: v ?? false) : null,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Reporté manuellement sur Sillage'),
              value: obs.reportedSillage,
              onChanged: p.isActive ? (v) => appStore.setObservationReported(p, obs, sillage: v ?? false) : null,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            Text(obs.fullyReported ? '✓ Deux reports confirmés' : 'Report(s) à confirmer',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                color: obs.fullyReported ? VColors.ink : const Color(0xFFA45633))),
          ])),
        )),
      ],
    )),
  );

  Widget _line(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: const TextStyle(color: VColors.muted, fontSize: 10, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 12.5)),
    ]));

  Future<void> _editObservation(BuildContext context, {DailyObservation? existing}) async {
    DateTime selected = existing?.date ?? DateTime.now();
    final initial = existing;
    final vitals = TextEditingController(text: existing?.vitals ?? '');
    final symptoms = TextEditingController(text: existing?.symptoms ?? '');
    final exam = TextEditingController(text: existing?.clinicalExam ?? '');
    final results = TextEditingController(text: existing?.results ?? '');
    final plan = TextEditingController(text: existing?.plan ?? '');
    final values = [vitals, symptoms, exam, results, plan];
    try {
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true, showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, redraw) =>
          Padding(padding: EdgeInsets.fromLTRB(18, 5, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 12),
            child: SizedBox(height: MediaQuery.of(sheetContext).size.height * .78,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Observation clinique', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_outlined),
                  label: Text('Date : ${_obsDate(selected)}'),
                  onPressed: initial == null ? () async {
                    final start = DateTime(p.admittedAt.year, p.admittedAt.month, p.admittedAt.day);
                    final today = DateTime.now();
                    final first = start.isAfter(today) ? today : start;
                    final picked = await showDatePicker(context: sheetContext,
                      initialDate: selected, firstDate: first,
                      lastDate: today);
                    if (picked != null) redraw(() => selected = picked);
                  } : null,
                ),
                const SizedBox(height: 8),
                Expanded(child: ListView(children: [
                  VoiceClinicalField(label: 'Constantes : TA, FC, T°, SpO₂, diurèse…', controller: vitals, maxLines: 3),
                  const SizedBox(height: 12),
                  VoiceClinicalField(label: 'Évolution / plaintes / symptômes', controller: symptoms, maxLines: 4),
                  const SizedBox(height: 12),
                  VoiceClinicalField(label: 'Examen clinique du jour', controller: exam, maxLines: 4),
                  const SizedBox(height: 12),
                  VoiceClinicalField(label: 'Bilans, imagerie, résultats', controller: results, maxLines: 4),
                  const SizedBox(height: 12),
                  VoiceClinicalField(label: 'Conduite à tenir / prescriptions à valider', controller: plan, maxLines: 4),
                  const SizedBox(height: 12),
                  const Text('Le texte dicté est un brouillon. Vérifier notamment les valeurs, négations, doses et unités.',
                    style: TextStyle(color: VColors.muted, fontSize: 12)),
                ])),
                const SizedBox(height: 9),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  icon: const Icon(Icons.check), label: const Text('Enregistrer l’observation'),
                  onPressed: () {
                    if (values.every((c) => c.text.trim().isEmpty)) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Renseignez au moins un élément clinique.')));
                      return;
                    }
                    final duplicate = p.dailyObservations.any((o) => !_sameDay(o.date, initial?.date ?? DateTime(1900)) && _sameDay(o.date, selected));
                    if (duplicate) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Une observation existe déjà à cette date. Ouvrez-la pour la modifier.')));
                      return;
                    }
                    final changed = initial != null &&
                      [initial.vitals, initial.symptoms, initial.clinicalExam, initial.results, initial.plan]
                        .asMap().entries.any((entry) => entry.value != values[entry.key].text.trim());
                    appStore.saveDailyObservation(p, DailyObservation(
                      date: selected, vitals: vitals.text.trim(), symptoms: symptoms.text.trim(),
                      clinicalExam: exam.text.trim(), results: results.text.trim(), plan: plan.text.trim(),
                      reportedMagica: changed ? false : (initial?.reportedMagica ?? false),
                      reportedSillage: changed ? false : (initial?.reportedSillage ?? false),
                      reportedMagicaAt: changed ? null : initial?.reportedMagicaAt,
                      reportedSillageAt: changed ? null : initial?.reportedSillageAt,
                    ));
                    Navigator.pop(sheetContext);
                  },
                )),
              ]),
            ),
          ),
        ),
      );
    } finally {
      for (final controller in values) { controller.dispose(); }
    }
  }
}
