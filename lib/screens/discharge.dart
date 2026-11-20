import '../branding.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../voice_dictation.dart';

class DischargePage extends StatefulWidget {
  const DischargePage({super.key,required this.patient,this.readOnly=false});
  final PatientCase patient;final bool readOnly;
  @override State<DischargePage> createState()=>_DischargePageState();
}
class _DischargePageState extends State<DischargePage> {
  late final TextEditingController prescription,stayReport,operationReport;
  bool saving=false;
  PatientCase get p=>widget.patient;
  @override void initState(){super.initState();
    prescription=TextEditingController(text:p.dischargePrescription.isNotEmpty?p.dischargePrescription:_prescriptionDraft(p));
    stayReport=TextEditingController(text:p.dischargeReport.isNotEmpty?p.dischargeReport:_stayDraft(p));
    operationReport=TextEditingController(text:p.operationReport.isNotEmpty?p.operationReport:_operationDraft(p));
  }
  @override void dispose(){for(final c in [prescription,stayReport,operationReport]){c.dispose();}super.dispose();}

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: VisceraPageTitle(widget.readOnly
        ? 'Documents de sortie archivés' : 'Brouillons de sortie'),
      backgroundColor: VColors.background),
    body: SafeArea(child: ListView(
      padding: const EdgeInsets.fromLTRB(20,14,20,35),
      children: [
        VCard(color: VColors.ink,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
            const Text('DOSSIER DE SORTIE',style: TextStyle(
              color: VColors.mint,fontSize: 11,letterSpacing: 1.6,
              fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(p.name,style: const TextStyle(color: Colors.white,
              fontSize: 22,fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(p.effectiveProcedure,style: const TextStyle(
              color: Colors.white70,fontSize: 12)),
            const SizedBox(height: 14),
            AdmissionDateHighlight(patient: p),
          ])),
        if (!widget.readOnly) ...[
          const SizedBox(height: 12),
          const VCard(color: VColors.softMint,
            child: Text('Cette page sert uniquement à rédiger et enregistrer '
              'les brouillons médicaux. La vérification des documents et '
              'des cachets, puis la déclaration de sortie, s’effectuent '
              'exclusivement avec le bouton rouge « Déclarer la sortie » '
              'du dossier patient.',style: TextStyle(fontSize: 12.5))),
        ],
        if (p.isFar) ...[
          const SizedBox(height: 13),
          const VCard(color: VColors.orangeSoft,
            child: Text('Mutuelle FAR : préparer l’ordonnance sur '
              'le support FAR avant la vérification de sortie.')),
        ],
        SectionHeading('1. Ordonnance de sortie'),
        _editor(prescription,label: 'Texte de l’ordonnance (brouillon)',
          lines: 9,readOnly: widget.readOnly),
        _copyButton('Copier l’ordonnance',prescription),
        SectionHeading('2. Compte rendu d’hospitalisation'),
        _editor(stayReport,label: 'Compte rendu d’hospitalisation (brouillon)',
          lines: 10,readOnly: widget.readOnly),
        _copyButton('Copier le compte rendu',stayReport),
        SectionHeading('3. Compte rendu opératoire / rapport'),
        _editor(operationReport,label: 'Compte rendu opératoire (brouillon)',
          lines: 9,readOnly: widget.readOnly),
        _copyButton('Copier le rapport',operationReport),
        const SizedBox(height: 10),
        const Text('Ces textes sont des brouillons à vérifier et signer '
          'dans le dossier médical officiel. Ils ne valident aucune sortie.',
          style: TextStyle(color: VColors.muted,fontSize: 11.5)),
        if (!widget.readOnly) ...[
          const SizedBox(height: 18),
          SizedBox(width: double.infinity,
            child: FilledButton.icon(
              key: const Key('save-discharge-drafts'),
              icon: saving
                ? const SizedBox(height: 16,width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
              onPressed: saving ? null : _saveDrafts,
              label: Text(saving
                ? 'Enregistrement…' : 'Enregistrer les brouillons'),
            )),
        ],
      ],
    )),
  );
  Widget _editor(TextEditingController c,{required String label,required int lines,required bool readOnly})=>VoiceClinicalField(controller:c,label:label,maxLines:lines,readOnly:readOnly);
  Widget _copyButton(String label,TextEditingController c)=>Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:c.text));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Texte copié.')));},icon:const Icon(Icons.copy_outlined,size:15),label:Text(label)));
  Future<void> _saveDrafts() async {
    if (widget.readOnly || saving) return;
    final previousPrescription = p.dischargePrescription;
    final previousReport = p.dischargeReport;
    final previousOperation = p.operationReport;
    setState(() => saving = true);
    p.dischargePrescription = prescription.text;
    p.dischargeReport = stayReport.text;
    p.operationReport = operationReport.text;
    try {
      await appStore.saveClinical(p);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Brouillons de sortie enregistrés dans VISCERA.')));
    } catch (_) {
      p.dischargePrescription = previousPrescription;
      p.dischargeReport = previousReport;
      p.operationReport = previousOperation;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enregistrement impossible : brouillons non sauvegardés.')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  String _prescriptionDraft(PatientCase p){
    final standard=p.effectiveProcedure==procedures[0]||p.effectiveProcedure==procedures[1];
    return 'PROJET D’ORDONNANCE DE SORTIE — À VALIDER\n'
      'Patient : ${p.name}\nIntervention : ${p.effectiveProcedure}\n\n'
      '${standard?'Parcours standard de chirurgie laparoscopique. À adapter au patient.':'Parcours individualisé.'}\n\n'
      'MÉDICAMENTS (à renseigner par le prescripteur)\n'
      '1. [Dénomination / dose / voie / fréquence / durée]\n'
      '2. [Dénomination / dose / voie / fréquence / durée]\n\n'
      'Soins de plaies : [consignes validées]\n'
      'Activité / alimentation : [consignes individualisées]\n'
      'Suivi / contrôle : [date et lieu]\n'
      'Signes devant motiver une réévaluation urgente : [à préciser]\n\n'
      'Médecin prescripteur / signature : [à compléter]';
  }
  String _stayDraft(PatientCase p)=>'PROJET DE COMPTE RENDU D’HOSPITALISATION — À VALIDER\n'
    'Patient : ${p.name} (${p.id})\nOrigine : ${p.origin}\n'
    'Motif d’hospitalisation : ${p.motive}\nHistoire : ${p.history}\n'
    'Examen initial : ${p.exam}\nExamens complémentaires : ${p.investigations}\n'
    'Bilans : ${p.labs}\nIntervention : ${p.effectiveProcedure}\n'
    'Déroulement / suites opératoires : [à compléter après vérification]\n'
    'Traitements reçus : [à compléter]\nÉtat clinique à la sortie : [à compléter]\n'
    'Consignes, suivi et rendez-vous : [à compléter]\n'
    'Date de sortie : [à confirmer]\nMédecin / signature : [à compléter]';
  String _operationDraft(PatientCase p)=>'PROJET DE COMPTE RENDU OPÉRATOIRE — À VALIDER\n'
    'Patient : ${p.name}\nDate programmée du bloc : ${_fmt(p.blockAt)}\n'
    'Intitulé de l’intervention : ${p.effectiveProcedure}\n'
    'Chirurgien(s) : [à préciser]\nAnesthésie : [à préciser]\n'
    'Installation / voie d’abord : [à préciser]\n'
    'Constatations peropératoires : [à documenter]\n'
    'Gestes réalisés : [à documenter]\n'
    'Prélèvements / pièces : [à préciser]\n'
    'Incidents / complications : [à renseigner]\n'
    'Suites et consignes : [à compléter]\n'
    'Signature : [à compléter]';
  String _fmt(DateTime d)=>'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}
