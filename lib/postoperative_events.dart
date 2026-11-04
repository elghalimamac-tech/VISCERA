import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';

/// Complications et reprises : données déclaratives, jamais inférées de la CRP.
class PostoperativeEventsCard extends StatelessWidget {
  const PostoperativeEventsCard({super.key,required this.patient,
    this.readOnly=false});
  final PatientCase patient;
  final bool readOnly;

  static const kinds=<String>[
    'Fistule anastomotique',
    'Reprise chirurgicale',
    'Infection ou abcès',
    'Hémorragie',
    'Occlusion postopératoire',
    'Autre complication',
  ];

  String formatDate(String raw) {
    final date=DateTime.tryParse(raw);
    if(date==null)return raw;
    return date.day.toString().padLeft(2,'0')+'/' +
      date.month.toString().padLeft(2,'0')+'/'+date.year.toString();
  }

  Future<void> _add(BuildContext context) async {
    var kind=kinds.first;
    var date=DateTime.now();
    var status='Suspectée';
    final description=TextEditingController();
    final intervention=TextEditingController();
    try {
      final submitted=await showModalBottomSheet<bool>(
        context:context,isScrollControlled:true,showDragHandle:true,
        builder:(sheet)=>StatefulBuilder(builder:(sheet,redraw)=>
          Padding(padding:EdgeInsets.fromLTRB(18,8,18,
            MediaQuery.of(sheet).viewInsets.bottom+18),
            child:ConstrainedBox(
              constraints:BoxConstraints(maxHeight:
                MediaQuery.of(sheet).size.height*0.8),
              child:ListView(shrinkWrap:true,children:[
                const Text('Ajouter une complication / reprise',
                  style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),
                const SizedBox(height:8),
                const Text('Enregistrement médical manuel. Aucune déduction '
                  'automatique à partir des bilans.',
                  style:TextStyle(fontSize:12,color:Colors.black54)),
                const SizedBox(height:14),
                DropdownButtonFormField<String>(
                  value:kind,isExpanded:true,
                  decoration:const InputDecoration(
                    labelText:'Type',border:OutlineInputBorder()),
                  items:[for(final v in kinds)DropdownMenuItem(
                    value:v,child:Text(v,overflow:TextOverflow.ellipsis))],
                  onChanged:(v)=>redraw(()=>kind=v??kind)),
                const SizedBox(height:12),
                DropdownButtonFormField<String>(
                  value:status,isExpanded:true,
                  decoration:const InputDecoration(
                    labelText:'État',border:OutlineInputBorder()),
                  items:const [
                    DropdownMenuItem(value:'Suspectée',child:Text('Suspectée')),
                    DropdownMenuItem(value:'Confirmée',child:Text('Confirmée')),
                  ],
                  onChanged:(v)=>redraw(()=>status=v??status)),
                const SizedBox(height:12),
                OutlinedButton.icon(
                  icon:const Icon(Icons.event_outlined),
                  label:Text('Date : '+formatDate(date.toIso8601String())),
                  onPressed:()async {
                    final now=DateTime.now();
                    final first=DateTime(patient.blockAt.year,
                      patient.blockAt.month,patient.blockAt.day);
                    final picked=await showDatePicker(context:sheet,
                      initialDate:date,firstDate:first.isAfter(now)?now:first,
                      lastDate:now);
                    if(picked!=null)redraw(()=>date=picked);
                  }),
                const SizedBox(height:12),
                TextField(controller:description,maxLines:3,
                  decoration:const InputDecoration(
                    labelText:'Constatations, examens et évolution',
                    border:OutlineInputBorder())),
                const SizedBox(height:12),
                TextField(controller:intervention,maxLines:3,
                  decoration:const InputDecoration(
                    labelText:'Traitement / geste de reprise (si réalisé)',
                    border:OutlineInputBorder())),
                const SizedBox(height:15),
                FilledButton.icon(
                  onPressed:()=>Navigator.pop(sheet,true),
                  icon:const Icon(Icons.save_outlined),
                  label:const Text('Enregistrer cet événement')),
              ])))));
      if(submitted!=true || !context.mounted)return;
      if(description.text.trim().isEmpty &&
          intervention.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('Décrivez au moins une constatation ou un geste.')));
        return;
      }
      final event=<String,dynamic>{
        'id':DateTime.now().microsecondsSinceEpoch.toString(),
        'date':date.toIso8601String(),
        'type':kind,
        'status':status,
        'details':description.text.trim(),
        'treatment':intervention.text.trim(),
        'recordedBy':appStore.activeLocalProfile?.id??'',
        'recordedAt':DateTime.now().toUtc().toIso8601String(),
      };
      patient.postoperativeEvents.add(event);
      appStore.refresh();
      try {
        await appStore.saveClinical(patient);
        if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Événement enregistré dans le dossier.')));
      } catch (_) {
        patient.postoperativeEvents.remove(event);
        appStore.refresh();
        if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Échec de sauvegarde : aucune '
            'modification confirmée.')));
      }
    } finally {
      description.dispose();
      intervention.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data=[...patient.postoperativeEvents]
      ..sort((a,b)=>(b['date']??'').toString()
        .compareTo((a['date']??'').toString()));
    return Card(
      key:const Key('patient-postoperative-events'),
      color:Colors.white,elevation:0,
      shape:RoundedRectangleBorder(
        borderRadius:BorderRadius.circular(16),
        side:BorderSide(color:Colors.grey.shade300)),
      child:ExpansionTile(
        initiallyExpanded:data.isNotEmpty,
        title:const Text('Complications et reprises',
          style:TextStyle(fontSize:14,fontWeight:FontWeight.w800)),
        subtitle:Text(data.isEmpty?'Aucun événement documenté':
          data.length.toString()+' événement(s) daté(s)'),
        childrenPadding:const EdgeInsets.fromLTRB(16,0,16,16),
        children:[
          for(final event in data)ListTile(
            contentPadding:EdgeInsets.zero,
            title:Text((event['type']??'').toString(),
              style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text(formatDate((event['date']??'').toString())+
              ' · '+(event['status']??'').toString()+'\n'+
              (event['details']??'').toString()+
              ((event['treatment']??'').toString().isEmpty?'':'\nGeste / traitement : '+
                (event['treatment']??'').toString())),
          ),
          if(data.isEmpty)
            const Text('Fistules, infections, hémorragies et reprises '
              'peuvent être consignées ici après évaluation médicale.',
              style:TextStyle(fontSize:12,color:Colors.black54)),
          const SizedBox(height:12),
          if(!readOnly)
            SizedBox(width:double.infinity,child:OutlinedButton.icon(
              key:const Key('add-postoperative-event'),
              onPressed:()=>_add(context),
              icon:const Icon(Icons.add_circle_outline),
              label:const Text('Déclarer une complication ou une reprise'))),
          const SizedBox(height:8),
          const Text('Le grade ISREC se renseigne séparément uniquement '
            'pour une fistule colorectale confirmée. '
            'La CRP ne valide pas un diagnostic.',
            style:TextStyle(fontSize:11,color:Colors.black54)),
        ],
      ),
    );
  }
}
