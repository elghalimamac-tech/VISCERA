import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Services sollicités pour un avis pendant le séjour.
/// « Autre service » permet d'indiquer n'importe quelle spécialité.
const specialistOpinionServices = <String>[
  'Anesthésie-réanimation',
  'Cardiologie',
  'Dermatologie',
  'Endocrinologie',
  'Gastro-entérologie',
  'Hématologie',
  'Infectiologie',
  'Médecine interne',
  'Néphrologie',
  'Neurologie',
  'Pneumologie',
  'Psychiatrie',
  'Radiologie',
  'Réanimation',
  'Urologie',
  'Chirurgie vasculaire',
  'Autre service',
];

class _OpinionInput {
  const _OpinionInput(this.service, this.done);
  final String service;
  final bool done;
}

/// Rubrique du parcours d'hospitalisation. Plusieurs avis sont conservés
/// indépendamment, même lorsqu'ils concernent une seule spécialité.
class SpecialistOpinionsCard extends StatefulWidget {
  const SpecialistOpinionsCard({
    super.key,
    required this.patient,
    this.readOnly = false,
  });

  final PatientCase patient;
  final bool readOnly;

  @override
  State<SpecialistOpinionsCard> createState() => _SpecialistOpinionsCardState();
}

class _SpecialistOpinionsCardState extends State<SpecialistOpinionsCard> {
  bool _saving = false;

  bool get _canEdit => !widget.readOnly && !_saving &&
      (widget.patient.isActive || widget.patient.isProgrammed);

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _commit(
    void Function() apply,
    void Function() rollback,
  ) async {
    if (!_canEdit) return;
    setState(() {
      _saving = true;
      apply();
    });
    try {
      await appStore.saveClinical(widget.patient);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Avis spécialisé enregistré dans VISCERA.')),
      );
    } catch (_) {
      rollback();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text(
          'Enregistrement impossible : l’avis précédent a été conservé.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add() async {
    if (!_canEdit) return;
    String? service;
    bool done = false;
    final custom = TextEditingController();
    final input = await showModalBottomSheet<_OpinionInput>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) {
          final other = service == 'Autre service';
          final valid = service != null &&
              (!other || custom.text.trim().isNotEmpty);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20, 8, 20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ajouter un avis spécialisé',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('specialist-opinion-service'),
                    isExpanded: true,
                    initialValue: service,
                    decoration: const InputDecoration(
                      labelText: 'Service sollicité',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Choisir un service'),
                    items: specialistOpinionServices.map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)),
                    ).toList(),
                    onChanged: (value) => update(() => service = value),
                  ),
                  if (other) ...[
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('specialist-opinion-custom-service'),
                      controller: custom,
                      maxLength: 90,
                      decoration: const InputDecoration(
                        labelText: 'Nom du service',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => update(() {}),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    key: const Key('specialist-opinion-done-input'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(done ? 'Avis fait' : 'Avis non fait'),
                    subtitle: const Text('Statut de l’avis spécialisé'),
                    value: done,
                    onChanged: (value) => update(() => done = value),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: FilledButton.icon(
                    onPressed: !valid ? null : () {
                      Navigator.pop(sheetContext, _OpinionInput(
                        other ? custom.text.trim() : service!, done,
                      ));
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter cet avis'),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
    custom.dispose();
    if (!mounted || input == null || !_canEdit) return;
    final now = DateTime.now();
    final opinion = SpecialistOpinion(
      id: '${now.microsecondsSinceEpoch}-${widget.patient.specialistOpinions.length}',
      service: input.service,
      done: input.done,
      requestedAt: now,
      doneAt: input.done ? now : null,
    );
    await _commit(
      () => widget.patient.specialistOpinions.add(opinion),
      () => widget.patient.specialistOpinions.remove(opinion),
    );
  }

  Future<void> _changeStatus(SpecialistOpinion opinion, bool done) async {
    if (!_canEdit || opinion.done == done) return;
    final previousDone = opinion.done;
    final previousDoneAt = opinion.doneAt;
    await _commit(
      () {
        opinion.done = done;
        opinion.doneAt = done ? DateTime.now() : null;
      },
      () {
        opinion.done = previousDone;
        opinion.doneAt = previousDoneAt;
      },
    );
  }

  Future<void> _remove(SpecialistOpinion opinion) async {
    if (!_canEdit) return;
    final confirmed = await showConfirmation(
      context,
      title: 'Supprimer cet avis spécialisé ?',
      message: 'Retirer l’avis du service ${opinion.service} du dossier ?',
      action: 'Supprimer',
    );
    if (!confirmed || !mounted || !_canEdit) return;
    final originalIndex = widget.patient.specialistOpinions.indexOf(opinion);
    if (originalIndex == -1) return;
    await _commit(
      () => widget.patient.specialistOpinions.remove(opinion),
      () => widget.patient.specialistOpinions.insert(originalIndex, opinion),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opinions = widget.patient.specialistOpinions;
    final completed = opinions.where((opinion) => opinion.done).length;
    return VCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.medical_information_outlined, color: VColors.ink),
            const SizedBox(width: 10),
            const Expanded(child: Text('Avis spécialisés',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            if (_saving) const SizedBox(
              height: 17, width: 17,
              child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 8),
          Text('${opinions.length} avis · ${completed} fait(s)',
            style: const TextStyle(fontSize: 12, color: VColors.muted)),
          const SizedBox(height: 12),
          if (opinions.isEmpty)
            const Text('Aucun avis spécialisé demandé durant ce séjour.',
              style: TextStyle(fontSize: 13, color: VColors.muted)),
          for (final opinion in opinions) ...[
            Container(
              key: Key('specialist-opinion-${opinion.id}'),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.local_hospital_outlined, size: 17,
                      color: VColors.muted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(opinion.service,
                      style: const TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 14))),
                    if (!widget.readOnly) IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 19),
                      tooltip: 'Supprimer l’avis',
                      onPressed: _canEdit ? () => _remove(opinion) : null,
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    ChoiceChip(
                      label: const Text('Non fait'),
                      selected: !opinion.done,
                      onSelected: _canEdit && opinion.done
                        ? (_) => _changeStatus(opinion, false) : null,
                    ),
                    ChoiceChip(
                      label: const Text('Fait'),
                      selected: opinion.done,
                      onSelected: _canEdit && !opinion.done
                        ? (_) => _changeStatus(opinion, true) : null,
                    ),
                  ]),
                  if (opinion.done && opinion.doneAt != null) ...[
                    const SizedBox(height: 5),
                    Text('Fait le ${_date(opinion.doneAt!)}',
                      style: const TextStyle(color: VColors.muted,fontSize: 11)),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          if (_canEdit) ...[
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              key: const Key('add-specialist-opinion'),
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un avis spécialisé'),
            )),
          ],
        ],
      ),
    );
  }
}
