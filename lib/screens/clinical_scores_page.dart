import 'package:flutter/material.dart';
import '../branding.dart';
import '../cfs_assessment.dart';
import '../clinical_scores.dart';
import '../biological_followup.dart';
import 'lab_results_page.dart';
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
            Card(
              elevation:0,
              child:Padding(
                padding:const EdgeInsets.all(14),
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.stretch,
                  children:[
                    const Text('Bilans nécessaires aux scores',
                      style:TextStyle(fontWeight:FontWeight.w800,
                        fontSize:15)),
                    const SizedBox(height:5),
                    Text('CRP : ' +
                      (labSeries(patient,'crp').isEmpty ? 'non renseignée'
                        : labSeries(patient,'crp').last.value.toString()+' mg/L') +
                      ' · Hémoglobine : ' +
                      (labSeries(patient,'hb').isEmpty ? 'non renseignée'
                        : labSeries(patient,'hb').last.value.toString()+' g/dL'),
                      style:const TextStyle(fontSize:12)),
                    const SizedBox(height:10),
                    FilledButton.icon(
                      key:const Key('open-labs-from-scores'),
                      onPressed:()=>Navigator.push(context,MaterialPageRoute(
                        builder:(_)=>LabResultsPage(patient:patient))),
                      icon:const Icon(Icons.science_outlined),
                      label:const Text('Saisir CRP et tous les bilans'),
                    ),
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
