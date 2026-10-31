/// Référentiels et planning : toutes les entrées sont des données de démonstration
/// en mémoire et sont à renseigner par l'équipe du service.
class TeamMember {
  TeamMember({required this.id, required this.name});
  final String id;
  String name;
}

class DutyDay {
  DutyDay({required this.date, this.juniorId, this.seniorProfessorId, this.seniorName});
  final DateTime date;
  String? juniorId;
  String? seniorProfessorId;
  /// Identité du médecin senior ; ne présume pas du titre de professeur.
  String? seniorName;
}

/// Congé affiché dans la même vue mensuelle que les gardes.
/// Il s'agit d'une information déclarative, sans validation ni workflow administratif.
class LeaveEntry {
  LeaveEntry({required this.id,required this.doctorName,required this.start,required this.end});
  final String id;
  final String doctorName;
  final DateTime start;
  final DateTime end;
  bool includes(DateTime d) => !DateTime(d.year,d.month,d.day).isBefore(DateTime(start.year,start.month,start.day)) && !DateTime(d.year,d.month,d.day).isAfter(DateTime(end.year,end.month,end.day));
}

class ConsultationVacation {
  ConsultationVacation({required this.id,required this.professorId,required this.start,required this.end});
  final String id;
  String professorId;
  DateTime start;
  DateTime end;
}

/// Nom historique conservé pour compatibilité interne : professorId peut aussi
/// porter un identifiant SENIOR-xxx lorsque le responsable n’est pas professeur.
class ProfessorMatch {
  const ProfessorMatch({this.professorId,required this.explanation,required this.mode,required this.requiresSelection});
  final String? professorId;
  final String explanation;
  final String mode;
  final bool requiresSelection;
}

String dayKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';


/// Vacations hebdomadaires confirmées par le service comme valables toute l'année.
/// Source du référentiel : document de mai 2026.
/// Les titres Pr / Dr sont conservés ; un médecin Dr n'est pas converti
/// automatiquement en professeur responsable.
class ReferenceConsultationSlot {
  const ReferenceConsultationSlot({required this.weekday,required this.startHour,required this.endHour,required this.consultantName,this.professorName});
  final int weekday; // DateTime.monday = 1
  final int startHour;
  final int endHour;
  final String consultantName;
  final String? professorName;
  bool contains(DateTime d) => d.weekday==weekday && d.hour*60+d.minute>=startHour*60 && d.hour*60+d.minute<endHour*60;
}

const weeklyVisceralConsultations = <ReferenceConsultationSlot>[
  ReferenceConsultationSlot(weekday:1,startHour:9,endHour:13,consultantName:'Pr BENSAAD',professorName:'Pr BENSAAD'),
  ReferenceConsultationSlot(weekday:1,startHour:14,endHour:19,consultantName:'Pr BENSAAD',professorName:'Pr BENSAAD'),
  ReferenceConsultationSlot(weekday:2,startHour:9,endHour:13,consultantName:'Pr GHADDOU',professorName:'Pr GHADDOU'),
  ReferenceConsultationSlot(weekday:2,startHour:14,endHour:19,consultantName:'Pr GHADDOU',professorName:'Pr GHADDOU'),
  ReferenceConsultationSlot(weekday:3,startHour:9,endHour:13,consultantName:'Pr GHADDOU',professorName:'Pr GHADDOU'),
  ReferenceConsultationSlot(weekday:3,startHour:14,endHour:19,consultantName:'Dr BENGHAIT'),
  ReferenceConsultationSlot(weekday:4,startHour:9,endHour:13,consultantName:'Pr BENSAAD',professorName:'Pr BENSAAD'),
  ReferenceConsultationSlot(weekday:4,startHour:14,endHour:19,consultantName:'Dr LAABOULI'),
  ReferenceConsultationSlot(weekday:5,startHour:9,endHour:13,consultantName:'Pr NOURI',professorName:'Pr NOURI'),
  ReferenceConsultationSlot(weekday:5,startHour:14,endHour:19,consultantName:'Pr CHOUKRI',professorName:'Pr CHOUKRI'),
  ReferenceConsultationSlot(weekday:6,startHour:9,endHour:13,consultantName:'Médecin de garde'),
  ReferenceConsultationSlot(weekday:6,startHour:14,endHour:19,consultantName:'Médecin de garde'),
];

const referenceConsultationDoctors = ['Dr BENGHAIT','Dr LAABOULI'];

/// Document du service : gardes seniors d'octobre 2026 (31 dates).
/// Les années mal saisies sur certaines lignes de la photographie ont été
/// corrigées selon le titre « OCTOBRE 2026 » et la succession des jours.
/// AUCUNE garde junior n'est renseignée sur le document.
const october2026SeniorByDay = <String>[
  'LAFKIH',
  'GHADDOU',
  'FAHSI',
  'FAHSI',
  'GHADDOU',
  'LAABOULI',
  'LAFKIH',
  'LAABOULI',
  'FAHSI',
  'BENSAAD',
  'BENSAAD',
  'GHADDOU',
  'LAFKIH',
  'LAABOULI',
  'FAHSI',
  'LAFKIH',
  'GHADDOU',
  'GHADDOU',
  'LAABOULI',
  'GHADDOU',
  'FAHSI',
  'BENSAAD',
  'LAFKIH',
  'LAABOULI',
  'LAABOULI',
  'GHADDOU',
  'LAABOULI',
  'FAHSI',
  'LAFKIH',
  'BENSAAD',
  'LAFKIH'
];
