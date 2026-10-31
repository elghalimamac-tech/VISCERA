import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../doctor_registration_options.dart';
import '../store.dart';
import '../theme.dart';

/// Espace privé : les fonctions RPC revérifient l'identité du propriétaire.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override State<AdminPage> createState()=>_AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<List<Map<String,dynamic>>> _list;
  String _tab='pending', _search='';
  bool _saving=false;

  @override void initState(){super.initState();_list=_load();}
  Future<List<Map<String,dynamic>>> _load() async {
    final data=await Supabase.instance.client.rpc('viscera_admin_get_doctors');
    if(data is! List) throw StateError('Réponse inattendue');
    return data.map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  void _refresh(){if(mounted)setState(()=>_list=_load());}

  String _grade(Map<String,dynamic> d) {
    if(d['requested_role']=='senior')return 'Senior · ${d['senior_title']??'Dr'}';
    final key=d['junior_category'] as String?;
    return key==null?'Junior':gradeLabel(key,(d['internship_passage'] as num?)?.toInt());
  }
  String _status(String? s) => switch(s) {
    'approved'=>'Actif','disabled'=>'Désactivé',_=>'En attente'
  };
  Future<void> _change(Map<String,dynamic> doctor,String action) async {
    if(_saving||doctor['is_admin']==true)return;
    final name=doctor['display_name'] as String? ?? 'ce compte';
    final label=switch(action){
      'approve'=>'Approuver','disable'=>'Désactiver',_=>'Remettre en attente'
    };
    final confirmed=await showDialog<bool>(context:context,
      builder:(ctx)=>AlertDialog(
        title:Text('$label le médecin ?'),
        content:Text(action=='approve'
          ? 'Confirmez avoir vérifié l’identité médicale et le rattachement au service de $name.'
          : 'Confirmer : $label — $name ?'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Annuler')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(label)),
        ],
      ));
    if(confirmed!=true||!mounted)return;
    setState(()=>_saving=true);
    try {
      await Supabase.instance.client.rpc('viscera_admin_review_doctor',params:{
        'p_target':doctor['user_id'],'p_action':action
      });
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Action « $label » enregistrée.')));
      _refresh();
    } on PostgrestException catch(e) {
      if(!mounted)return;
      final msg=e.message.contains('e-mail non confirmée')
        ? 'Ce médecin doit confirmer son adresse e-mail avant validation.'
        : 'Action impossible : droits insuffisants ou compte protégé.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg)));
    } catch(_) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Connexion impossible au serveur.')));
    } finally {if(mounted)setState(()=>_saving=false);}
  }
  Widget _counter(int value,String label,IconData icon)=>Expanded(
    child:Container(padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),
        border:Border.all(color:const Color(0xFFE0E8E4))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(icon,color:VColors.ink,size:19),
        const SizedBox(height:10),
        Text('$value',style:const TextStyle(fontSize:27,fontWeight:FontWeight.w800,color:VColors.ink)),
        Text(label,style:const TextStyle(color:VColors.muted,fontSize:11)),
      ]),
    ));
  Widget _doctor(Map<String,dynamic> d) {
    final state=d['approval_status'] as String? ?? 'pending';
    final admin=d['is_admin']==true;
    return Container(margin:const EdgeInsets.only(bottom:11),padding:const EdgeInsets.all(15),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),
        border:Border.all(color:const Color(0xFFE0E8E4))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          CircleAvatar(backgroundColor:VColors.softMint,
            child:Icon(admin?Icons.admin_panel_settings_outlined:Icons.person_outline,color:VColors.ink)),
          const SizedBox(width:11),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(d['display_name'] as String? ?? 'Médecin',
              style:const TextStyle(fontWeight:FontWeight.w800,color:VColors.ink,fontSize:15)),
            const SizedBox(height:3),
            Text(_grade(d),style:const TextStyle(fontSize:12,color:VColors.muted)),
          ])),
        ]),
        const SizedBox(height:11),
        Row(children:[
          Icon(state=='approved'?Icons.check_circle_outline:Icons.info_outline,
            size:17,color:state=='approved'?const Color(0xFF117C57):const Color(0xFFA66B35)),
          const SizedBox(width:7),
          Text(admin?'Administrateur principal':_status(state),
            style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),
        ]),
        if(!admin)...[
          const SizedBox(height:12),
          Wrap(spacing:8,runSpacing:5,children:[
            if(state!='approved')FilledButton.icon(
              onPressed:_saving?null:()=>_change(d,'approve'),
              icon:const Icon(Icons.check,size:18),
              label:Text(state=='disabled'?'Réactiver':'Approuver')),
            if(state!='disabled')OutlinedButton.icon(
              onPressed:_saving?null:()=>_change(d,'disable'),
              icon:const Icon(Icons.block,size:18),label:const Text('Désactiver')),
            if(state=='disabled')TextButton(
              onPressed:_saving?null:()=>_change(d,'pending'),
              child:const Text('Remettre en attente')),
          ]),
        ],
      ]),
    );
  }

  @override Widget build(BuildContext context) {
    if(appStore.activeLocalProfile?.isVisceraOwner != true) {
      return Scaffold(appBar:AppBar(title:const Text('Administration')),
        body:const Center(child:Text('Accès réservé à l’administrateur principal.')));
    }
    return Scaffold(
      backgroundColor:const Color(0xFFF4F7F6),
      appBar:AppBar(
        backgroundColor:const Color(0xFFF4F7F6),
        title:const Text('Administration VISCERA'),
        actions:[IconButton(tooltip:'Actualiser',onPressed:_saving?null:_refresh,
          icon:const Icon(Icons.refresh))],
      ),
      body:FutureBuilder<List<Map<String,dynamic>>>(
        future:_list,
        builder:(context,snapshot){
          if(snapshot.connectionState!=ConnectionState.done){
            return const Center(child:CircularProgressIndicator());
          }
          if(snapshot.hasError){
            return Center(child:Padding(padding:const EdgeInsets.all(25),
              child:Column(mainAxisSize:MainAxisSize.min,children:[
                const Icon(Icons.lock_outline,size:42,color:VColors.muted),
                const SizedBox(height:12),
                const Text('Accès aux comptes impossible. Vérifiez votre connexion ou vos droits.',
                  textAlign:TextAlign.center),
                const SizedBox(height:15),
                FilledButton(onPressed:_refresh,child:const Text('Réessayer')),
              ])));
          }
          final rows=snapshot.data??[];
          final pending=rows.where((d)=>d['approval_status']=='pending').length;
          final active=rows.where((d)=>d['approval_status']=='approved').length;
          final inactive=rows.where((d)=>d['approval_status']=='disabled').length;
          final filtered=rows.where((d){
            return (_tab=='all'||d['approval_status']==_tab)
              && (d['display_name'] as String? ?? '').toLowerCase()
                  .contains(_search.trim().toLowerCase());
          }).toList();
          return RefreshIndicator(
            onRefresh:()async{final data=await _load();if(mounted)setState(()=>_list=Future.value(data));},
            child:ListView(padding:const EdgeInsets.fromLTRB(18,16,18,32),children:[
              const Text('Mon espace administrateur',
                style:TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:VColors.ink)),
              const SizedBox(height:5),
              const Text('Chirurgie viscérale · HUIM6 Bouskoura',
                style:TextStyle(color:VColors.muted,fontSize:13)),
              const SizedBox(height:19),
              Row(children:[
                _counter(pending,'En attente',Icons.hourglass_empty),
                const SizedBox(width:8),
                _counter(active,'Actifs',Icons.verified_outlined),
                const SizedBox(width:8),
                _counter(inactive,'Bloqués',Icons.block_outlined),
              ]),
              const SizedBox(height:22),
              const Text('Gestion des médecins',
                style:TextStyle(fontWeight:FontWeight.w800,fontSize:18,color:VColors.ink)),
              const SizedBox(height:11),
              TextField(onChanged:(v)=>setState(()=>_search=v),
                decoration:const InputDecoration(
                  hintText:'Rechercher un médecin',
                  prefixIcon:Icon(Icons.search),filled:true,fillColor:Colors.white)),
              const SizedBox(height:12),
              SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
                for(final option in const [
                  ('pending','En attente'),('approved','Actifs'),
                  ('disabled','Bloqués'),('all','Tous')
                ])Padding(padding:const EdgeInsets.only(right:7),
                  child:ChoiceChip(label:Text(option.$2),
                    selected:_tab==option.$1,
                    selectedColor:VColors.softMint,
                    onSelected:(_)=>setState(()=>_tab=option.$1))),
              ])),
              const SizedBox(height:15),
              if(filtered.isEmpty)const Padding(padding:EdgeInsets.all(25),
                child:Text('Aucun médecin dans cette liste.',
                  textAlign:TextAlign.center,
                  style:TextStyle(color:VColors.muted)))
              else ...filtered.map(_doctor),
              const SizedBox(height:13),
              const Text('L’accès est réservé à ton compte et vérifié côté serveur. '
                'Vérifie personnellement chaque nouvelle inscription avant de l’approuver.',
                style:TextStyle(fontSize:11,color:VColors.muted,height:1.5)),
              const SizedBox(height:9),
              const Text('Version de démonstration : patients fictifs, '
                'sans synchronisation clinique sécurisée.',
                style:TextStyle(fontSize:11,color:VColors.muted,height:1.5)),
            ]),
          );
        },
      ),
    );
  }
}
