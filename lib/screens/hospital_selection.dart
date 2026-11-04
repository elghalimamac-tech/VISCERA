import 'package:flutter/material.dart';
import '../branding.dart';
import '../hospital_site.dart';
import '../push_device_registration.dart';
import '../store.dart';
import '../theme.dart';
import 'shell.dart';

/// Montée UNIQUEMENT après une session médecin confirmée et approuvée
/// par AuthGate. Une simple sélection ne procure aucun droit supplémentaire.
class HospitalSelectionGate extends StatefulWidget {
  const HospitalSelectionGate({super.key, required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  State<HospitalSelectionGate> createState() => _HospitalSelectionGateState();
}

class _HospitalSelectionGateState extends State<HospitalSelectionGate> {
  HospitalSite? _site;

  void _changeHospital() {
    if (mounted) setState(() => _site = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_site == HospitalSite.huim6) {
      return PushDeviceRegistration(
        child: MainShell(onChangeHospital: _changeHospital),
      );
    }
    if (_site == HospitalSite.huick) {
      return HuickMaintenancePage(
        onChangeHospital: _changeHospital,
        onSignOut: widget.onSignOut,
      );
    }
    return HospitalSelectionPage(
      onSelected: (site) => setState(() => _site = site),
      onSignOut: widget.onSignOut,
    );
  }
}

/// L'espace HUICK n'initialise aucun écran ni aucune requête clinique HUIM6.
class HuickMaintenancePage extends StatelessWidget {
  const HuickMaintenancePage({
    super.key,
    required this.onChangeHospital,
    required this.onSignOut,
  });
  final VoidCallback onChangeHospital;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final isAdmin = appStore.activeLocalProfile?.isVisceraOwner == true;
    return Scaffold(
      backgroundColor: VColors.background,
      appBar: AppBar(
        title: const Text('VISCERA · HUICK'),
        backgroundColor: VColors.background,
      ),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: VisceraBrandLockup(markSize: 53, subtitle: null)),
              const SizedBox(height: 32),
              const Icon(Icons.construction_rounded, size: 52,
                color: Color(0xFFA45633)),
              const SizedBox(height: 14),
              Text('HUICK Casablanca · En travaux',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(isAdmin
                ? 'Accès administrateur autorisé pour préparer le futur espace HUICK. '
                  'Les admissions, les données cliniques et le programme du bloc '
                  'ne sont pas encore ouverts : aucune donnée HUIM6 n’est affichée.'
                : 'L’espace HUICK est actuellement en travaux et ne permet '
                  'pas encore l’accès aux utilisateurs. Accès réservé à '
                  'l’administrateur principal pendant sa préparation.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14,
                  color: VColors.muted, height: 1.6)),
              const SizedBox(height: 25),
              if (isAdmin) Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: VColors.softMint,
                  borderRadius: BorderRadius.circular(16)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Préparation de HUICK',
                      style: TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 15, color: VColors.ink)),
                    SizedBox(height: 8),
                    Text('À configurer : unités, boxes, plannings, '
                      'programmes opératoires et autorisations serveur. '
                      'L’équipe médicale est commune aux deux hôpitaux. '
                      'Aucun dossier HUIM6 ne peut être utilisé ici.',
                      style: TextStyle(fontSize: 12,
                        color: VColors.ink, height: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('change-hospital-from-huick'),
                onPressed: onChangeHospital,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Changer d’établissement')),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_outlined),
                label: const Text('Se déconnecter')),
            ],
          ),
        ),
      ))),
    );
  }
}

class HospitalSelectionPage extends StatelessWidget {
  const HospitalSelectionPage({super.key, required this.onSelected,
    this.onSignOut});
  final ValueChanged<HospitalSite> onSelected;
  final VoidCallback? onSignOut;

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
              if (onSignOut != null) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  key: const Key('logout-from-hospital-selection'),
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout_outlined),
                  label: const Text('Se déconnecter')),
              ],
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
