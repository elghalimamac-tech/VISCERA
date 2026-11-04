import 'package:flutter/material.dart';
import '../branding.dart';
import '../hospital_site.dart';
import '../theme.dart';
import 'auth_gate.dart';

/// Le choix d'hopital est volontairement un ecran de demarrage.
/// HUICK ne doit jamais monter MainShell avant la separation cote Supabase.
class HospitalSelectionGate extends StatefulWidget {
  const HospitalSelectionGate({super.key});

  @override
  State<HospitalSelectionGate> createState() => _HospitalSelectionGateState();
}

class _HospitalSelectionGateState extends State<HospitalSelectionGate> {
  HospitalSite? _site;

  @override
  Widget build(BuildContext context) {
    if (_site != null) {
      return AuthGate(
        key: ValueKey(_site),
        hospital: _site!,
        onChangeHospital: () => setState(() => _site = null),
      );
    }
    return HospitalSelectionPage(onSelected: (site) {
      setState(() => _site = site);
    });
  }
}

class HospitalSelectionPage extends StatelessWidget {
  const HospitalSelectionPage({super.key, required this.onSelected});
  final ValueChanged<HospitalSite> onSelected;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VColors.background,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 530),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 36),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Center(child: VisceraBrandLockup(markSize: 56, subtitle: null)),
              const SizedBox(height: 33),
              Text('Choisissez votre établissement',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Une seule application VISCERA, avec un espace dédié à chaque hôpital.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: VColors.muted, height: 1.5)),
              const SizedBox(height: 27),
              _siteCard(
                context,
                site: HospitalSite.huim6,
                icon: Icons.local_hospital_outlined,
                status: 'Espace clinique opérationnel',
                statusColor: const Color(0xFF087B71),
                onTap: () => onSelected(HospitalSite.huim6)),
              const SizedBox(height: 12),
              _siteCard(
                context,
                site: HospitalSite.huick,
                icon: Icons.apartment_outlined,
                status: 'En travaux · accès administrateur uniquement',
                statusColor: const Color(0xFFA45633),
                onTap: () => onSelected(HospitalSite.huick)),
              const SizedBox(height: 23),
              const Row(children: [
                Icon(Icons.shield_outlined, size: 17, color: VColors.muted),
                SizedBox(width: 9),
                Expanded(child: Text(
                  'Les dossiers HUIM6 restent exclusivement dans leur espace. '
                  'Aucune donnée clinique HUIM6 n’est transférée vers HUICK.',
                  style: TextStyle(fontSize: 11.5, height: 1.45, color: VColors.muted))),
              ]),
            ]),
          ),
        ),
      ),
    ),
  );

  Widget _siteCard(
    BuildContext context, {
    required HospitalSite site,
    required IconData icon,
    required String status,
    required Color statusColor,
    required VoidCallback onTap,
  }) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: Key('hospital-choice-' + site.shortName.toLowerCase()),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: VColors.line, width: 1.2)),
        padding: const EdgeInsets.fromLTRB(16, 19, 13, 19),
        child: Row(children: [
          Container(
            height: 53,
            width: 53,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: site == HospitalSite.huim6
                ? VColors.softMint : VColors.orangeSoft,
              borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, size: 28, color: VColors.ink)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(site.name,
              style: const TextStyle(fontWeight: FontWeight.w900,
                fontSize: 16, color: VColors.ink)),
            const SizedBox(height: 4),
            Text(site.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: VColors.muted)),
            const SizedBox(height: 9),
            Text(status,
              maxLines: 2,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800,
                color: statusColor)),
          ])),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: VColors.muted),
        ]),
      ),
    ),
  );
}
