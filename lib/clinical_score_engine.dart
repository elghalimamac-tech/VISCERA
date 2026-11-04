import 'models.dart';

/// Résultat clinique purement informatif, non prescriptif.
class ScoreResult {
  const ScoreResult(this.value, this.interpretation, {this.parameterAtThree = false});
  final String value;
  final String interpretation;
  final bool parameterAtThree;
}

class ClinicalScoring {
  static int? age(PatientCase p) {
    final date = p.birthDate;
    if (date != null) {
      final now = DateTime.now();
      var years = now.year - date.year;
      if (now.month < date.month ||
          (now.month == date.month && now.day < date.day)) years--;
      return years >= 0 && years <= 125 ? years : null;
    }
    final years = int.tryParse(p.age);
    return years != null && years >= 0 && years <= 125 ? years : null;
  }

  static ScoreResult? compute(String id, Map<String, String> data, {int? age}) {
    bool all(List<String> keys) => keys.every(
        (key) => data[key] != null && data[key]!.trim().isNotEmpty);
    int? n(String key) => int.tryParse(data[key] ?? '');
    switch (id) {
      case 'nrs2002':
        if (age == null || !all(['nutrition', 'disease']) ||
            ![0,1,2,3].contains(n('nutrition')) ||
            ![0,1,2,3].contains(n('disease'))) return null;
        final score = n('nutrition')! + n('disease')! + (age >= 70 ? 1 : 0);
        return ScoreResult(score.toString(), score >= 3
            ? 'Risque nutritionnel : évaluation et plan de soins à envisager'
            : 'Score <3 : réévaluation hebdomadaire à envisager');
      case 'ariscat':
        if (age == null || !all(['spo2','infection','hb','incision',
              'duration','emergency'])) return null;
        const allowed = <String,List<int>>{
          'spo2':[0,8,24], 'infection':[0,17], 'hb':[0,11],
          'incision':[0,15,24], 'duration':[0,16,23], 'emergency':[0,8],
        };
        if (allowed.entries.any((e) => !e.value.contains(n(e.key)))) return null;
        final score = (age <= 50 ? 0 : age <= 80 ? 3 : 16) +
            allowed.keys.fold<int>(0, (sum, key) => sum + n(key)!);
        return ScoreResult(score.toString(), score < 26 ? 'Risque faible'
          : score < 45 ? 'Risque intermédiaire' : 'Risque élevé');
      case 'rcri':
        const keys = ['surgery','ischemia','heartFailure','stroke',
          'insulin','creatinine'];
        if (!all(keys) || keys.any((key) => ![0,1].contains(n(key)))) return null;
        final score = keys.fold<int>(0, (sum, key) => sum + n(key)!);
        return ScoreResult(score.toString(), 'Facteurs de risque cardiaque : ' +
            score.toString() + ' sur 6');
      case 'caprini':
        if (!all(['total'])) return null;
        final score = n('total');
        if (score == null || score < 0 || score > 100) return null;
        return ScoreResult(score.toString(), 'Total renseigné sur grille Caprini 2013 complète ; vérifier le protocole local');
      case 'clavien':
        const grades = <String,String>{
          'I':'Soins simples', 'II':'Traitement pharmacologique / transfusion',
          'IIIa':'Intervention sans anesthésie générale',
          'IIIb':'Intervention sous anesthésie générale',
          'IVa':'Défaillance d’un organe',
          'IVb':'Défaillance multiviscérale', 'V':'Décès'};
        final grade = data['grade'];
        return grade != null && grades.containsKey(grade)
            ? ScoreResult(grade, grades[grade]!) : null;
      case 'news2':
        const keys = ['rr','spo2','oxygen','scale','sbp','pulse','conscious','temp'];
        if (!all(keys)) return null;
        final rr=n('rr'), spo2=n('spo2'), bp=n('sbp'), hr=n('pulse');
        final temp=double.tryParse(data['temp']!.replaceAll(',', '.'));
        final oxygen=data['oxygen'], scale=data['scale'], conscious=data['conscious'];
        if (rr==null || rr<1 || rr>90 || spo2==null || spo2<50 ||
            spo2>100 || bp==null || bp<40 || bp>300 || hr==null ||
            hr<20 || hr>250 || temp==null || temp<30 || temp>43 ||
            !['yes','no'].contains(oxygen) || !['1','2'].contains(scale) ||
            !['alert','confusion','voice','pain','unresponsive'].contains(conscious)) return null;
        final a=rr<=8?3:rr<=11?1:rr<=20?0:rr<=24?2:3;
        final b=scale=='1'
            ? (spo2<=91?3:spo2<=93?2:spo2<=95?1:0)
            : (spo2<=83?3:spo2<=85?2:spo2<=87?1:
                spo2<=92||oxygen=='no'?0:spo2<=94?1:spo2<=96?2:3);
        final c=bp<=90?3:bp<=100?2:bp<=110?1:bp<=219?0:3;
        final d=hr<=40?3:hr<=50?1:hr<=90?0:hr<=110?1:hr<=130?2:3;
        final e=temp<=35?3:temp<=36?1:temp<=38?0:temp<=39?1:2;
        final f=conscious=='alert'?0:3;
        final single=[a,b,c,d,e,f].contains(3);
        final score=a+b+c+d+e+f+(oxygen=='yes'?2:0);
        return ScoreResult(score.toString(), score>=7
          ? 'Risque élevé : évaluation urgente selon protocole'
          : score>=5 ? 'Risque intermédiaire : escalade selon protocole'
          : single ? 'Paramètre isolé coté 3 : escalade selon protocole'
          : 'Risque faible : surveillance selon protocole',
          parameterAtThree:single);
    }
    return null;
  }
}
