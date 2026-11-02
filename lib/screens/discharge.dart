import '../branding.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../document_checklist.dart';
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
  bool prescriptionChanged=false,clinicalValidated=false,farPrescriptionReady=false,saving=false;
  PatientCase get p=>widget.patient;
  @override void initState(){super.initState();
    prescription=TextEditingController(text:p.dischargePrescription.isNotEmpty?p.dischargePrescription:_prescriptionDraft(p));
    stayReport=TextEditingController(text:p.dischargeReport.isNotEmpty?p.dischargeReport:_stayDraft(p));
    operationReport=TextEditingController(text:p.operationReport.isNotEmpty?p.operationReport:_operationDraft(p));
  }
  @override void dispose(){for(final c in [prescription,stayReport,operationReport]){c.dispose();}super.dispose();}

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:VisceraPageTitle(widget.readOnly?'Documents de sortie':'Préparer la sortie'),backgroundColor:VColors.background),
    body:AnimatedBuilder(animation:appStore,builder:(context,_)=>SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(20,14,20,35),children:[
      VCard(color:VColors.ink,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('DOSSIER DE SORTIE',style:TextStyle(color:VColors.mint,fontSize:11,letterSpacing:1.6,fontWeight:FontWeight.w800)),const SizedBox(height:8),Text(p.name,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(p.procedure,style:const TextStyle(color:Colors.white70,fontSize:12))])),
      if(p.isFar)...[const SizedBox(height:13),VCard(color:VColors.orangeSoft,child:Row(children:[const Icon(Icons.priority_high_rounded,color:Color(0xFFA45633)),const SizedBox(width:12),const Expanded(child:Text('Mutuelle FAR : préparer l’ordonnance sur le support FAR.',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)))]))],
      SectionHeading('1. Ordonnance de sortie'),
      if(!widget.readOnly)CheckboxListTile(contentPadding:EdgeInsets.zero,value:prescriptionChanged,onChanged:(v)=>setState(()=>prescriptionChanged=v??false),title:const Text('L’ordonnance doit être adaptée / modifiée ?',style:TextStyle(fontSize:13.5)),controlAffinity:ListTileControlAffinity.leading),
      _editor(prescription,label:'Texte de l’ordonnance (brouillon)',lines:9,readOnly:widget.readOnly),_copyButton('Copier l’ordonnance',prescription),
      SectionHeading('2. Compte rendu d’hospitalisation'),_editor(stayReport,label:'Compte rendu d’hospitalisation (brouillon)',lines:10,readOnly:widget.readOnly),_copyButton('Copier le compte rendu',stayReport),
      SectionHeading('3. Compte rendu opératoire / rapport'),_editor(operationReport,label:'Compte rendu opératoire (brouillon)',lines:9,readOnly:widget.readOnly),_copyButton('Copier le rapport',operationReport),
      VCard(color:VColors.softMint,child:const Text('Certificat médical : cochez « fait / vérifié » dans la checklist seulement s’il est nécessaire et contrôlez le cachet. Sinon, sélectionnez « Non applicable ». Aucun modèle n’est généré.',style:TextStyle(fontSize:12.5))),
      SectionHeading('Checklist documentaire de sortie'),
      AnimatedBuilder(animation:appStore,builder:(context,_)=>DocumentChecklist(patient:p,title:'Documents à remettre et cachets',requirements:ClinicalDocuments.discharge,readOnly:widget.readOnly)),
      if(!widget.readOnly)...[
        SectionHeading('Validation médicale'),
        VCard(child:Column(children:[CheckboxListTile(contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,title:const Text('Évaluation clinique et documents relus, corrigés et validés par le médecin.',style:TextStyle(fontSize:12.8)),value:clinicalValidated,onChanged:(v)=>setState(()=>clinicalValidated=v??false)),if(p.isFar)CheckboxListTile(contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,title:const Text('Ordonnance sur support FAR préparée.',style:TextStyle(fontSize:12.8)),value:farPrescriptionReady,onChanged:(v)=>setState(()=>farPrescriptionReady=v??false))])),
        const SizedBox(height:18),SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:(!saving&&p.canDeclareDischarge&&clinicalValidated&&(!p.isFar||farPrescriptionReady))?_confirm:null,icon:const Icon(Icons.check_circle_outline_rounded),label:const Text('Valider la sortie et libérer le box'))),
        if(!p.allChecked(ClinicalDocuments.discharge))const Padding(padding:EdgeInsets.only(top:9),child:Text('Sortie bloquée : vérifiez tous les documents obligatoires et leurs cachets. Pour les pièces absentes ou non requises, utilisez « Non applicable » lorsque proposé.',style:TextStyle(color:Color(0xFFA45633),fontSize:12))),
        const SizedBox(height:10),const Text('Les textes sont des brouillons. Aucun traitement médicamenteux n’est prescrit automatiquement. La validation ne remplace pas le dossier médical officiel.',style:TextStyle(color:VColors.muted,fontSize:11.5)),
      ]
    ]))),
  );
  Widget _editor(TextEditingController c,{required String label,required int lines,required bool readOnly})=>VoiceClinicalField(controller:c,label:label,maxLines:lines,readOnly:readOnly);
  Widget _copyButton(String label,TextEditingController c)=>Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:c.text));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Texte copié.')));},icon:const Icon(Icons.copy_outlined,size:15),label:Text(label)));
  Future<void> _confirm() async{
    final ok=await showConfirmation(context,title:'Confirmer la sortie',message:'Le dossier sera marqué « Sorti » et le box libéré dans le tableau du service. Avez-vous vérifié l’aptitude clinique à la sortie et les documents ?',action:'Valider la sortie');
    if(!ok||!mounted)return;
    setState(()=>saving=true);
    try {
      final saved=await appStore.finalizeDischarge(p,
        prescription:prescription.text,
        report:stayReport.text,
        operationReport:operationReport.text,
        clinicalValidated:clinicalValidated,
        farPrescriptionReady:farPrescriptionReady);
      if(!mounted)return;
      if(saved) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Sortie bloquée : documents ou état clinique incomplets.')));
      }
    } catch (_) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Sortie non enregistrée. Le box reste occupé.')));
      }
    } finally {
      if(mounted)setState(()=>saving=false);
    }
  }
  String _prescriptionDraft(PatientCase p){
    final standard=p.procedure==procedures[0]||p.procedure==procedures[1];
    return 'PROJET D’ORDONNANCE DE SORTIE — À VALIDER\n'
      'Patient : ${p.name}\nIntervention : ${p.procedure}\n\n'
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
    'Bilans : ${p.labs}\nIntervention : ${p.procedure}\n'
    'Déroulement / suites opératoires : [à compléter après vérification]\n'
    'Traitements reçus : [à compléter]\nÉtat clinique à la sortie : [à compléter]\n'
    'Consignes, suivi et rendez-vous : [à compléter]\n'
    'Date de sortie : [à confirmer]\nMédecin / signature : [à compléter]';
  String _operationDraft(PatientCase p)=>'PROJET DE COMPTE RENDU OPÉRATOIRE — À VALIDER\n'
    'Patient : ${p.name}\nDate programmée du bloc : ${_fmt(p.blockAt)}\n'
    'Intitulé de l’intervention : ${p.procedure}\n'
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
