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

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: const TextStyle(
        color: VColors.muted, fontSize: 10, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 12.5)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final obs = observation;
    final editable = (patient.isActive || patient.isProgrammed) &&
        !patient.isOmitted;
    return VCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(
            (isAdmission ? 'Admission · ' : '') + _obsDate(obs.date) +
            (patient.hospitalizationDayOn(obs.date) == null ? '' :
                ' · J' + patient.hospitalizationDayOn(obs.date).toString()),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          )),
          if (editable) TextButton.icon(
            onPressed: () => showClinicalObservationEditor(context, patient,
              existing: obs),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Modifier'),
          ),
        ]),
        if (obs.vitals.trim().isNotEmpty) _line('Constantes', obs.vitals),
        if (obs.symptoms.trim().isNotEmpty) _line('Symptômes / évolution', obs.symptoms),
        if (obs.clinicalExam.trim().isNotEmpty) _line('Examen clinique', obs.clinicalExam),
        if (obs.biology.isNotEmpty) ...[
          const Text('BILANS BIOLOGIQUES', style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 11, color: VColors.ink)),
          const SizedBox(height: 6),
          Wrap(spacing: 7, runSpacing: 6, children: [
            for (final field in biologyFields)
              if (obs.biology.containsKey(field.key))
                Chip(label: Text(field.label + ' : ' +
                  obs.biology[field.key]!.toString() + ' ' + field.unit,
                  style: const TextStyle(fontSize: 11))),
          ]),
          const SizedBox(height: 8),
        ],
        if (obs.results.trim().isNotEmpty) _line('Bilans / imagerie', obs.results),
        if (obs.plan.trim().isNotEmpty) _line('Conduite à tenir', obs.plan),
        const Divider(height: 21),
        CheckboxListTile(
          key: ValueKey('report-magica-sillage-' + _obsDate(obs.date)),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Reporté sur Magica / Sillage'),
          subtitle: const Text('Une seule validation de report manuel'),
          value: obs.fullyReported,
          onChanged: editable
            ? (v) => appStore.setObservationReported(
                patient, obs, reported: v ?? false)
            : null,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        Text(obs.fullyReported
          ? '✓ Report manuel confirmé'
          : 'Report manuel à confirmer',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
            color: obs.fullyReported ? VColors.ink : const Color(0xFFA45633))),
      ],
    ));
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

/// Formulaire commun accessible directement depuis le dossier patient
/// et depuis le suivi des observations, avec les mêmes validations.
Future<void> showClinicalObservationEditor(
  BuildContext context, PatientCase p, {DailyObservation? existing}) async {
    if (!p.isActive && !p.isProgrammed) return;
    DateTime selected = existing?.date ?? DateTime.now();
    final initial = existing;
    final vitals = TextEditingController(text: existing?.vitals ?? '');
    final symptoms = TextEditingController(text: existing?.symptoms ?? '');
    final exam = TextEditingController(text: existing?.clinicalExam ?? '');
    final results = TextEditingController(text: existing?.results ?? '');
    final plan = TextEditingController(text: existing?.plan ?? '');
    final values = [vitals, symptoms, exam, results, plan];
    final labs = <String,TextEditingController>{
      for(final field in biologyFields) field.key:TextEditingController(
        text:existing?.biology[field.key]?.toString() ?? ''),
    };
    final labControllers=labs.values.toList();
    try {
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true, showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, redraw) =>
          Padding(padding: EdgeInsets.fromLTRB(18, 5, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 12),
            child: SizedBox(height: MediaQuery.of(sheetContext).size.height * .78,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Observation clinique du jour', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_outlined),
                  label: Text('Date : ${_obsDate(selected)}'),
                  onPressed: initial == null ? () async {
                    final admission = p.admittedAt;
                    final start = admission == null ? DateTime(2020)
                      : DateTime(admission.year, admission.month, admission.day);
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
                  const Text('Bilans biologiques utiles aux scores · champs individuels',
                    style:TextStyle(fontWeight:FontWeight.w800,fontSize:13)),
                  const SizedBox(height:6),
                  const Text('CRP pour mDULK ; Hb pour ARISCAT ; créatinine pour RCRI ; '
                    'albumine, lymphocytes, bilirubine et poids pour les indices '
                    'biologiques. Tous les champs sont facultatifs ; une valeur '
                    'absente reste vide et ne vaut jamais zéro.',
                    style:TextStyle(fontSize:11,color:VColors.muted)),
                  const SizedBox(height:9),
                  for(final field in biologyFields) ...[
                    if(field.key=='albumin') ...[
                      const SizedBox(height:7),
                      const Text('Autres bilans utilisés par les scores et indices',
                        style:TextStyle(fontWeight:FontWeight.w800,fontSize:12)),
                      const SizedBox(height:10),
                    ],
                    Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(
                      key:ValueKey('daily-biology-'+field.key),
                      controller:labs[field.key],
                      keyboardType:const TextInputType.numberWithOptions(decimal:true),
                      decoration:InputDecoration(labelText:field.label+' ('+field.unit+')',
                        hintText:'Résultat non renseigné',
                        border:const OutlineInputBorder(),isDense:true))),
                  ],
                  const Divider(height:22),
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
                    final biology=<String,double>{};
                    try {
                      for(final field in biologyFields){
                        final entered=parseBiology(labs[field.key]!.text,field);
                        if(entered!=null)biology[field.key]=entered;
                      }
                    } on FormatException catch(error){
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content:Text(error.message)));
                      return;
                    }
                    if (biology.isEmpty && values.every((c) => c.text.trim().isEmpty)) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Renseignez au moins un élément clinique.')));
                      return;
                    }
                    final duplicate = p.dailyObservations.any((o) => !_sameDay(o.date, initial?.date ?? DateTime(1900)) && _sameDay(o.date, selected));
                    if (duplicate) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Une observation existe déjà à cette date. Ouvrez-la pour la modifier.')));
                      return;
                    }
                    final changed = initial != null &&
                      ([initial.vitals, initial.symptoms, initial.clinicalExam, initial.results, initial.plan]
                        .asMap().entries.any((entry) => entry.value != values[entry.key].text.trim()) ||
                        initial.biology.length!=biology.length ||
                        biology.entries.any((e)=>initial.biology[e.key]!=e.value));
                    appStore.saveDailyObservation(p, DailyObservation(
                      date: selected, vitals: vitals.text.trim(), symptoms: symptoms.text.trim(),
                      clinicalExam: exam.text.trim(), results: results.text.trim(), plan: plan.text.trim(),
                      biology:biology,
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
      for (final controller in [...values,...labControllers]) { controller.dispose(); }
    }
  }
