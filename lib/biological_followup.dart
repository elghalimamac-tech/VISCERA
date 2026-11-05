import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';

class BiologyField {
  const BiologyField(this.key,this.label,this.unit,this.max,
    {this.canonicalFactor = 1.0});
  final String key,label,unit;
  /// Maximum de saisie dans l'unité affichée.
  final double max;
  /// Compatibilité avec tous les dossiers précédemment enregistrés :
  /// créatinine en µmol/L, bilirubine en µmol/L, cellules en G/L.
  /// Le facteur n'est appliqué qu'à l'entrée/sortie, jamais au dossier déjà stocké.
  final double canonicalFactor;

  double toCanonical(double displayed) => displayed * canonicalFactor;
  double fromCanonical(double stored) => stored / canonicalFactor;

  String displayStored(double stored) {
    if (canonicalFactor == 1.0) return stored.toString();
    final formatted = fromCanonical(stored).toStringAsFixed(3);
    return formatted.replaceFirst(RegExp(r'0+
const biologyFields=<BiologyField>[
  BiologyField('crp','CRP','mg/L',1500),
  BiologyField('wbc','Globules blancs','G/L',150),
  BiologyField('albumin','Albuminémie','g/L',70),
  BiologyField('lymphocytes','Lymphocytes','×10³/mm³',40),
  BiologyField('neutrophils','Neutrophiles','×10³/mm³',100),
  BiologyField('hb','Hémoglobine','g/dL',30),
  BiologyField('platelets','Plaquettes','×10³/mm³',2000),
  BiologyField('creatinine','Créatinine','mg/L',450,
    canonicalFactor:8.84),
  BiologyField('urea','Urée','g/L',20),
  BiologyField('lipase','Lipase','UI/L',100000),
  BiologyField('pct','Procalcitonine','ng/mL',500),
  BiologyField('lactate','Lactates','mmol/L',40),
  BiologyField('bilirubin','Bilirubine totale','mg/L',700,
    canonicalFactor:1.7104),
  BiologyField('sodium','Sodium','mmol/L',220),
  BiologyField('potassium','Potassium','mmol/L',12),
  BiologyField('weightKg','Poids actuel','kg',400),
  BiologyField('idealWeightKg','Poids de référence validé','kg',400),
];
double? parseBiology(String raw,BiologyField field) {
  if(raw.trim().isEmpty)return null;
  final v=double.tryParse(raw.trim().replaceAll(',','.'));
  if(v==null||!v.isFinite||v<0||v>field.max||
      (['weightKg','idealWeightKg','bilirubin'].contains(field.key)&&v<=0)){
    throw FormatException('Valeur invalide pour '+field.label+' ('+field.unit+')');
  }
  return field.toCanonical(v);
}
class LabPoint {
  const LabPoint(this.day,this.value);
  final DateTime day;
  final double value;
}
List<LabPoint> labSeries(PatientCase p,String key){
  final values=<LabPoint>[];
  for(final o in p.dailyObservations) {
    final v=o.biology[key];
    if(v!=null&&v.isFinite&&v>=0)values.add(LabPoint(o.date,v));
  }
  return values..sort((a,b)=>a.day.compareTo(b.day));
}
class CrpKinetics {
  CrpKinetics(this.points);
  final List<LabPoint> points;
  double? get last=>points.isEmpty?null:points.last.value;
  double? get delta=>points.length<2?null:
    points.last.value-points[points.length-2].value;
  bool get secondaryRise {
    if(points.length<3)return false;
    var previousDecrease=false;
    for(var i=1;i<points.length;i++){
      final change=points[i].value-points[i-1].value;
      if(i==points.length-1)return previousDecrease&&change>0;
      if(change<0)previousDecrease=true;
    }
    return false;
  }
}
class BioIndex {
  const BioIndex(this.name,this.value,this.detail);
  final String name,value,detail;
}
class BioIndices {
  static List<BioIndex> compute(PatientCase p) {
    final result=<BioIndex>[];
    final observations=[...p.dailyObservations]
      ..sort((a,b)=>b.date.compareTo(a.date));
    Map<String,double>? find(List<String> keys) {
      for(final o in observations){
        if(keys.every(o.biology.containsKey))return o.biology;
      }
      return null;
    }
    final crp=find(['crp'])?['crp'];
    final alb=find(['crp','albumin']);
    if(crp!=null&&crp<=10) {
      result.add(const BioIndex('mGPS','0','CRP ≤ 10 mg/L'));
    } else if(alb!=null&&alb['crp']!>10) {
      result.add(BioIndex('mGPS',alb['albumin']!<35?'2':'1',
        'CRP >10 mg/L · albumine '+(alb['albumin']!<35?'<35':'≥35')+' g/L'));
    }
    if(alb!=null&&alb['albumin']!>0)result.add(BioIndex('CAR',
      (alb['crp']!/alb['albumin']!).toStringAsFixed(2),
      'CRP (mg/L) / albumine (g/L), sans seuil universel'));
    final pni=find(['albumin','lymphocytes']);
    if(pni!=null)result.add(BioIndex('PNI',
      (pni['albumin']!+5*pni['lymphocytes']!).toStringAsFixed(1),
      'Albumine (g/L) + 5 × lymphocytes (×10³/mm³)'));
    final age=p.birthDate==null?int.tryParse(p.age):
      DateTime.now().year-p.birthDate!.year-
      ((DateTime.now().month<p.birthDate!.month||
      (DateTime.now().month==p.birthDate!.month&&
      DateTime.now().day<p.birthDate!.day))?1:0);
    final gnri=find(['albumin','weightKg','idealWeightKg']);
    if(age!=null&&age>=65&&gnri!=null&&gnri['idealWeightKg']!>0)
      result.add(BioIndex('GNRI',
        (1.489*gnri['albumin']!+
          41.7*math.min(gnri['weightKg']!/gnri['idealWeightKg']!,1.0))
          .toStringAsFixed(1),
        'Indice gériatrique, poids de référence validé'));
    final procedure=p.effectiveProcedure.toLowerCase();
    final hepatic=procedure.contains('hépat')||procedure.contains('hepatect')||
      procedure.contains('foie')||procedure.contains('biliaire')||
      procedure.contains('cholangi');
    final albi=find(['albumin','bilirubin']);
    if(hepatic&&albi!=null&&albi['bilirubin']!>0)
      result.add(BioIndex('ALBI',
        (0.66*math.log(albi['bilirubin']!)/math.ln10-0.085*albi['albumin']!)
        .toStringAsFixed(2),
        'Bilirubine saisie en mg/L, convertie en µmol/L pour ALBI · '
        'contexte hépatobiliaire uniquement'));
    return result;
  }
}
class CrpTrendCard extends StatelessWidget {
  const CrpTrendCard({super.key,required this.patient,this.compact=false});
  final PatientCase patient;
  final bool compact;
  @override Widget build(BuildContext context){
    final kinetics=CrpKinetics(labSeries(patient,'crp'));
    return Card(
      key:const Key('patient-crp-chart'),color:Colors.white,elevation:0,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),
        side:BorderSide(color:Colors.grey.shade300)),
      child:Padding(padding:const EdgeInsets.all(16),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Row(children:[Icon(Icons.show_chart,color:Color(0xFF087B71)),
            SizedBox(width:9),Expanded(child:Text('Courbe de CRP par patient',
              style:TextStyle(fontWeight:FontWeight.w800,fontSize:15)))]),
          const SizedBox(height:8),
          const Text('CRP (mg/L) · prélèvements réellement enregistrés',
            style:TextStyle(fontSize:11,color:Colors.black54)),
          const SizedBox(height:10),
          if(kinetics.points.isEmpty)
            const Padding(padding:EdgeInsets.symmetric(vertical:12),
              child:Text('Aucune CRP saisie : courbe et calculs indisponibles.',
                style:TextStyle(fontSize:12,color:Colors.black54)))
          else ...[
            SizedBox(height:compact?125:185,
              child:CustomPaint(painter:_CrpPainter(kinetics.points),
                child:const SizedBox.expand())),
            Text('Dernière CRP : '+kinetics.last!.toStringAsFixed(1)+' mg/L'+
              (kinetics.delta==null?'':' · variation : '+
                (kinetics.delta!>0?'+':'')+
                kinetics.delta!.toStringAsFixed(1)+' mg/L'),
              style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12)),
            if(kinetics.secondaryRise)
              const Text('Réascension après diminution : à réévaluer cliniquement.',
                style:TextStyle(color:Color(0xFFA45633),fontSize:12)),
          ],
          const SizedBox(height:8),
          const Text('La CRP seule ne confirme pas une fistule ni une infection. '
            'Pas de seuil décisionnel automatique.',
            style:TextStyle(fontSize:11,color:Colors.black54)),
        ])));
  }
}
class _CrpPainter extends CustomPainter {
  const _CrpPainter(this.values);
  final List<LabPoint> values;
  @override void paint(Canvas canvas,Size size){
    final left=42.0,top=10.0,right=math.max(left+2,size.width-12);
    final bottom=math.max(top+3,size.height-30);
    final height=bottom-top,width=right-left;
    final maximum=math.max(1.0,values.fold<double>(0,
      (m,v)=>math.max(m,v.value))*1.1);
    final first=values.first.day.millisecondsSinceEpoch;
    final last=values.last.day.millisecondsSinceEpoch;
    for(var j=0;j<=4;j++) {
      final y=bottom-j*height/4;
      canvas.drawLine(Offset(left,y),Offset(right,y),
        Paint()..color=const Color(0xFFE4E9E8)..strokeWidth=1);
      _label(canvas,(maximum*j/4).toStringAsFixed(0),Offset(0,y-6));
    }
    Offset pt(LabPoint point) =>Offset(
      left+(last==first?0.5:
        (point.day.millisecondsSinceEpoch-first)/(last-first))*width,
      bottom-(point.value/maximum)*height);
    final path=Path();
    for(var i=0;i<values.length;i++) {
      final a=pt(values[i]);
      if(i==0)path.moveTo(a.dx,a.dy);else path.lineTo(a.dx,a.dy);
    }
    canvas.drawPath(path,Paint()..color=const Color(0xFF087B71)
      ..strokeWidth=2.5..style=PaintingStyle.stroke);
    for(final x in values)canvas.drawCircle(pt(x),3.7,
      Paint()..color=const Color(0xFF087B71));
    String date(DateTime v)=>v.day.toString().padLeft(2,'0')+'/'+
      v.month.toString().padLeft(2,'0');
    _label(canvas,date(values.first.day),Offset(left,bottom+7));
    if(values.length>1)_label(canvas,date(values.last.day),
      Offset(right-34,bottom+7));
  }
  void _label(Canvas canvas,String label,Offset pos){
    final p=TextPainter(text:TextSpan(text:label,
      style:const TextStyle(fontSize:10,color:Color(0xFF66757A))),
      textDirection:TextDirection.ltr)..layout();
    p.paint(canvas,pos);
  }
  @override bool shouldRepaint(covariant _CrpPainter old)=>true;
}
class BiologicalIndicesCard extends StatelessWidget {
  const BiologicalIndicesCard({super.key,required this.patient});
  final PatientCase patient;
  @override Widget build(BuildContext context) {
    final indices=BioIndices.compute(patient);
    return Card(key:const Key('patient-biological-indices'),
      color:Colors.white,elevation:0,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),
        side:BorderSide(color:Colors.grey.shade300)),
      child:ExpansionTile(initiallyExpanded:false,
        title:const Text('Indices biologiques (facultatifs)',
          style:TextStyle(fontSize:14,fontWeight:FontWeight.w800)),
        subtitle:const Text('mGPS · CAR · PNI · GNRI · ALBI'),
        childrenPadding:const EdgeInsets.fromLTRB(16,0,16,16),
        children:[
          if(indices.isEmpty)
            const Text('Aucun indice calculé : remplir les bilans dans les '
              'observations quotidiennes uniquement si disponibles.'),
          for(final index in indices)
            ListTile(dense:true,contentPadding:EdgeInsets.zero,
              title:Text(index.name),
              subtitle:Text(index.detail),
              trailing:Text(index.value,style:
                const TextStyle(fontWeight:FontWeight.w900))),
          const Text('Chaque formule utilise des paramètres d’une même '
            'observation datée. Indices non diagnostiques. '
            'L’albumine seule ne diagnostique pas une dénutrition.',
            style:TextStyle(fontSize:11,color:Colors.black54)),
        ]));
  }
}
), '')
      .replaceFirst(RegExp(r'\.
const biologyFields=<BiologyField>[
  BiologyField('crp','CRP','mg/L',1500),
  BiologyField('wbc','Globules blancs','G/L',150),
  BiologyField('albumin','Albuminémie','g/L',70),
  BiologyField('lymphocytes','Lymphocytes','G/L',40),
  BiologyField('neutrophils','Neutrophiles','G/L',100),
  BiologyField('hb','Hémoglobine','g/dL',30),
  BiologyField('platelets','Plaquettes','G/L',2000),
  BiologyField('creatinine','Créatinine','µmol/L',4000),
  BiologyField('pct','Procalcitonine','ng/mL',500),
  BiologyField('lactate','Lactates','mmol/L',40),
  BiologyField('bilirubin','Bilirubine totale','µmol/L',1200),
  BiologyField('sodium','Sodium','mmol/L',220),
  BiologyField('potassium','Potassium','mmol/L',12),
  BiologyField('weightKg','Poids actuel','kg',400),
  BiologyField('idealWeightKg','Poids de référence validé','kg',400),
];
double? parseBiology(String raw,BiologyField field) {
  if(raw.trim().isEmpty)return null;
  final v=double.tryParse(raw.trim().replaceAll(',','.'));
  if(v==null||!v.isFinite||v<0||v>field.max||
      (['weightKg','idealWeightKg','bilirubin'].contains(field.key)&&v<=0)){
    throw FormatException('Valeur invalide pour '+field.label+' ('+field.unit+')');
  }
  return v;
}
class LabPoint {
  const LabPoint(this.day,this.value);
  final DateTime day;
  final double value;
}
List<LabPoint> labSeries(PatientCase p,String key){
  final values=<LabPoint>[];
  for(final o in p.dailyObservations) {
    final v=o.biology[key];
    if(v!=null&&v.isFinite&&v>=0)values.add(LabPoint(o.date,v));
  }
  return values..sort((a,b)=>a.day.compareTo(b.day));
}
class CrpKinetics {
  CrpKinetics(this.points);
  final List<LabPoint> points;
  double? get last=>points.isEmpty?null:points.last.value;
  double? get delta=>points.length<2?null:
    points.last.value-points[points.length-2].value;
  bool get secondaryRise {
    if(points.length<3)return false;
    var previousDecrease=false;
    for(var i=1;i<points.length;i++){
      final change=points[i].value-points[i-1].value;
      if(i==points.length-1)return previousDecrease&&change>0;
      if(change<0)previousDecrease=true;
    }
    return false;
  }
}
class BioIndex {
  const BioIndex(this.name,this.value,this.detail);
  final String name,value,detail;
}
class BioIndices {
  static List<BioIndex> compute(PatientCase p) {
    final result=<BioIndex>[];
    final observations=[...p.dailyObservations]
      ..sort((a,b)=>b.date.compareTo(a.date));
    Map<String,double>? find(List<String> keys) {
      for(final o in observations){
        if(keys.every(o.biology.containsKey))return o.biology;
      }
      return null;
    }
    final crp=find(['crp'])?['crp'];
    final alb=find(['crp','albumin']);
    if(crp!=null&&crp<=10) {
      result.add(const BioIndex('mGPS','0','CRP ≤ 10 mg/L'));
    } else if(alb!=null&&alb['crp']!>10) {
      result.add(BioIndex('mGPS',alb['albumin']!<35?'2':'1',
        'CRP >10 mg/L · albumine '+(alb['albumin']!<35?'<35':'≥35')+' g/L'));
    }
    if(alb!=null&&alb['albumin']!>0)result.add(BioIndex('CAR',
      (alb['crp']!/alb['albumin']!).toStringAsFixed(2),
      'CRP (mg/L) / albumine (g/L), sans seuil universel'));
    final pni=find(['albumin','lymphocytes']);
    if(pni!=null)result.add(BioIndex('PNI',
      (pni['albumin']!+5*pni['lymphocytes']!).toStringAsFixed(1),
      'Albumine (g/L) + 5 × lymphocytes (G/L)'));
    final age=p.birthDate==null?int.tryParse(p.age):
      DateTime.now().year-p.birthDate!.year-
      ((DateTime.now().month<p.birthDate!.month||
      (DateTime.now().month==p.birthDate!.month&&
      DateTime.now().day<p.birthDate!.day))?1:0);
    final gnri=find(['albumin','weightKg','idealWeightKg']);
    if(age!=null&&age>=65&&gnri!=null&&gnri['idealWeightKg']!>0)
      result.add(BioIndex('GNRI',
        (1.489*gnri['albumin']!+
          41.7*math.min(gnri['weightKg']!/gnri['idealWeightKg']!,1.0))
          .toStringAsFixed(1),
        'Indice gériatrique, poids de référence validé'));
    final procedure=p.effectiveProcedure.toLowerCase();
    final hepatic=procedure.contains('hépat')||procedure.contains('hepatect')||
      procedure.contains('foie')||procedure.contains('biliaire')||
      procedure.contains('cholangi');
    final albi=find(['albumin','bilirubin']);
    if(hepatic&&albi!=null&&albi['bilirubin']!>0)
      result.add(BioIndex('ALBI',
        (0.66*math.log(albi['bilirubin']!)/math.ln10-0.085*albi['albumin']!)
        .toStringAsFixed(2),'Contexte hépatobiliaire uniquement'));
    return result;
  }
}
class CrpTrendCard extends StatelessWidget {
  const CrpTrendCard({super.key,required this.patient,this.compact=false});
  final PatientCase patient;
  final bool compact;
  @override Widget build(BuildContext context){
    final kinetics=CrpKinetics(labSeries(patient,'crp'));
    return Card(
      key:const Key('patient-crp-chart'),color:Colors.white,elevation:0,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),
        side:BorderSide(color:Colors.grey.shade300)),
      child:Padding(padding:const EdgeInsets.all(16),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Row(children:[Icon(Icons.show_chart,color:Color(0xFF087B71)),
            SizedBox(width:9),Expanded(child:Text('Courbe de CRP par patient',
              style:TextStyle(fontWeight:FontWeight.w800,fontSize:15)))]),
          const SizedBox(height:8),
          const Text('CRP (mg/L) · prélèvements réellement enregistrés',
            style:TextStyle(fontSize:11,color:Colors.black54)),
          const SizedBox(height:10),
          if(kinetics.points.isEmpty)
            const Padding(padding:EdgeInsets.symmetric(vertical:12),
              child:Text('Aucune CRP saisie : courbe et calculs indisponibles.',
                style:TextStyle(fontSize:12,color:Colors.black54)))
          else ...[
            SizedBox(height:compact?125:185,
              child:CustomPaint(painter:_CrpPainter(kinetics.points),
                child:const SizedBox.expand())),
            Text('Dernière CRP : '+kinetics.last!.toStringAsFixed(1)+' mg/L'+
              (kinetics.delta==null?'':' · variation : '+
                (kinetics.delta!>0?'+':'')+
                kinetics.delta!.toStringAsFixed(1)+' mg/L'),
              style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12)),
            if(kinetics.secondaryRise)
              const Text('Réascension après diminution : à réévaluer cliniquement.',
                style:TextStyle(color:Color(0xFFA45633),fontSize:12)),
          ],
          const SizedBox(height:8),
          const Text('La CRP seule ne confirme pas une fistule ni une infection. '
            'Pas de seuil décisionnel automatique.',
            style:TextStyle(fontSize:11,color:Colors.black54)),
        ])));
  }
}
class _CrpPainter extends CustomPainter {
  const _CrpPainter(this.values);
  final List<LabPoint> values;
  @override void paint(Canvas canvas,Size size){
    final left=42.0,top=10.0,right=math.max(left+2,size.width-12);
    final bottom=math.max(top+3,size.height-30);
    final height=bottom-top,width=right-left;
    final maximum=math.max(1.0,values.fold<double>(0,
      (m,v)=>math.max(m,v.value))*1.1);
    final first=values.first.day.millisecondsSinceEpoch;
    final last=values.last.day.millisecondsSinceEpoch;
    for(var j=0;j<=4;j++) {
      final y=bottom-j*height/4;
      canvas.drawLine(Offset(left,y),Offset(right,y),
        Paint()..color=const Color(0xFFE4E9E8)..strokeWidth=1);
      _label(canvas,(maximum*j/4).toStringAsFixed(0),Offset(0,y-6));
    }
    Offset pt(LabPoint point) =>Offset(
      left+(last==first?0.5:
        (point.day.millisecondsSinceEpoch-first)/(last-first))*width,
      bottom-(point.value/maximum)*height);
    final path=Path();
    for(var i=0;i<values.length;i++) {
      final a=pt(values[i]);
      if(i==0)path.moveTo(a.dx,a.dy);else path.lineTo(a.dx,a.dy);
    }
    canvas.drawPath(path,Paint()..color=const Color(0xFF087B71)
      ..strokeWidth=2.5..style=PaintingStyle.stroke);
    for(final x in values)canvas.drawCircle(pt(x),3.7,
      Paint()..color=const Color(0xFF087B71));
    String date(DateTime v)=>v.day.toString().padLeft(2,'0')+'/'+
      v.month.toString().padLeft(2,'0');
    _label(canvas,date(values.first.day),Offset(left,bottom+7));
    if(values.length>1)_label(canvas,date(values.last.day),
      Offset(right-34,bottom+7));
  }
  void _label(Canvas canvas,String label,Offset pos){
    final p=TextPainter(text:TextSpan(text:label,
      style:const TextStyle(fontSize:10,color:Color(0xFF66757A))),
      textDirection:TextDirection.ltr)..layout();
    p.paint(canvas,pos);
  }
  @override bool shouldRepaint(covariant _CrpPainter old)=>true;
}
class BiologicalIndicesCard extends StatelessWidget {
  const BiologicalIndicesCard({super.key,required this.patient});
  final PatientCase patient;
  @override Widget build(BuildContext context) {
    final indices=BioIndices.compute(patient);
    return Card(key:const Key('patient-biological-indices'),
      color:Colors.white,elevation:0,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),
        side:BorderSide(color:Colors.grey.shade300)),
      child:ExpansionTile(initiallyExpanded:false,
        title:const Text('Indices biologiques (facultatifs)',
          style:TextStyle(fontSize:14,fontWeight:FontWeight.w800)),
        subtitle:const Text('mGPS · CAR · PNI · GNRI · ALBI'),
        childrenPadding:const EdgeInsets.fromLTRB(16,0,16,16),
        children:[
          if(indices.isEmpty)
            const Text('Aucun indice calculé : remplir les bilans dans les '
              'observations quotidiennes uniquement si disponibles.'),
          for(final index in indices)
            ListTile(dense:true,contentPadding:EdgeInsets.zero,
              title:Text(index.name),
              subtitle:Text(index.detail),
              trailing:Text(index.value,style:
                const TextStyle(fontWeight:FontWeight.w900))),
          const Text('Chaque formule utilise des paramètres d’une même '
            'observation datée. Indices non diagnostiques. '
            'L’albumine seule ne diagnostique pas une dénutrition.',
            style:TextStyle(fontSize:11,color:Colors.black54)),
        ]));
  }
}
), '');
  }
}
const biologyFields=<BiologyField>[
  BiologyField('crp','CRP','mg/L',1500),
  BiologyField('wbc','Globules blancs','G/L',150),
  BiologyField('albumin','Albuminémie','g/L',70),
  BiologyField('lymphocytes','Lymphocytes','G/L',40),
  BiologyField('neutrophils','Neutrophiles','G/L',100),
  BiologyField('hb','Hémoglobine','g/dL',30),
  BiologyField('platelets','Plaquettes','G/L',2000),
  BiologyField('creatinine','Créatinine','µmol/L',4000),
  BiologyField('pct','Procalcitonine','ng/mL',500),
  BiologyField('lactate','Lactates','mmol/L',40),
  BiologyField('bilirubin','Bilirubine totale','µmol/L',1200),
  BiologyField('sodium','Sodium','mmol/L',220),
  BiologyField('potassium','Potassium','mmol/L',12),
  BiologyField('weightKg','Poids actuel','kg',400),
  BiologyField('idealWeightKg','Poids de référence validé','kg',400),
];
double? parseBiology(String raw,BiologyField field) {
  if(raw.trim().isEmpty)return null;
  final v=double.tryParse(raw.trim().replaceAll(',','.'));
  if(v==null||!v.isFinite||v<0||v>field.max||
      (['weightKg','idealWeightKg','bilirubin'].contains(field.key)&&v<=0)){
    throw FormatException('Valeur invalide pour '+field.label+' ('+field.unit+')');
  }
  return v;
}
class LabPoint {
  const LabPoint(this.day,this.value);
  final DateTime day;
  final double value;
}
List<LabPoint> labSeries(PatientCase p,String key){
  final values=<LabPoint>[];
  for(final o in p.dailyObservations) {
    final v=o.biology[key];
    if(v!=null&&v.isFinite&&v>=0)values.add(LabPoint(o.date,v));
  }
  return values..sort((a,b)=>a.day.compareTo(b.day));
}
class CrpKinetics {
  CrpKinetics(this.points);
  final List<LabPoint> points;
  double? get last=>points.isEmpty?null:points.last.value;
  double? get delta=>points.length<2?null:
    points.last.value-points[points.length-2].value;
  bool get secondaryRise {
    if(points.length<3)return false;
    var previousDecrease=false;
    for(var i=1;i<points.length;i++){
      final change=points[i].value-points[i-1].value;
      if(i==points.length-1)return previousDecrease&&change>0;
      if(change<0)previousDecrease=true;
    }
    return false;
  }
}
class BioIndex {
  const BioIndex(this.name,this.value,this.detail);
  final String name,value,detail;
}
class BioIndices {
  static List<BioIndex> compute(PatientCase p) {
    final result=<BioIndex>[];
    final observations=[...p.dailyObservations]
      ..sort((a,b)=>b.date.compareTo(a.date));
    Map<String,double>? find(List<String> keys) {
      for(final o in observations){
        if(keys.every(o.biology.containsKey))return o.biology;
      }
      return null;
    }
    final crp=find(['crp'])?['crp'];
    final alb=find(['crp','albumin']);
    if(crp!=null&&crp<=10) {
      result.add(const BioIndex('mGPS','0','CRP ≤ 10 mg/L'));
    } else if(alb!=null&&alb['crp']!>10) {
      result.add(BioIndex('mGPS',alb['albumin']!<35?'2':'1',
        'CRP >10 mg/L · albumine '+(alb['albumin']!<35?'<35':'≥35')+' g/L'));
    }
    if(alb!=null&&alb['albumin']!>0)result.add(BioIndex('CAR',
      (alb['crp']!/alb['albumin']!).toStringAsFixed(2),
      'CRP (mg/L) / albumine (g/L), sans seuil universel'));
    final pni=find(['albumin','lymphocytes']);
    if(pni!=null)result.add(BioIndex('PNI',
      (pni['albumin']!+5*pni['lymphocytes']!).toStringAsFixed(1),
      'Albumine (g/L) + 5 × lymphocytes (G/L)'));
    final age=p.birthDate==null?int.tryParse(p.age):
      DateTime.now().year-p.birthDate!.year-
      ((DateTime.now().month<p.birthDate!.month||
      (DateTime.now().month==p.birthDate!.month&&
      DateTime.now().day<p.birthDate!.day))?1:0);
    final gnri=find(['albumin','weightKg','idealWeightKg']);
    if(age!=null&&age>=65&&gnri!=null&&gnri['idealWeightKg']!>0)
      result.add(BioIndex('GNRI',
        (1.489*gnri['albumin']!+
          41.7*math.min(gnri['weightKg']!/gnri['idealWeightKg']!,1.0))
          .toStringAsFixed(1),
        'Indice gériatrique, poids de référence validé'));
    final procedure=p.effectiveProcedure.toLowerCase();
    final hepatic=procedure.contains('hépat')||procedure.contains('hepatect')||
      procedure.contains('foie')||procedure.contains('biliaire')||
      procedure.contains('cholangi');
    final albi=find(['albumin','bilirubin']);
    if(hepatic&&albi!=null&&albi['bilirubin']!>0)
      result.add(BioIndex('ALBI',
        (0.66*math.log(albi['bilirubin']!)/math.ln10-0.085*albi['albumin']!)
        .toStringAsFixed(2),'Contexte hépatobiliaire uniquement'));
    return result;
  }
}
class CrpTrendCard extends StatelessWidget {
  const CrpTrendCard({super.key,required this.patient,this.compact=false});
  final PatientCase patient;
  final bool compact;
  @override Widget build(BuildContext context){
    final kinetics=CrpKinetics(labSeries(patient,'crp'));
    return Card(
      key:const Key('patient-crp-chart'),color:Colors.white,elevation:0,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),
        side:BorderSide(color:Colors.grey.shade300)),
      child:Padding(padding:const EdgeInsets.all(16),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Row(children:[Icon(Icons.show_chart,color:Color(0xFF087B71)),
            SizedBox(width:9),Expanded(child:Text('Courbe de CRP par patient',
              style:TextStyle(fontWeight:FontWeight.w800,fontSize:15)))]),
          const SizedBox(height:8),
          const Text('CRP (mg/L) · prélèvements réellement enregistrés',
            style:TextStyle(fontSize:11,color:Colors.black54)),
          const SizedBox(height:10),
          if(kinetics.points.isEmpty)
            const Padding(padding:EdgeInsets.symmetric(vertical:12),
              child:Text('Aucune CRP saisie : courbe et calculs indisponibles.',
                style:TextStyle(fontSize:12,color:Colors.black54)))
          else ...[
            SizedBox(height:compact?125:185,
              child:CustomPaint(painter:_CrpPainter(kinetics.points),
                child:const SizedBox.expand())),
            Text('Dernière CRP : '+kinetics.last!.toStringAsFixed(1)+' mg/L'+
              (kinetics.delta==null?'':' · variation : '+
                (kinetics.delta!>0?'+':'')+
                kinetics.delta!.toStringAsFixed(1)+' mg/L'),
              style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12)),
            if(kinetics.secondaryRise)
              const Text('Réascension après diminution : à réévaluer cliniquement.',
                style:TextStyle(color:Color(0xFFA45633),fontSize:12)),
          ],
          const SizedBox(height:8),
          const Text('La CRP seule ne confirme pas une fistule ni une infection. '
            'Pas de seuil décisionnel automatique.',
            style:TextStyle(fontSize:11,color:Colors.black54)),
        ])));
  }
}
class _CrpPainter extends CustomPainter {
  const _CrpPainter(this.values);
  final List<LabPoint> values;
  @override void paint(Canvas canvas,Size size){
    final left=42.0,top=10.0,right=math.max(left+2,size.width-12);
    final bottom=math.max(top+3,size.height-30);
    final height=bottom-top,width=right-left;
    final maximum=math.max(1.0,values.fold<double>(0,
      (m,v)=>math.max(m,v.value))*1.1);
    final first=values.first.day.millisecondsSinceEpoch;
    final last=values.last.day.millisecondsSinceEpoch;
    for(var j=0;j<=4;j++) {
      final y=bottom-j*height/4;
      canvas.drawLine(Offset(left,y),Offset(right,y),
        Paint()..color=const Color(0xFFE4E9E8)..strokeWidth=1);
      _label(canvas,(maximum*j/4).toStringAsFixed(0),Offset(0,y-6));
    }
    Offset pt(LabPoint point) =>Offset(
      left+(last==first?0.5:
        (point.day.millisecondsSinceEpoch-first)/(last-first))*width,
      bottom-(point.value/maximum)*height);
    final path=Path();
    for(var i=0;i<values.length;i++) {
      final a=pt(values[i]);
      if(i==0)path.moveTo(a.dx,a.dy);else path.lineTo(a.dx,a.dy);
    }
    canvas.drawPath(path,Paint()..color=const Color(0xFF087B71)
      ..strokeWidth=2.5..style=PaintingStyle.stroke);
    for(final x in values)canvas.drawCircle(pt(x),3.7,
      Paint()..color=const Color(0xFF087B71));
    String date(DateTime v)=>v.day.toString().padLeft(2,'0')+'/'+
      v.month.toString().padLeft(2,'0');
    _label(canvas,date(values.first.day),Offset(left,bottom+7));
    if(values.length>1)_label(canvas,date(values.last.day),
      Offset(right-34,bottom+7));
  }
  void _label(Canvas canvas,String label,Offset pos){
    final p=TextPainter(text:TextSpan(text:label,
      style:const TextStyle(fontSize:10,color:Color(0xFF66757A))),
      textDirection:TextDirection.ltr)..layout();
    p.paint(canvas,pos);
  }
  @override bool shouldRepaint(covariant _CrpPainter old)=>true;
}
class BiologicalIndicesCard extends StatelessWidget {
  const BiologicalIndicesCard({super.key,required this.patient});
  final PatientCase patient;
  @override Widget build(BuildContext context) {
    final indices=BioIndices.compute(patient);
    return Card(key:const Key('patient-biological-indices'),
      color:Colors.white,elevation:0,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),
        side:BorderSide(color:Colors.grey.shade300)),
      child:ExpansionTile(initiallyExpanded:false,
        title:const Text('Indices biologiques (facultatifs)',
          style:TextStyle(fontSize:14,fontWeight:FontWeight.w800)),
        subtitle:const Text('mGPS · CAR · PNI · GNRI · ALBI'),
        childrenPadding:const EdgeInsets.fromLTRB(16,0,16,16),
        children:[
          if(indices.isEmpty)
            const Text('Aucun indice calculé : remplir les bilans dans les '
              'observations quotidiennes uniquement si disponibles.'),
          for(final index in indices)
            ListTile(dense:true,contentPadding:EdgeInsets.zero,
              title:Text(index.name),
              subtitle:Text(index.detail),
              trailing:Text(index.value,style:
                const TextStyle(fontWeight:FontWeight.w900))),
          const Text('Chaque formule utilise des paramètres d’une même '
            'observation datée. Indices non diagnostiques. '
            'L’albumine seule ne diagnostique pas une dénutrition.',
            style:TextStyle(fontSize:11,color:Colors.black54)),
        ]));
  }
}
