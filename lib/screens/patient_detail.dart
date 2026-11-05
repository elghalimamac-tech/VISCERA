import '../branding.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import '../program_admission.dart';
import '../document_checklist.dart';
import '../biological_followup.dart';
import '../postoperative_events.dart';
import '../preoperative_readiness.dart';
import 'clinical_scores_page.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'discharge.dart';
import 'discharge_verification_sheet.dart';
import 'daily_observations.dart';
import '../voice_dictation.dart';
import '../manual_admission_service.dart';
import '../specialist_opinions.dart';

class PatientDetailPage extends StatefulWidget {
  const PatientDetailPage({super.key,required this.patient});
  final PatientCase patient;
  @override State<PatientDetailPage> createState()=>_PatientDetailPageState();
}
class _PatientDetailPageState extends State<PatientDetailPage> {
  PatientCase get p=>widget.patient;
  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && p.dischargeDue) _showDischargeReview();
    });
  }

  Future<void> _showDischargeReview() async {
    if (!mounted || !p.dischargeDue) return;
    final date = p.dischargeReviewAt;
    final result = await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Row(children:[
          Icon(Icons.event_available_outlined,color:Color(0xFFA45633)),
          SizedBox(width:10),
          Expanded(child:Text('Sortie à réévaluer')),
        ]),
        content:Text(
          'Le dossier a atteint sa date indicative de révision de sortie'
          '${date == null ? '' : ' (${_date(date)})'}.\n\n'
          'Vérifiez l’état clinique, les complications éventuelles, '
          'les prescriptions et les documents obligatoires. '
          'La sortie nécessite une décision médicale et une validation explicite.',
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Plus tard')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Vérifier la sortie')),
        ],
      ),
    );
    if (result==true && mounted) await _openDischargeVerification();
  }
  Future<void> _openDischargeVerification() async {
    if (!p.isPostOp || !p.physicallyAdmitted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => DischargeVerificationSheet(patient: p),
    );
    if (!mounted) return;
    if (action == 'documents') {
      await Navigator.push(context,
        MaterialPageRoute(builder: (_) => DischargePage(patient: p)));
    } else if (action == 'confirmed') {
      _notice('Sortie enregistrée. Le box est désormais libéré.');
    }
  }

  @override
  Widget build(BuildContext context)=>AnimatedBuilder(
    animation:appStore,
    builder:(context,_)=>Scaffold(
      appBar:AppBar(
        title:const VisceraPageTitle('Dossier patient'),
        backgroundColor:VColors.background,surfaceTintColor:Colors.transparent,
      ),
      // Point d'entrée clinique accessible à tout moment pendant le séjour.
      floatingActionButton:(p.isActive||p.isProgrammed)?Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (p.isPostOp && p.physicallyAdmitted) ...[
            FloatingActionButton.extended(
              key: const Key('declare-discharge-fab'),
              heroTag: 'discharge-${p.id}',
              backgroundColor: const Color(0xFFB4232F),
              foregroundColor: Colors.white,
              elevation: 3,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Déclarer la sortie',
                style: TextStyle(fontWeight: FontWeight.w800)),
              tooltip: 'Vérifier les documents avant de déclarer la sortie',
              onPressed: _openDischargeVerification,
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            key:const Key('add-daily-observation-fab'),
            heroTag: 'observation-${p.id}',
            backgroundColor: VColors.ink,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Observation quotidienne',
              style: TextStyle(fontWeight: FontWeight.w700)),
            tooltip: 'Ajouter une observation clinique quotidienne à ce dossier',
            onPressed: () => showClinicalObservationEditor(context,p),
          ),
        ],
      ):null,
      floatingActionButtonLocation:FloatingActionButtonLocation.endFloat,
      body:ListView(
        // Laisser assez d'espace SOUS la dernière action pour qu'elle
        // reste entièrement accessible au-dessus des FAB persistants.
        // Deux FAB en postopératoire (sortie + observation), sinon un seul.
        padding: EdgeInsets.fromLTRB(18, 14, 18,
          (p.isPostOp && p.physicallyAdmitted) ? 450 : 300),
        children:[
          VCard(color:VColors.ink,padding:const EdgeInsets.all(18),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                Expanded(child:Text(p.id,style:const TextStyle(
                  color:VColors.mint,fontSize:11,fontWeight:FontWeight.w700,letterSpacing:1.2))),
                const Icon(Icons.folder_shared_outlined,color:VColors.mint,size:20),
              ]),
              const SizedBox(height:8),
              Text(p.name,style:const TextStyle(color:Colors.white,fontSize:23,
                fontWeight:FontWeight.w800)),
              const SizedBox(height:5),
              Text('${p.age == '—' ? 'Âge non renseigné' : '${p.age} ans'} · ${p.origin}',style:const TextStyle(
                color:Color(0xFFD8EAE4),fontSize:13)),
              if(p.birthDate!=null)...[
                const SizedBox(height:5),
                Text('Né(e) le ${_date(p.birthDate!)}',
                  style:const TextStyle(color:Colors.white70,fontSize:12)),
              ],
              const SizedBox(height:13),
              Wrap(spacing:7,runSpacing:7,children:[
                VTag(p.stage.label,highlight:true),
                VTag(p.insurance),
                if(p.blockTiming=='Immédiat')const VTag('Bloc immédiat',warn:true),
                if(p.requiresFrailtyAttention)VTag('CFS ${p.cfsScore} · Fragilité',warn:true),
              ]),
            ])),
          if(p.fromBlocProgram || p.fromManualAdmission)...[
            const SizedBox(height:10),
            VCard(
              color:p.isOmitted?VColors.orangeSoft:VColors.softMint,
              padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
              child:Row(children:[
                Icon(p.isOmitted?Icons.person_off_outlined:Icons.cloud_done_outlined,
                  color:VColors.ink,size:20),
                const SizedBox(width:10),
                Expanded(child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(p.isOmitted?'Admission annulée · programme conservé'
                    :p.fromBlocProgram?'Programme importé · dossier partagé'
                    :'Dossier partagé VISCERA',
                    style:const TextStyle(fontSize:12.5,fontWeight:FontWeight.w800)),
                  const SizedBox(height:3),
                  Text(appStore.clinicalSyncState(p),
                    maxLines:2,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(fontSize:11,color:VColors.muted)),
                ])),
                IconButton(
                  key:const Key('save-patient-record'),
                  tooltip:'Enregistrer le dossier dans VISCERA',
                  onPressed:() async {
                    try {
                      await appStore.saveClinical(p);
                      if(mounted)_notice('Dossier enregistré dans VISCERA.');
                    } catch (_) {
                      if(mounted)_notice('Enregistrement impossible. Vérifiez les modifications.');
                    }
                  },
                  icon:const Icon(Icons.save_outlined,color:VColors.ink)),
              ]),
            ),
          ],
          const SizedBox(height:11),
          VCard(
            color:VColors.softMint,
            padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
            child:HospitalizationDayCounter(
              patient:p,showStartDate:true,compact:true)),
          const SizedBox(height:11),
          Row(children:[
            Expanded(child:_factCard(Icons.bed_outlined,'Unité / box',
              p.currentUnit.isEmpty ? 'Non attribué' : p.currentBox.isEmpty
                ? '${p.currentUnit} · Box à préciser' : '${p.currentUnit} · ${p.currentBox}',
              onTap:(p.stage==CaseStage.discharged||p.isOmitted)?null:_changeBed)),
            const SizedBox(width:9),
            Expanded(child:_factCard(Icons.person_outline_rounded,'Responsable',
              (p.stage==CaseStage.inTheatre || p.isPostOp
                ? (appStore.responsibleById(p.blockResponsibleId)?.name ??
                   appStore.responsibleById(p.professorId)?.name)
                : (appStore.responsibleById(p.professorId)?.name ??
                   appStore.responsibleById(p.blockResponsibleId)?.name)) ??
                (p.programSurgeon.isNotEmpty?p.programSurgeon:'À attribuer'),
              onTap:(p.stage==CaseStage.discharged||p.isOmitted)?null:_editResponsible)),
          ]),
          const SizedBox(height:11),
          SizedBox(width:double.infinity,child:FilledButton.tonalIcon(
            key:const Key('open-clinical-score-forms'),
            onPressed:()=>Navigator.push(context,MaterialPageRoute(
              builder:(_)=>ClinicalScoresPage(patient:p))),
            icon:const Icon(Icons.assignment_outlined),
            label:const Text('Scores cliniques et bilans biologiques'),
          )),
          if(p.physicallyAdmitted && p.stage!=CaseStage.inTheatre &&
              !p.isOmitted)...[
            const SizedBox(height:8),
            SizedBox(width:double.infinity,child:OutlinedButton.icon(
              key:const Key('transfer-patient-service'),
              onPressed:_transferService,
              icon:const Icon(Icons.swap_horiz_rounded),
              label:const Text('Transférer vers un autre service'),
            )),
          ],
          if(p.dischargeDue||p.stage==CaseStage.dischargeReady)...[
            const SizedBox(height:11),
            VCard(color:VColors.orangeSoft,padding:const EdgeInsets.all(14),
              child:const Row(children:[
                Icon(Icons.notifications_active_outlined,color:Color(0xFFA45633)),
                SizedBox(width:10),
                Expanded(child:Text('Sortie potentielle : évaluation et validation médicales nécessaires.',
                  style:TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
              ])),
          ],
          SectionHeading('Parcours hospitalier'),
          VCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            // La vue principale montre seulement les données utiles à l'instant.
            _line(Icons.medical_services_outlined,'Intervention',p.effectiveProcedure),
            const Divider(height:22),
            _line(Icons.event_rounded,'Date du bloc',_format(p.blockAt)),
            if(p.stage!=CaseStage.discharged && !p.isOmitted)...[
              const SizedBox(height:12),
              Wrap(spacing:8,runSpacing:8,children:[
                OutlinedButton.icon(
                  key:const Key('edit-surgery-details'),
                  onPressed:_editSurgery,
                  icon:const Icon(Icons.edit_note_outlined,size:18),
                  label:const Text('Modifier type de chirurgie / intervention')),
              ]),
            ],
            const Divider(height:26),
            ExpansionTile(
              key:const Key('patient-stay-details'),
              initiallyExpanded:false,
              tilePadding:EdgeInsets.zero,
              childrenPadding:const EdgeInsets.only(top:10),
              title:const Text('Informations complémentaires du séjour',
                style:TextStyle(fontSize:13,fontWeight:FontWeight.w800,color:VColors.ink)),
              subtitle:const Text('Admission, programme, chirurgie et sortie prévue',
                style:TextStyle(fontSize:12,color:VColors.muted)),
              children:[
                _line(Icons.login_rounded,'Admission',p.admissionTiming),
                if(p.consultationAt!=null)...[
                  const Divider(height:22),
                  _line(Icons.event_outlined,'Consultation',_format(p.consultationAt!)),
                ],
                if(p.fromManualAdmission && p.origin=='Consultation')...[
                  const Divider(height:22),
                  _line(Icons.link_outlined,'Programme',
                    p.linkedProgramEntryId==null
                      ? 'À rapprocher du programme opératoire'
                      : 'Associé au dossier de consultation'),
                  if(p.linkedProgramEntryId!=null && p.programRoom.isNotEmpty)...[
                    const SizedBox(height:6),
                    Text('Salle ' + p.programRoom + ' · ' + p.programScheduledTime + ' · ' + p.programSurgeon,
                      style:const TextStyle(fontSize:12,color:VColors.muted)),
                  ],
                  if(p.linkedProgramEntryId==null &&
                      p.stage!=CaseStage.discharged && !p.isOmitted)...[
                    const SizedBox(height:8),
                    OutlinedButton.icon(onPressed:_reconcileBloc,
                      icon:const Icon(Icons.link),
                      label:const Text('Rapprocher avec le programme du bloc')),
                  ],
                ],
                const Divider(height:22),
                _line(Icons.category_outlined,'Type de chirurgie',p.standardizedSurgeryType),
                if(p.procedureOverride.trim().isNotEmpty)...[
                  const SizedBox(height:8),
                  Text('Programme original : ${p.procedure}',
                    style:const TextStyle(fontSize:11,color:VColors.muted)),
                ],
                const Divider(height:22),
                _line(Icons.event_available_outlined,'Sortie estimée',
                  p.dischargeReviewAt==null?'Admission à confirmer':
                    '${_date(p.expectedDischargeAt)} · proposition à vérifier'),
              ],
            ),
          ])),
          if(p.serviceTransfers.isNotEmpty)...[
            const SizedBox(height:10),
            VCard(child:ExpansionTile(
              key:const Key('patient-service-transfer-history'),
              initiallyExpanded:false,
              tilePadding:EdgeInsets.zero,
              title:Text('Historique des transferts · ${p.serviceTransfers.length}',
                style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800)),
              children:[
                for(final transfer in p.serviceTransfers.reversed.take(20))
                  ListTile(
                    dense:true,
                    leading:const Icon(Icons.swap_horiz_rounded),
                    title:Text('${transfer['fromUnit'] ?? '—'} → '
                      '${transfer['toUnit'] ?? '—'}'),
                    subtitle:Text(
                      'Box : ${transfer['fromBox'] ?? '—'} → '
                      '${(transfer['toBox'] ?? '').toString().isEmpty ? 'à préciser' : transfer['toBox']}'
                      '\\nMotif : ${transfer['reason'] ?? '—'}'
                      '\\nPar : ${transfer['by'] ?? '—'} · '
                      '${DateTime.tryParse((transfer['at'] ?? '').toString())?.toLocal().toString().substring(0,16) ?? '—'}'),
                  ),
              ],
            )),
          ],
          SectionHeading('Clinique et observations',trailing:Row(
            mainAxisSize:MainAxisSize.min,children:[
              IconButton(onPressed:_editIdentity,
                tooltip:'Modifier identité et couverture',
                icon:const Icon(Icons.badge_outlined,size:20)),
              IconButton(onPressed:_editClinical,
                tooltip:'Modifier le dossier clinique',
                icon:const Icon(Icons.edit_outlined,size:20)),
            ])),
          VCard(
            padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),
            child:ExpansionTile(
              key:const Key('patient-admission-observation'),
              initiallyExpanded:false,
              tilePadding:EdgeInsets.zero,
              childrenPadding:const EdgeInsets.only(bottom:12),
              expandedAlignment:Alignment.topLeft,
              title:const Text('Observation clinique à l’admission',
                style:TextStyle(fontSize:14,fontWeight:FontWeight.w800,
                  color:VColors.ink)),
              subtitle:Text(p.hospitalizationStartDate==null
                ? 'Évaluation clinique initiale'
                : 'Entrée · '+_date(p.hospitalizationStartDate!),
                style:const TextStyle(fontSize:12,color:VColors.muted)),
              children:[
                // Étirement explicite : ExpansionTile centre par défaut
                // ses enfants à leur largeur intrinsèque sur écran Web.
                SizedBox(width:double.infinity,child:Column(
                  crossAxisAlignment:CrossAxisAlignment.stretch,
                  children:[
                    const Divider(height:18,color:VColors.line),
                    _clinical('Motif d’admission',p.motive),
                    if(p.history.trim().isNotEmpty)
                      _clinical('Interrogatoire',p.history),
                    if(p.exam.trim().isNotEmpty)
                      _clinical('Examen clinique initial',p.exam),
                    if(p.investigations.trim().isNotEmpty)
                      _clinical('Examens complémentaires initiaux',p.investigations),
                    if(p.labs.trim().isNotEmpty)
                      _clinical('Bilans à l’admission',p.labs),
                    if(p.immediatePlan.trim().isNotEmpty)
                      _clinical('Conduite à tenir initiale',p.immediatePlan),
                    if(admissionObservationFor(p)!=null)...[
                      const Divider(height:20,color:VColors.line),
                      const Text('Suivi daté du jour d’entrée',
                        style:TextStyle(fontWeight:FontWeight.w800,
                          fontSize:12,color:VColors.ink)),
                      const SizedBox(height:9),
                      DailyObservationCard(patient:p,
                        observation:admissionObservationFor(p)!,
                        isAdmission:true),
                    ],
                  ],
                )),
              ],
            ),
          ),
          const SizedBox(height:10),
          VCard(
            padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),
            child:ExpansionTile(
              key:const Key('patient-daily-observations'),
              initiallyExpanded:true,
              tilePadding:EdgeInsets.zero,
              childrenPadding:const EdgeInsets.only(bottom:12),
              expandedAlignment:Alignment.topLeft,
              title:Row(children:[
                const Expanded(child:Text('Observations cliniques actuelles',
                  style:TextStyle(fontSize:14,fontWeight:FontWeight.w800,
                    color:VColors.ink))),
                const SizedBox(width:8),
                VTag(currentObservationsFor(p).length.toString(),highlight:true),
              ]),
              subtitle:Text(currentObservationsFor(p).isEmpty
                  ? 'Aucune observation après l’admission'
                  : 'Dernière : '+_date(currentObservationsFor(p).first.date),
                  style:const TextStyle(fontSize:12,color:VColors.muted)),
              children:[
                SizedBox(width:double.infinity,child:Column(
                  crossAxisAlignment:CrossAxisAlignment.stretch,
                  children:[
                    const Divider(height:18,color:VColors.line),
                    if(currentObservationsFor(p).isEmpty)
                      Container(
                        padding:const EdgeInsets.all(14),
                        decoration:BoxDecoration(
                          color:VColors.background,
                          borderRadius:BorderRadius.circular(12)),
                        child:const Text(
                          'Aucune note quotidienne. Utilisez « Observation quotidienne » '
                          'pour enregistrer le prochain examen.',
                          style:TextStyle(fontSize:12,color:VColors.muted))),
                    for(final note in currentObservationsFor(p))
                      Padding(
                        padding:const EdgeInsets.only(bottom:10),
                        child:DailyObservationCard(patient:p,observation:note)),
                    if(p.dailyObservations.any((note)=>!note.fullyReported))
                      Padding(
                        padding:const EdgeInsets.only(top:3,bottom:6),
                        child:Row(children:[
                          const Icon(Icons.info_outline_rounded,size:16,
                            color:VColors.muted),
                          const SizedBox(width:7),
                          Expanded(child:Text(
                            p.dailyObservations.where((note)=>!note.fullyReported)
                            .length.toString()+
                            ' observation(s) à reporter dans Magica/Sillage',
                            style:const TextStyle(fontSize:11,color:VColors.muted))),
                        ])),
                  ],
                )),
              ],
            ),
          ),
          if(p.stage!=CaseStage.scheduled && p.stage!=CaseStage.notAdmitted)...[
            const SizedBox(height:12),
            SpecialistOpinionsCard(
              patient:p,readOnly:p.stage==CaseStage.discharged),
          ],
          const SizedBox(height:14),
          SectionHeading('Suivi biologique · CRP'),
          CrpTrendCard(patient:p,compact:true),
          const SizedBox(height:12),
          SectionHeading('Documents et vérifications'),
          VCard(child:ExpansionTile(
            key:const Key('patient-admission-documents'),
            initiallyExpanded:p.stage==CaseStage.preoperative ||
              p.stage==CaseStage.scheduled,
            tilePadding:EdgeInsets.zero,
            title:const Text('Admission et préparation opératoire',
              style:TextStyle(fontSize:13,fontWeight:FontWeight.w800,color:VColors.ink)),
            subtitle:Text('${p.completedCount(ClinicalDocuments.admission)}/${ClinicalDocuments.admission.length} documents d’admission vérifiés',
              style:const TextStyle(fontSize:12,color:VColors.muted)),
            children:[
              DocumentChecklist(patient:p,title:'Documents à l’admission',
                requirements:ClinicalDocuments.admission),
              const SizedBox(height:12),
              if(p.stage==CaseStage.scheduled || p.stage==CaseStage.preoperative ||
                 p.stage==CaseStage.inTheatre)
                PreoperativeReadinessCard(patient:p,
                  onChanged:()=>appStore.refresh(changed:p),
                  readOnly:p.stage==CaseStage.discharged),
            ],
          )),
          if(p.stage==CaseStage.inTheatre || p.isPostOp ||
              p.stage==CaseStage.discharged)...[
            const SizedBox(height:12),
            VCard(child:ExpansionTile(
              key:const Key('patient-postoperative-documents'),
              initiallyExpanded:false,
              tilePadding:EdgeInsets.zero,
              title:const Text('Documents postopératoires',
                style:TextStyle(fontSize:13,fontWeight:FontWeight.w800,color:VColors.ink)),
              subtitle:Text(p.completedCount(ClinicalDocuments.postBlock).toString() +
                '/' + ClinicalDocuments.postBlock.length.toString() + ' documents vérifiés',
                style:const TextStyle(fontSize:12,color:VColors.muted)),
              children:[
                DocumentChecklist(patient:p,title:'Vérifications postopératoires',
                  requirements:ClinicalDocuments.postBlock,
                  readOnly:p.stage==CaseStage.discharged),
              ],
            )),
          ],
          if(p.stage==CaseStage.inTheatre || p.isPostOp ||
              p.stage==CaseStage.discharged) ...[
            const SizedBox(height:12),
            SectionHeading('Événements postopératoires'),
            PostoperativeEventsCard(patient:p,
              readOnly:p.stage==CaseStage.discharged),
          ],
          if(p.stage!=CaseStage.notAdmitted)...[
            SectionHeading('Actions de prise en charge'),
            _actions(),
          ],
          if(p.fromBlocProgram && p.stage!=CaseStage.discharged)...[
            const SizedBox(height:18),
            const Divider(),
            OutlinedButton.icon(
              key:Key(p.isOmitted?'restore-program-admission':'omit-program-admission'),
              onPressed:()=>_setProgramOmitted(!p.isOmitted),
              icon:Icon(p.isOmitted?Icons.undo_rounded:Icons.person_off_outlined),
              label:Text(p.isOmitted
                ? 'Rétablir l’admission automatique'
                : 'Le patient n’a pas été réellement admis'),
              style:OutlinedButton.styleFrom(
                foregroundColor:p.isOmitted?VColors.ink:const Color(0xFFB4232F),
                minimumSize:const Size(double.infinity,48)),
            ),
            const SizedBox(height:12),
          ],
        ],
      ),
    ),
  );

  Widget _factCard(IconData icon,String label,String value,{VoidCallback? onTap})=>VCard(
    onTap:onTap,padding:const EdgeInsets.all(13),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Icon(icon,color:VColors.ink,size:20),
        if(onTap!=null)...[
          const Spacer(),
          const Icon(Icons.edit_outlined,color:VColors.muted,size:16),
        ],
      ]),
      const SizedBox(height:7),
      Text(label,style:const TextStyle(fontSize:11,color:VColors.muted)),
      const SizedBox(height:4),
      Text(value,maxLines:2,overflow:TextOverflow.ellipsis,
        style:const TextStyle(fontSize:12.5,fontWeight:FontWeight.w800,color:VColors.ink)),
    ]),
  );

  Widget _line(IconData icon,String label,String value)=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:VColors.muted,size:18),const SizedBox(width:11),SizedBox(width:90,child:Text(label,style:const TextStyle(fontSize:12,color:VColors.muted))),Expanded(child:Text(value,style:const TextStyle(fontSize:12.8,fontWeight:FontWeight.w700)))]);
  /// Même alignement que les observations quotidiennes : lecture verticale,
  /// texte sur toute la largeur, sans colonne vide sur les écrans Web.
  Widget _clinical(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 12, 12),
      decoration: BoxDecoration(
        color: VColors.background,
        borderRadius: BorderRadius.circular(11),
        border: const Border(
          left: BorderSide(color: VColors.mint, width: 3),
          top: BorderSide(color: VColors.line),
          right: BorderSide(color: VColors.line),
          bottom: BorderSide(color: VColors.line),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(
          fontSize: 10, letterSpacing: .7,
          fontWeight: FontWeight.w800, color: VColors.muted)),
        const SizedBox(height: 5),
        Text(value.trim().isEmpty ? 'Non renseigné' : value.trim(),
          softWrap: true,
          style: TextStyle(fontSize: 13.5, height: 1.4,
            color: value.trim().isEmpty ? VColors.muted : VColors.ink)),
      ]),
    ),
  );
  Widget _envelope()=>VCard(color:p.confidentialEnvelopeDone?VColors.softMint:VColors.orangeSoft,child:Row(children:[Icon(p.confidentialEnvelopeDone?Icons.check_circle_outline_rounded:Icons.mark_email_unread_outlined,color:VColors.ink),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.isFar?'Pli confidentiel — FAR':'Pli confidentiel',style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:3),Text(p.confidentialEnvelopeDone?'Marqué comme effectué':'À créer / à demander',style:const TextStyle(fontSize:12,color:VColors.muted))])),Switch(value:p.confidentialEnvelopeDone,onChanged:(_)=>appStore.toggleEnvelope(p))]));
  Widget _actions()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    if(!p.fromBlocProgram && p.isPostopReviewDay(DateTime.now()))ElevatedButton.icon(
      onPressed:_confirmPostopDay,
      icon:const Icon(Icons.how_to_reg_outlined),
      label:const Text('Confirmer admission postopératoire réelle')),
    if(!p.fromBlocProgram && p.stage==CaseStage.scheduled)ElevatedButton.icon(onPressed:_confirmAdmission,icon:const Icon(Icons.how_to_reg_outlined),label:const Text('Confirmer l’admission avant le bloc')),
    if(p.stage==CaseStage.preoperative)...[
      if(!p.canConfirmTheatreEntry)...[
        VCard(key:const Key('theatre-missing-documents'),
          color:VColors.orangeSoft,padding:const EdgeInsets.all(12),
          child:Row(children:[
            const Icon(Icons.fact_check_outlined,color:VColors.ink),
            const SizedBox(width:10),
            Expanded(child:Text(
              'Documents d’admission à vérifier : ${p.completedCount(ClinicalDocuments.admission)}/${ClinicalDocuments.admission.length}. Complétez la checklist ci-dessus.',
              style:const TextStyle(fontSize:12,color:VColors.ink))),
          ])),
        const SizedBox(height:9),
      ],
      ElevatedButton.icon(
        key:const Key('confirm-theatre-entry'),
        onPressed:p.canConfirmTheatreEntry?_startTheatre:null,
        icon:const Icon(Icons.medical_services_outlined),
        label:const Text('Confirmer l’entrée au bloc')),
    ],
    if(p.stage==CaseStage.inTheatre)ElevatedButton.icon(onPressed:_finishTheatre,icon:const Icon(Icons.check_rounded),label:const Text('Fin du bloc → postopératoire')),
    if(p.stage==CaseStage.postoperative)ElevatedButton.icon(onPressed:()=>appStore.markForDischarge(p),icon:const Icon(Icons.assignment_turned_in_outlined),label:const Text('Préparer la sortie')),
    if(p.stage==CaseStage.dischargeReady)ElevatedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>DischargePage(patient:p))),icon:const Icon(Icons.description_outlined),label:const Text('Documents et validation de sortie')),
    if(p.stage==CaseStage.discharged)OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>DischargePage(patient:p,readOnly:true))),icon:const Icon(Icons.file_open_outlined),label:const Text('Consulter les documents de sortie')),
  ]);
  Future<void> _editResponsible() async {
    if(p.stage==CaseStage.discharged || p.isOmitted) return;
    await showModalBottomSheet<void>(
      context:context,
      useSafeArea:true,
      showDragHandle:true,
      builder:(sheetContext)=>Padding(
        padding:const EdgeInsets.fromLTRB(16,4,16,24),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text('Modifier le responsable',
            style:Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height:12),
          ListTile(
            key:const Key('choose-admission-responsible'),
            leading:const Icon(Icons.person_outline_rounded,color:VColors.ink),
            title:const Text('Responsable de l’admission'),
            subtitle:Text(appStore.responsibleById(p.professorId)?.name??'À attribuer'),
            trailing:const Icon(Icons.edit_outlined),
            onTap:(){
              Navigator.pop(sheetContext);
              _changeProfessor();
            }),
          ListTile(
            key:const Key('choose-block-responsible'),
            leading:const Icon(Icons.medical_services_outlined,color:VColors.ink),
            title:const Text('Responsable du bloc'),
            subtitle:Text(appStore.responsibleById(p.blockResponsibleId)?.name??
              (p.programSurgeon.isEmpty?'À attribuer':p.programSurgeon)),
            trailing:const Icon(Icons.edit_outlined),
            onTap:(){
              Navigator.pop(sheetContext);
              _changeBlockDoctor();
            }),
        ])));
  }

  Future<void> _changeBlockDoctor() async {
    final doctors=appStore.responsibleOptions(forEmergencies:false);
    if(doctors.isEmpty){_notice('Aucun médecin du service disponible.');return;}
    String? selected=appStore.responsibleById(p.blockResponsibleId)!=null
      ? p.blockResponsibleId : null;
    final reason=TextEditingController();
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,showDragHandle:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>Padding(
        padding:EdgeInsets.fromLTRB(20,10,20,
          MediaQuery.of(ctx).viewInsets.bottom+22),
        child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Responsable du bloc',
              style:Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height:14),
            DropdownButtonFormField<String>(
              value:selected,
              isExpanded:true,
              decoration:const InputDecoration(
                labelText:'Médecin opérateur responsable'),
              items:doctors.map((doc)=>DropdownMenuItem(
                value:doc.id,
                child:Text(doc.name,overflow:TextOverflow.ellipsis))).toList(),
              onChanged:(value)=>update(()=>selected=value)),
            const SizedBox(height:12),
            TextField(controller:reason,maxLines:2,
              decoration:const InputDecoration(
                labelText:'Motif du changement (obligatoire)')),
            const SizedBox(height:14),
            SizedBox(width:double.infinity,
              child:FilledButton(
                onPressed:(){
                  if(selected==null || reason.text.trim().isEmpty){
                    _notice('Choisissez un médecin et précisez le motif.');
                    return;
                  }
                  appStore.changeBlockResponsible(p,selected!,reason.text);
                  Navigator.pop(ctx);
                },
                child:const Text('Enregistrer le responsable du bloc'))),
          ]))));
    reason.dispose();
  }

  Future<void> _changeProfessor() async {
    if(appStore.responsibleOptions(forEmergencies:p.origin=='Urgences').isEmpty){_notice('Ajoutez d’abord les médecins au planning.');return;}
    String? selected=p.professorId;
    final reason=TextEditingController();
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>Padding(
      padding:EdgeInsets.fromLTRB(20,8,20,MediaQuery.of(ctx).viewInsets.bottom+22),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Responsable de l’admission',style:Theme.of(ctx).textTheme.titleLarge),const SizedBox(height:16),
        DropdownButtonFormField<String>(value:appStore.responsibleById(selected)!=null?selected:null,isExpanded:true,decoration:const InputDecoration(labelText:'Responsable de l’admission'),items:appStore.responsibleOptions(forEmergencies:p.origin=='Urgences').map((x)=>DropdownMenuItem(value:x.id,child:Text(x.name,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>update(()=>selected=v)),const SizedBox(height:12),
        TextField(controller:reason,maxLines:2,decoration:const InputDecoration(labelText:'Motif du changement (obligatoire)')),
        const SizedBox(height:14),SizedBox(width:double.infinity,child:ElevatedButton(onPressed:(){if(selected==null||reason.text.trim().isEmpty){_notice('Sélectionnez un médecin et renseignez le motif.');return;}appStore.changeProfessor(p,selected!,reason.text);Navigator.pop(ctx);},child:const Text('Enregistrer la modification'))),
      ]))));
    reason.dispose();
  }
  Future<void> _startTheatre() async {
    if(!p.canConfirmTheatreEntry) {
      _notice('Vérifiez les documents d’admission avant de confirmer l’entrée au bloc.');
      return;
    }
    if(await showConfirmation(context,title:'Entrée au bloc',
      message:'Les documents d’admission ont été vérifiés. Confirmer l’entrée réelle au bloc de ${p.name} ? La préparation anesthésique et médicale doit également être validée par l’équipe.',
      action:'Confirmer l’entrée au bloc') && p.canConfirmTheatreEntry) {
      appStore.startTheatre(p);
    }
  }
  Future<void> _finishTheatre() async {
    final conflict=appStore.conflictingBox(p.afterUnit,p.afterBox,exceptPatientId:p.id);
    if(conflict!=null){_notice('Box postopératoire occupé par ${conflict.name}. Modifiez l’affectation avant de confirmer.');return;}
    if(await showConfirmation(context,title:'Fin du bloc',message:'Retour prévu à ${p.afterUnit} / Box ${p.afterBox}. Les documents manquants resteront signalés dans le dossier postopératoire.',action:'Valider'))appStore.finishTheatre(p);
  }
  void _notice(String text)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));

  /// Transfert effectif entre services du même établissement, distinct
  /// d'une simple modification de box. La date d'admission ne change pas.
  Future<void> _transferService() async {
    if(!p.physicallyAdmitted || p.stage==CaseStage.inTheatre ||
       p.stage==CaseStage.discharged || p.isOmitted ||
       (!p.fromBlocProgram && !p.fromManualAdmission)) {
      _notice('Le transfert nécessite un séjour actif et un dossier partagé.');
      return;
    }
    if(p.currentUnit.trim().isEmpty) {
      _notice('Renseignez d’abord le service actuel du patient.');
      return;
    }

    String? selectedService;
    final otherService = TextEditingController();
    final targetBox = TextEditingController();
    final reason = TextEditingController();
    final navigationInset = MediaQuery.of(context).viewPadding.bottom;
    final details = await showModalBottomSheet<List<String>>(
      context:context, isScrollControlled:true, useSafeArea:true,
      showDragHandle:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh) {
        final media=MediaQuery.of(ctx);
        return Padding(
          padding:EdgeInsets.fromLTRB(20,8,20,
            media.viewInsets.bottom>0
              ? media.viewInsets.bottom+24 : navigationInset+28),
          child:ConstrainedBox(
            constraints:BoxConstraints(
              maxHeight:(media.size.height-media.viewInsets.bottom-
                navigationInset-90).clamp(210.0,media.size.height).toDouble()),
            child:SingleChildScrollView(child:Column(
              mainAxisSize:MainAxisSize.min,
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text('Transfert vers un autre service',
                  style:Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height:6),
                Text('Service actuel : ${p.currentUnit}'
                  '${p.currentBox.isEmpty ? '' : ' · Box ${p.currentBox}'}',
                  style:const TextStyle(fontSize:12,color:VColors.muted)),
                const SizedBox(height:10),
                const Text('Le dossier et ses observations seront conservés. '
                  'Ce transfert ne constitue pas une sortie hospitalière.',
                  style:TextStyle(fontSize:12)),
                const SizedBox(height:15),
                DropdownButtonFormField<String>(
                  key:const Key('transfer-destination-service'),
                  isExpanded:true,
                  initialValue:selectedService,
                  decoration:const InputDecoration(
                    labelText:'Service destinataire *',
                    border:OutlineInputBorder()),
                  items:[
                    ...hospitalUnits.map((unit)=>DropdownMenuItem<String>(
                      value:unit.code,
                      child:Text(unit.label,overflow:TextOverflow.ellipsis))),
                    const DropdownMenuItem<String>(
                      value:'__OTHER_SERVICE__',
                      child:Text('Autre service (à préciser)')),
                  ],
                  onChanged:(value)=>refresh(()=>selectedService=value)),
                if(selectedService=='__OTHER_SERVICE__')...[
                  const SizedBox(height:12),
                  TextField(
                    key:const Key('transfer-other-service'),
                    controller:otherService,
                    maxLength:100,
                    decoration:const InputDecoration(
                      labelText:'Nom du service destinataire *',
                      border:OutlineInputBorder()),
                  ),
                ],
                const SizedBox(height:12),
                TextField(
                  key:const Key('transfer-destination-box'),
                  controller:targetBox,
                  maxLength:30,
                  decoration:const InputDecoration(
                    labelText:'Numéro du box (facultatif)',
                    border:OutlineInputBorder()),
                ),
                const SizedBox(height:12),
                TextField(
                  key:const Key('transfer-reason'),
                  controller:reason,
                  maxLength:400, minLines:2, maxLines:4,
                  decoration:const InputDecoration(
                    labelText:'Motif du transfert *',
                    border:OutlineInputBorder()),
                ),
                const SizedBox(height:15),
                SizedBox(width:double.infinity,child:FilledButton.icon(
                  key:const Key('confirm-service-transfer-form'),
                  icon:const Icon(Icons.swap_horiz_rounded),
                  onPressed:(){
                    final service=selectedService=='__OTHER_SERVICE__'
                      ? otherService.text.trim() : (selectedService??'');
                    if(service.length<2 || reason.text.trim().isEmpty) {
                      _notice('Précisez le service destinataire et le motif.');
                      return;
                    }
                    if(service.toLowerCase()==p.currentUnit.trim().toLowerCase()){
                      _notice('Même service : utilisez Modifier l’unité / le box.');
                      return;
                    }
                    Navigator.pop(ctx,[service,targetBox.text.trim(),
                      reason.text.trim()]);
                  },
                  label:const Text('Vérifier le transfert'),
                )),
                const SizedBox(height:8),
              ],
            )),
          ),
        );
      }),
    );
    otherService.dispose();
    targetBox.dispose();
    reason.dispose();
    if(!mounted || details==null)return;
    final destination=details[0], box=details[1], reasonText=details[2];
    final conflict=appStore.conflictingBox(destination,box,
      exceptPatientId:p.id);
    if(conflict!=null) {
      _notice('Box déjà occupé par ${conflict.name}. Transfert non enregistré.');
      return;
    }
    final confirmed=await showConfirmation(context,
      title:'Confirmer le transfert',
      message:'Transférer ${p.name} de ${p.currentUnit} vers $destination'
        '${box.isEmpty ? ' (box à préciser)' : ' / Box $box'} ? '
        'Le dossier et l’historique restent conservés.',
      action:'Confirmer le transfert');
    if(!mounted || !confirmed)return;
    // Sauvegarde sécurisée avec retour à l'état précédent en cas d'échec.
    final beforeUnit=p.beforeUnit, beforeBox=p.beforeBox;
    final afterUnit=p.afterUnit, afterBox=p.afterBox;
    final fromUnit=p.currentUnit, fromBox=p.currentBox;
    final postoperative=p.isPostOp;
    if(postoperative){
      p.afterUnit=destination;
      p.afterBox=box;
    }else{
      final afterWasSame=p.afterUnit==p.beforeUnit &&
        p.afterBox==p.beforeBox;
      p.beforeUnit=destination;
      p.beforeBox=box;
      if(afterWasSame) {
        p.afterUnit=destination;
        p.afterBox=box;
      }
    }
    p.serviceTransfers.add({
      'fromUnit':fromUnit,
      'fromBox':fromBox,
      'toUnit':destination,
      'toBox':box,
      'reason':reasonText,
      'at':DateTime.now().toUtc().toIso8601String(),
      'by':appStore.activeLocalProfile?.name??'Médecin non identifié',
      'byId':appStore.activeLocalProfile?.id??'',
      'stage':p.stage.name,
    });
    appStore.refresh();
    try {
      await appStore.saveClinical(p);
      if(mounted){
        appStore.refresh();
        _notice('Transfert vers $destination enregistré dans le dossier.');
      }
    }catch(_){
      p.beforeUnit=beforeUnit;p.beforeBox=beforeBox;
      p.afterUnit=afterUnit;p.afterBox=afterBox;
      p.serviceTransfers.removeLast();
      appStore.refresh();
      if(mounted)_notice('Transfert non enregistré. Affectation précédente conservée.');
    }
  }

  Future<void> _changeBed() async {
    final postoperative = p.isPostOp || p.stage == CaseStage.inTheatre;
    String current = postoperative ? p.afterUnit : p.beforeUnit;
    final controller = TextEditingController(
      text: postoperative ? p.afterBox : p.beforeBox,
    );
    // Capturer l'espace de navigation depuis la page : showModalBottomSheet
    // peut supprimer le padding bas de son propre MediaQuery sur Android.
    final navigationInset = MediaQuery.of(context).viewPadding.bottom;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) {
          final media = MediaQuery.of(sheetContext);
          final keyboardInset = media.viewInsets.bottom;
          final bottomInset = keyboardInset > 0
              ? keyboardInset + 22
              : navigationInset + 28;
          final contentHeight = (media.size.height -
              keyboardInset - navigationInset - 95)
              .clamp(180.0, media.size.height).toDouble();
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: contentHeight),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modifier l’unité / le box',
                      style: Theme.of(sheetContext).textTheme.titleLarge),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: hospitalUnits.any((u) => u.code == current)
                          ? current : null,
                      decoration: const InputDecoration(labelText: 'Unité'),
                      items: hospitalUnits.map((u) => DropdownMenuItem(
                        value: u.code, child: Text(u.code),
                      )).toList(),
                      onChanged: (value) {
                        if (value != null) refresh(() => current = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Numéro du box',
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(width: double.infinity, child: FilledButton(
                      key: const Key('save-bed-assignment'),
                      onPressed: () {
                        final box = controller.text.trim();
                        if (current.isEmpty || box.isEmpty) {
                          _notice('Précisez l’unité et le numéro de box.');
                          return;
                        }
                        final conflict = appStore.conflictingBox(
                          current, box, exceptPatientId: p.id,
                        );
                        if (conflict != null) {
                          _notice('Box déjà occupé par ${conflict.name}.');
                          return;
                        }
                        if (postoperative) {
                          // Le box précédent reste dans l'historique interne.
                          p.afterUnit = current;
                          p.afterBox = box;
                        } else {
                          // Un transfert préopératoire ne doit pas rétablir un
                          // ancien box à la fin du bloc si aucun autre n'était prévu.
                          final sameAsFuture=p.afterUnit==p.beforeUnit &&
                            p.afterBox==p.beforeBox;
                          p.beforeUnit = current;
                          p.beforeBox = box;
                          if(sameAsFuture){p.afterUnit=current;p.afterBox=box;}
                        }
                        appStore.refresh(changed: p);
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Enregistrer l’affectation'),
                    )),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
  }

  Future<void> _editSurgery() async {
    if (p.stage == CaseStage.discharged || p.isOmitted) return;
    final type = TextEditingController(
      text: p.standardizedSurgeryType == 'À préciser'
          ? '' : p.standardizedSurgeryType,
    );
    final procedure = TextEditingController(text: p.effectiveProcedure);
    final navigationInset = MediaQuery.of(context).viewPadding.bottom;
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20, 8, 20,
            media.viewInsets.bottom > 0
                ? media.viewInsets.bottom + 24 : navigationInset + 28,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (media.size.height - media.viewInsets.bottom -
                  navigationInset - 90).clamp(190.0, media.size.height)
                  .toDouble(),
            ),
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modifier la chirurgie',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('La correction sera enregistrée dans le dossier clinique. '
                    'L’intitulé original du programme opératoire restera conservé.',
                    style: TextStyle(fontSize: 12, color: VColors.muted)),
                const SizedBox(height: 15),
                TextField(
                  key: const Key('surgery-type-input'),
                  controller: type,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Type de chirurgie',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('procedure-correction-input'),
                  controller: procedure,
                  maxLength: 300,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Intervention chirurgicale',
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(width: double.infinity, child: FilledButton(
                  key: const Key('save-surgery-details'),
                  onPressed: () {
                    if (type.text.trim().length < 2 ||
                        procedure.text.trim().length < 3) {
                      _notice('Renseignez le type de chirurgie et l’intervention.');
                      return;
                    }
                    Navigator.pop(ctx, [type.text.trim(), procedure.text.trim()]);
                  },
                  child: const Text('Enregistrer la chirurgie'),
                )),
                const SizedBox(height: 6),
              ],
            )),
          ),
        );
      },
    );
    type.dispose();
    procedure.dispose();
    if (!mounted || result == null) return;
    final oldType = p.surgeryType;
    final oldOverride = p.procedureOverride;
    p.surgeryType = result[0];
    p.procedureOverride = result[1] == p.procedure ? '' : result[1];
    setState(() {});
    try {
      await appStore.saveClinical(p);
      if (!mounted) return;
      appStore.refresh();
      _notice('Type de chirurgie et intervention enregistrés.');
    } catch (_) {
      p.surgeryType = oldType;
      p.procedureOverride = oldOverride;
      if (!mounted) return;
      appStore.refresh();
      setState(() {});
      _notice('Sauvegarde impossible : les informations précédentes ont été conservées.');
    }
  }

  Future<void> _editIdentity() async {
    final age = TextEditingController(text:p.age == '—' ? '' : p.age);
    final insurance = TextEditingController(
      text:p.insurance == 'À préciser' ? '' : p.insurance);
    final days = TextEditingController(
      text:p.expectedDays == 0 ? '' : p.expectedDays.toString());
    DateTime? consultation = p.consultationAt;
    DateTime? born = p.birthDate;
    final surgical = TextEditingController(text:p.surgeryType);
    await showModalBottomSheet<void>(
      context:context, isScrollControlled:true, showDragHandle:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>Padding(
        padding:EdgeInsets.fromLTRB(20,10,20,MediaQuery.of(ctx).viewInsets.bottom+24),
        child:ConstrainedBox(
          constraints:BoxConstraints(maxHeight:MediaQuery.of(ctx).size.height*.75),
          child:SingleChildScrollView(child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              const Text('Compléter le dossier patient',
                style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
              const SizedBox(height:6),
              Text('Provenance : ${p.origin}. Le nom et l’intervention d’origine ne sont pas modifiés.',
                style:TextStyle(fontSize:12,color:VColors.muted)),
              const SizedBox(height:16),
              OutlinedButton.icon(icon:const Icon(Icons.cake_outlined),
                label:Text(born==null?'Renseigner la date de naissance'
                  :'Naissance : ${_date(born!)}'),
                onPressed:p.linkedProgramEntryId!=null ? null : ()async{
                  final now=DateTime.now();
                  final picked=await showDatePicker(context:ctx,
                    initialDate:born??DateTime(now.year-35,now.month,now.day),
                    firstDate:DateTime(1900),lastDate:now);
                  if(picked!=null)refresh(()=>born=picked);
                }),
              const SizedBox(height:10),
              TextField(controller:surgical,
                decoration:const InputDecoration(labelText:'Type de chirurgie')),
              const SizedBox(height:10),
              TextField(controller:age,keyboardType:TextInputType.number,
                decoration:const InputDecoration(labelText:'Âge (si connu)')),
              const SizedBox(height:10),
              TextField(controller:insurance,
                decoration:const InputDecoration(labelText:'Mutuelle / assurance (si connue)')),
              const SizedBox(height:10),
              TextField(controller:days,keyboardType:TextInputType.number,
                decoration:const InputDecoration(labelText:'Durée prévisionnelle (jours, si connue)')),
              const SizedBox(height:10),
              OutlinedButton.icon(
                icon:const Icon(Icons.calendar_month),
                label:Text(consultation==null?'Renseigner la date de consultation':
                  'Consultation : ${_date(consultation!)}'),
                onPressed:() async{
                  final picked=await showDatePicker(context:ctx,
                    initialDate:consultation??DateTime.now(),
                    firstDate:DateTime(2020),lastDate:DateTime(2100));
                  if(picked!=null) refresh(()=>consultation=picked);
                }),
              const SizedBox(height:16),
              SizedBox(width:double.infinity,child:FilledButton(
                onPressed:(){
                  final parsedAge=int.tryParse(age.text.trim());
                  final parsedDays=days.text.trim().isEmpty?0:int.tryParse(days.text.trim());
                  if((age.text.trim().isNotEmpty &&
                      (parsedAge==null || parsedAge<0 || parsedAge>130))
                    || parsedDays==null || parsedDays<0 || parsedDays>365){
                    _notice('Vérifiez l’âge et la durée prévisionnelle.');return;
                  }
                  if(p.fromManualAdmission && born==null){
                    _notice('Date de naissance obligatoire pour les admissions.');
                    return;
                  }
                  if(p.fromManualAdmission && surgical.text.trim().isEmpty){
                    _notice('Précisez le type de chirurgie.');return;
                  }
                  p.birthDate=born;
                  p.surgeryType=surgical.text.trim();
                  p.age=age.text.trim().isEmpty?'—':age.text.trim();
                  p.insurance=insurance.text.trim().isEmpty?'À préciser':insurance.text.trim();
                  p.expectedDays=parsedDays;
                  p.consultationAt=consultation;
                  appStore.refresh(changed:p);
                  Navigator.pop(ctx);
                },child:const Text('Enregistrer les informations'))),
            ],
          )),
        ),
      )));
    age.dispose();insurance.dispose();days.dispose();surgical.dispose();
  }

  Future<void> _reconcileBloc() async {
    if(!p.fromManualAdmission || p.origin!='Consultation' || p.birthDate==null){
      _notice('La date de naissance et la provenance Consultation sont nécessaires.');
      return;
    }
    String key(String text)=>text.trim().replaceAll(RegExp(r'\s+'),' ').toUpperCase();
    bool sameDate(DateTime a,DateTime b)=>
      a.year==b.year && a.month==b.month && a.day==b.day;
    final choices=appStore.patients.where((candidate)=>
      candidate.fromBlocProgram && key(candidate.name)==key(p.name) &&
      sameDate(candidate.blockAt,p.blockAt)).toList();
    if(choices.isEmpty){
      _notice('Aucun programme non associé ne correspond à ce nom et à cette date. '
        'Actualisez les dossiers si nécessaire.');
      return;
    }
    final picked=await showModalBottomSheet<PatientCase>(context:context,
      showDragHandle:true,builder:(ctx)=>SafeArea(child:Padding(
        padding:const EdgeInsets.all(16),child:Column(
          mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            const Text('Programme correspondant à vérifier',
              style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
            const SizedBox(height:8),
            Text('Dossier existant : ${p.name} · né(e) le ${_date(p.birthDate!)}',
              style:const TextStyle(fontWeight:FontWeight.w600)),
            const SizedBox(height:8),
            const Text('Le programme ne contient pas la date de naissance. '
              'Vérifiez l’identité auprès du service avant d’associer les dossiers.',
              style:TextStyle(fontSize:12,color:VColors.muted)),
            const SizedBox(height:12),
            ...choices.map((candidate)=>ListTile(
              leading:const Icon(Icons.medical_services_outlined),
              title:Text(candidate.procedure),
              subtitle:Text('${candidate.name} · ${_date(candidate.blockAt)} · '
                'Salle ${candidate.programRoom}'),
              trailing:const Icon(Icons.chevron_right),
              onTap:()=>Navigator.pop(ctx,candidate))),
          ],
        ))));
    if(picked==null || !mounted)return;
    final verified=await showConfirmation(context,
      title:'Vérifier et associer les dossiers',
      message:'Confirmez-vous avoir vérifié que le patient du programme '
        '(${picked.name}, ${_date(picked.blockAt)}) est bien '
        '${p.name}, né(e) le ${_date(p.birthDate!)} ? '
        'Le dossier de consultation existant sera conservé.',
      action:'Identité vérifiée · associer');
    if(!verified || !mounted)return;
    try{
      await ManualAdmissionService().linkToProgram(p,picked);
      if(!mounted)return;
      appStore.attachVerifiedProgram(p,picked);
      _notice('Programme associé. Le dossier original de consultation est conservé.');
    }catch(_){
      if(mounted)_notice('Rapprochement impossible. Vérifiez les données et les observations du programme.');
    }
  }

  Future<void> _setProgramOmitted(bool omit) async {
    if(!p.fromBlocProgram || p.stage==CaseStage.discharged ||
       p.isOmitted==omit)return;
    final confirmed=await showConfirmation(context,
      title:omit?'Patient non réellement admis':'Rétablir l’admission',
      message:omit
        ? 'Omettre ce patient des admissions actives ? Son programme opératoire '
          'et les informations déjà saisies sont conservés. '
          'Cette opération peut être annulée depuis le dossier.'
        : 'Réintégrer ce patient au suivi automatique du programme opératoire ?',
      action:omit?'Omettre cette admission':'Rétablir');
    if(!confirmed || !mounted)return;
    final stage=p.stage, date=p.admittedAt, timing=p.admissionTiming;
    if(omit) { ProgramAdmission.omit(p); }
    else { ProgramAdmission.restore(p,DateTime.now()); }
    try {
      await appStore.saveClinical(p);
      if(!mounted)return;
      appStore.refresh();
      setState((){});
      _notice(omit?'Admission omise. Programme conservé.':'Admission rétablie.');
    } catch(_) {
      p.stage=stage;
      p.admittedAt=date;
      p.admissionTiming=timing;
      if(mounted){
        appStore.refresh();
        setState((){});
        _notice('Sauvegarde impossible : la modification n’a pas été appliquée.');
      }
    }
  }

  Future<void> _confirmPostopDay() async {
    if(!p.isPostopReviewDay(DateTime.now()))return;
    final confirmed=await showConfirmation(context,
      title:'Admission en postopératoire',
      message:'Confirmer que l’intervention de ${p.name} est réellement terminée '
        'et que la prise en charge postopératoire est effective ? '
        'La seule présence au programme du bloc ne suffit pas. '
        'Aucun lit ou box ne sera attribué automatiquement.',
      action:'Confirmer le postopératoire');
    if(!confirmed||!mounted)return;
    final oldStage=p.stage, oldDate=p.admittedAt, oldTiming=p.admissionTiming;
    p.stage=CaseStage.postoperative;
    p.admittedAt=DateTime.now();
    p.admissionTiming='Postopératoire confirmé le jour du bloc';
    try {
      await appStore.saveClinical(p);
      if(mounted)setState((){});
    }catch(_){
      p.stage=oldStage;
      p.admittedAt=oldDate;
      p.admissionTiming=oldTiming;
      if(mounted)_notice('Enregistrement du postopératoire impossible. Rien n’a été validé.');
    }
  }

  Future<void> _confirmAdmission() async {
    if(!p.isProgrammed) return;
    final today=DateTime.now();
    final day=await showDatePicker(context:context,initialDate:today,
      firstDate:DateTime(2020),lastDate:today);
    if(day==null || !mounted) return;
    final clock=await showTimePicker(context:context,
      initialTime:TimeOfDay.fromDateTime(today));
    if(clock==null || !mounted)return;
    final arrival=DateTime(day.year,day.month,day.day,clock.hour,clock.minute);
    if(arrival.isAfter(DateTime.now().add(const Duration(minutes:1)))){
      _notice('L’heure d’admission ne peut pas être future.');return;
    }
    final confirmed=await showConfirmation(context,
      title:'Confirmer l’admission hospitalière',
      message:'Avez-vous vérifié l’admission réelle de ${p.name} le ${_format(arrival)} ? '
        'Cette validation activera le suivi préopératoire. Aucun box ne sera attribué automatiquement.',
      action:'Confirmer l’admission');
    if(!confirmed)return;
    p.admittedAt=arrival;
    p.admissionTiming='Confirmée';
    p.stage=CaseStage.preoperative;
    appStore.refresh(changed:p);
  }

  Future<void> _editClinical() async {
    final controllers=[p.motive,p.history,p.exam,p.investigations,p.labs,p.immediatePlan].map((value) => TextEditingController(text: value)).toList();
    final labels=['Motif','Histoire de la maladie','Examen clinique','Examens complémentaires','Bilans','Conduite à tenir immédiate'];
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(sheetContext)=>Padding(padding:EdgeInsets.fromLTRB(20,8,20,MediaQuery.of(sheetContext).viewInsets.bottom+12),child:FlexibleClinicalEditor(controllers:controllers,labels:labels,onSave:(){p.motive=controllers[0].text;p.history=controllers[1].text;p.exam=controllers[2].text;p.investigations=controllers[3].text;p.labs=controllers[4].text;p.immediatePlan=controllers[5].text;appStore.refresh(changed:p);Navigator.pop(sheetContext);})));for(final c in controllers){c.dispose();}
  }
  String _date(DateTime d)=>'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  String _format(DateTime d)=>'${_date(d)} à ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

class FlexibleClinicalEditor extends StatelessWidget {
  const FlexibleClinicalEditor({super.key,required this.controllers,required this.labels,required this.onSave});
  final List<TextEditingController> controllers; final List<String> labels;final VoidCallback onSave;
  @override Widget build(BuildContext context)=>SizedBox(height:MediaQuery.of(context).size.height*.68,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Modifier le dossier',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:15),Expanded(child:ListView(children:List.generate(controllers.length,(i)=>Padding(padding:const EdgeInsets.only(bottom:12),child:VoiceClinicalField(controller:controllers[i],label:labels[i],maxLines:i==0?2:4))))),const SizedBox(height:8),SizedBox(width:double.infinity,child:ElevatedButton(onPressed:onSave,child:const Text('Enregistrer les modifications')))]));
}
