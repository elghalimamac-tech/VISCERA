import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// Checklist clinique modifiable ; les dossiers issus du bloc sont sauvegardés dans Supabase.
class DocumentChecklist extends StatelessWidget {
  const DocumentChecklist({super.key, required this.patient, required this.title,
    required this.requirements, this.readOnly=false, this.compact=false});
  final PatientCase patient;
  final String title;
  final List<DocumentRequirement> requirements;
  final bool readOnly, compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation:appStore,builder:(context,_) {
    final count = patient.completedCount(requirements);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VColors.line)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Row(children:[Expanded(child:Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:VColors.ink))),
          Text('$count / ${requirements.length}',style:TextStyle(color:count==requirements.length?VColors.ink:VColors.muted,fontWeight:FontWeight.w800))]),
        const SizedBox(height:7),
        LinearProgressIndicator(value:count/requirements.length,minHeight:5,
          color:VColors.ink,backgroundColor:VColors.line,borderRadius:BorderRadius.circular(8)),
        const SizedBox(height:6),
        const Text('Cochez « fait / vérifié », puis contrôlez le cachet séparément.',style:TextStyle(fontSize:11,color:VColors.muted)),
        const SizedBox(height:12),
        ...requirements.map((item)=>_row(context,item)),
      ]),
    );
    });
  }

  Widget _row(BuildContext context, DocumentRequirement item){
    final check=patient.check(item.key);
    final disabled = readOnly || (!patient.isActive && !patient.isProgrammed);
    return Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        SizedBox(width:38,height:42,child:Checkbox(
          value:check.verified,onChanged:disabled||check.notApplicable?null:(v)=>appStore.updateDocument(patient,item,verified:v??false),
          activeColor:VColors.ink)),
        Expanded(child:Text(item.title,style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,
          color:check.notApplicable?VColors.muted:VColors.ink))),
        if(check.complete(item))const Icon(Icons.check_circle_rounded,color:Color(0xFF248567),size:20)
        else if(check.verified && item.needsStamp && check.stamped==false)
          const Icon(Icons.error_outline_rounded,color:Color(0xFFBF773D),size:20),
      ]),
      Padding(padding:const EdgeInsets.only(left:38),child:Wrap(spacing:7,runSpacing:7,children:[
        if(item.needsStamp && !check.notApplicable) ...[
          _pill('Cacheté',check.stamped==true,check.verified&&!disabled,
            ()=>appStore.updateDocument(patient,item,stamped:true)),
          _pill('Non cacheté',check.stamped==false,check.verified&&!disabled,
            ()=>appStore.updateDocument(patient,item,stamped:false)),
        ],
        if(!item.needsStamp && check.verified) const Text('Rendez-vous confirmé',style:TextStyle(fontSize:11,color:VColors.muted)),
        if(item.optional) _pill('Non applicable',check.notApplicable,!disabled,
          ()=>appStore.updateDocument(patient,item,notApplicable:!check.notApplicable)),
      ])),
      const SizedBox(height:8), const Divider(height:1,color:VColors.line),
    ]));
  }
  Widget _pill(String text,bool selected,bool enabled,VoidCallback action)=>
    OutlinedButton(onPressed:enabled?action:null,
      style:OutlinedButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
        minimumSize:const Size(0,34),tapTargetSize:MaterialTapTargetSize.shrinkWrap,
        backgroundColor:selected?VColors.softMint:Colors.white,
        side:BorderSide(color:selected?VColors.ink:VColors.line),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
      child:Text(text,style:TextStyle(fontSize:11,fontWeight:selected?FontWeight.w800:FontWeight.w600,
        color:selected?VColors.ink:VColors.muted)));
}
