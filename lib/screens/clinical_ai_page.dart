import 'package:flutter/material.dart';
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
        });
      }
    } catch (error) {
      if (mounted) {
        final info = error.toString();
        setState(() {
          errorMessage = info.contains('groq_key_not_configured')
            ? 'GROQ_API_KEY n’est pas configurée dans les secrets Supabase. '
              'Aucune information clinique n’a été envoyée à GROQ.'
            : info.contains('possible_identifier_detected')
            ? 'Un identifiant possible a été repéré dans la synthèse. '
              'Corrigez le texte avant de réessayer.'
            : 'Analyse indisponible. Vérifiez la connexion, les autorisations '
              'du médecin et la configuration serveur GROQ.';
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
