import 'package:flutter/material.dart';
import 'clinical_score_engine.dart';
import 'caprini_assessment.dart';
import 'clinical_score_specs.dart';
import 'models.dart';
import 'store.dart';

/// Rubrique repliée par défaut, sans doublon avec CFS et ASA.
class ClinicalScoresCard extends StatelessWidget {
  const ClinicalScoresCard({super.key, required this.patient, this.readOnly = false, this.expandedOnLoad = false, this.expandFirstForm = false});
  final PatientCase patient;
  final bool readOnly;
  final bool expandedOnLoad;
  final bool expandFirstForm;

  @override Widget build(BuildContext context) {
    final preop=patient.stage==CaseStage.scheduled ||
      patient.stage==CaseStage.preoperative;
    final postop=patient.stage==CaseStage.postoperative ||
      patient.stage==CaseStage.dischargeReady ||
      patient.stage==CaseStage.discharged;
    final colorectal=RegExp(r'colo|rect|sigmo|anastomos',
      caseSensitive:false).hasMatch(patient.effectiveProcedure);
    bool visible(ClinicalScoreSpec score) =>
      (score.id=='mdulk'||score.id=='isrec') &&
         !colorectal && !patient.clinicalScores.containsKey(score.id)
       ? false : (score.period=='Hospitalisation' && (preop||postop)) ||
      (score.period=='Préopératoire' && preop) ||
      (score.period=='Postopératoire' && postop) ||
      patient.clinicalScores.containsKey(score.id);
    final firstVisible = clinicalScoreSpecs.where(visible).firstOrNull?.id;
    return Card(color:Colors.white,elevation:0,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),
        side:BorderSide(color:Colors.grey.shade300)),
      child:ExpansionTile(
        key:const Key('clinical-scores-tile'),
        initiallyExpanded:expandedOnLoad,
        title:Text('Scores adaptés · '+(preop?'Préopératoire':postop?'Postopératoire':'Au bloc'),
          style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800)),
        subtitle:Text(preop
          ? 'Nutrition · thrombose · anesthésie · cœur'
          : postop ? 'Complications · fistules · surveillance'
          : 'En attente de confirmation de fin du bloc',
          style:const TextStyle(fontSize:12)),
        childrenPadding:const EdgeInsets.fromLTRB(12,0,12,12),
        children:[
          const Text('Évaluations facultatives, proposées selon la phase clinique. '
            'Une donnée manquante ne vaut pas zéro. Aucun score ne déclenche '
            'seul une décision médicale.',style:TextStyle(fontSize:12)),
          for(final score in clinicalScoreSpecs)
            if(visible(score))
              ClinicalScoreForm(key:ValueKey('form-'+score.id),
                patient:patient,spec:score,
                initiallyExpanded:expandFirstForm && score.id==firstVisible,
                readOnly:readOnly ||
                  (score.period=='Préopératoire' && !preop) ||
                  (score.period=='Postopératoire' && !postop)),
        ],
      ),
    );
  }
}

class ClinicalScoreForm extends StatefulWidget {
  const ClinicalScoreForm({super.key, required this.patient,
    required this.spec, this.readOnly = false,
    this.initiallyExpanded = false});
  final PatientCase patient;
  final ClinicalScoreSpec spec;
  final bool readOnly;
  final bool initiallyExpanded;
  @override State<ClinicalScoreForm> createState() => _ClinicalScoreFormState();
}

class _ClinicalScoreFormState extends State<ClinicalScoreForm> {
  Map<String, String> answers = {};
  bool saving = false;

  @override void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final record = widget.patient.clinicalScores[widget.spec.id];
    final raw = record is Map ? record['inputs'] : null;
    answers = raw is Map
      ? raw.map<String, String>((key, value) =>
          MapEntry(key.toString(), value.toString()))
      : {};
  }

  @override void didUpdateWidget(covariant ClinicalScoreForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.patient, widget.patient)) _load();
  }

  Future<void> _save(ScoreResult result) async {
    if (widget.readOnly || saving) return;
    final p = widget.patient;
    if (!p.fromBlocProgram && !p.fromManualAdmission) {
      _message('Créer le dossier patient partagé avant de sauvegarder ce score.');
      return;
    }
    final backup = Map<String, dynamic>.from(p.clinicalScores);
    setState(() => saving = true);
    final snapshot=Map<String,String>.from(answers);
    DateTime? biologicalDate;
    if(widget.spec.id=='mdulk') {
      final today=DateTime.now();
      for(final note in widget.patient.dailyObservations){
        if(note.date.year==today.year && note.date.month==today.month &&
           note.date.day==today.day && note.biology['crp']!=null) {
          snapshot['crp']=note.biology['crp']!.toString();
          biologicalDate=note.date;
          break;
        }
      }
      if(!snapshot.containsKey('crp')){
        if(mounted)setState(()=>saving=false);
        _message('CRP du jour absente : score mDULK non enregistré.');
        return;
      }
    }
    p.clinicalScores[widget.spec.id] = {
      'value': result.value,
      'interpretation': result.interpretation,
      'inputs': snapshot,
      'biologicalDate':biologicalDate?.toIso8601String(),
      'assessedAt': DateTime.now().toUtc().toIso8601String(),
      'assessedBy': appStore.activeLocalProfile?.id ?? '',
      'assessedStage':p.stage.name,
      'schemaVersion':2,
    };
    try {
      await appStore.saveClinical(p);
      appStore.refresh();
      if (mounted) _message('Évaluation enregistrée dans le dossier partagé.');
    } catch (_) {
      p.clinicalScores = backup;
      appStore.refresh();
      if (mounted) _message('Échec de sauvegarde : évaluation non confirmée.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)));
  }


  Future<void> _selectChoice(ClinicalQuestion question) async {
    if (widget.readOnly || saving) return;
    final value = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false, initialChildSize: .68,
          minChildSize: .35, maxChildSize: .92,
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(question.title,
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Lire le descriptif complet avant de choisir.',
                style: TextStyle(fontSize: 12)),
              const SizedBox(height: 14),
              for (final option in question.choices)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                    selected: answers[question.id] == option.value,
                    title: Text(option.label, softWrap: true),
                    trailing: answers[question.id] == option.value
                      ? const Icon(Icons.check_circle_outline) : null,
                    onTap: () => Navigator.pop(sheetContext, option.value),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && value != null) {
      setState(() => answers[question.id] = value);
    }
  }

  Widget _choice(ClinicalQuestion question) {
    final index = question.choices.indexWhere(
      (item) => item.value == answers[question.id]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        key: ValueKey(widget.spec.id + '-' + question.id),
        onTap: widget.readOnly || saving
          ? null : () => _selectChoice(question),
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: question.title,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.expand_more)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(index < 0 ? 'Sélectionner une réponse'
                : question.choices[index].label,
              softWrap: true, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ),
    );
  }

  Widget _capriniFactor(CapriniFactor factor) {
    final chosen = answers[factor.id];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(factor.label, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 5),
          if (factor.countable)
            TextFormField(
              key: ValueKey('caprini-count-' + factor.id),
              initialValue: chosen ?? '',
              readOnly: widget.readOnly || saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true, labelText: 'Nombre vérifié (0 si aucun)',
                border: OutlineInputBorder()),
              onChanged: (value) => setState(() =>
                answers[factor.id] = value.trim()),
            )
          else Wrap(spacing: 8, runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Oui'), selected: chosen == 'yes',
                onSelected: widget.readOnly || saving ? null
                  : (_) => setState(() => answers[factor.id] = 'yes'),
              ),
              ChoiceChip(
                label: const Text('Non'), selected: chosen == 'no',
                onSelected: widget.readOnly || saving ? null
                  : (_) => setState(() => answers[factor.id] = 'no'),
              ),
              if (factor.womenOnly)
                ChoiceChip(
                  label: const Text('Non applicable'),
                  selected: chosen == 'na',
                  onSelected: widget.readOnly || saving ? null
                    : (_) => setState(() => answers[factor.id] = 'na'),
                ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _capriniForm(int? age) {
    final done = CapriniAssessment.answeredCount(answers);
    final total = capriniFactors.length;
    final conflict = CapriniAssessment.conflict(answers);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Grille Caprini 2013 : vérifier chaque facteur. Une '
        'réponse manquante ne vaut jamais « Non ». L’âge est repris '
        'du dossier.', style: TextStyle(fontSize: 12)),
      const SizedBox(height: 8),
      Text(age == null ? 'Âge absent : compléter le dossier.'
        : 'Âge : $age ans · ${CapriniAssessment.agePoints(age)} point(s)',
        style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: done / total),
      const SizedBox(height: 5),
      Text('$done / $total facteurs vérifiés',
        style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 8),
      for (final points in const [1, 2, 3, 5])
        Card(
          elevation: 0, margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300)),
          child: ExpansionTile(
            key: ValueKey('caprini-group-$points'),
            initiallyExpanded: points == 1,
            title: Text('$points point(s) par facteur'),
            subtitle: Text(
              '${capriniFactors.where((f) => f.points == points && CapriniAssessment.validAnswer(f, answers[f.id])).length}'
              ' / ${capriniFactors.where((f) => f.points == points).length} vérifiés',
              style: const TextStyle(fontSize: 11)),
            children: [
              for (final factor in capriniFactors.where(
                  (f) => f.points == points)) _capriniFactor(factor),
            ],
          ),
        ),
      if (conflict != null)
        Text(conflict, style: const TextStyle(
          fontSize: 12, color: Colors.deepOrange)),
      const Text('Score calculé uniquement après vérification complète. '
        'Décision de prévention selon le protocole et le risque hémorragique.',
        style: TextStyle(fontSize: 11, color: Colors.black54)),
      const SizedBox(height: 12),
    ]);
  }

  Widget _number(String id, String label, {bool decimal = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      key: ValueKey(widget.spec.id + '-' + id),
      initialValue: answers[id] ?? '',
      readOnly: widget.readOnly || saving,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label,
        border: const OutlineInputBorder()),
      onChanged: (v) => setState(() => answers[id] = v.trim()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final age = ClinicalScoring.age(widget.patient);
    final computedInputs=Map<String,String>.from(answers);
    if(widget.spec.id=='mdulk') {
      computedInputs.remove('crp');
      final now=DateTime.now();
      for(final note in widget.patient.dailyObservations) {
        final sameDay=note.date.year==now.year &&
          note.date.month==now.month && note.date.day==now.day;
        if(sameDay && note.biology['crp']!=null) {
          computedInputs['crp']=note.biology['crp']!.toString();
          break;
        }
      }
    }
    final result=ClinicalScoring.compute(widget.spec.id,computedInputs,age:age);
    final stored = widget.patient.clinicalScores[widget.spec.id];
    final saved = stored is Map ? stored : null;
    final ageRequired = ['nrs2002', 'ariscat'].contains(widget.spec.id);
    return ExpansionTile(
      key: ValueKey('score-' + widget.spec.id),
      initiallyExpanded: widget.initiallyExpanded,
      title: Text(widget.spec.title, style:
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text(saved == null
          ? widget.spec.period + ' · À compléter'
          : widget.spec.period + ' · ' + (saved['value'] ?? '—').toString() +
              ' · Enregistré', style: const TextStyle(fontSize: 11)),
      childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      children: [
        if (ageRequired)
          Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Text(age == null
                ? 'Âge manquant : compléter la date de naissance ou l’âge'
                : 'Âge du dossier pris en compte : ' + age.toString() + ' ans',
              style: const TextStyle(fontSize: 12))),
        if (widget.spec.id == 'caprini') _capriniForm(age),
        if(widget.spec.id=='mdulk') ...[
          const Text('mDULK : quatre critères de vigilance des fistules '
            'colorectales. La CRP provient de l’observation du jour uniquement. '
            'Ce score ne confirme pas une fistule.',
            style:TextStyle(fontSize:12)),
          const SizedBox(height:8),
          _number('rr','Fréquence respiratoire du jour (/min)'),
          Text(computedInputs['crp']==null
            ? 'CRP absente : aucun score calculé.'
            : 'CRP retenue : '+computedInputs['crp']!+' mg/L',
            style:const TextStyle(fontSize:12)),
        ],
        if(widget.spec.id=='isrec')
          const Text('ISREC s’applique uniquement à une fistule '
            'colorectale confirmée par un médecin.',
            style:TextStyle(fontSize:12)),
        if (widget.spec.id == 'news2') ...[
          const Text('L’échelle SpO₂ 2 n’est utilisable que si la cible '
            '88–92 % a été prescrite par un clinicien compétent. '
            'NEWS2 ne remplace pas la surveillance clinique.',
            style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          _number('rr','Fréquence respiratoire (par min)'),
          _number('spo2','SpO₂ (%)'),
          _number('sbp','Pression systolique (mmHg)'),
          _number('pulse','Pouls (par min)'),
          _number('temp','Température (°C)',decimal:true),
        ],
        for (final question in widget.spec.questions) _choice(question),
        if (result != null)
          Align(alignment: Alignment.centerLeft,
            child: Text('Résultat : ' + result.value + ' · ' +
              result.interpretation,
              style: const TextStyle(fontWeight: FontWeight.w700,
                fontSize: 12)))
        else const Align(alignment: Alignment.centerLeft,
          child: Text('Évaluation incomplète : aucun résultat calculé.',
            style: TextStyle(fontSize: 12))),
        if (result?.parameterAtThree == true)
          const Align(alignment: Alignment.centerLeft,
            child: Text('NEWS2 : au moins un paramètre coté 3.',
              style: TextStyle(fontSize: 12, color: Colors.deepOrange))),
        const SizedBox(height: 10),
        if (!widget.readOnly)
          SizedBox(width: double.infinity, child: FilledButton.icon(
            key: ValueKey('save-score-' + widget.spec.id),
            onPressed: result == null || saving ? null : () => _save(result),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(saving ? 'Enregistrement…' : 'Enregistrer ce score'),
          )),
        if (saved != null)
          Align(alignment: Alignment.centerLeft,
            child: Text('Dernière évaluation : ' +
              (saved['assessedAt'] ?? '').toString(),
              style: const TextStyle(fontSize: 11, color: Colors.black54))),
      ],
    );
  }
}
