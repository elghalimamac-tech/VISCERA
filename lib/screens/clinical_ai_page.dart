import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../biological_followup.dart';
import '../clinical_score_specs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../branding.dart';
import '../clinical_ai_summary.dart';
import '../models.dart';
import '../theme.dart';

/// Aide à la discussion médicale. Jamais de prescription automatique.
class ClinicalAiPage extends StatefulWidget {
  const ClinicalAiPage({super.key, required this.patient});
  final PatientCase patient;

  @override
  State<ClinicalAiPage> createState() => _ClinicalAiPageState();
}

class _ClinicalAiPageState extends State<ClinicalAiPage> {
  late final TextEditingController summary;
  bool reviewed = false;
  bool loading = false;
  Map<String,dynamic>? response;
  String? errorMessage;
  List<Map<String,dynamic>> references = [];
  String? bibliographyDate;
  String? sourceWarning;

  @override
  void initState() {
    super.initState();
    summary = TextEditingController(
      text: buildClinicalAiSummary(widget.patient));
    summary.addListener(() {
      if (reviewed || response != null) {
        setState(() {
          reviewed = false;
          response = null;
          references = [];
        });
      }
    });
  }

  @override
  void dispose() {
    summary.dispose();
    super.dispose();
  }

  Future<void> requestAnalysis() async {
    if (loading || !reviewed ||
        summary.text.trim().length < 40 ||
        summary.text.trim().length > 9000) return;
    setState(() {
      loading = true;
      response = null;
      errorMessage = null;
      references = [];
    });
    try {
      final result = await Supabase.instance.client.functions.invoke(
        'viscera-clinical-assist',
        body: {
          'clinical_summary': summary.text.trim(),
          'reviewed_deidentified': true,
        },
      );
      final body = result.data;
      if (body is! Map || body['result'] is! Map) {
        throw const FormatException('invalid_result');
      }
      if (mounted) {
        setState(() {
          response = Map<String,dynamic>.from(body['result'] as Map);
          references = body['reference_catalog'] is List
            ? (body['reference_catalog'] as List)
                .whereType<Map>()
                .map((v)=>Map<String,dynamic>.from(v)).toList()
            : [];
          bibliographyDate=body['bibliography_reviewed_at']?.toString();
          sourceWarning=body['warning']?.toString();
        });
      }
    } catch (error) {
      if (mounted) {
        Map<String,dynamic> details={};
        if (error is FunctionException) {
          final raw=error.details;
          if(raw is Map) details=Map<String,dynamic>.from(raw);
          if(raw is String) {
            try {
              final parsed=jsonDecode(raw);
              if(parsed is Map) details=Map<String,dynamic>.from(parsed);
            } catch (_) {}
          }
        }
        final code=details['error']?.toString()??'';
        final status=details['provider_http_status']?.toString()??'—';
        setState(() {
          errorMessage=switch(code) {
            'groq_key_not_configured' =>
              'Clé GROQ_API_KEY manquante dans les secrets Supabase.',
            'groq_invalid_api_key' =>
              'GROQ a refusé la clé API (401).',
            'groq_access_denied' =>
              'Accès GROQ ou modèle refusé (403).',
            'groq_model_unavailable' =>
              'Modèle GROQ indisponible (404).',
            'groq_request_rejected' =>
              'Requête GROQ rejetée (HTTP $status) : vérifier les paramètres JSON.',
            'groq_rate_limited' =>
              'Quota ou limite GROQ atteinte (429).',
            'groq_service_unavailable' =>
              'Service GROQ indisponible (HTTP $status).',
            'groq_timeout' => 'Délai GROQ dépassé.',
            'groq_network_failure' => 'Connexion Supabase–GROQ impossible.',
            'groq_invalid_response' || 'invalid_ai_response' =>
              'Réponse GROQ non conforme : aucun résultat affiché.',
            'possible_identifier_detected' =>
              'Donnée identifiante détectée dans le texte.',
            'exact_age_detected' =>
              'Utilisez une tranche d’âge et non l’âge exact.',
            'doctor_approval_required' =>
              'Seuls les médecins approuvés peuvent utiliser cet outil.',
            'unauthorized' =>
              'Session non valide. Reconnectez-vous.',
            _ => 'Analyse indisponible : consultez les logs de la fonction '
              'viscera-clinical-assist.',
          };
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<dynamic> items(String key) {
    final value = response?[key];
    return value is List ? value : const [];
  }

  Widget section(String title, String key, IconData icon) {
    final content = items(key);
    return Card(
      color:Colors.white,elevation:0,
      child:Padding(padding:const EdgeInsets.all(14),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Icon(icon,color:VColors.ink,size:20),
            const SizedBox(width:8),
            Expanded(child:Text(title,style:const TextStyle(
              fontWeight:FontWeight.w800,fontSize:15))),
          ]),
          const SizedBox(height:8),
          if(content.isEmpty)
            const Text('Aucun élément proposé.',
              style:TextStyle(fontSize:12,color:VColors.muted)),
          for (final item in content)
            Padding(padding:const EdgeInsets.only(bottom:9),
              child:Text('• '+item.toString(),
                style:const TextStyle(fontSize:13))),
        ])));
  }

  Widget hypothesesCard() => Card(
    color:Colors.white,elevation:0,
    child:Padding(padding:const EdgeInsets.all(14),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Hypothèses diagnostiques différentielles',
          style:TextStyle(fontWeight:FontWeight.w800,fontSize:15)),
        const SizedBox(height:9),
        if(items('hypotheses').isEmpty)
          const Text('Données insuffisantes pour proposer des hypothèses.'),
        for(final hypothesis in items('hypotheses'))
          if(hypothesis is Map) Padding(
            padding:const EdgeInsets.only(bottom:12),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text((hypothesis['possibility'] ?? '').toString(),
                style:const TextStyle(fontWeight:FontWeight.w700)),
              Text('Éléments disponibles : '
                +(hypothesis['supporting_data'] ?? '').toString(),
                style:const TextStyle(fontSize:12)),
              Text('À confirmer / rechercher : '
                +(hypothesis['data_to_verify'] ?? '').toString(),
                style:const TextStyle(fontSize:12,color:VColors.muted)),
              const Divider(),
            ]),
          ),
      ])));


  Map<String,dynamic>? _reference(String id) {
    for(final ref in references) {
      if(ref['id']==id) return ref;
    }
    return null;
  }

  Future<void> _openReference(Map<String,dynamic> ref) async {
    final uri=Uri.tryParse((ref['url']??'').toString());
    if(uri==null || uri.scheme!='https') return;
    try {
      await launchUrl(uri,mode:LaunchMode.externalApplication);
    } catch (_) {
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Impossible d’ouvrir cette référence médicale.')));
    }
  }

  Widget _citations(dynamic input) {
    final ids=input is List ? input.whereType<String>().toSet() : <String>{};
    return Padding(
      padding:const EdgeInsets.only(top:8),
      child:Wrap(spacing:5,runSpacing:4,children:[
        for(final id in ids)
          if(_reference(id)!=null)
            ActionChip(
              key:ValueKey('ai-citation-'+id),
              backgroundColor:VColors.softMint,
              visualDensity:VisualDensity.compact,
              avatar:const Icon(Icons.menu_book_outlined,size:15),
              label:Text(id+' · '+_reference(id)!['year'].toString(),
                style:const TextStyle(fontSize:11)),
              onPressed:()=>_openReference(_reference(id)!),
            ),
        if(ids.isEmpty)const Text('Référence absente : à vérifier.',
          style:TextStyle(fontSize:11,color:VColors.muted)),
      ]),
    );
  }

  Widget _scoreDashboard() {
    final p=widget.patient;
    final values=<MapEntry<String,String>>[];
    if(p.cfsScore!=null)values.add(MapEntry('CFS',p.cfsScore.toString()));
    if(p.asaClass.trim().isNotEmpty)values.add(MapEntry('ASA',p.asaClass));
    for(final record in p.clinicalScores.entries){
      final data=record.value;
      if(data is! Map || data['value']==null)continue;
      final name=clinicalScoreSpecs
        .where((item)=>item.id==record.key)
        .map((item)=>item.title.split(' · ').first)
        .firstOrNull ?? record.key.toUpperCase();
      values.add(MapEntry(name,data['value'].toString()));
    }
    for(final idx in BioIndices.compute(p)){
      values.add(MapEntry(idx.name,idx.value));
    }
    return Card(
      key:const Key('clinical-ai-score-dashboard'),
      color:Colors.white,elevation:0,
      child:Padding(padding:const EdgeInsets.all(16),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Row(children:[
            Icon(Icons.monitor_heart_outlined,color:VColors.ink),
            SizedBox(width:8),
            Expanded(child:Text('Scores et indices cliniques',
              style:TextStyle(fontSize:16,fontWeight:FontWeight.w800))),
          ]),
          const SizedBox(height:5),
          const Text('Données enregistrées dans le dossier ; aucun '
            'score manquant n’est inventé.',
            style:TextStyle(fontSize:11,color:VColors.muted)),
          const SizedBox(height:13),
          if(values.isEmpty)
            const Text('Aucun score renseigné pour ce dossier.')
          else Wrap(spacing:9,runSpacing:9,children:[
            for(final entry in values)
              Container(
                key:ValueKey('ai-score-'+entry.key),
                padding:const EdgeInsets.symmetric(
                  horizontal:13,vertical:10),
                decoration:BoxDecoration(
                  color:VColors.blueSoft,
                  border:Border.all(color:VColors.line),
                  borderRadius:BorderRadius.circular(12)),
                child:Column(mainAxisSize:MainAxisSize.min,
                  crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(entry.key,style:const TextStyle(fontSize:11,
                    color:VColors.ink,fontWeight:FontWeight.w600)),
                  const SizedBox(height:4),
                  Text(entry.value,style:const TextStyle(
                    fontSize:19,color:VColors.ink,
                    fontWeight:FontWeight.w900)),
                ]),
              ),
          ]),
          const SizedBox(height:8),
          const Text('Vérifier la date, les critères et la phase '
            'clinique avant d’interpréter un score.',
            style:TextStyle(fontSize:11,color:VColors.muted)),
        ]),
      ),
    );
  }

  Widget _bibliographyCard() => Card(
    key:const Key('clinical-ai-sources'),
    color:Colors.white,elevation:0,
    child:Padding(padding:const EdgeInsets.all(16),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Row(children:[
          Icon(Icons.library_books_outlined,color:VColors.ink),
          SizedBox(width:8),
          Expanded(child:Text('Sources et recommandations',
            style:TextStyle(fontSize:16,fontWeight:FontWeight.w800))),
        ]),
        const SizedBox(height:7),
        Text('Catalogue documentaire vérifié le '
          +(bibliographyDate??'date inconnue')
          +' · pas de recherche web en temps réel.',
          style:const TextStyle(fontSize:12,color:VColors.muted)),
        const SizedBox(height:12),
        if(references.isEmpty)
          const Text('Aucune référence fournie. Les propositions '
            'ne peuvent pas être considérées comme étayées.'),
        for(final ref in references)
          ListTile(
            key:ValueKey('ai-source-'+ref['id'].toString()),
            dense:true,
            contentPadding:EdgeInsets.zero,
            leading:const Icon(Icons.open_in_new,color:VColors.ink),
            title:Text(ref['organization'].toString()+' · '+
              ref['year'].toString(),
              style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12)),
            subtitle:Text(ref['title'].toString(),
              style:const TextStyle(fontSize:12)),
            onTap:()=>_openReference(ref),
          ),
        if(sourceWarning!=null)Padding(
          padding:const EdgeInsets.only(top:8),
          child:Text(sourceWarning!,
            style:const TextStyle(fontSize:11,color:VColors.muted))),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const VisceraPageTitle('Assistant clinique GROQ'),
      backgroundColor:VColors.background,
      surfaceTintColor:Colors.transparent,
    ),
    body: ListView(
      key:const Key('clinical-ai-page'),
      padding:const EdgeInsets.fromLTRB(16,12,16,44),
      children:[
        Card(color:VColors.softMint,elevation:0,
          child:Padding(padding:const EdgeInsets.all(14),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('Aide à la décision : médecin uniquement',
                style:TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
              const SizedBox(height:6),
              const Text('GROQ peut suggérer des hypothèses, examens à discuter '
                'et options de conduite à tenir. Ses réponses peuvent être '
                'inexactes : les recouper avec le dossier, l’examen et '
                'les protocoles du service. Aucune prescription, action '
                'ou décision médicale n’est automatisée.',
                style:TextStyle(fontSize:12)),
            ]))),
        const SizedBox(height:12),
        const Text('1. Vérifier la synthèse à transmettre',
          style:TextStyle(fontWeight:FontWeight.w800,fontSize:15)),
        const SizedBox(height:7),
        TextField(
          key:const Key('clinical-ai-preview'),
          controller:summary,
          minLines:10,maxLines:18,maxLength:9000,
          enabled:!loading,
          decoration:const InputDecoration(
            border:OutlineInputBorder(),
            helperText:'Document modifiable : supprimer tous noms, '
              'coordonnées, dates exactes et identifiants avant envoi.',
            helperMaxLines:3,
          ),
        ),
        const SizedBox(height:6),
        const Text('Cette synthèse est issue des données du dossier. '
          'La suppression automatique des identifiants est incomplète. '
          'La transmission à un fournisseur externe doit être autorisée '
          'par l’établissement et conforme aux règles de confidentialité.',
          style:TextStyle(fontSize:12,color:VColors.muted)),
        const SizedBox(height:8),
        CheckboxListTile(
          key:const Key('clinical-ai-consent'),
          value:reviewed,
          onChanged:loading?null:(v)=>setState(()=>reviewed=v==true),
          controlAffinity:ListTileControlAffinity.leading,
          contentPadding:EdgeInsets.zero,
          title:const Text('J’ai relu et désidentifié le texte, et je suis '
            'autorisé(e) à le transmettre à GROQ.',
            style:TextStyle(fontSize:13)),
        ),
        const SizedBox(height:6),
        FilledButton.icon(
          key:const Key('clinical-ai-generate'),
          onPressed:loading||!reviewed||summary.text.trim().length<40
            ? null : requestAnalysis,
          icon:loading?const SizedBox(width:17,height:17,
            child:CircularProgressIndicator(strokeWidth:2))
            :const Icon(Icons.psychology_alt_outlined),
          label:Text(loading?'Analyse en cours…'
            :'Proposer hypothèses et conduites à tenir'),
        ),
        if(errorMessage!=null) Padding(
          padding:const EdgeInsets.only(top:12),
          child:Text(errorMessage!,
            style:const TextStyle(color:Color(0xFFA45633),fontSize:12))),
        if(response!=null) ...[
          const SizedBox(height:18),
          const Text('2. Propositions GROQ — non validées',
            style:TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
          const SizedBox(height:9),
          hypothesesCard(),
          section('Évaluations / examens à discuter',
            'assessments_to_discuss',Icons.fact_check_outlined),
          section('Conduites à tenir à discuter',
            'management_options_to_discuss',Icons.medical_services_outlined),
          section('Signes d’alerte à surveiller',
            'warning_signs',Icons.warning_amber_outlined),
          section('Limites et informations manquantes',
            'limits',Icons.info_outline),
          const Padding(padding:EdgeInsets.symmetric(vertical:8),
            child:Text('Résultat non enregistré dans le dossier. '
              'Vérifier chaque suggestion avant tout acte, '
              'en particulier en situation d’urgence.',
              style:TextStyle(fontSize:12,color:VColors.muted))),
        ],
      ],
    ),
  );
}
