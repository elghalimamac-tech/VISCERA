import 'package:flutter/material.dart';
import 'clinical_score_engine.dart';
import 'clinical_score_specs.dart';
import 'models.dart';
import 'store.dart';

/// Rubrique repliée par défaut, sans doublon avec CFS et ASA.
class ClinicalScoresCard extends StatelessWidget {
  const ClinicalScoresCard({super.key, required this.patient, this.readOnly = false});
  final PatientCase patient;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white, elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.grey.shade300)),
    child: ExpansionTile(
      key: const Key('clinical-scores-tile'),
      initiallyExpanded: false,
      title: const Text('Scores cliniques complémentaires',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      subtitle: const Text('Nutrition · thrombose · respiration · cœur · surveillance',
        style: TextStyle(fontSize: 12)),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        const Text('Évaluations médicales facultatives. Les données absentes ne sont '
          'pas considérées normales. Aucun score ne déclenche seul une décision '
          'chirurgicale ou thérapeutique.', style: TextStyle(fontSize: 12)),
        for (final spec in clinicalScoreSpecs)
          ClinicalScoreForm(key: ValueKey('form-' + spec.id),
            patient: patient, spec: spec, readOnly: readOnly),
      ],
    ),
  );
}

class ClinicalScoreForm extends StatefulWidget {
  const ClinicalScoreForm({super.key, required this.patient,
    required this.spec, this.readOnly = false});
  final PatientCase patient;
  final ClinicalScoreSpec spec;
  final bool readOnly;
  @override State<ClinicalScoreForm> createState() => _ClinicalScoreFormState();
}

class _ClinicalScoreFormState extends State<ClinicalScoreForm> {
  Map<String, String> answers = {};
  bool saving = false;

  @override void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final record = widget.patient.clinicalScores[widget.spec.id];
    final raw = record is Map ? record['inputs'] : null;
    answers = raw is Map
      ? raw.map<String, String>((key, value) =>
          MapEntry(key.toString(), value.toString()))
      : {};
  }

  @override void didUpdateWidget(covariant ClinicalScoreForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.patient, widget.patient)) _load();
  }

  Future<void> _save(ScoreResult result) async {
    if (widget.readOnly || saving) return;
    final p = widget.patient;
    if (!p.fromBlocProgram && !p.fromManualAdmission) {
      _message('Créer le dossier patient partagé avant de sauvegarder ce score.');
      return;
    }
    final backup = Map<String, dynamic>.from(p.clinicalScores);
    setState(() => saving = true);
    p.clinicalScores[widget.spec.id] = {
      'value': result.value,
      'interpretation': result.interpretation,
      'inputs': Map<String, String>.from(answers),
      'assessedAt': DateTime.now().toUtc().toIso8601String(),
      'assessedBy': appStore.activeLocalProfile?.id ?? '',
      'schemaVersion': 1,
    };
    try {
      await appStore.saveClinical(p);
      appStore.refresh();
      if (mounted) _message('Évaluation enregistrée dans le dossier partagé.');
    } catch (_) {
      p.clinicalScores = backup;
      appStore.refresh();
      if (mounted) _message('Échec de sauvegarde : évaluation non confirmée.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)));
  }

  Widget _choice(ClinicalQuestion question) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<String>(
      key: ValueKey(widget.spec.id + '-' + question.id),
      value: question.choices.any((c) => c.value == answers[question.id])
        ? answers[question.id] : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: question.title,
        labelStyle: const TextStyle(fontSize: 12),
        border: const OutlineInputBorder()),
      items: question.choices.map((c) => DropdownMenuItem<String>(
        value: c.value,
        child: Text(c.label, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: widget.readOnly || saving ? null
        : (v) => setState(() {
            if (v != null) answers[question.id] = v;
          }),
    ),
  );

  Widget _number(String id, String label, {bool decimal = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      key: ValueKey(widget.spec.id + '-' + id),
      initialValue: answers[id] ?? '',
      readOnly: widget.readOnly || saving,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label,
        border: const OutlineInputBorder()),
      onChanged: (v) => setState(() => answers[id] = v.trim()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final age = ClinicalScoring.age(widget.patient);
    final result = ClinicalScoring.compute(widget.spec.id, answers, age: age);
    final stored = widget.patient.clinicalScores[widget.spec.id];
    final saved = stored is Map ? stored : null;
    final ageRequired = ['nrs2002', 'ariscat'].contains(widget.spec.id);
    return ExpansionTile(
      key: ValueKey('score-' + widget.spec.id),
      initiallyExpanded: false,
      title: Text(widget.spec.title, style:
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text(saved == null
          ? widget.spec.period + ' · À compléter'
          : widget.spec.period + ' · ' + (saved['value'] ?? '—').toString() +
              ' · Enregistré', style: const TextStyle(fontSize: 11)),
      childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      children: [
        if (ageRequired)
          Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Text(age == null
                ? 'Âge manquant : compléter la date de naissance ou l’âge'
                : 'Âge du dossier pris en compte : ' + age.toString() + ' ans',
              style: const TextStyle(fontSize: 12))),
        if (widget.spec.id == 'caprini') ...[
          const Text('Renseigner le total après calcul sur la grille Caprini '
            '2013 complète. Aucune déduction automatique des facteurs absents. '
            'Interprétation et prévention selon le protocole local.',
            style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          _number('total', 'Total de la grille complète'),
        ],
        if (widget.spec.id == 'news2') ...[
          const Text('L’échelle SpO₂ 2 n’est utilisable que si la cible '
            '88–92 % a été prescrite par un clinicien compétent. '
            'NEWS2 ne remplace pas la surveillance clinique.',
            style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          _number('rr','Fréquence respiratoire (par min)'),
          _number('spo2','SpO₂ (%)'),
          _number('sbp','Pression systolique (mmHg)'),
          _number('pulse','Pouls (par min)'),
          _number('temp','Température (°C)',decimal:true),
        ],
        for (final question in widget.spec.questions) _choice(question),
        if (result != null)
          Align(alignment: Alignment.centerLeft,
            child: Text('Résultat : ' + result.value + ' · ' +
              result.interpretation,
              style: const TextStyle(fontWeight: FontWeight.w700,
                fontSize: 12)))
        else const Align(alignment: Alignment.centerLeft,
          child: Text('Évaluation incomplète : aucun résultat calculé.',
            style: TextStyle(fontSize: 12))),
        if (result?.parameterAtThree == true)
          const Align(alignment: Alignment.centerLeft,
            child: Text('NEWS2 : au moins un paramètre coté 3.',
              style: TextStyle(fontSize: 12, color: Colors.deepOrange))),
        const SizedBox(height: 10),
        if (!widget.readOnly)
          SizedBox(width: double.infinity, child: FilledButton.icon(
            key: ValueKey('save-score-' + widget.spec.id),
            onPressed: result == null || saving ? null : () => _save(result),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(saving ? 'Enregistrement…' : 'Enregistrer ce score'),
          )),
        if (saved != null)
          Align(alignment: Alignment.centerLeft,
            child: Text('Dernière évaluation : ' +
              (saved['assessedAt'] ?? '').toString(),
              style: const TextStyle(fontSize: 11, color: Colors.black54))),
      ],
    );
  }
}
