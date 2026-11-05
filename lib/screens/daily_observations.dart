import '../branding.dart';
import '../biological_followup.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../voice_dictation.dart';
import 'lab_results_page.dart';

String _obsDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Le jour de l'entrée constitue l'observation initiale du dossier.
/// Les notes ultérieures sont conservées dans la chronologie quotidienne.
DailyObservation? admissionObservationFor(PatientCase patient) {
  final admitted = patient.hospitalizationStartDate ?? patient.admittedAt;
  if (admitted == null) return null;
  for (final note in patient.dailyObservations) {
    if (_sameDay(note.date, admitted)) return note;
  }
  return null;
}

List<DailyObservation> currentObservationsFor(PatientCase patient) {
  final admission = admissionObservationFor(patient);
  return patient.dailyObservations
      .where((note) => !identical(note, admission)).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}

/// La même carte est utilisée dans le dossier patient et dans le suivi.
/// Magica/Sillage est un seul logiciel et une seule attestation de report.
class DailyObservationCard extends StatelessWidget {
  const DailyObservationCard({super.key, required this.patient,
    required this.observation, this.isAdmission = false});
  final PatientCase patient;
  final DailyObservation observation;
  final bool isAdmission;

  /// Un contenu clinique occupe une véritable zone de lecture : une colonne
  /// sur mobile, deux colonnes régulières sur les grands écrans Web.
  Widget _clinicalPanel(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: VColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: VColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
          style: const TextStyle(color: VColors.muted,
            fontSize: 10, letterSpacing: .7, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(value, softWrap: true,
          style: const TextStyle(fontSize: 13.5,
            height: 1.4, color: VColors.ink)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final obs = observation;
    final editable = (patient.isActive || patient.isProgrammed) &&
        !patient.isOmitted;
    final day = patient.hospitalizationDayOn(obs.date);
    final sections = <Widget>[
      if (obs.vitals.trim().isNotEmpty)
        _clinicalPanel('Constantes et paramètres', obs.vitals.trim()),
      if (obs.symptoms.trim().isNotEmpty)
        _clinicalPanel('Évolution et symptômes', obs.symptoms.trim()),
      if (obs.clinicalExam.trim().isNotEmpty)
        _clinicalPanel('Examen clinique', obs.clinicalExam.trim()),
      if (obs.results.trim().isNotEmpty)
        _clinicalPanel('Examens complémentaires / imagerie', obs.results.trim()),
      if (obs.plan.trim().isNotEmpty)
        _clinicalPanel('Conduite à tenir', obs.plan.trim()),
    ];
    return VCard(
      key: ValueKey('clinical-note-' + _obsDate(obs.date)),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 37, height: 37,
            decoration: BoxDecoration(
              color: VColors.softMint,
              borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.event_note_outlined,
              color: VColors.ink, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_obsDate(obs.date),
                style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w800, color: VColors.ink)),
              const SizedBox(height: 3),
              Text(isAdmission ? 'Observation du jour d’entrée' :
                  'Observation clinique quotidienne',
                style: const TextStyle(fontSize: 11, color: VColors.muted)),
            ],
          )),
          if (day != null) VTag('J$day', highlight:true),
          if (editable) IconButton(
            key: ValueKey('edit-clinical-note-' + _obsDate(obs.date)),
            tooltip: 'Modifier cette observation',
            onPressed: () => showClinicalObservationEditor(
              context, patient, existing: obs),
            icon: const Icon(Icons.edit_outlined,
              size: 19, color: VColors.ink)),
        ]),
        if (sections.isNotEmpty) ...[
          const SizedBox(height: 13),
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            final panelWidth = width >= 720 ? (width - 12) / 2 : width;
            return Wrap(
              spacing: 12, runSpacing: 10,
              children: [
                for (final section in sections)
                  SizedBox(width: panelWidth, child: section),
              ],
            );
          }),
        ],
        if (obs.biology.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: VColors.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.biotech_outlined, size: 17, color: VColors.ink),
                  SizedBox(width: 7),
                  Text('Biologie du jour', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: VColors.ink)),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  for (final field in biologyFields)
                    if (obs.biology.containsKey(field.key))
                      Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: VColors.softMint,
                        side: const BorderSide(color: VColors.line),
                        label: Text(field.label + ' : ' +
                          obs.biology[field.key]!.toString() + ' ' + field.unit,
                          style: const TextStyle(fontSize: 11.5,
                            color: VColors.ink))),
                ]),
              ],
            ),
          ),
        ],
        const Divider(height: 22, color: VColors.line),
        CheckboxListTile(
          key: ValueKey('report-magica-sillage-' + _obsDate(obs.date)),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          title: const Text('Reporté sur Magica / Sillage',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          subtitle: Text(obs.fullyReported
            ? 'Report manuel confirmé' : 'Report manuel à confirmer',
            style: const TextStyle(fontSize: 11, color: VColors.muted)),
          value: obs.fullyReported,
          onChanged: editable
            ? (v) => appStore.setObservationReported(
                patient, obs, reported: v ?? false)
            : null,
        ),
      ]),
    );
  }
}

class DailyObservationsPage extends StatefulWidget {
  const DailyObservationsPage({super.key, required this.patient});
  final PatientCase patient;
  @override State<DailyObservationsPage> createState() => _DailyObservationsPageState();
}

class _DailyObservationsPageState extends State<DailyObservationsPage> {
  PatientCase get p => widget.patient;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const VisceraPageTitle('Observations quotidiennes'), backgroundColor: VColors.background),
    body: AnimatedBuilder(animation: appStore, builder: (context, _) => ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
      children: [
        VCard(color: VColors.ink, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 7),
          Text(p.isProgrammed ? 'Consultation · Patient programmé' : '${p.currentUnit} · Box ${p.currentBox}', style: const TextStyle(color: Colors.white70)),
        ])),
        const SizedBox(height: 14),
        VCard(color: VColors.softMint, child: const Text(
          'Une observation datée par jour, modifiable. Le jour d’entrée est classé à l’admission, puis le suivi quotidien apparaît séparément. La case Magica/Sillage atteste un report manuel, sans synchronisation.',
          style: TextStyle(fontSize: 12.5))),
        const SizedBox(height: 15),
        CrpTrendCard(patient:p),
        const SizedBox(height: 13),
        if (p.isActive || p.isProgrammed) ...[
          FilledButton.tonalIcon(
            key:const Key('open-daily-labs-form'),
            onPressed:()=>Navigator.push(context,MaterialPageRoute(
              builder:(_)=>LabResultsPage(patient:p))),
            icon:const Icon(Icons.biotech_outlined),
            label:const Text('Saisir les bilans biologiques du jour'),
          ),
          const SizedBox(height:9),
        ],
        if (p.isActive || p.isProgrammed) ElevatedButton.icon(
          onPressed: () => showClinicalObservationEditor(context, p),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Observation du jour / autre date'),
        ),
        SectionHeading('Observation clinique à l’admission'),
        if (admissionObservationFor(p) != null)
          Padding(padding: const EdgeInsets.only(bottom: 11),
            child: DailyObservationCard(
              patient: p,
              observation: admissionObservationFor(p)!,
              isAdmission: true)),
        if (admissionObservationFor(p) == null)
          const VCard(child: Text(
            'L’observation initiale figure dans le dossier d’admission. '
            'Aucune note supplémentaire datée du jour d’entrée.')),
        SectionHeading('Observations cliniques actuelles et quotidiennes'),
        if (currentObservationsFor(p).isEmpty)
          const VCard(child: Text('Aucune observation quotidienne après l’admission.')),
        for (final obs in currentObservationsFor(p))
          Padding(padding: const EdgeInsets.only(bottom: 11),
            child: DailyObservationCard(patient: p, observation: obs)),
      ],
    )),
  );

}

/// Saisie clinique commune : les résultats biologiques sont saisis une fois
/// dans LabResultsPage, et réutilisés sans être effacés par cette observation.
Future<void> showClinicalObservationEditor(
    BuildContext context, PatientCase p, {DailyObservation? existing}) async {
  if (!p.isActive && !p.isProgrammed) return;

  DailyObservation? findOnDate(DateTime date) {
    for (final note in p.dailyObservations) {
      if (_sameDay(note.date, date)) return note;
    }
    return null;
  }

  DateTime selected = existing?.date ?? DateTime.now();
  DailyObservation? editing = existing ?? findOnDate(selected);
  final vitals = TextEditingController(text: editing?.vitals ?? '');
  final symptoms = TextEditingController(text: editing?.symptoms ?? '');
  final exam = TextEditingController(text: editing?.clinicalExam ?? '');
  final results = TextEditingController(text: editing?.results ?? '');
  final plan = TextEditingController(text: editing?.plan ?? '');
  final fields = [vitals, symptoms, exam, results, plan];

  void loadClinical(DailyObservation? note) {
    vitals.text = note?.vitals ?? '';
    symptoms.text = note?.symptoms ?? '';
    exam.text = note?.clinicalExam ?? '';
    results.text = note?.results ?? '';
    plan.text = note?.plan ?? '';
  }

  try {
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, redraw) => Padding(
          padding: EdgeInsets.fromLTRB(
            18, 5, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 12),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * .78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Observation clinique du jour',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_outlined),
                  label: Text('Date : ${_obsDate(selected)}'),
                  onPressed: existing == null ? () async {
                    final admission = p.admittedAt;
                    final start = admission == null ? DateTime(2020)
                      : DateTime(admission.year, admission.month, admission.day);
                    final today = DateTime.now();
                    final first = start.isAfter(today) ? today : start;
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: selected,
                      firstDate: first,
                      lastDate: today,
                    );
                    if (picked != null && sheetContext.mounted) {
                      redraw(() {
                        selected = picked;
                        editing = findOnDate(picked);
                        loadClinical(editing);
                      });
                    }
                  } : null,
                ),
                const SizedBox(height: 8),
                Expanded(child: ListView(children: [
                  Card(
                    elevation: 0,
                    color: VColors.softMint,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Bilans biologiques liés aux scores',
                            style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                          const SizedBox(height: 5),
                          Text(
                            'CRP, GB, Hb, créatinine, albumine et autres '
                            'paramètres : un seul formulaire daté, sans doublon. '
                            'Les résultats seront conservés lorsque vous '
                            'enregistrerez cette observation.',
                            style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            key: const Key('observation-open-lab-results'),
                            onPressed: () async {
                              await Navigator.of(sheetContext).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => LabResultsPage(
                                    patient: p, initialDate: selected),
                                ),
                              );
                              if (sheetContext.mounted) redraw(() {});
                            },
                            icon: const Icon(Icons.biotech_outlined),
                            label: const Text('Renseigner les bilans / scores'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  VoiceClinicalField(
                    label: 'Constantes : TA, FC, T°, SpO₂, diurèse…',
                    controller: vitals, maxLines: 3),
                  const SizedBox(height: 12),
                  VoiceClinicalField(
                    label: 'Évolution / plaintes / symptômes',
                    controller: symptoms, maxLines: 4),
                  const SizedBox(height: 12),
                  VoiceClinicalField(
                    label: 'Examen clinique du jour',
                    controller: exam, maxLines: 4),
                  const SizedBox(height: 12),
                  VoiceClinicalField(
                    label: 'Imagerie / examens complémentaires',
                    controller: results, maxLines: 4),
                  const SizedBox(height: 12),
                  VoiceClinicalField(
                    label: 'Conduite à tenir / prescriptions à valider',
                    controller: plan, maxLines: 4),
                  const SizedBox(height: 12),
                  const Text(
                    'Relire les valeurs, négations, doses et unités dictées. '
                    'Les bilans biologiques sont saisis dans leur formulaire dédié.',
                    style: TextStyle(color: VColors.muted, fontSize: 12)),
                ])),
                const SizedBox(height: 9),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Enregistrer l’observation'),
                  onPressed: () {
                    // Une saisie biologique effectuée dans l'écran dédié peut
                    // avoir été enregistrée après l'ouverture de ce formulaire.
                    final previous = findOnDate(selected);
                    final biology = Map<String, double>.from(
                      previous?.biology ?? const <String, double>{});
                    if (biology.isEmpty &&
                        fields.every((field) => field.text.trim().isEmpty)) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text(
                          'Renseignez au moins un élément clinique '
                          'ou un bilan biologique.')));
                      return;
                    }
                    final inputs = fields.map((field) => field.text.trim()).toList();
                    final changed = previous == null ||
                      [previous.vitals, previous.symptoms,
                        previous.clinicalExam, previous.results, previous.plan]
                      .asMap().entries.any((entry) =>
                        entry.value != inputs[entry.key]);

                    appStore.saveDailyObservation(p, DailyObservation(
                      date: previous?.date ?? selected,
                      vitals: inputs[0],
                      symptoms: inputs[1],
                      clinicalExam: inputs[2],
                      results: inputs[3],
                      plan: inputs[4],
                      biology: biology,
                      reportedMagica: changed
                        ? false : (previous?.reportedMagica ?? false),
                      reportedSillage: changed
                        ? false : (previous?.reportedSillage ?? false),
                      reportedMagicaAt: changed
                        ? null : previous?.reportedMagicaAt,
                      reportedSillageAt: changed
                        ? null : previous?.reportedSillageAt,
                    ));
                    Navigator.pop(sheetContext);
                  },
                )),
              ],
            ),
          ),
        ),
      ),
    );
  } finally {
    for (final controller in fields) {
      controller.dispose();
    }
  }
}
