import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

class VCard extends StatelessWidget {
  const VCard({super.key,required this.child,this.padding=const EdgeInsets.all(18),this.color=Colors.white,this.margin=EdgeInsets.zero,this.onTap});
  final Widget child;final EdgeInsets padding,margin;final Color color;final VoidCallback? onTap;
  @override Widget build(BuildContext context) => Container(
    margin:margin,decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(18),border:Border.all(color:VColors.line)),
    child:Material(color:Colors.transparent,borderRadius:BorderRadius.circular(18),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:Padding(padding:padding,child:child))),
  );
}

class Overline extends StatelessWidget {
  const Overline(this.text,{super.key});final String text;
  @override Widget build(BuildContext context)=>Text(text.toUpperCase(),style:const TextStyle(fontSize:10.5,letterSpacing:1.9,fontWeight:FontWeight.w800,color:VColors.muted));
}

class VTag extends StatelessWidget {
  const VTag(this.text,{super.key,this.highlight=false,this.warn=false});
  final String text;final bool highlight,warn;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:warn?VColors.orangeSoft:highlight?VColors.softMint:VColors.background,borderRadius:BorderRadius.circular(18)),child:Text(text,style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:warn?const Color(0xFFA45633):VColors.ink)));
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title,{super.key,this.trailing});final String title;final Widget? trailing;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(top:23,bottom:12),child:Row(children:[Expanded(child:Text(title,style:Theme.of(context).textTheme.titleLarge)),if(trailing!=null)trailing!]));
}

class PatientTile extends StatelessWidget {
  const PatientTile({super.key,required this.patient,required this.onTap});
  final PatientCase patient;final VoidCallback onTap;
  @override Widget build(BuildContext context)=>VCard(
    onTap:onTap,margin:const EdgeInsets.only(bottom:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Container(height:42,width:42,alignment:Alignment.center,decoration:BoxDecoration(color:VColors.softMint,borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.person_outline_rounded,color:VColors.ink)),
        const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(patient.name,style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:3),Text('${patient.age} ans  •  ${patient.origin}',style:const TextStyle(fontSize:12,color:VColors.muted))])),
        const Icon(Icons.chevron_right_rounded,color:VColors.muted)
      ]),const SizedBox(height:13),Text(patient.motive,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13,color:VColors.ink)),const SizedBox(height:13),
      Wrap(spacing:6,runSpacing:6,children:[VTag(patient.stage.label,highlight:patient.isPostOp,warn:patient.stage==CaseStage.dischargeReady),if(patient.blockTiming=='Immédiat')const VTag('Bloc immédiat',warn:true),if(patient.physicallyAdmitted)VTag('${patient.currentUnit} • Box ${patient.currentBox}'), VTag('Docs sortie ${patient.completedCount(ClinicalDocuments.discharge)}/10')])
    ]),
  );
}

class VScaffoldPage extends StatelessWidget {
  const VScaffoldPage({super.key,required this.title,required this.child,this.subtitle});final String title;final Widget child;final String? subtitle;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(backgroundColor:VColors.background,surfaceTintColor:Colors.transparent,title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800,letterSpacing:-0.7)),centerTitle:false),body:child);
}

Future<bool> showConfirmation(BuildContext context,{required String title,required String message,required String action}) async {
  return (await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:Text(title),content:Text(message),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:Text(action))])))??false;
}
