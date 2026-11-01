import 'package:flutter/material.dart';
import '../models.dart';
import '../document_checklist.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'discharge.dart';
import 'daily_observations.dart';
import '../voice_dictation.dart';

class PatientDetailPage extends StatefulWidget {
  const PatientDetailPage({super.key,required this.patient});
  final PatientCase patient;
  @override State<PatientDetailPage> createState()=>_PatientDetailPageState();
}
class _PatientDetailPageState extends State<PatientDetailPage> {
  PatientCase get p=>widget.patient;
  void _openObservations()=>Navigator.push(
    context,MaterialPageRoute(builder:(_)=>DailyObservationsPage(patient:p)));

  @override
  Widget build(BuildContext context)=>AnimatedBuilder(
    animation:appStore,
    builder:(context,_)=>Scaffold(
      appBar:AppBar(
        title:const Text('Dossier patient',style:TextStyle(fontWeight:FontWeight.w800)),
        backgroundColor:VColors.background,surfaceTintColor:Colors.transparent,
      ),
      // Point d'entrée clinique accessible à tout moment pendant le séjour.
      floatingActionButton:(p.isActive||p.isProgrammed)?FloatingActionButton.extended(
        heroTag:'observation-${p.id}',
        backgroundColor:VColors.ink,foregroundColor:Colors.white,
        icon:const Icon(Icons.add_rounded),
        label:const Text('Observation clinique',
          style:TextStyle(fontWeight:FontWeight.w700)),
        tooltip:'Ajouter une observation clinique à ce dossier',
        onPressed:()=>showClinicalObservationEditor(context,p),
      ):null,
      floatingActionButtonLocation:FloatingActionButtonLocation.endFloat,
      body:ListView(
        padding:const EdgeInsets.fromLTRB(18,14,18,120),
        children:[
          VCard(color:VColors.ink,padding:const EdgeInsets.all(18),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                Expanded(child:Text(p.id,style:const TextStyle(
                  color:VColors.mint,fontSize:11,fontWeight:FontWeight.w700,letterSpacing:1.2))),
                const Icon(Icons.folder_shared_outlined,color:VColors.mint,size:20),
              ]),
              const SizedBox(height:8),
              Text(p.name,style:const TextStyle(color:Colors.white,fontSize:23,
                fontWeight:FontWeight.w800)),
              const SizedBox(height:5),
              Text('${p.age == '—' ? 'Âge non renseigné' : '${p.age} ans'} · ${p.origin}',style:const TextStyle(
                color:Color(0xFFD8EAE4),fontSize:13)),
              const SizedBox(height:13),
              Wrap(spacing:7,runSpacing:7,children:[
                VTag(p.stage.label,highlight:true),
                VTag(p.insurance),
                if(p.blockTiming=='Immédiat')const VTag('Bloc immédiat',warn:true),
              ]),
            ])),
          if(p.fromBlocProgram)...[
            const SizedBox(height:11),
            VCard(color:VColors.softMint,child:Row(children:[
              const Icon(Icons.cloud_done_outlined,color:VColors.ink),
              const SizedBox(width:10),
              Expanded(child:Text(appStore.clinicalSyncState(p),
                style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
              IconButton(
                tooltip:'Enregistrer le dossier dans VISCERA',
                onPressed:() async{
                  try{
                    await appStore.saveClinical(p);
                    if(mounted)_notice('Dossier enregistré dans VISCERA.');
                  }catch(_){
                    if(mounted)_notice('Enregistrement impossible. Actualisez et vérifiez les modifications.');
                  }
                },
                icon:const Icon(Icons.save_outlined)),
            ])),
            if(p.isProgrammed)...[
              const SizedBox(height:10),
              VCard(color:VColors.orangeSoft,child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('Patient programmé · Provenance Consultation',
                  style:TextStyle(fontWeight:FontWeight.w800)),
                const SizedBox(height:7),
                Text(p.blockAt.isBefore(DateTime(DateTime.now().year,DateTime.now().month,DateTime.now().day))
                  ? 'Programmation antérieure : le devenir clinique doit être vérifié. Aucune admission n’est présumée.'
                  : 'Le programme opératoire ne confirme pas une admission hospitalière. Le dossier est modifiable avant admission ; aucun lit ou séjour n’est supposé.',
                  style:TextStyle(fontSize:12)),
                const SizedBox(height:12),
                FilledButton.icon(onPressed:_confirmAdmission,
                  icon:const Icon(Icons.how_to_reg_outlined),
                  label:const Text('Confirmer l’admission réelle')),
              ])),
            ],
          ],
          const SizedBox(height:11),
          Row(children:[
            Expanded(child:_factCard(Icons.bed_outlined,'Unité / box',
              p.currentUnit.isEmpty || p.currentBox.isEmpty ? 'Non attribué' : '${p.currentUnit} · ${p.currentBox}')),
            const SizedBox(width:9),
            Expanded(child:_factCard(Icons.person_outline_rounded,'Responsable',
              appStore.responsibleById(p.professorId)?.name??(p.programSurgeon.isNotEmpty ? p.programSurgeon : 'À attribuer'))),
          ]),
          if(p.dischargeDue||p.stage==CaseStage.dischargeReady)...[
            const SizedBox(height:11),
            VCard(color:VColors.orangeSoft,padding:const EdgeInsets.all(14),
              child:const Row(children:[
                Icon(Icons.notifications_active_outlined,color:Color(0xFFA45633)),
                SizedBox(width:10),
                Expanded(child:Text('Sortie potentielle : évaluation et validation médicales nécessaires.',
                  style:TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
              ])),
          ],
          SectionHeading('Suivi clinique',trailing:TextButton.icon(
            onPressed:_openObservations,icon:const Icon(Icons.history_rounded,size:17),
            label:const Text('Historique'))),
          VCard(color:VColors.softMint,padding:const EdgeInsets.all(16),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                const Icon(Icons.monitor_heart_outlined,color:VColors.ink,size:22),
                const SizedBox(width:10),
                Expanded(child:Text(
                  '${p.dailyObservations.length} observation(s) clinique(s)',
                  style:const TextStyle(fontWeight:FontWeight.w800,fontSize:15))),
              ]),
              const SizedBox(height:8),
              Text(p.dailyObservations.isEmpty
                ? 'Aucune observation enregistrée pour ce séjour.'
                : 'Dernière observation : ${_date(p.dailyObservations.first.date)}',
                style:const TextStyle(fontSize:12.5,color:VColors.muted)),
              const SizedBox(height:4),
              Text('${p.dailyObservations.where((o)=>!o.fullyReported).length} en attente de report Magica/Sillage',
                style:const TextStyle(fontSize:12.5,color:VColors.muted)),
              const SizedBox(height:10),
              TextButton.icon(onPressed:_openObservations,
                icon:const Icon(Icons.visibility_outlined,size:18),
                label:const Text('Consulter les observations')),
            ])),
          SectionHeading('Dossier clinique',trailing:Row(children:[
            IconButton(onPressed:_editIdentity,tooltip:'Modifier identité et couverture',
              icon:const Icon(Icons.badge_outlined)),
            TextButton.icon(onPressed:_editClinical,
              icon:const Icon(Icons.edit_outlined,size:16),
              label:const Text('Modifier'))])),
          VCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            _clinical('Motif de prise en charge',p.motive),
            const Divider(height:1,color:VColors.line),
            ExpansionTile(
              initiallyExpanded:false,tilePadding:EdgeInsets.zero,
              childrenPadding:const EdgeInsets.only(top:10),
              title:const Text('Voir le dossier clinique détaillé',
                style:TextStyle(fontSize:13,fontWeight:FontWeight.w800,color:VColors.ink)),
              children:[
                _clinical('Interrogatoire',p.history),
                _clinical('Examen clinique',p.exam),
                _clinical('Examens complémentaires',p.investigations),
                _clinical('Bilans',p.labs),
                _clinical('Conduite à tenir immédiate',p.immediatePlan),
              ],
            ),
          ])),
          SectionHeading('Parcours hospitalier'),
          VCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            _line(Icons.login_rounded,'Admission',p.admissionTiming),
            if(p.consultationAt!=null)...[
              const Divider(height:22),
              _line(Icons.event_outlined,'Consultation',_format(p.consultationAt!)),
            ],
            const Divider(height:22),
            _line(Icons.medical_services_outlined,'Médecin responsable',
              appStore.responsibleById(p.professorId)?.name??(p.programSurgeon.isNotEmpty ? p.programSurgeon : 'À attribuer')),
            const SizedBox(height:5),
            Text('${p.assignmentMode} · ${p.assignmentExplanation}',
              style:const TextStyle(fontSize:11,color:VColors.muted)),
            const SizedBox(height:8),
            OutlinedButton.icon(onPressed:_changeProfessor,
              icon:const Icon(Icons.manage_accounts_outlined,size:17),
              label:const Text('Modifier le responsable')),
            const Divider(height:22),
            _line(Icons.medical_services_outlined,'Bloc',
              '${p.procedure}\n${_format(p.blockAt)} · ${p.blockTiming}'),
            const Divider(height:22),
            _line(Icons.bed_outlined,'Avant le bloc',p.beforeBox.isEmpty ? 'Non attribué' : '${p.beforeUnit} · Box ${p.beforeBox}'),
            const Divider(height:22),
            _line(Icons.bed_outlined,'Après le bloc',p.afterBox.isEmpty ? 'Non attribué' : '${p.afterUnit} · Box ${p.afterBox}'),
            const Divider(height:22),
            _line(Icons.event_available_outlined,'Sortie estimée',
              p.expectedDays == 0 ? 'Non renseignée' : '${_date(p.expectedDischargeAt)} · ${p.expectedDays} jour(s)'),
            const SizedBox(height:12),
            OutlinedButton.icon(onPressed:_changeBed,
              icon:const Icon(Icons.edit_location_alt_outlined,size:18),
              label:const Text('Modifier l’affectation')),
          ])),
          SectionHeading('Documents et vérifications'),
          DocumentChecklist(patient:p,title:'Documents à l’admission',
            requirements:ClinicalDocuments.admission),
          if(p.stage==CaseStage.inTheatre || p.isPostOp ||
            p.stage==CaseStage.discharged)...[
            const SizedBox(height:12),
            DocumentChecklist(patient:p,title:'Vérifications postopératoires',
              requirements:ClinicalDocuments.postBlock,
              readOnly:p.stage==CaseStage.discharged),
          ],
          SectionHeading('Actions de prise en charge'),
          _actions(),
          if(p.stage==CaseStage.discharged)...[
            const SizedBox(height:12),
            VCard(color:VColors.softMint,child:Text(
              'Sortie validée le ${_format(p.dischargeAt!)}. Dossier de sortie archivé.')),
          ],
        ],
      ),
    ),
  );

  Widget _factCard(IconData icon,String label,String value)=>VCard(
    padding:const EdgeInsets.all(13),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:VColors.ink,size:20),
      const SizedBox(height:7),
      Text(label,style:const TextStyle(fontSize:11,color:VColors.muted)),
      const SizedBox(height:4),
      Text(value,maxLines:2,overflow:TextOverflow.ellipsis,
        style:const TextStyle(fontSize:12.5,fontWeight:FontWeight.w800,color:VColors.ink)),
    ]),
  );

  Widget _line(IconData icon,String label,String value)=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:VColors.muted,size:18),const SizedBox(width:11),SizedBox(width:90,child:Text(label,style:const TextStyle(fontSize:12,color:VColors.muted))),Expanded(child:Text(value,style:const TextStyle(fontSize:12.8,fontWeight:FontWeight.w700)))]);
  Widget _clinical(String label,String value)=>Padding(padding:const EdgeInsets.only(bottom:17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Overline(label),const SizedBox(height:5),Text(value.trim().isEmpty?'Non renseigné':value,style:TextStyle(fontSize:13,color:value.trim().isEmpty?VColors.muted:VColors.ink))]));
  Widget _envelope()=>VCard(color:p.confidentialEnvelopeDone?VColors.softMint:VColors.orangeSoft,child:Row(children:[Icon(p.confidentialEnvelopeDone?Icons.check_circle_outline_rounded:Icons.mark_email_unread_outlined,color:VColors.ink),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.isFar?'Pli confidentiel — FAR':'Pli confidentiel',style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:3),Text(p.confidentialEnvelopeDone?'Marqué comme effectué':'À créer / à demander',style:const TextStyle(fontSize:12,color:VColors.muted))])),Switch(value:p.confidentialEnvelopeDone,onChanged:(_)=>appStore.toggleEnvelope(p))]));
  Widget _actions()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    if(p.stage==CaseStage.scheduled)ElevatedButton.icon(onPressed:_confirmAdmission,icon:const Icon(Icons.how_to_reg_outlined),label:const Text('Confirmer l’admission avant le bloc')),
    if(p.stage==CaseStage.preoperative)ElevatedButton.icon(onPressed:_startTheatre,icon:const Icon(Icons.medical_services_outlined),label:const Text('Confirmer l’entrée au bloc')),
    if(p.stage==CaseStage.inTheatre)ElevatedButton.icon(onPressed:_finishTheatre,icon:const Icon(Icons.check_rounded),label:const Text('Fin du bloc → postopératoire')),
    if(p.stage==CaseStage.postoperative)ElevatedButton.icon(onPressed:()=>appStore.markForDischarge(p),icon:const Icon(Icons.assignment_turned_in_outlined),label:const Text('Préparer la sortie')),
    if(p.stage==CaseStage.dischargeReady)ElevatedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>DischargePage(patient:p))),icon:const Icon(Icons.description_outlined),label:const Text('Documents et validation de sortie')),
    if(p.stage==CaseStage.discharged)OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>DischargePage(patient:p,readOnly:true))),icon:const Icon(Icons.file_open_outlined),label:const Text('Consulter les documents de sortie')),
  ]);
  Future<void> _changeProfessor() async {
    if(appStore.responsibleOptions(forEmergencies:p.origin=='Urgences').isEmpty){_notice('Ajoutez d’abord les médecins au planning.');return;}
    String? selected=p.professorId;
    final reason=TextEditingController();
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>Padding(
      padding:EdgeInsets.fromLTRB(20,8,20,MediaQuery.of(ctx).viewInsets.bottom+22),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Médecin responsable',style:Theme.of(ctx).textTheme.titleLarge),const SizedBox(height:16),
        DropdownButtonFormField<String>(value:appStore.responsibleById(selected)!=null?selected:null,isExpanded:true,decoration:const InputDecoration(labelText:'Médecin responsable'),items:appStore.responsibleOptions(forEmergencies:p.origin=='Urgences').map((x)=>DropdownMenuItem(value:x.id,child:Text(x.name,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>update(()=>selected=v)),const SizedBox(height:12),
        TextField(controller:reason,maxLines:2,decoration:const InputDecoration(labelText:'Motif du changement (obligatoire)')),
        const SizedBox(height:14),SizedBox(width:double.infinity,child:ElevatedButton(onPressed:(){if(selected==null||reason.text.trim().isEmpty){_notice('Sélectionnez un médecin et renseignez le motif.');return;}appStore.changeProfessor(p,selected!,reason.text);Navigator.pop(ctx);},child:const Text('Enregistrer la modification'))),
      ]))));
    reason.dispose();
  }
  Future<void> _startTheatre() async {
    if(await showConfirmation(context,title:'Entrée au bloc',message:'Confirmer l’entrée au bloc de ${p.name} ?',action:'Valider'))appStore.startTheatre(p);
  }
  Future<void> _finishTheatre() async {
    final conflict=appStore.conflictingBox(p.afterUnit,p.afterBox,exceptPatientId:p.id);
    if(conflict!=null){_notice('Box postopératoire occupé par ${conflict.name}. Modifiez l’affectation avant de confirmer.');return;}
    if(await showConfirmation(context,title:'Fin du bloc',message:'Retour prévu à ${p.afterUnit} / Box ${p.afterBox}. Les documents manquants resteront signalés dans le dossier postopératoire.',action:'Valider'))appStore.finishTheatre(p);
  }
  void _notice(String text)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
  Future<void> _changeBed() async {
    final postoperative=p.isPostOp||p.stage==CaseStage.inTheatre;
    String current=postoperative?p.afterUnit:p.beforeUnit;
    final controller=TextEditingController(text:postoperative?p.afterBox:p.beforeBox);
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(sheetContext)=>StatefulBuilder(builder:(sheetContext,refresh)=>Padding(padding:EdgeInsets.fromLTRB(22,8,22,MediaQuery.of(sheetContext).viewInsets.bottom+25),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(postoperative?'Modifier l’unité postopératoire':'Modifier l’unité préopératoire',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:15),DropdownButtonFormField<String>(value:hospitalUnits.any((u)=>u.code==current)?current:null,decoration:const InputDecoration(labelText:'Unité'),items:hospitalUnits.map((u)=>DropdownMenuItem(value:u.code,child:Text(u.code))).toList(),onChanged:(v)=>refresh(()=>current=v!)),const SizedBox(height:13),TextField(controller:controller,decoration:const InputDecoration(labelText:'Numéro du box')),const SizedBox(height:17),SizedBox(width:double.infinity,child:ElevatedButton(onPressed:(){if(current.isEmpty||controller.text.trim().isEmpty){_notice('Précisez l’unité et le numéro de box.');return;}final conflicting=appStore.conflictingBox(current,controller.text,exceptPatientId:p.id);if(conflicting!=null){_notice('Box déjà occupé par ${conflicting.name}.');return;}if(postoperative){p.afterUnit=current;p.afterBox=controller.text.trim();}else{p.beforeUnit=current;p.beforeBox=controller.text.trim();}appStore.refresh(changed:p);Navigator.pop(sheetContext);},child:const Text('Enregistrer l’affectation'))),
    ]))));
    controller.dispose();
  }

  Future<void> _editIdentity() async {
    final age = TextEditingController(text:p.age == '—' ? '' : p.age);
    final insurance = TextEditingController(
      text:p.insurance == 'À préciser' ? '' : p.insurance);
    final days = TextEditingController(
      text:p.expectedDays == 0 ? '' : p.expectedDays.toString());
    DateTime? consultation = p.consultationAt;
    await showModalBottomSheet<void>(
      context:context, isScrollControlled:true, showDragHandle:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>Padding(
        padding:EdgeInsets.fromLTRB(20,10,20,MediaQuery.of(ctx).viewInsets.bottom+24),
        child:ConstrainedBox(
          constraints:BoxConstraints(maxHeight:MediaQuery.of(ctx).size.height*.75),
          child:SingleChildScrollView(child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              const Text('Compléter le dossier patient',
                style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
              const SizedBox(height:6),
              const Text('Provenance : Consultation. Le nom et l’intervention du programme officiel ne sont pas modifiés.',
                style:TextStyle(fontSize:12,color:VColors.muted)),
              const SizedBox(height:16),
              TextField(controller:age,keyboardType:TextInputType.number,
                decoration:const InputDecoration(labelText:'Âge (si connu)')),
              const SizedBox(height:10),
              TextField(controller:insurance,
                decoration:const InputDecoration(labelText:'Mutuelle / assurance (si connue)')),
              const SizedBox(height:10),
              TextField(controller:days,keyboardType:TextInputType.number,
                decoration:const InputDecoration(labelText:'Durée prévisionnelle (jours, si connue)')),
              const SizedBox(height:10),
              OutlinedButton.icon(
                icon:const Icon(Icons.calendar_month),
                label:Text(consultation==null?'Renseigner la date de consultation':
                  'Consultation : ${_date(consultation!)}'),
                onPressed:() async{
                  final picked=await showDatePicker(context:ctx,
                    initialDate:consultation??DateTime.now(),
                    firstDate:DateTime(2020),lastDate:DateTime(2100));
                  if(picked!=null) refresh(()=>consultation=picked);
                }),
              const SizedBox(height:16),
              SizedBox(width:double.infinity,child:FilledButton(
                onPressed:(){
                  final parsedAge=int.tryParse(age.text.trim());
                  final parsedDays=days.text.trim().isEmpty?0:int.tryParse(days.text.trim());
                  if((age.text.trim().isNotEmpty &&
                      (parsedAge==null || parsedAge<0 || parsedAge>130))
                    || parsedDays==null || parsedDays<0 || parsedDays>365){
                    _notice('Vérifiez l’âge et la durée prévisionnelle.');return;
                  }
                  p.age=age.text.trim().isEmpty?'—':age.text.trim();
                  p.insurance=insurance.text.trim().isEmpty?'À préciser':insurance.text.trim();
                  p.expectedDays=parsedDays;
                  p.consultationAt=consultation;
                  appStore.refresh(changed:p);
                  Navigator.pop(ctx);
                },child:const Text('Enregistrer les informations'))),
            ],
          )),
        ),
      )));
    age.dispose();insurance.dispose();days.dispose();
  }

  Future<void> _confirmAdmission() async {
    if(!p.isProgrammed) return;
    final today=DateTime.now();
    final day=await showDatePicker(context:context,initialDate:today,
      firstDate:DateTime(2020),lastDate:today);
    if(day==null || !mounted) return;
    final clock=await showTimePicker(context:context,
      initialTime:TimeOfDay.fromDateTime(today));
    if(clock==null || !mounted)return;
    final arrival=DateTime(day.year,day.month,day.day,clock.hour,clock.minute);
    if(arrival.isAfter(DateTime.now().add(const Duration(minutes:1)))){
      _notice('L’heure d’admission ne peut pas être future.');return;
    }
    final confirmed=await showConfirmation(context,
      title:'Confirmer l’admission hospitalière',
      message:'Avez-vous vérifié l’admission réelle de ${p.name} le ${_format(arrival)} ? '
        'Cette validation activera le suivi préopératoire. Aucun box ne sera attribué automatiquement.',
      action:'Confirmer l’admission');
    if(!confirmed)return;
    p.admittedAt=arrival;
    p.admissionTiming='Confirmée';
    p.stage=CaseStage.preoperative;
    appStore.refresh(changed:p);
  }

  Future<void> _editClinical() async {
    final controllers=[p.motive,p.history,p.exam,p.investigations,p.labs,p.immediatePlan].map((value) => TextEditingController(text: value)).toList();
    final labels=['Motif','Histoire de la maladie','Examen clinique','Examens complémentaires','Bilans','Conduite à tenir immédiate'];
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(sheetContext)=>Padding(padding:EdgeInsets.fromLTRB(20,8,20,MediaQuery.of(sheetContext).viewInsets.bottom+12),child:FlexibleClinicalEditor(controllers:controllers,labels:labels,onSave:(){p.motive=controllers[0].text;p.history=controllers[1].text;p.exam=controllers[2].text;p.investigations=controllers[3].text;p.labs=controllers[4].text;p.immediatePlan=controllers[5].text;appStore.refresh(changed:p);Navigator.pop(sheetContext);})));for(final c in controllers){c.dispose();}
  }
  String _date(DateTime d)=>'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  String _format(DateTime d)=>'${_date(d)} à ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

class FlexibleClinicalEditor extends StatelessWidget {
  const FlexibleClinicalEditor({super.key,required this.controllers,required this.labels,required this.onSave});
  final List<TextEditingController> controllers; final List<String> labels;final VoidCallback onSave;
  @override Widget build(BuildContext context)=>SizedBox(height:MediaQuery.of(context).size.height*.68,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Modifier le dossier',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:15),Expanded(child:ListView(children:List.generate(controllers.length,(i)=>Padding(padding:const EdgeInsets.only(bottom:12),child:VoiceClinicalField(controller:controllers[i],label:labels[i],maxLines:i==0?2:4))))),const SizedBox(height:8),SizedBox(width:double.infinity,child:ElevatedButton(onPressed:onSave,child:const Text('Enregistrer les modifications')))]));
}
