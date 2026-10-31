import 'package:flutter/material.dart';
import '../models.dart';
import '../document_checklist.dart';
import '../planning_models.dart';
import 'planning.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../voice_dictation.dart';

class IntakePage extends StatefulWidget { const IntakePage({super.key}); @override State<IntakePage> createState()=>_IntakePageState(); }
class _IntakePageState extends State<IntakePage> {
  int step=0;
  late final PatientCase _intakeDocs = PatientCase(
    id:'TEMP',name:'Brouillon',age:'—',origin:'Urgences',insurance:'À préciser',
    motive:'',history:'',exam:'',investigations:'',labs:'',immediatePlan:'',
    procedure:procedures.first,blockTiming:'Différé',admissionTiming:'Immédiate',
    beforeUnit:'TC1',beforeBox:'',afterUnit:'TC1',afterBox:'',expectedDays:1,
    blockAt:DateTime.now(),admittedAt:DateTime.now());
  final name=TextEditingController(),age=TextEditingController(),motive=TextEditingController(),history=TextEditingController(),exam=TextEditingController(),investigations=TextEditingController(),labs=TextEditingController(),plan=TextEditingController();
  final preBox=TextEditingController(),postBox=TextEditingController();
  final length=TextEditingController(text:'1');
  final assignmentReason=TextEditingController();
  String? professorOverrideId;
  DateTime consultationAt=DateTime.now();
  DateTime arrivalAt=DateTime.now();
  ProfessorMatch get match => appStore.resolveProfessor(origin, origin=='Urgences'?arrivalAt:consultationAt);
  String? get selectedProfessorId => professorOverrideId??match.professorId;
  bool get manualOverride => professorOverrideId!=null && match.professorId!=null && professorOverrideId!=match.professorId;
  String origin='Urgences',insurance='À préciser',procedure=procedures.first,blockTiming='Différé',admissionTiming='Le jour du bloc',preUnit='TC1',postUnit='TC1';
  DateTime blockAt=DateTime.now().add(const Duration(days:1));
  @override void dispose(){for(final c in [name,age,motive,history,exam,investigations,labs,plan,preBox,postBox,length,assignmentReason]){c.dispose();}super.dispose();}

  void alert(String message)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
  void next(){
    if(step==0&&name.text.trim().isEmpty){alert('Renseignez le nom ou identifiant du patient.');return;}
    if(step==0&&appStore.responsibleOptions(forEmergencies:origin=='Urgences').isEmpty){alert('Ajoutez les médecins dans Équipe & planning avant cette admission.');return;}
    if(step==0&&appStore.responsibleById(selectedProfessorId)==null){alert('Veuillez attribuer un médecin responsable.');return;}
    if(step==0&&manualOverride&&assignmentReason.text.trim().isEmpty){alert('Précisez la raison du changement de professeur.');return;}

    if(step==1&&motive.text.trim().isEmpty){alert('Renseignez le motif de consultation.');return;}
    if(step==2){if(preBox.text.trim().isEmpty||postBox.text.trim().isEmpty){alert('Renseignez les boxes pré- et postopératoires.');return;}if(int.tryParse(length.text.trim())==null||int.parse(length.text.trim())<0){alert('Renseignez une durée de séjour valide.');return;}}
    if(step<3){setState(()=>step++);}else{_save();}
  }
  void _save(){
    final effectiveDate=blockTiming=='Immédiat'?DateTime.now():blockAt;
    final conflict=admissionTiming=='Immédiate'?appStore.conflictingBox(preUnit,preBox.text):null;
    if(conflict!=null){alert('Box préopératoire déjà attribué à ${conflict.name}.');return;}
    // Les affectations futures restent à confirmer au moment du transfert au bloc / postop.
    final assignment=match;
    final physician=selectedProfessorId;
    if(appStore.responsibleById(physician)==null){alert('Médecin responsable non renseigné.');return;}
    final manuallyChosen=professorOverrideId!=null;
    if(manualOverride&&assignmentReason.text.trim().isEmpty){alert('Précisez le motif de dérogation.');return;}
    final p=PatientCase(
      id:appStore.nextId(),name:name.text.trim(),age:age.text.trim().isEmpty?'—':age.text.trim(),origin:origin,insurance:insurance,
      motive:motive.text.trim(),history:history.text.trim(),exam:exam.text.trim(),investigations:investigations.text.trim(),labs:labs.text.trim(),immediatePlan:plan.text.trim(),
      procedure:procedure,blockTiming:blockTiming,admissionTiming:admissionTiming,beforeUnit:preUnit,beforeBox:preBox.text.trim(),afterUnit:postUnit,afterBox:postBox.text.trim(),
      expectedDays:int.parse(length.text.trim()),blockAt:effectiveDate,admittedAt:arrivalAt,
      consultationAt:origin=='Consultation'?consultationAt:null,
      professorId:physician,
      assignmentMode:manuallyChosen?'Attribution manuelle':assignment.mode,
      assignmentExplanation:manuallyChosen?(manualOverride?'Dérogation : ${assignmentReason.text.trim()}':assignment.explanation):assignment.explanation,

    );
    for (final entry in _intakeDocs.documents.entries) {
      final source=entry.value, target=p.check(entry.key);
      target.verified=source.verified;
      target.stamped=source.stamped;
      target.notApplicable=source.notApplicable;
      target.checkedAt=source.checkedAt;
    }
    p.confidentialEnvelopeDone = p.check('pli').verified;
    appStore.add(p);
    Navigator.pop(context);
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Nouvelle admission',style:TextStyle(fontWeight:FontWeight.w800)),backgroundColor:VColors.background,surfaceTintColor:Colors.transparent),
    body:SafeArea(child:Column(children:[
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: Row(children: List.generate(4, (i) => Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: i <= step ? VColors.ink : VColors.line, borderRadius: BorderRadius.circular(3)),
          ),
        ))),
      ),
      Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(20,9,20,20),children:[
        Overline('ÉTAPE ${step+1} SUR 4'),const SizedBox(height:7),Text(['Identité & couverture','Dossier clinique','Séjour & intervention','Vérification'][step],style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:6),Text(['L’essentiel à l’arrivée.','Un seul dossier médical continu.','Lits avant/après bloc et séjour prévu.','Confirmez avant de créer le dossier.'][step],style:const TextStyle(color:VColors.muted)),const SizedBox(height:25),
        if(step==0)..._identity(),if(step==1)..._clinical(),if(step==2)..._organization(),if(step==3)..._review(),
      ])),
      Container(padding:const EdgeInsets.fromLTRB(20,12,20,15),decoration:const BoxDecoration(color:Colors.white,border:Border(top:BorderSide(color:VColors.line))),child:Row(children:[if(step>0)...[Expanded(child:OutlinedButton(onPressed:()=>setState(()=>step--),child:const Padding(padding:EdgeInsets.symmetric(vertical:13),child:Text('Retour')))),const SizedBox(width:10)],Expanded(flex:2,child:ElevatedButton(onPressed:next,child:Text(step==3?'Créer le dossier':'Continuer')))])),
    ])),
  );

  List<Widget> _identity()=>[
    _field('Nom / identifiant patient',name,hint:'Ex. Patient ou n° de dossier'),const SizedBox(height:12),_field('Âge',age,hint:'En années',number:true),const SizedBox(height:19),
    const Overline('PROVENANCE'),const SizedBox(height:9),_chips(['Urgences','Consultation'],origin,(v)=>setState((){origin=v;professorOverrideId=null;assignmentReason.clear();})),const SizedBox(height:17),
    if(origin=='Urgences')...[
      VCard(onTap:_chooseArrivalDate,child:Row(children:[const Icon(Icons.access_time_outlined),const SizedBox(width:11),Expanded(child:Text('Arrivée aux urgences : ${_format(arrivalAt)}',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12.5))),const Icon(Icons.edit_outlined,size:18)])),const SizedBox(height:14),
    ],
    if(origin=='Consultation')...[
      VCard(onTap:_chooseConsultationDate,child:Row(children:[const Icon(Icons.event_outlined),const SizedBox(width:11),Expanded(child:Text('Date et heure de consultation : ${_format(consultationAt)}',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12.5))),const Icon(Icons.edit_outlined,size:18)])),const SizedBox(height:14),
    ],
    VCard(color:match.professorId!=null?VColors.softMint:VColors.orangeSoft,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Overline('MÉDECIN RESPONSABLE'),const SizedBox(height:7),
      Text(match.explanation,style:const TextStyle(fontSize:12.5)),
      const SizedBox(height:11),
      if(appStore.responsibleOptions(forEmergencies:origin=='Urgences').isEmpty)...[
        const Text('Aucun médecin enregistré.',style:TextStyle(fontWeight:FontWeight.w700)),
        TextButton.icon(onPressed:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>const PlanningPage()));if(mounted)setState((){});},icon:const Icon(Icons.group_add_outlined),label:const Text('Configurer les médecins')),
      ] else DropdownButtonFormField<String>(value:selectedProfessorId,isExpanded:true,decoration:const InputDecoration(labelText:'Médecin responsable'),
        items:appStore.responsibleOptions(forEmergencies:origin=='Urgences').map((p)=>DropdownMenuItem(value:p.id,child:Text(p.name,overflow:TextOverflow.ellipsis))).toList(),
        onChanged:(id)=>setState((){professorOverrideId=id==match.professorId?null:id;assignmentReason.clear();})),
      if(manualOverride)...[const SizedBox(height:9),_field('Motif du changement obligatoire',assignmentReason,maxLines:2)],
    ])),const SizedBox(height:21),
    _picker('Mutuelle / assurance',insurance,healthInsurances,(v)=>setState(()=>insurance=v)),const SizedBox(height:14),
    VCard(color:insurance=='FAR'?VColors.orangeSoft:VColors.softMint,child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(insurance=='FAR'?Icons.priority_high_rounded:Icons.mark_email_unread_outlined,color:VColors.ink),const SizedBox(width:11),Expanded(child:Text(insurance=='FAR'?'Rappel : créer un pli confidentiel sur mutuelle FAR.':'Rappel : demander la création du pli confidentiel.',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)))])),
  ];
  List<Widget> _clinical()=>[
    _field('Motif de consultation',motive,hint:'Motif principal',maxLines:2),const SizedBox(height:12),
    _field('Interrogatoire / histoire de la maladie',history,maxLines:4),const SizedBox(height:12),
    _field('Examen clinique',exam,maxLines:4),const SizedBox(height:12),
    _field('Examens complémentaires',investigations,maxLines:3),const SizedBox(height:12),
    _field('Bilans biologiques',labs,maxLines:3),const SizedBox(height:12),
    _field('Conduite à tenir immédiate',plan,maxLines:3),
  ];
  List<Widget> _organization()=>[
    _picker('Intervention prévue',procedure,procedures,(v)=>setState((){procedure=v;if(v==procedures[0]||v==procedures[1]){length.text='1';admissionTiming='Le jour du bloc';}})),const SizedBox(height:16),
    const Overline('BLOC OPÉRATOIRE'),const SizedBox(height:9),_chips(['Immédiat','Différé'],blockTiming,(v)=>setState(()=>blockTiming=v)),
    if(blockTiming=='Différé')...[const SizedBox(height:10),VCard(onTap:_chooseBlockDate,child:Row(children:[const Icon(Icons.calendar_month_outlined),const SizedBox(width:12),Expanded(child:Text('Date et heure : ${_format(blockAt)}',style:const TextStyle(fontWeight:FontWeight.w700))),const Icon(Icons.edit_outlined,size:18)]))],
    const SizedBox(height:20),const Overline('DÉBUT D’HOSPITALISATION'),const SizedBox(height:9),_chips(['Immédiate','Le jour du bloc'],admissionTiming,(v)=>setState(()=>admissionTiming=v)),const SizedBox(height:19),
    _picker('Unité avant bloc',preUnit,hospitalUnits.map((u)=>u.code).toList(),(v)=>setState(()=>preUnit=v)),const SizedBox(height:12),_field('Numéro de box avant bloc',preBox,hint:'Ex. 03'),const SizedBox(height:20),
    _picker('Unité après bloc',postUnit,hospitalUnits.map((u)=>u.code).toList(),(v)=>setState(()=>postUnit=v)),const SizedBox(height:12),_field('Numéro de box après bloc',postBox,hint:'Ex. 08'),const SizedBox(height:20),
    _field('Durée prévisionnelle du séjour (jours)',length,number:true),const SizedBox(height:12),
    if(procedure==procedures[0]||procedure==procedures[1])const VCard(color:VColors.softMint,child:Text('Parcours standard proposé : hospitalisation le jour du bloc, J0–J1. À adapter selon l’état clinique, le protocole local et la décision du chirurgien.',style:TextStyle(fontSize:12.5))),
  ];
  List<Widget> _review()=>[
    _reviewBlock('PATIENT',['${name.text}  •  ${age.text.isEmpty?'Âge non renseigné':'${age.text} ans'}',origin,'Mutuelle : $insurance','Médecin responsable : ${appStore.responsibleById(selectedProfessorId)?.name??'À attribuer'}','Attribution : ${professorOverrideId!=null?'Manuelle':match.mode}',if(origin=='Consultation')'Consultation le ${_format(consultationAt)}']),
    const SizedBox(height:13),_reviewBlock('CLINIQUE',[motive.text,'Histoire : ${history.text.isEmpty?'À compléter':history.text}','CAT : ${plan.text.isEmpty?'À compléter':plan.text}']),
    const SizedBox(height:13),_reviewBlock('PARCOURS',[procedure,'Bloc : $blockTiming  •  ${_format(blockTiming=='Immédiat'?DateTime.now():blockAt)}','Hospitalisation : $admissionTiming','Avant : $preUnit • Box ${preBox.text}','Après : $postUnit • Box ${postBox.text}','Séjour estimé : ${length.text} jour(s)']),
    const SizedBox(height:15),DocumentChecklist(patient:_intakeDocs,title:'Documents à l’admission',requirements:ClinicalDocuments.admission),
    const SizedBox(height:15),VCard(color:VColors.orangeSoft,child:const Text('Les affectations de box sont prévisionnelles tant que le patient n’y est pas transféré. Toute sortie et toute prescription nécessitent une validation médicale.',style:TextStyle(fontSize:12))),
  ];
  Widget _reviewBlock(String title,List<String> lines)=>VCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Overline(title),const SizedBox(height:12),...lines.map((s)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Text(s,style:const TextStyle(fontSize:13))))]));
  Widget _field(String label,TextEditingController controller,{String? hint,int maxLines=1,bool number=false})=>maxLines>1 ? VoiceClinicalField(label:label,controller:controller,hint:hint,maxLines:maxLines) : TextField(controller:controller,maxLines:maxLines,keyboardType:number?TextInputType.number:TextInputType.text,decoration:InputDecoration(labelText:label,hintText:hint));
  Widget _picker(String label,String value,List<String> values,void Function(String) onValue)=>DropdownButtonFormField<String>(value:value,isExpanded:true,decoration:InputDecoration(labelText:label),items:values.map((v)=>DropdownMenuItem(value:v,child:Text(v,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v){if(v!=null)onValue(v);});
  Widget _chips(List<String> values,String selected,void Function(String) onValue)=>Wrap(spacing:9,runSpacing:8,children:values.map((v)=>ChoiceChip(label:Text(v),selected:selected==v,onSelected:(_)=>onValue(v),selectedColor:VColors.softMint,showCheckmark:false,labelStyle:TextStyle(color:VColors.ink,fontWeight:selected==v?FontWeight.w800:FontWeight.w500))).toList());
  Future<void> _chooseArrivalDate()async{
    final picked=await showDatePicker(context:context,initialDate:arrivalAt,firstDate:DateTime(2020),lastDate:DateTime(2100));
    if(picked==null||!mounted)return;
    final clock=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(arrivalAt));
    if(clock==null||!mounted)return;
    setState((){arrivalAt=DateTime(picked.year,picked.month,picked.day,clock.hour,clock.minute);professorOverrideId=null;assignmentReason.clear();});
  }
  Future<void> _chooseConsultationDate()async{
    final picked=await showDatePicker(context:context,initialDate:consultationAt,firstDate:DateTime(2020),lastDate:DateTime(2100));
    if(picked==null||!mounted)return;
    final clock=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(consultationAt));
    if(clock==null||!mounted)return;
    setState((){consultationAt=DateTime(picked.year,picked.month,picked.day,clock.hour,clock.minute);professorOverrideId=null;assignmentReason.clear();});
  }
  Future<void> _chooseBlockDate()async{
    final date=await showDatePicker(context:context,initialDate:blockAt,firstDate:DateTime(2020),lastDate:DateTime(2100));if(date==null||!mounted)return;
    final time=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(blockAt));if(time==null||!mounted)return;
    setState(()=>blockAt=DateTime(date.year,date.month,date.day,time.hour,time.minute));
  }
  String _format(DateTime d)=>'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} à ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}
