import 'dart:async';
import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

/// Vérifications préopératoires indépendantes des pièces d'admission.
/// Les statuts sont à renseigner par l'équipe, sans validation automatique.
class PreoperativeReadinessCard extends StatefulWidget {
  const PreoperativeReadinessCard({
    super.key,required this.patient,required this.onChanged,this.readOnly=false,
  });
  final PatientCase patient;
  final VoidCallback onChanged;
  final bool readOnly;
  @override
  State<PreoperativeReadinessCard> createState()=>_PreoperativeReadinessCardState();
}

class _PreoperativeReadinessCardState extends State<PreoperativeReadinessCard> {
  late final TextEditingController _order;
  Timer? _debounce;

  @override
  void initState(){
    super.initState();
    _order=TextEditingController(text:widget.patient.admissionPrescriptionDetails);
  }
  @override
  void dispose(){
    _debounce?.cancel();
    _order.dispose();
    super.dispose();
  }
  void _notify(){
    widget.onChanged();
    if(mounted)setState((){});
  }
  void _orderChanged(String value){
    widget.patient.admissionPrescriptionDetails=value;
    _debounce?.cancel();
    _debounce=Timer(const Duration(milliseconds:600),widget.onChanged);
  }
  Widget _choice(String label,String value,List<(String,String)> options,
      ValueChanged<String> changed){
    return Padding(
      padding:const EdgeInsets.only(bottom:12),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(label,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
        const SizedBox(height:8),
        Wrap(spacing:7,runSpacing:7,children:options.map((option)=>
          ChoiceChip(
            label:Text(option.$2),
            selected:value==option.$1,
            onSelected:widget.readOnly?null:(selected){
              if(selected){changed(option.$1);_notify();}
            },
          )).toList()),
      ]),
    );
  }

  @override
  Widget build(BuildContext context){
    final p=widget.patient;
    return Container(
      width:double.infinity,
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),
        border:Border.all(color:VColors.line)),
      padding:const EdgeInsets.all(16),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Documents à avoir en préopératoire',
          style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:VColors.ink)),
        const SizedBox(height:6),
        const Text('Renseigner les contrôles. « À vérifier » ne vaut pas validation '
          'médicale ou anesthésique.',
          style:TextStyle(fontSize:11,color:VColors.muted)),
        const SizedBox(height:16),
        _choice('CPA : accord anesthésique obtenu ?',p.cpaStatus,
          const [('a_verifier','À vérifier'),('ok','OK obtenu'),('non_ok','Pas encore OK')],
          (value)=>p.cpaStatus=value),
        _choice('Bilans préopératoires',p.preopLabStatus,
          const [('a_verifier','À vérifier'),('faits','Faits'),('a_faire','À faire')],
          (value)=>p.preopLabStatus=value),
        _choice('Ordonnance à l’admission ?',p.admissionPrescriptionStatus,
          const [('a_verifier','À préciser'),('oui','Oui'),('non','Non')],
          (value){
            p.admissionPrescriptionStatus=value;
            if(value!='oui'){
              p.admissionPrescriptionDetails='';
              _order.clear();
            }
          }),
        if(p.admissionPrescriptionStatus=='oui')...[
          TextField(
            controller:_order,
            readOnly:widget.readOnly,
            minLines:1,
            maxLines:4,
            decoration:const InputDecoration(
              labelText:'Que prescrire ? (facultatif)',
              hintText:'Ex. prescriptions à préciser par le médecin',
              border:OutlineInputBorder()),
            onChanged:widget.readOnly?null:_orderChanged,
          ),
          const SizedBox(height:5),
          const Text('Ce champ est une note de suivi, pas une prescription '
            'médicale exécutoire.',
            style:TextStyle(fontSize:11,color:VColors.muted)),
        ],
      ]),
    );
  }
}
