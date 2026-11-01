import 'package:flutter/material.dart';
import '../document_checklist.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Fenêtre de contrôle accessible depuis le bouton flottant rouge.
/// La fermeture de cette fenêtre n'est jamais une confirmation de sortie.
class DischargeVerificationSheet extends StatefulWidget {
  const DischargeVerificationSheet({super.key, required this.patient});
  final PatientCase patient;

  @override
  State<DischargeVerificationSheet> createState() =>
      _DischargeVerificationSheetState();
}

class _DischargeVerificationSheetState extends State<DischargeVerificationSheet> {
  bool _clinicalValidated = false;
  bool _farPrescriptionReady = false;
  bool _saving = false;
  PatientCase get p => widget.patient;

  Future<void> _confirm() async {
    if (_saving || !p.canDeclareDischarge || !_clinicalValidated ||
        (p.isFar && !_farPrescriptionReady)) return;
    final confirmed = await showConfirmation(
      context: context,
      title: 'Confirmer définitivement la sortie',
      message: 'Les documents obligatoires ont été vérifiés, ainsi que '
          'leurs cachets. Confirmez-vous la décision médicale de sortie de '
          '${p.name} ? Le dossier sera marqué « Sorti » et le box libéré '
          'uniquement après enregistrement réussi dans VISCERA.',
      action: 'Confirmer la sortie',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      final saved = await appStore.finalizeDischarge(
        p,
        prescription: p.dischargePrescription,
        report: p.dischargeReport,
        operationReport: p.operationReport,
      );
      if (!mounted) return;
      if (saved) {
        Navigator.pop(context, 'confirmed');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sortie bloquée : vérifiez les documents et le statut clinique.'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La sortie n’a pas été enregistrée. Le patient reste hospitalisé.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appStore,
    builder: (context, _) {
      final missing = ClinicalDocuments.discharge.where((requirement) =>
          !p.check(requirement.key).complete(requirement)).toList();
      final eligible = p.isPostOp && p.physicallyAdmitted;
      final valid = eligible && missing.isEmpty && _clinicalValidated &&
          (!p.isFar || _farPrescriptionReady);
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * .86,
        child: SafeArea(
          top: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 14, 8),
              child: Row(children: [
                const Icon(Icons.assignment_turned_in_outlined,
                    color: Color(0xFFB4232F), size: 24),
                const SizedBox(width: 10),
                const Expanded(child: Text('Vérification avant sortie',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                IconButton(
                  tooltip: 'Fermer sans déclarer la sortie',
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: AbsorbPointer(
                absorbing: _saving,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                  children: [
                    VCard(color: VColors.softMint,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17)),
                          const SizedBox(height: 5),
                          Text('${p.stage.label} · ${p.currentUnit} · Box ${p.currentBox}',
                            style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 10),
                          Text('${ClinicalDocuments.discharge.length - missing.length}'
                            ' / ${ClinicalDocuments.discharge.length} documents vérifiés',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (!eligible)
                      const VCard(color: VColors.orangeSoft,
                        child: Text('La déclaration de sortie est réservée '
                          'aux patients réellement hospitalisés en phase '
                          'postopératoire ou en préparation de sortie.')),
                    const Text('Contrôle documentaire',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text(
                      'Vérifiez chaque pièce et le cachet lorsqu’il est requis. '
                      'Les pièces facultatives peuvent être déclarées « Non applicable ».',
                      style: TextStyle(fontSize: 12, color: VColors.muted)),
                    const SizedBox(height: 10),
                    DocumentChecklist(
                      patient: p,
                      title: 'Documents de sortie',
                      requirements: ClinicalDocuments.discharge,
                      readOnly: !eligible || _saving,
                    ),
                    if (missing.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      VCard(color: VColors.orangeSoft,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pièces encore à vérifier',
                              style: TextStyle(fontWeight: FontWeight.w700,
                                color: Color(0xFF984520))),
                            const SizedBox(height: 8),
                            ...missing.map((requirement) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text('• ${requirement.title}',
                                style: const TextStyle(fontSize: 12)),
                            )),
                          ],
                        )),
                    ],
                    const SizedBox(height: 18),
                    const Text('Validation médicale',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _clinicalValidated,
                      onChanged: eligible ? (value) =>
                        setState(() => _clinicalValidated = value ?? false) : null,
                      title: const Text('Aptitude clinique à la sortie et '
                        'documents relus et validés par le médecin',
                        style: TextStyle(fontSize: 13)),
                    ),
                    if (p.isFar) CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _farPrescriptionReady,
                      onChanged: eligible ? (value) =>
                        setState(() => _farPrescriptionReady = value ?? false) : null,
                      title: const Text('Ordonnance sur support FAR préparée',
                        style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Ouvrir les documents de sortie'),
                      onPressed: _saving ? null :
                        () => Navigator.pop(context, 'documents'),
                    ),
                    const SizedBox(height: 8),
                    const Text('Aucun document n’est considéré comme signé '
                      'ou remis automatiquement. Vérifiez le dossier médical '
                      'officiel avant validation.',
                      style: TextStyle(fontSize: 11, color: VColors.muted)),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: SizedBox(width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB4232F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: _saving
                    ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.logout_rounded),
                  label: Text(_saving ? 'Enregistrement de la sortie…'
                    : 'Déclarer la sortie et libérer le box'),
                  onPressed: valid && !_saving ? _confirm : null,
                ),
              ),
            ),
          ]),
        ),
      );
    },
  );
}
