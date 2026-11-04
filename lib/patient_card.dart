import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

/// Carte unique pour l'accueil et l'onglet Patients.
/// Le service figure dans l'en-tête du groupe : seul le box courant est repris.
class PatientCard extends StatelessWidget {
  const PatientCard({super.key, required this.patient, required this.onTap});
  final PatientCase patient;
  final VoidCallback onTap;

  Color get _accent {
    if (patient.blockTiming == 'Immédiat' && patient.isActive) {
      return const Color(0xFFBB5A41);
    }
    if (patient.stage == CaseStage.dischargeReady || patient.dischargeDue) {
      return const Color(0xFFC47B37);
    }
    if (patient.stage == CaseStage.inTheatre) return VColors.ink;
    if (patient.isPostOp) return const Color(0xFF0F938D);
    return VColors.muted;
  }

  String get _initials {
    final words = patient.name.trim().split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty).toList();
    if (words.isEmpty) return 'P';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (words.first.substring(0, 1) + words.last.substring(0, 1))
        .toUpperCase();
  }

  String get _subject {
    final surgery = patient.effectiveProcedure.trim();
    if (surgery.isNotEmpty) return surgery;
    final motive = patient.motive.trim();
    return motive.isEmpty ? 'Intervention non renseignée' : motive;
  }

  Widget _pill(IconData icon, String label, {bool warning = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: warning ? VColors.orangeSoft : VColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13,
            color: warning ? const Color(0xFF9D542E) : VColors.ink),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: warning ? const Color(0xFF9D542E) : VColors.ink)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBox = patient.currentBox.trim();
    final day = patient.hospitalizationDay;
    final age = patient.age.trim();
    final secondary = [
      if (age.isNotEmpty && age != '—') '$age ans',
      if (patient.origin.trim().isNotEmpty) patient.origin.trim(),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        key: Key('patient-card-' + patient.id),
        color: Colors.white,
        elevation: 1,
        shadowColor: VColors.ink.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: VColors.line),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Container(width: 4, color: _accent)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 15, 12, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46, height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: VColors.softMint,
                              borderRadius: BorderRadius.circular(14)),
                            child: Text(_initials,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: VColors.ink)),
                          ),
                          const SizedBox(width: 11),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(patient.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2, color: VColors.ink)),
                              if (secondary.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(secondary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5,
                                    color: VColors.muted)),
                              ],
                            ],
                          )),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded,
                            color: VColors.muted, size: 22),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(_subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: VColors.ink)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 6, runSpacing: 7, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(10)),
                          child: Text(patient.stage.label,
                            style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w800, color: _accent)),
                        ),
                        if (day != null)
                          _pill(Icons.today_outlined, 'J$day'),
                        if (currentBox.isNotEmpty)
                          _pill(Icons.bed_outlined, 'Box $currentBox'),
                        if (patient.blockTiming == 'Immédiat' && patient.isActive)
                          _pill(Icons.priority_high_rounded, 'Urgence', warning: true),
                        if (patient.requiresFrailtyAttention)
                          _pill(Icons.health_and_safety_outlined,
                            'CFS ' + patient.cfsScore.toString(), warning: true),
                        if (patient.dischargeDue)
                          _pill(Icons.event_available_outlined,
                            'Sortie à revoir', warning: true),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
