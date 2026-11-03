import 'models.dart';

/// Groupement unique des listes de patients par leur service d'affectation.
/// Une localisation non confirmée n'est jamais inventée.
const unassignedPatientService = 'À affecter';

String patientService(PatientCase patient) {
  if(patient.isOmitted)return unassignedPatientService;
  // Après la sortie, la dernière unité postopératoire garde la priorité.
  // Le getter currentUnit revient sinon à l'unité préopératoire.
  final code = patient.isArchived
    ? (patient.afterUnit.trim().isNotEmpty
        ? patient.afterUnit.trim() : patient.beforeUnit.trim())
    : patient.currentUnit.trim();
  if(code.isEmpty)return unassignedPatientService;
  return code;
}

/// Conserve l'ordre opérationnel des unités du service. Les unités externes
/// sont ajoutées alphabétiquement, puis les patients sans affectation.
Map<String,List<PatientCase>> patientsByService(Iterable<PatientCase> patients) {
  final buckets = <String,List<PatientCase>>{};
  for(final patient in patients) {
    buckets.putIfAbsent(patientService(patient), ()=> <PatientCase>[])
      .add(patient);
  }
  final names = buckets.keys.toList();
  int rank(String service) {
    final index = hospitalUnits.indexWhere((unit)=>unit.code==service);
    if(index>=0)return index;
    return service==unassignedPatientService ? 10000 : 1000;
  }
  names.sort((a,b){
    final priority=rank(a).compareTo(rank(b));
    return priority!=0?priority:a.compareTo(b);
  });
  return {for(final name in names) name: buckets[name]!};
}
