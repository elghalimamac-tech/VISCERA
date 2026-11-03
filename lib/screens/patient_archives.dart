import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../branding.dart';
import '../widgets.dart';
import 'patient_detail.dart';

/// Les archives restent dans la base clinique partagée ; cet écran
/// n'efface ni ne duplique de données patient.
class PatientArchivesPage extends StatefulWidget {
  const PatientArchivesPage({super.key});

  @override
  State<PatientArchivesPage> createState() => _PatientArchivesPageState();
}

class _PatientArchivesPageState extends State<PatientArchivesPage> {
  String _query = '';

  String _date(DateTime? date) {
    if (date == null) return 'Date non renseignée';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: VColors.background,
      title: const VisceraPageTitle('Archives'),
    ),
    backgroundColor: VColors.background,
    body: AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final archived = appStore.patients.where((p) {
          if (!p.isArchived) return false;
          final search = _query.trim().toLowerCase();
          if (search.isEmpty) return true;
          return '${p.name} ${p.effectiveProcedure} ${p.id} ${p.surgeryType}'
              .toLowerCase().contains(search);
        }).toList()
          ..sort((a, b) {
            final timeA = a.dischargeAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final timeB = b.dischargeAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return timeB.compareTo(timeA);
          });

        return ListView(
          key: const Key('archives-patient-list'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 35),
          children: [
            Text('Patients sortis',
              style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text('Les dossiers sortis sont conservés dans les archives '
                'dès validation de la sortie. Ils quittent les listes du '
                'service 48 heures après leur sortie, sans suppression '
                'du dossier médical.',
                style: TextStyle(color: VColors.muted, fontSize: 12)),
            const SizedBox(height: 17),
            TextField(
              key: const Key('archives-search-field'),
              decoration: const InputDecoration(
                hintText: 'Rechercher patient ou intervention',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 16),
            Text('${archived.length} dossier(s) archivé(s)',
              style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...archived.map((p) => VCard(
              margin: const EdgeInsets.only(bottom: 10),
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => PatientDetailPage(patient: p))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.inventory_2_outlined, color: VColors.ink),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15))),
                    const Icon(Icons.chevron_right_rounded,
                      color: VColors.muted),
                  ]),
                  const SizedBox(height: 8),
                  Text(p.effectiveProcedure.trim().isEmpty
                      ? 'Intervention non renseignée' : p.effectiveProcedure,
                    style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Text('Sortie le ${_date(p.dischargeAt)}',
                    style: const TextStyle(fontSize: 12,
                      color: VColors.muted)),
                ],
              ),
            )),
            if (archived.isEmpty)
              const VCard(child: Text('Aucun dossier archivé pour cette recherche.')),
          ],
        );
      },
    ),
  );
}
