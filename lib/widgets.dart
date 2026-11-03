import 'dart:async';
import 'branding.dart';
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

/// Compteur J1 / J2 / J3… basé sur le jour civil du programme ou de
/// l'admission réelle. Se recalcule au changement de journée et au réveil
/// de l'application, sans modifier les données médicales.
class HospitalizationDayCounter extends StatefulWidget {
  const HospitalizationDayCounter({
    super.key, required this.patient, this.showStartDate = false,
  });
  final PatientCase patient;
  final bool showStartDate;

  @override
  State<HospitalizationDayCounter> createState()=>_HospitalizationDayCounterState();
}
class _HospitalizationDayCounterState extends State<HospitalizationDayCounter>
    with WidgetsBindingObserver {
  Timer? _midnight;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }
  void _scheduleMidnight() {
    _midnight?.cancel();
    final now=DateTime.now();
    final midnight=DateTime(now.year,now.month,now.day+1);
    _midnight=Timer(midnight.difference(now)+const Duration(milliseconds:150),(){
      if(!mounted)return;
      setState((){});
      _scheduleMidnight();
    });
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.resumed && mounted) {
      setState((){});
      _scheduleMidnight();
    }
  }
  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    super.dispose();
  }
  @override Widget build(BuildContext context) {
    final p=widget.patient;
    if(p.isOmitted) {
      return const VTag('Non admis',warn:true);
    }
    final start=p.hospitalizationStartDate;
    final day=p.hospitalizationDay;
    String label;
    if(day!=null){
      label='J$day';
    }else if(start!=null) {
      label='J1 à venir';
    }else{
      label='Admission à confirmer';
    }
    if(!widget.showStartDate){
      return VTag(label,highlight:day!=null);
    }
    final source=p.fromBlocProgram
      ? 'Programme opératoire' : 'Admission urgences / consultation';
    String date='Date d’admission non renseignée';
    if(start!=null){
      date='${start.day.toString().padLeft(2,'0')}/'
        '${start.month.toString().padLeft(2,'0')}/${start.year}';
    }
    // Sur un écran mobile, la pastille « Admission à confirmer » est trop
    // longue pour partager une ligne avec le libellé et la date. Un Row
    // à trois colonnes écrasait l'Expanded à quelques pixels et le titre
    // s'écrivait lettre par lettre sur toute la hauteur de l'écran.
    // Conserver le libellé et la source sur leur propre ligne évite ce bug.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            const Icon(Icons.today_rounded,color:VColors.ink,size:25),
            const SizedBox(width:12),
            Flexible(child:Container(
              key:const Key('hospitalization-day-counter'),
              padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),
              decoration:BoxDecoration(color:VColors.softMint,
                borderRadius:BorderRadius.circular(13)),
              child:Text(label,
                softWrap:true,
                style:const TextStyle(fontSize:22,
                  fontWeight:FontWeight.w900,color:VColors.ink)),
            )),
          ],
        ),
        const SizedBox(height:10),
        Text(p.stage==CaseStage.discharged
            ? 'Durée du séjour à la sortie'
            : 'Jour d’hospitalisation',
          style:const TextStyle(fontWeight:FontWeight.w800,fontSize:13)),
        const SizedBox(height:3),
        Text('$source · $date',
          softWrap:true,
          style:const TextStyle(fontSize:11,color:VColors.muted)),
      ],
    );
  }
}

class PatientTile extends StatelessWidget {
  const PatientTile({super.key,required this.patient,required this.onTap});
  final PatientCase patient;final VoidCallback onTap;
  @override Widget build(BuildContext context)=>VCard(
    onTap:onTap,margin:const EdgeInsets.only(bottom:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Container(height:42,width:42,alignment:Alignment.center,decoration:BoxDecoration(color:VColors.softMint,borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.person_outline_rounded,color:VColors.ink)),
        const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(patient.name,style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:3),Text(patient.isProgrammed ? 'Consultation • Bloc programmé' : '${patient.age} ans  •  ${patient.origin}',style:const TextStyle(fontSize:12,color:VColors.muted))])),
        const Icon(Icons.chevron_right_rounded,color:VColors.muted)
      ]),const SizedBox(height:13),Text(patient.isProgrammed ? patient.effectiveProcedure : patient.motive,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13,color:VColors.ink)),const SizedBox(height:13),
      Wrap(spacing:6,runSpacing:6,children:[
        VTag(patient.stage.label,highlight:patient.isPostOp,warn:patient.stage==CaseStage.dischargeReady),
        if(patient.isArchived)const VTag('Archivé',highlight:true),
        if(patient.physicallyAdmitted)HospitalizationDayCounter(patient:patient),
        if(patient.blockTiming=='Immédiat')const VTag('Bloc immédiat',warn:true),
        if(patient.physicallyAdmitted && patient.currentBox.trim().isNotEmpty)
          VTag('${patient.currentUnit} • Box ${patient.currentBox}'),
        if(patient.isPostOp && !patient.allChecked(ClinicalDocuments.discharge))
          VTag('Docs sortie ${patient.completedCount(ClinicalDocuments.discharge)}/${ClinicalDocuments.discharge.length}',warn:patient.stage==CaseStage.dischargeReady),
      ])
    ]),
  );
}

class VScaffoldPage extends StatelessWidget {
  const VScaffoldPage({super.key,required this.title,required this.child,this.subtitle});final String title;final Widget child;final String? subtitle;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(backgroundColor:VColors.background,surfaceTintColor:Colors.transparent,title:VisceraPageTitle(title),centerTitle:false),body:child);
}

Future<bool> showConfirmation(BuildContext context,{required String title,required String message,required String action}) async {
  return (await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:Text(title),content:Text(message),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:Text(action))])))??false;
}
