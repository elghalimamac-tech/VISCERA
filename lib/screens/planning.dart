import 'package:flutter/material.dart';
import '../planning_models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Référentiel de vacations et équipe — la planification personnelle des gardes et congés est dans PersonalPlanningPage.
class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});
  @override State<PlanningPage> createState()=>_PlanningPageState();
}
class _PlanningPageState extends State<PlanningPage> {
  DateTime month=DateTime(DateTime.now().year,DateTime.now().month);
  static const months=['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
  static const weekdays=['lun.','mar.','mer.','jeu.','ven.','sam.','dim.'];
  String when(DateTime d)=>'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  String time(DateTime d)=>'${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  void notice(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));

  Future<void> _chooseMonth() async {
    final picked = await showDatePicker(
      context:context, initialDate:month,
      firstDate:DateTime(2025,1), lastDate:DateTime(2032,12,31),
      helpText:'Choisir une date du mois à modifier',
    );
    if (picked != null) setState(() => month=DateTime(picked.year,picked.month));
  }

  @override Widget build(BuildContext context)=>DefaultTabController(length:2,child:Scaffold(
    appBar:AppBar(title:const Text('Consultations & équipe',style:TextStyle(fontWeight:FontWeight.w800)),backgroundColor:VColors.background,
      bottom:const TabBar(tabs:[Tab(text:'Consultations'),Tab(text:'Équipe')],labelColor:VColors.ink,indicatorColor:VColors.ink)),
    body:AnimatedBuilder(animation:appStore,builder:(context,_)=>TabBarView(children:[_vacations(),_team()])),
  ));

  Widget _duties(){
    final days=DateTime(month.year,month.month+1,0).day;
    final entries=List.generate(days,(i)=>appStore.dutyOn(DateTime(month.year,month.month,i+1)));
    final seniorCount=entries.where((d)=>d?.seniorName!=null).length;
    final juniorCount=entries.where((d)=>d?.juniorId!=null).length;
    return ListView(padding:const EdgeInsets.fromLTRB(18,18,18,32),children:[
      VCard(color:VColors.softMint,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Overline('PLANNING MENSUEL MODIFIABLE'),const SizedBox(height:8),
        const Text('Gardes seniors & juniors',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
        const SizedBox(height:12),
        Row(children:[
          IconButton(tooltip:'Mois précédent',onPressed:()=>setState(()=>month=DateTime(month.year,month.month-1)),icon:const Icon(Icons.chevron_left_rounded)),
          Expanded(child:InkWell(onTap:_chooseMonth,borderRadius:BorderRadius.circular(10),child:Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
            Flexible(child:Text('${months[month.month-1]} ${month.year}',textAlign:TextAlign.center,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800))),
            const SizedBox(width:6),const Icon(Icons.calendar_month_outlined,size:19)
          ])))),
          IconButton(tooltip:'Mois suivant',onPressed:()=>setState(()=>month=DateTime(month.year,month.month+1)),icon:const Icon(Icons.chevron_right_rounded)),
        ]),
        const SizedBox(height:8),
        Text('Seniors : $seniorCount/$days jours   ·   Juniors : $juniorCount/$days jours',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:VColors.ink)),
        const SizedBox(height:8),
        const Text('Astreintes = gardes : un seul planning. Les mêmes affectations sont visibles dans chaque tuile et le détail. Aucune garde aux urgences n’est créée.',style:TextStyle(fontSize:12,color:VColors.muted,height:1.5)),
      ])),
      const SizedBox(height:12),
      _monthTiles(days),
      const SizedBox(height:12),
      _leaveEditor(),
      const SizedBox(height:12),
      if(appStore.juniors.isEmpty)VCard(color:VColors.orangeSoft,child:const Text('Aucun résident dans l’annuaire. Ajoutez les juniors dans l’onglet Équipe pour pouvoir les programmer.',style:TextStyle(fontSize:12.5))),
      ...List.generate(days,(i){final d=DateTime(month.year,month.month,i+1),duty=appStore.dutyOn(d);
        final senior=appStore.seniorOnName(d) ?? 'À renseigner';
        final junior=appStore.juniorById(duty?.juniorId)?.name ?? 'À renseigner';
        final complete=duty?.seniorName!=null&&duty?.juniorId!=null;
        final leaveNames=appStore.leavesOn(d).map((l)=>l.doctorName).join(', ');
        return VCard(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(13),onTap:()=>_editDuty(d),child:Row(children:[
          Container(width:53,padding:const EdgeInsets.symmetric(vertical:7),decoration:BoxDecoration(color:complete?VColors.softMint:VColors.background,borderRadius:BorderRadius.circular(13)),child:Column(children:[Text('${d.day}',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800)),Text(weekdays[d.weekday-1],style:const TextStyle(fontSize:10,color:VColors.muted))])),
          const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Senior · $senior',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12.5,fontWeight:FontWeight.w700)),const SizedBox(height:5),Text('Junior · $junior',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,color:VColors.muted)),if(leaveNames.isNotEmpty)...[const SizedBox(height:5),Text('Congé : $leaveNames',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,color:Color(0xFF9A602E)))]])),
          const Icon(Icons.edit_calendar_outlined,color:VColors.ink,size:20),
        ]));
      }),
      const Text('Les mois futurs sont vierges et modifiables indépendamment. Octobre 2026 conserve son import initial tant que vous ne le changez pas. Heures de relève non définies.',style:TextStyle(fontSize:11,color:VColors.muted)),
    ]);
  }

  Widget _monthTiles(int days){
    final startPadding=(DateTime(month.year,month.month,1).weekday-1);
    return VCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Overline('TUILES · PLANNING UNIQUE'),const SizedBox(height:10),
      Row(children:[for(final w in weekdays) Expanded(child:Center(child:Text(w.substring(0,1).toUpperCase(),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:VColors.muted))))]),
      const SizedBox(height:7),
      GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:startPadding+days,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,childAspectRatio:0.57,crossAxisSpacing:4,mainAxisSpacing:4),itemBuilder:(ctx,index){
        if(index<startPadding)return const SizedBox.shrink();
        final d=DateTime(month.year,month.month,index-startPadding+1),g=appStore.dutyOn(d);
        final senior=appStore.seniorOnName(d)??'—',junior=appStore.juniorOn(d)?.name??'—';
        final isLeave=appStore.leavesOn(d).isNotEmpty;
        return InkWell(onTap:()=>_editDuty(d),borderRadius:BorderRadius.circular(8),child:Container(padding:const EdgeInsets.all(3),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:VColors.line),borderRadius:BorderRadius.circular(7)),child:Column(children:[
          Text('${d.day}',style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800)),
          const SizedBox(height:4),Text(senior,maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:const TextStyle(fontSize:8,color:VColors.ink,fontWeight:FontWeight.w800)),
          Text(junior,maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:const TextStyle(fontSize:8,color:VColors.muted)),
          if(isLeave)const Text('Congé',style:TextStyle(fontSize:8,color:Color(0xFFA05F2C),fontWeight:FontWeight.w800)),
        ])));
      }),const SizedBox(height:10),const Text('Touchez une tuile pour modifier la garde du jour. Les congés sont indiqués sans modifier automatiquement la garde.',style:TextStyle(fontSize:11,color:VColors.muted))
    ]));
  }

  Widget _leaveEditor(){
    final items=appStore.leaves.where((l)=>!l.end.isBefore(month) && l.start.isBefore(DateTime(month.year,month.month+1,1))).toList();
    return VCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Overline('CONGÉS · INFORMATION'),const SizedBox(height:8),
      const Text('Congés du service',style:TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
      const SizedBox(height:7),const Text('Enregistrer un congé pour l’afficher sur les tuiles. Aucune validation administrative n’est déclenchée.',style:TextStyle(fontSize:11,color:VColors.muted)),
      const SizedBox(height:8),FilledButton.icon(onPressed:_addLeave,icon:const Icon(Icons.add),label:const Text('Ajouter un congé')),
      ...items.map((l)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,title:Text(l.doctorName,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700)),subtitle:Text('${when(l.start)} → ${when(l.end)}'),trailing:IconButton(icon:const Icon(Icons.close),tooltip:'Supprimer le congé',onPressed:()=>appStore.removeLeave(l.id))))
    ]));
  }

  Future<void> _addLeave() async {
    final names=<String>{...appStore.seniorNames,...appStore.juniors.map((p)=>p.name)}.toList()..sort();
    if(names.isEmpty){notice('Ajoutez un médecin dans l’onglet Équipe.');return;}
    var doctor=names.first;
    var start=DateTime(month.year,month.month,1);
    var end=start;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>Padding(padding:EdgeInsets.fromLTRB(20,8,20,MediaQuery.of(ctx).viewInsets.bottom+30),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Ajouter un congé',style:Theme.of(ctx).textTheme.titleLarge),const SizedBox(height:15),
      DropdownButtonFormField<String>(value:doctor,isExpanded:true,decoration:const InputDecoration(labelText:'Médecin'),items:names.map((name)=>DropdownMenuItem(value:name,child:Text(name))).toList(),onChanged:(v){if(v!=null)refresh(()=>doctor=v);}),
      const SizedBox(height:13),
      OutlinedButton(onPressed:()async{final pick=await showDatePicker(context:ctx,initialDate:start,firstDate:DateTime(2025),lastDate:DateTime(2032,12,31));if(pick!=null)refresh((){start=pick;if(end.isBefore(start))end=start;});},child:Text('Début : ${when(start)}')),
      OutlinedButton(onPressed:()async{final pick=await showDatePicker(context:ctx,initialDate:end,firstDate:start,lastDate:DateTime(2032,12,31));if(pick!=null)refresh(()=>end=pick);},child:Text('Fin : ${when(end)}')),
      const SizedBox(height:13),SizedBox(width:double.infinity,child:ElevatedButton(onPressed:(){if(appStore.addLeave(doctorName:doctor,start:start,end:end)){Navigator.pop(ctx);notice('Congé signalé sur le planning');}},child:const Text('Ajouter au planning')))
    ]))));
  }

  Future<void> _editDuty(DateTime date) async {
    final existing=appStore.dutyOn(date);
    String? senior=existing?.seniorName,junior=existing?.juniorId;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>Padding(
      padding:EdgeInsets.fromLTRB(20,8,20,MediaQuery.of(ctx).viewInsets.bottom+24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Garde du ${when(date)}',style:Theme.of(ctx).textTheme.titleLarge),const SizedBox(height:9),const Text('Choisissez le junior et le senior pour cette garde de service. Sans règles automatiques d’échange ou d’approbation.',style:TextStyle(fontSize:12,color:VColors.muted)),const SizedBox(height:20),
      DropdownButtonFormField<String>(value:senior??'',isExpanded:true,decoration:const InputDecoration(labelText:'Médecin senior de garde'),items:[const DropdownMenuItem(value:'',child:Text('Non renseigné')),...appStore.seniorNames.map((name)=>DropdownMenuItem(value:name,child:Text(name,overflow:TextOverflow.ellipsis)))],onChanged:(v)=>update(()=>senior=v)),const SizedBox(height:13),
      DropdownButtonFormField<String>(value:junior,isExpanded:true,decoration:const InputDecoration(labelText:'Junior de garde'),items:[const DropdownMenuItem(value:'',child:Text('Non renseigné')),...appStore.juniors.map((p)=>DropdownMenuItem(value:p.id,child:Text(p.name,overflow:TextOverflow.ellipsis)))],onChanged:(v)=>update(()=>junior=v)),const SizedBox(height:20),
      SizedBox(width:double.infinity,child:ElevatedButton(onPressed:(){appStore.setDuty(date,juniorId:junior==''?null:junior,seniorName:senior==''?null:senior);Navigator.pop(ctx);notice('Garde enregistrée pour le ${when(date)}');},child:const Text('Enregistrer cette journée'))),
    ]))));
  }

  Widget _vacations()=>ListView(padding:const EdgeInsets.fromLTRB(18,22,18,32),children:[
    Text('Vacations de consultation',style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:7),
    const Text('Vacations datées et planning de référence. L’attribution du patient repose sur l’heure réelle de sa consultation.',style:TextStyle(fontSize:12.5,color:VColors.muted)),
    const SizedBox(height:14),
    VCard(color:VColors.softMint,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Overline('HUIM6 BOUSKOURA · GRILLE ANNUELLE CONFIRMÉE'),
      const SizedBox(height:7),
      const Text('Consultations · toute l’année',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
      const SizedBox(height:7),
      const Text('Planning récurrent chaque semaine : 9h–13h et 14h–19h. Les Dr BENGHAIT et Dr LAABOULI ainsi que le médecin de garde du samedi nécessitent la confirmation du professeur responsable.',style:TextStyle(fontSize:11.5,color:VColors.muted)),
      const SizedBox(height:11),
      ...List.generate(6,(index){
        final day=index+1;
        final parts=weeklyVisceralConsultations.where((slot)=>slot.weekday==day).toList();
        return Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(weekdays[index].toUpperCase(),style:const TextStyle(fontWeight:FontWeight.w800,fontSize:11)),
          const SizedBox(height:3),
          Text('09–13h  ${parts[0].consultantName}   ·   14–19h  ${parts[1].consultantName}',style:const TextStyle(fontSize:11.5)),
        ]));
      }),
      const SizedBox(height:9),
      const Text('Confirmé par le service : valable toute l’année, sauf changement ou remplacement ponctuel.',style:TextStyle(fontWeight:FontWeight.w700,fontSize:11.5,color:VColors.ink)),
    ])),
    const SizedBox(height:13),ElevatedButton.icon(onPressed:_addVacation,icon:const Icon(Icons.add_rounded),label:const Text('Ajouter une vacation')),
    const SizedBox(height:12),
    if(appStore.vacations.isEmpty)const VCard(child:Text('Aucune exception datée ajoutée. La grille hebdomadaire reste applicable toute l’année.')),
    ...appStore.vacations.map((v)=>VCard(margin:const EdgeInsets.only(bottom:9),child:Row(children:[const Icon(Icons.event_available_outlined,color:VColors.ink),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(appStore.professorById(v.professorId)?.name??'Professeur non trouvé',style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:5),Text('${when(v.start)}   ·   ${time(v.start)}–${time(v.end)}',style:const TextStyle(fontSize:12,color:VColors.muted))])),IconButton(tooltip:'Supprimer la vacation',onPressed:() async {if(await showConfirmation(context,title:'Supprimer cette vacation ?',message:'Les dossiers déjà attribués ne seront pas modifiés.',action:'Supprimer'))appStore.deleteVacation(v.id);},icon:const Icon(Icons.delete_outline,color:VColors.muted))]))),
    const SizedBox(height:14),const Text('Si deux professeurs ont une vacation qui se chevauche, l’application signale un conflit et ne choisit pas automatiquement.',style:TextStyle(fontSize:11.5,color:VColors.muted)),
  ]);

  Future<void> _addVacation() async {
    if(appStore.professors.isEmpty){notice('Ajoutez d’abord un professeur dans l’onglet Équipe.');return;}
    DateTime date=DateTime.now();TimeOfDay start=const TimeOfDay(hour:9,minute:0),end=const TimeOfDay(hour:13,minute:0);
    String professorId=appStore.professors.first.id;
    await showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
      String display(TimeOfDay t)=>'${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
      return Padding(padding:EdgeInsets.fromLTRB(20,6,20,MediaQuery.of(ctx).viewInsets.bottom+24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Nouvelle vacation',style:Theme.of(ctx).textTheme.titleLarge),const SizedBox(height:19),
        DropdownButtonFormField<String>(value:professorId,isExpanded:true,decoration:const InputDecoration(labelText:'Professeur consultant'),items:appStore.professors.map((p)=>DropdownMenuItem(value:p.id,child:Text(p.name,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>update(()=>professorId=v!)),
        const SizedBox(height:12),VCard(onTap:() async {final picked=await showDatePicker(context:ctx,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime(2100));if(picked!=null)update(()=>date=picked);},child:Row(children:[const Icon(Icons.calendar_month_outlined),const SizedBox(width:11),Text('Date : ${when(date)}')])) ,
        Row(children:[Expanded(child:VCard(onTap:() async {final t=await showTimePicker(context:ctx,initialTime:start);if(t!=null)update(()=>start=t);},child:Text('Début : ${display(start)}'))),const SizedBox(width:10),Expanded(child:VCard(onTap:() async {final t=await showTimePicker(context:ctx,initialTime:end);if(t!=null)update(()=>end=t);},child:Text('Fin : ${display(end)}')))]),const SizedBox(height:16),
        SizedBox(width:double.infinity,child:ElevatedButton(onPressed:(){final a=DateTime(date.year,date.month,date.day,start.hour,start.minute),b=DateTime(date.year,date.month,date.day,end.hour,end.minute);if(!appStore.addVacation(professorId:professorId,start:a,end:b)){notice('Vérifiez les heures : la fin doit être postérieure au début.');return;}Navigator.pop(ctx);},child:const Text('Enregistrer la vacation'))),
      ]));
    }));
  }

  Widget _team()=>ListView(padding:const EdgeInsets.fromLTRB(18,21,18,32),children:[
    Text('Annuaire du service',style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:7),
    const Text('Quatre professeurs de la grille annuelle sont préremplis. Complétez les autres noms ; les juniors restent à renseigner.',style:TextStyle(color:VColors.muted,fontSize:12.5)),
    SectionHeading('Professeurs',trailing:TextButton.icon(onPressed:()=>_addMember(professor:true),icon:const Icon(Icons.add,size:18),label:const Text('Ajouter'))),
    if(appStore.professors.isEmpty)const VCard(child:Text('Aucun professeur enregistré.')),
    ...appStore.professors.map((p)=>VCard(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(13),child:Row(children:[const CircleAvatar(backgroundColor:VColors.softMint,child:Icon(Icons.school_outlined,color:VColors.ink)),const SizedBox(width:12),Expanded(child:Text(p.name,style:const TextStyle(fontWeight:FontWeight.w700)))]))),
    const SizedBox(height:12),SectionHeading('Autres médecins consultants (grille annuelle)'),
    ...referenceConsultationDoctors.map((name)=>VCard(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),child:Text(name,style:const TextStyle(fontWeight:FontWeight.w700)))),
    SectionHeading('Médecins seniors (astreintes octobre 2026)',trailing:TextButton.icon(onPressed:()=>_addSenior(),icon:const Icon(Icons.add,size:18),label:const Text('Ajouter'))),
    ...appStore.seniorNames.map((name)=>VCard(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(13),child:Row(children:[const CircleAvatar(backgroundColor:VColors.softMint,child:Icon(Icons.medical_services_outlined,color:VColors.ink)),const SizedBox(width:12),Expanded(child:Text(name,style:const TextStyle(fontWeight:FontWeight.w700)))]))),
    SectionHeading('Juniors',trailing:TextButton.icon(onPressed:()=>_addMember(professor:false),icon:const Icon(Icons.add,size:18),label:const Text('Ajouter'))),
    if(appStore.juniors.isEmpty)const VCard(child:Text('Aucun junior enregistré.')),
    ...appStore.juniors.map((p)=>VCard(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(13),child:Row(children:[const CircleAvatar(backgroundColor:VColors.softMint,child:Icon(Icons.person_outline,color:VColors.ink)),const SizedBox(width:12),Expanded(child:Text(p.name,style:const TextStyle(fontWeight:FontWeight.w700)))]))),
  ]);

  Future<void> _addSenior() async {
    final controller=TextEditingController();
    final name=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Ajouter un médecin senior'),content:TextField(controller:controller,autofocus:true,decoration:const InputDecoration(labelText:'Nom du médecin')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text),child:const Text('Ajouter'))]));
    controller.dispose();if(!mounted||name==null)return;
    if(!appStore.addSenior(name))notice('Nom vide ou déjà enregistré.');
  }

  Future<void> _addMember({required bool professor}) async {
    final controller=TextEditingController();
    final name=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:Text(professor?'Ajouter un professeur':'Ajouter un junior'),content:TextField(controller:controller,autofocus:true,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Nom et prénom')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text),child:const Text('Ajouter'))]));
    controller.dispose(); if(!mounted||name==null)return;
    final ok=professor?appStore.addProfessor(name):appStore.addJunior(name);
    if(!ok)notice('Nom vide ou déjà enregistré.');
  }
}
