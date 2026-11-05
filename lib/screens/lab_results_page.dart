import 'package:flutter/material.dart';
import '../biological_followup.dart';
import '../branding.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Formulaire des bilans utilisable directement depuis les scores.
/// Enregistre un résultat daté par paramètre dans l'observation du jour,
/// sans modifier les éléments cliniques rédigés par l'équipe.
class LabResultsPage extends StatefulWidget {
  const LabResultsPage({super.key, required this.patient});
  final PatientCase patient;
  @override
  State<LabResultsPage> createState() => _LabResultsPageState();
}

class _LabResultsPageState extends State<LabResultsPage> {
  late DateTime selectedDate;
  late final Map<String, TextEditingController> controllers;
  final formKey = GlobalKey<FormState>();
  bool saving = false;

  PatientCase get p => widget.patient;
  bool get canEdit => (p.isActive || p.isProgrammed) &&
      !p.isOmitted && (p.fromBlocProgram || p.fromManualAdmission);

  DailyObservation? observationFor(DateTime date) {
    for (final note in p.dailyObservations) {
      if (note.date.year == date.year &&
          note.date.month == date.month && note.date.day == date.day) {
        return note;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    controllers = {
      for (final field in biologyFields)
        field.key: TextEditingController(),
    };
    loadSelectedDate();
  }

  void loadSelectedDate() {
    final note = observationFor(selectedDate);
    for (final field in biologyFields) {
      controllers[field.key]!.text =
          note?.biology[field.key]?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String dateLabel(DateTime d) =>
      d.day.toString().padLeft(2, '0') + '/' +
      d.month.toString().padLeft(2, '0') + '/' +
      d.year.toString();

  void notifyUser(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)));
  }

  Future<void> selectDate() async {
    if (saving) return;
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isAfter(today) ? today : selectedDate,
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: 'Date du prélèvement biologique',
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedDate = picked;
      loadSelectedDate();
    });
  }

  Future<void> saveResults() async {
    if (saving || !canEdit || !(formKey.currentState?.validate() ?? false)) return;
    final biology = <String, double>{};
    try {
      for (final field in biologyFields) {
        final value = parseBiology(controllers[field.key]!.text, field);
        if (value != null) biology[field.key] = value;
      }
    } on FormatException catch (error) {
      notifyUser(error.message);
      return;
    }
    if (biology.isEmpty) {
      notifyUser('Saisissez au moins un résultat mesuré, sans remplacer les données absentes par zéro.');
      return;
    }

    final old = observationFor(selectedDate);
    final originalIndex = p.dailyObservations.indexWhere((item) =>
        item.date.year == selectedDate.year &&
        item.date.month == selectedDate.month &&
        item.date.day == selectedDate.day);
    final sameData = old != null &&
        old.biology.length == biology.length &&
        biology.entries.every((entry) => old.biology[entry.key] == entry.value);
    if (sameData) {
      notifyUser('Ces résultats sont déjà enregistrés pour cette date.');
      return;
    }
    final updated = DailyObservation(
      date: old?.date ?? selectedDate,
      vitals: old?.vitals ?? '',
      symptoms: old?.symptoms ?? '',
      clinicalExam: old?.clinicalExam ?? '',
      results: old?.results ?? '',
      plan: old?.plan ?? '',
      biology: biology,
      // Un nouveau bilan nécessite une nouvelle vérification du report.
      reportedMagica: false,
      reportedSillage: false,
    );
    setState(() => saving = true);
    if (originalIndex >= 0) {
      p.dailyObservations[originalIndex] = updated;
    } else {
      p.dailyObservations.add(updated);
    }
    p.dailyObservations.sort((a, b) => b.date.compareTo(a.date));
    appStore.refresh();
    try {
      await appStore.saveClinical(p);
      if (!mounted) return;
      appStore.refresh();
      notifyUser('Bilans enregistrés : scores et courbe CRP actualisés.');
    } catch (_) {
      p.dailyObservations.remove(updated);
      if (old != null) p.dailyObservations.add(old);
      p.dailyObservations.sort((a, b) => b.date.compareTo(a.date));
      appStore.refresh();
      notifyUser('Échec de sauvegarde : les anciens résultats sont conservés.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appStore,
    builder: (context, _) {
      final crp = observationFor(selectedDate)?.biology['crp'];
      final wbc = observationFor(selectedDate)?.biology['wbc'];
      return Scaffold(
        appBar: AppBar(
          title: const VisceraPageTitle('Bilans biologiques'),
          backgroundColor: VColors.background,
          surfaceTintColor: Colors.transparent,
        ),
        body: Form(
          key: formKey,
          child: ListView(
            key: const Key('lab-results-form'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Card(
                color: VColors.softMint,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 6),
                      const Text('Un champ numérique pour chaque bilan, avec ses unités. '
                        'Les résultats sont facultatifs et ne sont jamais inventés. '
                        'Les scores utilisant ces résultats ne seront calculés '
                        'que si les données nécessaires sont disponibles.',
                        style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('lab-select-date'),
                        onPressed: canEdit ? selectDate : null,
                        icon: const Icon(Icons.event_outlined),
                        label: Text('Prélèvement du ' + dateLabel(selectedDate)),
                      ),
                      const SizedBox(height: 8),
                      Text('CRP enregistrée : ' +
                          (crp == null ? 'non renseignée' : crp.toString() + ' mg/L') +
                          ' · GB : ' +
                          (wbc == null ? 'non renseignés' : wbc.toString() + ' G/L'),
                        style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('CRP (mDULK) et globules blancs', style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 7),
              const Text('À proposer à chaque observation quotidienne. '
                  'Une absence de prélèvement reste un champ vide.',
                style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              for (final field in biologyFields) ...[
                if (field.key == 'albumin') ...[
                  const SizedBox(height: 12),
                  const Text('Autres paramètres utiles aux indices et scores',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 10),
                ],
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    key: ValueKey('lab-result-' + field.key),
                    controller: controllers[field.key],
                    enabled: canEdit && !saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                    decoration: InputDecoration(
                      labelText: field.label,
                      suffixText: field.unit,
                      hintText: 'Non renseigné',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      try {
                        parseBiology(value ?? '', field);
                        return null;
                      } on FormatException catch (error) {
                        return error.message;
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const Key('save-lab-results'),
                onPressed: canEdit && !saving ? saveResults : null,
                icon: const Icon(Icons.save_outlined),
                label: Text(saving ? 'Enregistrement…' : 'Enregistrer les bilans'),
              ),
              const SizedBox(height: 12),
              const Text('Saisie clinique exclusivement à partir de résultats vérifiés. '
                'Une modification des bilans réinitialise les cases de report '
                'Magica/Sillage de cette observation.',
                style: TextStyle(fontSize: 11, color: VColors.muted)),
              const SizedBox(height: 14),
              CrpTrendCard(patient: p, compact: true),
              BiologicalIndicesCard(patient: p),
            ],
          ),
        ),
      );
    },
  );
}
