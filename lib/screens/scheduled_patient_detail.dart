import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

/// Le programme est une réservation opératoire, pas une admission hospitalière.
class ScheduledPatientPage extends StatelessWidget {
  const ScheduledPatientPage({super.key, required this.patient});
  final PatientCase patient;

  String _formatted(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final date = _formatted(patient.blockAt);
    final isPast = patient.blockAt.isBefore(DateTime(today.year, today.month, today.day));
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: VColors.muted)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Patient programmé')),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: VColors.softMint,
              borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PROGRAMME OFFICIEL DU BLOC',
                style: TextStyle(fontSize: 11, color: VColors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 9),
              Text(patient.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 9),
              const Text('Programmé · Provenance : Consultation',
                style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(isPast
                ? 'Date de programmation passée : vérifier le devenir auprès du service.'
                : 'Programmation prévisionnelle, sous réserve des modifications du bloc.',
                style: const TextStyle(fontSize: 12, color: VColors.muted)),
            ]),
          ),
          const SizedBox(height: 20),
          Text('Intervention programmée', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          line('Intervention', patient.procedure),
          line('Date du programme', date),
          line('Heure prévue', patient.programScheduledTime.isEmpty
            ? 'Non renseignée' : patient.programScheduledTime),
          line('Salle', patient.programRoom.isEmpty ? 'Non renseignée' : patient.programRoom),
          line('Chirurgien', patient.programSurgeon),
          if (patient.programSourceService.isNotEmpty)
            line('Service mentionné sur le programme', patient.programSourceService),
          const Divider(height: 30),
          Text('Admission et suivi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          line('Provenance', 'Consultation'),
          line('Admission hospitalière', 'Non confirmée dans VISCERA'),
          line('Date de consultation', 'Non renseignée sur le programme'),
          line('Mutuelle et identité complémentaire', 'À compléter lors de l’admission'),
          line('Lit / box', 'Non attribué'),
          const SizedBox(height: 14),
          const Text(
            'Ce patient provient du programme opératoire officiel. '
            'Sa présence sur le programme ne permet pas de confirmer son admission, '
            'la réalisation de l’intervention ou son hospitalisation. '
            'Aucun dossier clinique, bilan ou séjour n’a été renseigné automatiquement.',
            style: TextStyle(color: VColors.muted, fontSize: 12, height: 1.5),
          ),
        ],
      )),
    );
  }
}
