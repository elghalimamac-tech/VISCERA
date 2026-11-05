import 'package:flutter/material.dart';
import '../branding.dart';
import '../cfs_assessment.dart';
import '../clinical_scores.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Accès direct aux formulaires cliniques : aucun formulaire ne dépend
/// de l'ouverture préalable des autres rubriques du dossier patient.
class ClinicalScoresPage extends StatelessWidget {
  const ClinicalScoresPage({super.key, required this.patient});
  final PatientCase patient;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appStore,
    builder: (context, _) {
      final preoperative = patient.stage == CaseStage.scheduled ||
          patient.stage == CaseStage.preoperative;
      final postoperative = patient.isPostOp ||
          patient.stage == CaseStage.discharged;
      final readOnly = patient.isOmitted ||
          patient.stage == CaseStage.discharged;
      final phase = preoperative
          ? 'Préopératoire' : postoperative
          ? 'Postopératoire' : 'Au bloc';
      return Scaffold(
        appBar: AppBar(
          title: const VisceraPageTitle('Scores cliniques'),
          backgroundColor: VColors.background,
          surfaceTintColor: Colors.transparent,
        ),
        body: ListView(
          key: const Key('clinical-score-forms-page'),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
          children: [
            Card(
              color: VColors.softMint,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name,
                      style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text('Phase : $phase · '
                      '${patient.clinicalScores.length} score(s) enregistrés',
                      style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    const Text(
                      'Ouvrir un score pour remplir ses critères un à un. '
                      'Les données manquantes restent inconnues : aucun '
                      'calcul automatique sans informations complètes. '
                      'Chaque formulaire peut être enregistré séparément.',
                      style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ClinicalScoresCard(
              patient: patient,
              readOnly: readOnly,
              expandedOnLoad: true,
              expandFirstForm: true,
            ),
            if (preoperative || patient.cfsScore != null ||
                patient.asaClass.isNotEmpty) ...[
              const SizedBox(height: 12),
              CfsAssessmentCard(
                patient: patient,
                readOnly: readOnly || !preoperative,
                expandedOnLoad: false,
              ),
            ],
          ],
        ),
      );
    },
  );
}
