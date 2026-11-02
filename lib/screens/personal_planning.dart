import '../branding.dart';
import 'package:flutter/material.dart';
import '../store.dart';
import '../planning_models.dart';
import '../duty_reminders.dart';
import 'notification_settings.dart';

/// Calendrier personnel : garde de service 24H et congé.
class PersonalPlanningPage extends StatefulWidget {
  const PersonalPlanningPage({super.key});

  @override
  State<PersonalPlanningPage> createState() => _PersonalPlanningPageState();
}

class _PlanningTile {
  const _PlanningTile(this.kind,{this.from});
  final String kind; // garde de service 24H ou congé
  final DateTime? from;
}

class _PersonalPlanningPageState extends State<PersonalPlanningPage> {
  DateTime month=DateTime(DateTime.now().year,DateTime.now().month);
  _PlanningTile selected=const _PlanningTile('garde');
  final Map<int,String?> draft = {};
  bool saving = false;

  static const deep=Color(0xFF103F36);
  static const teal=Color(0xFF187A70);
  static const muted=Color(0xFF647973);
  static const paper=Color(0xFFF4F7F6);
  static const softTeal=Color(0xFFDDF2EA);
  static const softOrange=Color(0xFFFFEBDD);
  static const orange=Color(0xFF9A5934);
  static const weekdays=['L','M','M','J','V','S','D'];
  static const monthNames=['janvier','février','mars','avril','mai','juin',
    'juillet','août','septembre','octobre','novembre','décembre'];

  bool get isOldMonth {
    final today=DateTime.now();
    return month.year<today.year ||
        (month.year==today.year && month.month<today.month);
  }

  Future<bool> discardChangesIfNeeded() async {
    if(draft.isEmpty)return true;
    final discard=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Modifications non enregistrées'),
      content:const Text('Changer de mois annulera les tuiles non validées.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Rester')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Abandonner')),
      ]));
    return discard==true;
  }

  Future<void> changeMonth(int offset) async {
    if(!await discardChangesIfNeeded()||!mounted)return;
    setState((){
      month=DateTime(month.year,month.month+offset);
      draft.clear();
    });
  }

  Future<void> chooseMonth()async{
    if(!await discardChangesIfNeeded()||!mounted)return;
    final date=await showDatePicker(context:context,initialDate:month,
      firstDate:DateTime(2025),lastDate:DateTime(2035,12,31));
    if(date!=null&&mounted)setState((){
      month=DateTime(date.year,date.month);draft.clear();
    });
  }

  String? savedKind(DateTime date) {
    if(appStore.isMyDuty(date))return 'garde';
    if(appStore.myLeave(date)!=null)return 'conge';
    return null;
  }

  String? kindAt(DateTime date) {
    final key=date.day;
    return draft.containsKey(key)?draft[key]:savedKind(date);
  }

  void stage(DateTime date,String? kind) {
    setState((){
      if(kind==savedKind(date))draft.remove(date.day);
      else draft[date.day]=kind;
    });
  }

  Future<void> save() async {
    if(saving||draft.isEmpty)return;
    setState(()=>saving=true);
    try {
      final error=await appStore.validatePersonalMonth(month,Map<int,String?>.from(draft));
      if(error!=null){notice(error);return;}
      final duties=List.generate(DateTime(month.year,month.month+1,0).day,
        (day)=>DateTime(month.year,month.month,day+1))
        .where(appStore.isMyDuty).toList();
      String alertMessage;
      try {
        final doctorId = appStore.activeLocalProfile?.id;
        final settings = doctorId == null ? const DutyAlarmPreferences()
            : await loadDutyAlarmPreferences(doctorId);
        alertMessage=await scheduleDutyReminders(month,duties,settings:settings);
      } catch (_) {
        alertMessage='Rappels non activés. Vérifiez les autorisations du téléphone.';
      }
      if(!mounted)return;
      setState(()=>draft.clear());
      notice('Planning enregistré sur cet appareil. $alertMessage');
    } finally {
      if(mounted)setState(()=>saving=false);
    }
  }

  String label(_PlanningTile tile)=>tile.kind=='conge' ? 'CONGÉ' : '24H';

  String paletteLabel(_PlanningTile tile)=>
      tile.kind=='conge' ? 'CONGÉ' : 'SERVICE · 24H';

  Color tileColor(_PlanningTile tile)=>tile.kind=='conge' ? orange : deep;

  Color tileSurface(_PlanningTile tile)=>tile.kind=='conge' ? softOrange : softTeal;

  void notice(String text){
    if(!mounted)return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content:Text(text),duration:const Duration(seconds:3)));
  }

  void apply(_PlanningTile tile,DateTime to){
    if(isOldMonth){
      notice('Les mois terminés ne sont pas modifiables.');
      return;
    }
    if(tile.from!=null) {
      if(tile.from!.year!=month.year||tile.from!.month!=month.month){
        notice('Déplacez les tuiles dans le même mois.');return;
      }
      if(dayKey(tile.from!)!=dayKey(to))stage(tile.from!,null);
    }
    stage(to,tile.kind);
  }

  Future<void> confirmRemove(_PlanningTile tile)async{
    if(isOldMonth||tile.from==null)return;
    final confirmed=await showDialog<bool>(context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Retirer cette tuile ?'),
        content:Text('${paletteLabel(tile)} du ${tile.from!.day}/${tile.from!.month}/${tile.from!.year}.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Annuler')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Retirer')),
        ],
      ));
    if(confirmed==true&&mounted)stage(tile.from!,null);
  }

  Widget dragFeedback(_PlanningTile tile)=>Material(
    color:tileColor(tile),
    elevation:6,
    borderRadius:BorderRadius.circular(12),
    child:Padding(padding:const EdgeInsets.symmetric(horizontal:17,vertical:13),
      child:Row(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.drag_indicator_rounded,size:18,color:Colors.white),
        const SizedBox(width:5),
        Text(paletteLabel(tile),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),
      ])),
  );

  Widget paletteTile(_PlanningTile tile,IconData icon){
    final active=selected.kind==tile.kind;
    final color=tileColor(tile);
    final card=Material(color:active?tileSurface(tile):Colors.white,
      borderRadius:BorderRadius.circular(11),
      child:InkWell(onTap:()=>setState(()=>selected=tile),
        borderRadius:BorderRadius.circular(11),
        child:Container(
          height:65,
          decoration:BoxDecoration(borderRadius:BorderRadius.circular(11),
            border:Border.all(color:active?color:const Color(0xFFD7E2DD),width:active?2:1)),
          child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Icon(icon,color:color,size:21),
            const SizedBox(height:4),
            Text(paletteLabel(tile),style:TextStyle(color:color,fontSize:11,fontWeight:FontWeight.w900)),
          ]),
        )));
    if(isOldMonth)return Opacity(opacity:0.45,child:card);
    return LongPressDraggable<_PlanningTile>(
      data:tile,
      feedback:dragFeedback(tile),
      childWhenDragging:Opacity(opacity:0.35,child:card),
      child:card);
  }

  Widget day(DateTime date,{required bool highlighted}){
    final kind=kindAt(date);
    final tile=kind==null?null:_PlanningTile(kind,from:date);
    final isToday=dayKey(date)==dayKey(DateTime.now());
    final hasEvent=tile!=null;
    return DragTarget<_PlanningTile>(
      onWillAcceptWithDetails:(details)=>!isOldMonth &&
        (details.data.kind=='garde'||details.data.kind=='conge'),
      onAcceptWithDetails:(details)=>apply(details.data,date),
      builder:(context,candidates,rejected){
        final hover=candidates.isNotEmpty;
        final color=tile==null?deep:tileColor(tile);
        final surface=tile==null?Colors.white:tileSurface(tile);
        final content=Semantics(
          label:'${date.day} ${monthNames[date.month-1]}, '
            '${tile==null?'aucune affectation':label(tile)}',
          child:Material(
            color:hover?const Color(0xFFC6E8DE):isToday?const Color(0xFFEAF8F2):Colors.white,
            borderRadius:BorderRadius.circular(9),
            child:InkWell(
              borderRadius:BorderRadius.circular(9),
              onTap:(){
                if(isOldMonth)return;
                if(!hasEvent){apply(selected,date);return;}
                if(tile.kind==selected.kind){
                  if(selected.kind!=tile.kind)stage(date,selected.kind);
                }else{
                  notice('Appui long pour déplacer la tuile, ou touchez × pour la retirer.');
                }
              },
              child:Container(
                decoration:BoxDecoration(
                  borderRadius:BorderRadius.circular(9),
                  border:Border.all(color:hover?teal:isToday?teal:const Color(0xFFDCE5E1),
                    width:hover||isToday?1.8:1)),
                child:Stack(children:[
                  Positioned(left:5,top:4,child:Text('${date.day}',
                    style:TextStyle(color:isToday?teal:deep,
                      fontSize:12,fontWeight:FontWeight.w900))),
                  if(hasEvent)Positioned(left:3,right:3,bottom:4,top:23,
                    child:Container(
                      decoration:BoxDecoration(color:surface,
                        borderRadius:BorderRadius.circular(5)),
                      alignment:Alignment.center,
                      child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                        if(tile.kind=='garde')
                          Text('SERVICE',maxLines:1,style:TextStyle(color:color,
                            fontSize:7,fontWeight:FontWeight.w700)),
                        Text(label(tile),maxLines:1,style:TextStyle(color:color,
                          fontSize:10,fontWeight:FontWeight.w900)),
                      ]),
                    )),
                  if(hasEvent&&!isOldMonth)Positioned(right:0,top:0,
                    child:GestureDetector(
                      behavior:HitTestBehavior.opaque,
                      onTap:()=>confirmRemove(tile),
                      child:SizedBox(width:23,height:23,
                        child:Icon(Icons.close_rounded,size:14,color:color)),
                    )),
                ]),
              ),
            ),
          ),
        );
        if(!hasEvent||isOldMonth)return content;
        return LongPressDraggable<_PlanningTile>(
          data:tile,
          feedback:dragFeedback(tile),
          childWhenDragging:Opacity(opacity:0.35,child:content),
          child:content);
      });
  }

  Widget calendar(DateTime firstDay){
    final days=DateTime(month.year,month.month+1,0).day;
    final before=firstDay.weekday-1;
    final weeks=((before+days+6)~/7);
    return Column(children:[
      SizedBox(height:27,child:Row(children:[
        for(final weekDay in weekdays)Expanded(child:Center(
          child:Text(weekDay,style:const TextStyle(fontWeight:FontWeight.w800,
            fontSize:11,color:muted)))),
      ])),
      Expanded(child:Column(children:[
        for(var week=0;week<weeks;week++)Expanded(child:Row(children:[
          for(var column=0;column<7;column++)
            Expanded(child:Padding(
              padding:const EdgeInsets.all(2),
              child:Builder(builder:(context){
                final index=week*7+column-before;
                if(index<0||index>=days)return const SizedBox.shrink();
                return day(DateTime(month.year,month.month,index+1),highlighted:false);
              }),
            )),
        ])),
      ])),
    ]);
  }

  Widget discardTarget(){
    return DragTarget<_PlanningTile>(
      onWillAcceptWithDetails:(details)=>!isOldMonth&&details.data.from!=null,
      onAcceptWithDetails:(details)=>confirmRemove(details.data),
      builder:(context,candidates,rejected)=>Container(
        padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),
        decoration:BoxDecoration(
          color:candidates.isNotEmpty?const Color(0xFFFFDFDA):paper,
          borderRadius:BorderRadius.circular(9)),
        child:Row(mainAxisSize:MainAxisSize.min,children:[
          Icon(Icons.delete_outline_rounded,size:18,color:candidates.isNotEmpty?Colors.red:muted),
          const SizedBox(width:5),
          Text('Retirer',style:TextStyle(color:candidates.isNotEmpty?Colors.red:muted,
            fontSize:11,fontWeight:FontWeight.w800)),
        ]),
      ));
  }

  @override
  Widget build(BuildContext context)=>AnimatedBuilder(
    animation:appStore,
    builder:(context,_){
      final doctor=appStore.activeLocalProfile;
      if(doctor==null)return const Scaffold(
        body:Center(child:Text('Connectez-vous pour consulter votre planning personnel.')));
      final days=DateTime(month.year,month.month+1,0).day;
      final dates=List.generate(days,(i)=>DateTime(month.year,month.month,i+1));
      final dutyCount=dates.where((d)=>kindAt(d)=='garde').length;
      final leaveCount=dates.where((d)=>kindAt(d)=='conge').length;
      return Scaffold(
        backgroundColor:paper,
        appBar:AppBar(
          foregroundColor:deep,
          backgroundColor:Colors.white,
          elevation:0,
          title:const VisceraPageTitle('Planning personnel'),
          actions:[IconButton(tooltip:'Configurer les alarmes',
            icon:const Icon(Icons.notifications_active_outlined),
            onPressed:()=>Navigator.push(context,MaterialPageRoute(
              builder:(_)=>const NotificationSettingsPage())))],
        ),
        body:SafeArea(child:Padding(
          padding:const EdgeInsets.fromLTRB(12,8,12,11),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Row(children:[
              const Icon(Icons.account_circle_outlined,color:teal,size:21),
              const SizedBox(width:6),
              Expanded(child:Text(doctor.name,overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:deep,fontSize:14,fontWeight:FontWeight.w800))),
              Text('$dutyCount garde(s) · $leaveCount congé(s)',
                style:const TextStyle(color:muted,fontSize:10,fontWeight:FontWeight.w600)),
            ]),
            const SizedBox(height:8),
            Container(
              height:44,
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12)),
              child:Row(children:[
                IconButton(tooltip:'Mois précédent',
                  onPressed:()=>changeMonth(-1),icon:const Icon(Icons.chevron_left_rounded)),
                Expanded(child:TextButton(
                  onPressed:chooseMonth,
                  child:Text('${monthNames[month.month-1]} ${month.year}',
                    style:const TextStyle(color:deep,fontWeight:FontWeight.w900,fontSize:16)))),
                IconButton(tooltip:'Mois suivant',
                  onPressed:()=>changeMonth(1),icon:const Icon(Icons.chevron_right_rounded)),
              ]),
            ),
            if(isOldMonth)const Padding(
              padding:EdgeInsets.only(top:5),
              child:Text('Mois terminé · consultation uniquement',
                textAlign:TextAlign.center,
                style:TextStyle(color:orange,fontSize:11,fontWeight:FontWeight.w700)),
            ),
            const SizedBox(height:8),
            Expanded(child:calendar(DateTime(month.year,month.month,1))),
            const SizedBox(height:9),
            Container(
              padding:const EdgeInsets.fromLTRB(10,10,10,9),
              decoration:BoxDecoration(color:Colors.white,
                borderRadius:BorderRadius.circular(15),
                border:Border.all(color:const Color(0xFFE2EAE5))),
              child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                Row(children:[
                  const Icon(Icons.drag_indicator_rounded,color:teal,size:19),
                  const SizedBox(width:5),
                  const Expanded(child:Text('GLISSER UNE TUILE SUR UNE DATE',
                    style:TextStyle(color:deep,fontSize:11,fontWeight:FontWeight.w900))),
                  discardTarget(),
                ]),
                const SizedBox(height:8),
                Row(children:[
                  Expanded(child:paletteTile(const _PlanningTile('garde'),
                    Icons.access_time_rounded)),
                  const SizedBox(width:9),
                  Expanded(child:paletteTile(const _PlanningTile('conge'),
                    Icons.beach_access_outlined)),
                ]),
                const SizedBox(height:8),
                const Text('Choisissez puis touchez une date, ou glissez une tuile.',
                  textAlign:TextAlign.center,
                  style:TextStyle(color:muted,fontSize:11,height:1.4)),
              ]),
            ),
            const SizedBox(height:9),
            SizedBox(height:48,child:FilledButton.icon(
              onPressed:draft.isEmpty||saving||isOldMonth?null:save,
              style:FilledButton.styleFrom(backgroundColor:deep),
              icon:saving?const SizedBox(width:17,height:17,
                child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                :const Icon(Icons.check_circle_outline_rounded),
              label:Text(draft.isEmpty?'Planning enregistré'
                :'Valider et enregistrer (${draft.length})',
                style:const TextStyle(fontWeight:FontWeight.w800)),
            )),
            const SizedBox(height:5),
            const Text('Alarmes personnalisables depuis le menu notifications '
              '(Android, après validation du planning).',
              textAlign:TextAlign.center,
              style:TextStyle(color:muted,fontSize:10,height:1.4)),
          ]),
        )),
      );
    },
  );
}
