import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../push_device_registration.dart';
import '../store.dart';
import '../planning_models.dart';

/// Démonstration : planning personnel de gardes de SERVICE et congés uniquement.
/// LongPressDraggable + DragTarget = glisser-déposer mobile ; toucher reste possible.
class PersonalPlanningPage extends StatefulWidget {
  const PersonalPlanningPage({super.key});
  @override State<PersonalPlanningPage> createState()=>_PersonalPlanningPageState();
}
class _PlanningDrag {
  const _PlanningDrag(this.kind,{this.from});
  final String kind; // 'garde' ou 'conge' uniquement
  final DateTime? from;
}
class _PersonalPlanningPageState extends State<PersonalPlanningPage>{
  DateTime month=DateTime(DateTime.now().year,DateTime.now().month);
  String selected='garde';
  static const deep=Color(0xFF142C38), teal=Color(0xFF007C82), paper=Color(0xFFF3F6F7),muted=Color(0xFF627780);
  static const paleTeal=Color(0xFFDEF3F3),paleOrange=Color(0xFFFFEFE1);
  static const weekdays=['L','M','M','J','V','S','D'];
  String monthLabel(DateTime d)=>'${const ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'][d.month-1]} ${d.year}';
  void apply(_PlanningDrag drag,DateTime date){
    final issue=appStore.placePersonalEvent(date,kind:drag.kind,from:drag.from);
    if(issue!=null && mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(issue)));
  }
  void remove(DateTime date,String kind)=>appStore.removePersonalEvent(date,kind);
  Future<void> chooseMonth()async{
    final d=await showDatePicker(context:context,initialDate:month,firstDate:DateTime(2025),lastDate:DateTime(2032,12,31));
    if(d!=null)setState(()=>month=DateTime(d.year,d.month));
  }
  Widget action(String kind,String title,IconData icon){
    final active=selected==kind;
    final iconColor=kind=='garde'?teal:const Color(0xFFA66A38);
    final tile=InkWell(onTap:()=>setState(()=>selected=kind),borderRadius:BorderRadius.circular(10),
      child:Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(
        color:active?const Color(0xFFE9F4F5):Colors.white,borderRadius:BorderRadius.circular(10),
        border:Border.all(color:active?teal:const Color(0xFFDCE5E8),width:active?2:1)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(icon,color:iconColor,size:25),const SizedBox(height:9),Text(title,style:const TextStyle(color:deep,fontSize:13,fontWeight:FontWeight.w800)),
        ])));
    return LongPressDraggable<_PlanningDrag>(data:_PlanningDrag(kind),
      feedback:Material(borderRadius:BorderRadius.circular(8),color:deep,child:Padding(padding:const EdgeInsets.all(13),child:Text(title,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800)))),
      child:tile);
  }
  Widget dayTile(DateTime date){
    final myDuty=appStore.isMyDuty(date),leave=appStore.myLeave(date)!=null;
    final today=dayKey(date)==dayKey(DateTime.now());
    return DragTarget<_PlanningDrag>(
      onWillAcceptWithDetails:(d)=>d.data.kind=='garde'||d.data.kind=='conge',
      onAcceptWithDetails:(d)=>apply(d.data,date),
      builder:(ctx,candidates,rejected)=>InkWell(
        onTap:()=>apply(_PlanningDrag(selected),date),borderRadius:BorderRadius.circular(8),
        child:Container(padding:const EdgeInsets.symmetric(horizontal:3,vertical:7),
          decoration:BoxDecoration(color:candidates.isNotEmpty?paleTeal:Colors.white,borderRadius:BorderRadius.circular(8),
            border:Border.all(color:candidates.isNotEmpty||today?teal:const Color(0xFFDCE5E8))),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('${date.day}',style:const TextStyle(fontSize:12,color:deep,fontWeight:FontWeight.w800)),
            const SizedBox(height:6),
            if(myDuty)Container(padding:const EdgeInsets.symmetric(vertical:4),decoration:BoxDecoration(color:paleTeal,borderRadius:BorderRadius.circular(4)),child:const Text('GARDE',textAlign:TextAlign.center,style:TextStyle(color:teal,fontSize:8,fontWeight:FontWeight.w900))),
            if(leave)Container(padding:const EdgeInsets.symmetric(vertical:4),decoration:BoxDecoration(color:paleOrange,borderRadius:BorderRadius.circular(4)),child:const Text('CONGÉ',textAlign:TextAlign.center,style:TextStyle(color:Color(0xFF925D33),fontSize:8,fontWeight:FontWeight.w900))),
          ]))));
  }
  Widget eventRow(DateTime date,String kind){
    final label=kind=='garde'?'Garde de service':'Congé';
    final content=ListTile(dense:true,leading:const Icon(Icons.drag_indicator,color:muted),
      title:Text(label,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800)),
      subtitle:Text('${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}',style:const TextStyle(color:muted,fontSize:11)),
      trailing:IconButton(icon:const Icon(Icons.close_rounded,size:18),tooltip:'Retirer',onPressed:()=>remove(date,kind)));
    return LongPressDraggable<_PlanningDrag>(data:_PlanningDrag(kind,from:date),
      feedback:Material(color:deep,borderRadius:BorderRadius.circular(8),child:Padding(padding:const EdgeInsets.all(12),child:Text('Déplacer : $label',style:const TextStyle(color:Colors.white)))),
      child:content);
  }
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:appStore,builder:(context,_){
    final person=appStore.activeLocalProfile;
    if(person==null)return const Scaffold(body:Center(child:Text('Choisissez un profil pour accéder au planning.')));
    final days=DateTime(month.year,month.month+1,0).day;
    final first=DateTime(month.year,month.month,1).weekday-1;
    final dates=List.generate(days,(i)=>DateTime(month.year,month.month,i+1));
    final duty=dates.where(appStore.isMyDuty).toList();
    final leaves=dates.where((d)=>appStore.myLeave(d)!=null).toList();
    final items=<Widget>[];
    for(final d in dates){if(appStore.isMyDuty(d))items.add(eventRow(d,'garde'));if(appStore.myLeave(d)!=null)items.add(eventRow(d,'conge'));}
    return Scaffold(backgroundColor:paper,appBar:AppBar(backgroundColor:Colors.white,foregroundColor:deep,
      title:const Text('Mon planning',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),
      actions:[IconButton(tooltip:'Se déconnecter',onPressed:() async {Navigator.of(context).popUntil((route)=>route.isFirst);await unregisterCurrentPushDevice();await Supabase.instance.client.auth.signOut();},icon:const Icon(Icons.switch_account_outlined))]),
      body:ListView(padding:const EdgeInsets.fromLTRB(17,18,17,40),children:[
        Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:deep,borderRadius:BorderRadius.circular(13)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('MON ESPACE',style:TextStyle(color:Color(0xFFB6D6DB),fontSize:11,fontWeight:FontWeight.w800)),
          const SizedBox(height:6),Text(person.name,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w800)),
          const SizedBox(height:7),Text('${person.isSenior?'Médecin senior':'Médecin junior'} · calendrier individuel',style:const TextStyle(color:Color(0xFFC4DCE0),fontSize:12)),
        ])),
        const SizedBox(height:21),const Text('1 · CHOISIR UN TYPE',style:TextStyle(fontWeight:FontWeight.w900,fontSize:11,color:muted)),
        const SizedBox(height:9),Row(children:[Expanded(child:action('garde','Garde de service',Icons.calendar_view_month_rounded)),const SizedBox(width:10),Expanded(child:action('conge','Congé',Icons.beach_access_outlined))]),
        const SizedBox(height:8),const Text('Appui long pour déplacer sur un jour. Ou touchez un type puis un jour.',style:TextStyle(fontSize:11.5,color:muted)),
        const SizedBox(height:18),const Text('2 · CHOISIR UNE DATE',style:TextStyle(fontWeight:FontWeight.w900,fontSize:11,color:muted)),
        Row(children:[IconButton(onPressed:()=>setState(()=>month=DateTime(month.year,month.month-1)),icon:const Icon(Icons.chevron_left)),
          Expanded(child:TextButton(onPressed:chooseMonth,child:Text(monthLabel(month),style:const TextStyle(color:deep,fontWeight:FontWeight.w800,fontSize:16)))),
          IconButton(onPressed:()=>setState(()=>month=DateTime(month.year,month.month+1)),icon:const Icon(Icons.chevron_right))]),
        Row(children:[for(final w in weekdays)Expanded(child:Center(child:Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(w,style:const TextStyle(fontSize:11,color:muted,fontWeight:FontWeight.w800)))))]),
        GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
          itemCount:first+days,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,childAspectRatio:0.61,crossAxisSpacing:4,mainAxisSpacing:5),
          itemBuilder:(c,index)=>index<first?const SizedBox():dayTile(dates[index-first])),
        const SizedBox(height:9),Text('Mes gardes : ${duty.length}   ·   Mes jours de congé : ${leaves.length}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:deep)),
        const SizedBox(height:24),const Text('MES AFFECTATIONS',style:TextStyle(fontWeight:FontWeight.w900,fontSize:11,color:muted)),
        const SizedBox(height:10),Container(decoration:BoxDecoration(color:Colors.white,border:Border.all(color:const Color(0xFFDCE5E8)),borderRadius:BorderRadius.circular(12)),
          child:items.isEmpty?const Padding(padding:EdgeInsets.all(18),child:Text('Aucune affectation ce mois-ci.',style:TextStyle(color:muted))):Column(children:items)),
        const SizedBox(height:18),const Text('Planning unique : les gardes sont les astreintes de service (junior ou senior). Aucune garde aux urgences. Une affectation déjà occupée par un collègue ne peut pas être remplacée ici.',style:TextStyle(color:muted,fontSize:11,height:1.5)),
        const SizedBox(height:10),const Text('Version de démonstration locale : profils non authentifiés et aucune synchronisation entre appareils. Pour un déploiement médical, un serveur sécurisé et des permissions par compte sont nécessaires.',style:TextStyle(color:Color(0xFFA1663C),fontSize:11,height:1.5)),
      ]));
  });
}
