import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

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
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(item.title,style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,
            color:check.notApplicable?VColors.muted:VColors.ink)),
          if(check.fromProgram) const Text('Pré-coché · programme officiel (contrôler la pièce si nécessaire)',
            style:TextStyle(fontSize:10.5,color:VColors.muted)),
        ])),
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
        if(!item.needsStamp && check.verified) Text(item.key=='consent' ? 'Consentement signé / vérifié' : 'Document vérifié',style:TextStyle(fontSize:11,color:VColors.muted)),
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
/// Raccourci de sortie : attestation explicite, jamais une signature ou un cachet automatique.
class DischargeDocumentsBulkAction extends StatefulWidget {
  const DischargeDocumentsBulkAction({
    super.key, required this.patient, this.readOnly = false,
  });
  final PatientCase patient;
  final bool readOnly;

  @override
  State<DischargeDocumentsBulkAction> createState() =>
      _DischargeDocumentsBulkActionState();
}

class _DischargeDocumentsBulkActionState
    extends State<DischargeDocumentsBulkAction> {
  bool _saving = false;

  Future<void> _verifyAll() async {
    final patient = widget.patient;
    if (_saving || widget.readOnly || !patient.isPostOp ||
        !patient.physicallyAdmitted ||
        patient.allChecked(ClinicalDocuments.discharge)) return;

    final confirmed = await showConfirmation(
      context,
      title: 'Tous les documents vérifiés et cachetés',
      message: 'Je confirme avoir contrôlé réellement toutes les pièces '
          'de sortie et les cachets requis dans le dossier médical. '
          'Les pièces déjà déclarées « Non applicable » resteront '
          'inchangées. Cette validation ne déclare pas la sortie du patient.',
      action: 'Valider les documents',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      final saved = await appStore.verifyAndStampAllDischargeDocuments(patient);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved
            ? 'Documents de sortie vérifiés et cachetés : validation enregistrée.'
            : 'Enregistrement impossible. Les vérifications précédentes sont conservées.'),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appStore,
    builder: (context, _) {
      final patient = widget.patient;
      final allVerified = patient.allChecked(ClinicalDocuments.discharge);
      final enabled = !widget.readOnly && !_saving && !allVerified &&
          patient.isPostOp && patient.physicallyAdmitted;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: double.infinity, child: FilledButton.icon(
          key: const Key('bulk-verify-discharge-documents'),
          style: FilledButton.styleFrom(
            backgroundColor: VColors.ink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          ),
          onPressed: enabled ? _verifyAll : null,
          icon: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2,
                    color: Colors.white))
              : const Icon(Icons.fact_check_rounded),
          label: Text(_saving ? 'Enregistrement des vérifications…'
              : allVerified ? 'Documents vérifiés et cachetés'
              : 'Tous les documents vérifiés et cachetés',
              textAlign: TextAlign.center),
        )),
        const SizedBox(height: 6),
        const Text(
          'À utiliser uniquement après contrôle réel des documents et cachets. '
          'La décision médicale de sortie reste séparée.',
          style: TextStyle(fontSize: 11, color: VColors.muted),
        ),
      ]);
    },
  );
}


/// Date retenue pour le suivi du séjour, mise en évidence lors du contrôle
/// des documents de sortie. Pour le programme officiel, la date d'origine est
/// celle du programme opératoire et ne certifie pas une présence physique.
class AdmissionDateHighlight extends StatelessWidget {
  const AdmissionDateHighlight({super.key, required this.patient});

  final PatientCase patient;

  @override
  Widget build(BuildContext context) {
    final date = patient.hospitalizationStartDate;
    final dateLabel = date == null
        ? 'Non renseignée'
        : '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final source = patient.fromBlocProgram
        ? 'Date du programme opératoire · admission de suivi'
        : 'Date d’admission enregistrée';

    return Container(
      key: const Key('discharge-admission-date'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VColors.softMint,
        border: Border.all(color: VColors.ink, width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event_available_rounded,
            size: 24, color: VColors.ink),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DATE D’ADMISSION',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800,
                  color: VColors.ink,
                )),
              const SizedBox(height: 3),
              Text(dateLabel,
                key: const Key('discharge-admission-date-value'),
                style: const TextStyle(
                  fontSize: 21, fontWeight: FontWeight.w900,
                  color: VColors.ink,
                )),
              const SizedBox(height: 2),
              Text(source, style: const TextStyle(
                fontSize: 11, color: VColors.muted,
              )),
            ],
          )),
        ],
      ),
    );
  }
}
