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
    (1, '1 · Très en forme — robuste, actif, exercice régulier'),
    (2, '2 · En forme — autonome, sans symptômes actifs, exercice occasionnel'),
    (3, '3 · Autonome — maladies contrôlées, activité habituelle conservée'),
    (4, '4 · Vulnérable — ralenti ou fatigué, sans dépendance quotidienne'),
    (5, '5 · Fragilité légère — aide pour certaines activités instrumentales'),
    (6, '6 · Fragilité modérée — aide pour les activités extérieures et le ménage'),
    (7, '7 · Fragilité sévère — dépendance pour les soins personnels'),
    (8, '8 · Fragilité très sévère — dépendance totale, proche de la fin de vie'),
    (9, '9 · Phase terminale — espérance de vie < 6 mois, sans autre fragilité nécessaire'),
  ];
  static const _asaLevels = <(String, String)>[
    ('', 'Non renseignée — attendre une évaluation médicale'),
    ('I', 'ASA I — patient en bonne santé'),
    ('II', 'ASA II — maladie systémique légère, sans limitation importante'),
    ('III', 'ASA III — maladie systémique sévère avec retentissement fonctionnel'),
    ('IV', 'ASA IV — maladie systémique sévère menaçant constamment la vie'),
    ('V', 'ASA V — patient moribond qui ne survivrait pas sans intervention'),
    ('VI', 'ASA VI — mort encéphalique déclarée, prélèvement d’organes'),
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


  /// Liste lisible en entier, utilisable aussi sur écran mobile étroit.
  Future<T?> _chooseDescription<T>(
      String title, List<(T, String)> options, T? current) =>
    showModalBottomSheet<T>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false, initialChildSize: .67,
          minChildSize: .35, maxChildSize: .91,
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              for (final option in options)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                    title: Text(option.$2, softWrap: true),
                    selected: current == option.$1,
                    trailing: current == option.$1
                        ? const Icon(Icons.check_circle_outline) : null,
                    onTap: () => Navigator.pop(sheetContext, option.$1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

  Widget _selector(String label, String selected, VoidCallback onTap) =>
    InkWell(
      onTap: widget.readOnly || _saving ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.expand_more)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(selected, softWrap: true,
            style: const TextStyle(fontSize: 13)),
        ),
      ),
    );

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
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('1. Fragilité clinique',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
          const SizedBox(height: 10),
          _selector(
            'Quel était le niveau d’autonomie habituel ?',
            _score == null ? 'Choisir le niveau CFS (1–9)'
              : _levels.firstWhere((level) => level.$1 == _score).$2,
            () async {
              final choice = await _chooseDescription<int>(
                'Clinical Frailty Scale (CFS)', _levels, _score);
              if (choice != null && mounted) setState(() => _score = choice);
            },
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
          const Divider(height: 28),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('2. Classe ASA',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
          const SizedBox(height: 5),
          const Text(
            'Quelle classe d’état physique a été retenue ? '
            'Reprendre la classification documentée par l’équipe '
            'd’anesthésie, sans la déduire automatiquement du CFS.',
            style: TextStyle(fontSize: 12, color: VColors.muted)),
          const SizedBox(height: 10),
          _selector(
            'Classe ASA',
            _asaLevels.firstWhere((v) => v.$1 == _asa,
              orElse: () => _asaLevels.first).$2,
            () async {
              final selected = await _chooseDescription<String>(
                'Classification ASA', _asaLevels, _asa);
              if (selected != null && mounted) {
                setState(() => _asa = selected);
              }
            },
          ),
          ExpansionTile(
            key: const Key('cfs-associated-details'),
            initiallyExpanded: attention,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            title: const Text('3. Compléments et suivi',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: const Text('Comorbidités · nutrition · gériatrie',
              style: TextStyle(fontSize: 12, color: VColors.muted)),
            children: [
              TextField(
                key: const Key('cfs-comorbidities'),
                controller: _comorbidities,
                readOnly: widget.readOnly || _saving,
                maxLength: 1500,
                minLines: 1, maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comorbidités (synthèse)',
                  hintText: 'Ex. HTA, diabète, insuffisance cardiaque',
                  border: OutlineInputBorder()),
              ),
              _assessmentChoice(
                title: 'Évaluation nutritionnelle',
                value: _nutrition,
                onChanged: (v) => setState(
                  () => _nutrition = v ?? 'a_evaluer'),
              ),
              _assessmentChoice(
                title: 'Évaluation gériatrique',
                value: _geriatrics,
                onChanged: (v) => setState(
                  () => _geriatrics = v ?? 'a_evaluer'),
              ),
            ],
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
