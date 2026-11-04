import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// Évaluation CFS saisie par un médecin et persistée dans le dossier partagé.
/// Ni le CFS ni la classe ASA ne valident ou n'interdisent l'entrée au bloc.
class CfsAssessmentCard extends StatefulWidget {
  const CfsAssessmentCard({
    super.key, required this.patient, this.readOnly = false,
  });

  final PatientCase patient;
  final bool readOnly;

  @override
  State<CfsAssessmentCard> createState() => _CfsAssessmentCardState();
}

class _CfsAssessmentCardState extends State<CfsAssessmentCard> {
  static const _levels = <(int, String)>[
    (1, '1 · Très en forme'),
    (2, '2 · En forme'),
    (3, '3 · Autonome, maladies contrôlées'),
    (4, '4 · Vulnérable'),
    (5, '5 · Fragilité légère'),
    (6, '6 · Fragilité modérée'),
    (7, '7 · Fragilité sévère'),
    (8, '8 · Fragilité très sévère'),
    (9, '9 · Phase terminale'),
  ];
  static const _statuses = <(String, String)>[
    ('a_evaluer', 'À évaluer'),
    ('faite', 'Réalisée'),
    ('non_indiquee', 'Non indiquée (décision médicale)'),
  ];

  int? _score;
  DateTime? _baseline;
  String _asa = '';
  String _nutrition = 'a_evaluer';
  String _geriatrics = 'a_evaluer';
  late final TextEditingController _comorbidities;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load(widget.patient);
    _comorbidities =
        TextEditingController(text: widget.patient.comorbiditySummary);
  }

  void _load(PatientCase p) {
    _score = p.cfsScore;
    _baseline = p.cfsBaselineDate;
    _asa = p.asaClass;
    _nutrition = p.nutritionAssessmentStatus;
    _geriatrics = p.geriatricAssessmentStatus;
  }

  @override
  void didUpdateWidget(covariant CfsAssessmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.patient, widget.patient)) {
      _load(widget.patient);
      _comorbidities.text = widget.patient.comorbiditySummary;
    }
  }

  @override
  void dispose() {
    _comorbidities.dispose();
    super.dispose();
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2,'0')}/'
      '${date.month.toString().padLeft(2,'0')}/${date.year}';

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _chooseBaseline() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _baseline ?? now.subtract(const Duration(days: 14)),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Autonomie habituelle avant la maladie aiguë',
    );
    if (result != null && mounted) setState(() => _baseline = result);
  }

  Future<void> _save() async {
    if (_saving || widget.readOnly) return;
    if (_score != null && _baseline == null) {
      _notice('Renseignez la date de référence de l’autonomie habituelle.');
      return;
    }
    final p = widget.patient;
    if (!p.fromBlocProgram && !p.fromManualAdmission) {
      _notice('Enregistrez d’abord le dossier patient partagé.');
      return;
    }
    final oldScore = p.cfsScore;
    final oldBaseline = p.cfsBaselineDate;
    final oldAssessedAt = p.cfsAssessedAt;
    final oldAsa = p.asaClass;
    final oldComorbidities = p.comorbiditySummary;
    final oldNutrition = p.nutritionAssessmentStatus;
    final oldGeriatrics = p.geriatricAssessmentStatus;

    setState(() => _saving = true);
    p.cfsScore = _score;
    p.cfsBaselineDate = _score == null ? null : _baseline;
    p.cfsAssessedAt = _score == null ? null : DateTime.now();
    p.asaClass = _asa;
    p.comorbiditySummary = _comorbidities.text.trim();
    p.nutritionAssessmentStatus = _nutrition;
    p.geriatricAssessmentStatus = _geriatrics;
    try {
      await appStore.saveClinical(p);
      appStore.refresh();
      if (mounted) _notice('Évaluation préopératoire enregistrée.');
    } catch (_) {
      p.cfsScore = oldScore;
      p.cfsBaselineDate = oldBaseline;
      p.cfsAssessedAt = oldAssessedAt;
      p.asaClass = oldAsa;
      p.comorbiditySummary = oldComorbidities;
      p.nutritionAssessmentStatus = oldNutrition;
      p.geriatricAssessmentStatus = oldGeriatrics;
      appStore.refresh();
      if (mounted) _notice('Enregistrement échoué. Réessayez après synchronisation.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _assessmentChoice({
    required String title,
    required String value,
    required ValueChanged<String?> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: title,
        border: const OutlineInputBorder()),
      items: _statuses.map((v) => DropdownMenuItem<String>(
        value: v.$1, child: Text(v.$2, overflow: TextOverflow.ellipsis),
      )).toList(),
      onChanged: widget.readOnly || _saving ? null : onChanged,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final attention = _score != null && _score! >= 5;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: VColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
        key: const Key('cfs-collapse-tile'),
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: const Text('Fragilité clinique (CFS)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
            color: VColors.ink)),
        subtitle: Text(
          p.cfsScore == null ? 'Non évalué · évaluation préopératoire'
            : 'CFS ${p.cfsScore}/9 · ${p.requiresFrailtyAttention ? 'Attention : fragilité ou phase terminale' : 'Score renseigné'}',
          style: const TextStyle(fontSize: 12, color: VColors.muted)),
        children: [
          const Text(
            'Évaluer l’autonomie habituelle AVANT l’épisode aigu, généralement '
            'environ deux semaines auparavant. Score clinique surtout utilisé '
            'chez les patients de 65 ans et plus. Il ne décide jamais à lui seul '
            'd’une intervention ou d’une admission en réanimation.',
            style: TextStyle(fontSize: 12, color: VColors.muted)),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            key: const Key('cfs-score-field'),
            value: _score,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Clinical Frailty Scale · 1 à 9',
              hintText: 'Sélectionner le niveau clinique',
              border: OutlineInputBorder()),
            items: _levels.map((v) => DropdownMenuItem<int>(
              value: v.$1, child: Text(v.$2, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: widget.readOnly || _saving ? null
              : (value) => setState(() => _score = value),
          ),
          if (_score != null && !widget.readOnly)
            Align(alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _saving ? null : () => setState(() => _score = null),
                child: const Text('Effacer le score'))),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('cfs-baseline-date'),
            onPressed: widget.readOnly || _saving ? null : _chooseBaseline,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(_baseline == null
              ? 'Date de référence de l’autonomie'
              : 'Autonomie habituelle le ${_date(_baseline!)}'),
          ),
          if (attention) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: VColors.orangeSoft,
                borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'CFS ≥ 5 : envisager une évaluation nutritionnelle et '
                'gériatrique adaptée, et planifier la prise en charge '
                'postopératoire. Le CFS 9 désigne la phase terminale.',
                style: TextStyle(fontSize: 12, color: VColors.ink)),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _asa,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Classe ASA (si connue)',
              border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: '', child: Text('Non renseignée')),
              for (final asa in const ['I','II','III','IV','V','VI'])
                DropdownMenuItem(value: asa, child: Text('ASA $asa')),
            ],
            onChanged: widget.readOnly || _saving ? null
              : (value) => setState(() => _asa = value ?? ''),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('cfs-comorbidities'),
            controller: _comorbidities,
            readOnly: widget.readOnly || _saving,
            maxLength: 1500,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comorbidités (synthèse)',
              hintText: 'Ex. HTA, diabète, insuffisance cardiaque',
              border: OutlineInputBorder()),
          ),
          _assessmentChoice(
            title: 'Évaluation nutritionnelle',
            value: _nutrition,
            onChanged: (v) => setState(() => _nutrition = v ?? 'a_evaluer'),
          ),
          _assessmentChoice(
            title: 'Évaluation gériatrique',
            value: _geriatrics,
            onChanged: (v) => setState(() => _geriatrics = v ?? 'a_evaluer'),
          ),
          const SizedBox(height: 10),
          if (!widget.readOnly)
            SizedBox(width: double.infinity, child: FilledButton.icon(
              key: const Key('save-cfs-assessment'),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Enregistrement…'
                : 'Enregistrer l’évaluation'),
            )),
          if (widget.readOnly)
            const Text('Évaluation conservée en lecture seule.',
              style: TextStyle(fontSize: 12, color: VColors.muted)),
        ],
      ),
      ),
    );
  }
}
