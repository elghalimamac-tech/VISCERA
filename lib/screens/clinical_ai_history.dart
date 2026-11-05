import 'package:flutter/material.dart';

import '../clinical_ai_reports.dart';
import '../models.dart';
import '../theme.dart';
import 'clinical_ai_page.dart';

String _reportDate(DateTime time) {
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
    'à ${two(local.hour)}:${two(local.minute)}';
}

Widget _reportTile(BuildContext context,
    PatientCase patient, ClinicalAiSavedReport report) {
  return ListTile(
    key: ValueKey('ai-report-${report.id}'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
    leading: Container(
      width: 43, height: 43,
      decoration: BoxDecoration(
        color: VColors.softMint,
        borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.description_outlined, color: VColors.ink)),
    title: Text('Analyse du ${_reportDate(report.createdAt)}',
      style: const TextStyle(fontWeight: FontWeight.w800,
        color: VColors.ink, fontSize: 13)),
    subtitle: Text(
      '${report.createdByName} · ${report.hypothesisCount} '
      'hypothèse(s) · conservée dans le dossier',
      style: const TextStyle(fontSize: 11.5, color: VColors.muted)),
    trailing: const Icon(Icons.chevron_right_rounded, color: VColors.ink),
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => ClinicalAiPage(
        patient: patient, savedReport: report))),
  );
}

/// Recharge les rapports depuis Supabase à chaque ouverture du dossier.
class ClinicalAiHistoryCard extends StatefulWidget {
  const ClinicalAiHistoryCard({super.key, required this.patient});
  final PatientCase patient;
  @override
  State<ClinicalAiHistoryCard> createState() =>
    _ClinicalAiHistoryCardState();
}

class _ClinicalAiHistoryCardState extends State<ClinicalAiHistoryCard> {
  late Future<List<ClinicalAiSavedReport>> reports;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    reports = ClinicalAiReports.list(widget.patient, limit: 3);
  }

  @override
  void didUpdateWidget(covariant ClinicalAiHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patient.id != widget.patient.id) _reload();
  }

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('patient-clinical-ai-history'),
    color: Colors.white, elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: const BorderSide(color: VColors.line)),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.history_edu_rounded, color: VColors.ink),
            const SizedBox(width: 8),
            const Expanded(child: Text('Analyses cliniques enregistrées',
              style: TextStyle(fontWeight: FontWeight.w800,
                color: VColors.ink, fontSize: 14))),
            IconButton(
              tooltip: 'Actualiser les analyses enregistrées',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () => setState(_reload)),
          ]),
          FutureBuilder<List<ClinicalAiSavedReport>>(
            future: reports,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 9),
                  child: Text('Chargement des analyses sauvegardées…',
                    style: TextStyle(fontSize: 12,
                      color: VColors.muted)));
              }
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 9),
                  child: Text('Historique indisponible. Vérifiez la '
                    'connexion et les droits d’accès.',
                    style: TextStyle(fontSize: 12,
                      color: Color(0xFFA45633))));
              }
              final saved = snapshot.data ?? [];
              if (saved.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Aucune analyse GROQ enregistrée '
                    'pour ce dossier.',
                    style: TextStyle(fontSize: 12,
                      color: VColors.muted)));
              }
              return Column(children: [
                for (final report in saved)
                  _reportTile(context, widget.patient, report),
                const Divider(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const Key('ai-history-all'),
                    onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) =>
                        ClinicalAiHistoryPage(patient: widget.patient))),
                    icon: const Icon(Icons.library_books_outlined),
                    label: const Text('Voir tout l’historique'),
                  )),
              ]);
            },
          ),
        ],
      ),
    ),
  );
}

class ClinicalAiHistoryPage extends StatefulWidget {
  const ClinicalAiHistoryPage({super.key, required this.patient});
  final PatientCase patient;

  @override
  State<ClinicalAiHistoryPage> createState() =>
      _ClinicalAiHistoryPageState();
}

class _ClinicalAiHistoryPageState extends State<ClinicalAiHistoryPage> {
  late Future<List<ClinicalAiSavedReport>> reports;
  @override
  void initState() {
    super.initState();
    reports = ClinicalAiReports.list(widget.patient, limit: 100);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Historique des analyses cliniques'),
      backgroundColor: VColors.background),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: FutureBuilder<List<ClinicalAiSavedReport>>(
          future: reports,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Chargement de l’historique impossible.'),
                  TextButton(onPressed: () => setState(() =>
                    reports = ClinicalAiReports.list(widget.patient, limit: 100)),
                    child: const Text('Réessayer')),
                ],
              ));
            }
            final saved = snapshot.data ?? [];
            if (saved.isEmpty) {
              return const Center(child: Text(
                'Aucune analyse enregistrée dans ce dossier.'));
            }
            return ListView.separated(
              key: const Key('ai-history-list'),
              padding: const EdgeInsets.all(16),
              itemCount: saved.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) =>
                _reportTile(context, widget.patient, saved[index]),
            );
          },
        ),
      ),
    ),
  );
}
