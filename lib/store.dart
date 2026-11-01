import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'planning_models.dart';

class LocalDoctorProfile {
  LocalDoctorProfile({required this.id, required this.name, required this.email, required this.role, required this.memberId, this.isAdmin=false});
  final String id, name, email, role, memberId;
  final bool isAdmin;
  bool get isVisceraOwner => isAdmin && id == '4fa3bd1b-6ee1-4b87-97eb-d18527025bc6';
  bool get isSenior => role == 'senior';
  Map<String, String> toJson() => {'id':id,'name':name,'email':email,'role':role,'memberId':memberId};
  static LocalDoctorProfile? fromJson(dynamic value) {
    if(value is! Map) return null;
    if(!['junior','senior'].contains(value['role']) ||
       !['id','name','email','memberId'].every((k)=>value[k] is String)) return null;
    return LocalDoctorProfile(id:value['id'] as String,name:value['name'] as String,
      email:value['email'] as String,role:value['role'] as String,memberId:value['memberId'] as String);
  }
}

class AppStore extends ChangeNotifier {
  final List<LocalDoctorProfile> localProfiles=[];
  String? activeLocalProfileId;
  LocalDoctorProfile? get activeLocalProfile {
    for(final p in localProfiles){if(p.id==activeLocalProfileId)return p;}
    return null;
  }
  final List<PatientCase> patients = [];
  final List<TeamMember> professors = [];
  final List<TeamMember> juniors = [];
  /// Seniors (le document ne précise pas que tous sont professeurs).
  final List<String> seniorNames = [];
  final Map<String, DutyDay> dutyDays = {};
  final List<ConsultationVacation> vacations = [];
  final List<LeaveEntry> leaves = [];
  /// Compatibilité avec les anciens plannings locaux. Désormais une garde
  /// personnelle est exclusivement une garde de SERVICE de 24H.
  final Map<String, String> personalServiceShifts = {};
  int _staffSerial = 0;
  bool _planningPersistenceEnabled = false;
  static const _planningStorageKey = 'viscera_demo_v8_planning';

  // Seul le planning et l'annuaire de démo sont sauvegardés ; aucun dossier
  // patient n'est écrit ici. Ce stockage local n'est PAS une base clinique.
  Future<void> restorePlanning() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_planningStorageKey);
      if (raw == null) return;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> || data['version'] != 8) return;
      final restoredProfessors = data['professors'];
      if (restoredProfessors is List) {
        professors
          ..clear()
          ..addAll(restoredProfessors.whereType<Map>().where((v) => v['id'] is String && v['name'] is String)
              .map((v) => TeamMember(id: v['id'] as String, name: v['name'] as String)));
      }
      final restoredJuniors = data['juniors'];
      if (restoredJuniors is List) {
        juniors
          ..clear()
          ..addAll(restoredJuniors.whereType<Map>().where((v) => v['id'] is String && v['name'] is String)
              .map((v) => TeamMember(id: v['id'] as String, name: v['name'] as String)));
      }
      final restoredSeniors = data['seniorNames'];
      if (restoredSeniors is List) {
        seniorNames
          ..clear()
          ..addAll(restoredSeniors.whereType<String>());
      }
      final restoredDuties = data['dutyDays'];
      if (restoredDuties is Map) {
        dutyDays.clear();
        for (final entry in restoredDuties.entries) {
          if (entry.key is! String || entry.value is! Map) continue;
          final date = DateTime.tryParse(entry.key as String);
          final value = entry.value as Map;
          if (date == null) continue;
          dutyDays[dayKey(date)] = DutyDay(date: date,
            seniorName: value['seniorName'] is String ? value['seniorName'] as String : null,
            seniorProfessorId: value['seniorProfessorId'] is String ? value['seniorProfessorId'] as String : null,
            juniorId: value['juniorId'] is String ? value['juniorId'] as String : null);
        }
      }
      final restoredVacations = data['vacations'];
      if (restoredVacations is List) {
        vacations.clear();
        for (final item in restoredVacations) {
          if (item is! Map || item['id'] is! String || item['professorId'] is! String) continue;
          final start = DateTime.tryParse('${item['start']}');
          final end = DateTime.tryParse('${item['end']}');
          if (start != null && end != null && end.isAfter(start)) {
            vacations.add(ConsultationVacation(id: item['id'] as String,
              professorId: item['professorId'] as String, start: start, end: end));
          }
        }
      }
      final restoredLeaves = data['leaves'];
      if (restoredLeaves is List) {
        leaves.clear();
        for(final item in restoredLeaves){
          if(item is! Map || item['id'] is! String || item['doctorName'] is! String) continue;
          final a=DateTime.tryParse('${item['start']}');
          final b=DateTime.tryParse('${item['end']}');
          if(a!=null && b!=null && !b.isBefore(a)){
            leaves.add(LeaveEntry(id:item['id'] as String,doctorName:item['doctorName'] as String,start:a,end:b));
          }
        }
      }
      personalServiceShifts.clear();
      final restoredShifts = data['personalServiceShifts'];
      if(restoredShifts is Map) {
        for(final entry in restoredShifts.entries) {
          if(entry.key is String && entry.value is String &&
              ['jour','nuit','24h'].contains(entry.value)) {
            personalServiceShifts[entry.key as String] = entry.value as String;
          }
        }
      }
      // V12: ne JAMAIS restaurer d'anciens profils locaux comme sessions authentifiées.
      localProfiles.clear();
      activeLocalProfileId = null;
      if (data['staffSerial'] is int) _staffSerial = data['staffSerial'] as int;
      notifyListeners();
    } catch (error) {
      debugPrint('Impossible de recharger le planning de démonstration : $error');
    } finally {
      _planningPersistenceEnabled = true;
    }
  }

  void _savePlanning() {
    if (_planningPersistenceEnabled) unawaited(_persistPlanning());
  }

  Future<void> _persistPlanning() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'version': 8,
        'staffSerial': _staffSerial,
        'professors': professors.map((p) => {'id': p.id, 'name': p.name}).toList(),
        'juniors': juniors.map((p) => {'id': p.id, 'name': p.name}).toList(),
        'seniorNames': seniorNames,
        'dutyDays': dutyDays.map((key, duty) => MapEntry(key, {
          'juniorId': duty.juniorId,
          'seniorName': duty.seniorName,
          'seniorProfessorId': duty.seniorProfessorId,
        })),
        'leaves': leaves.map((x) => {'id':x.id,'doctorName':x.doctorName,'start':x.start.toIso8601String(),'end':x.end.toIso8601String()}).toList(),
        'personalServiceShifts': personalServiceShifts,
        'vacations': vacations.map((v) => {
          'id': v.id, 'professorId': v.professorId,
          'start': v.start.toIso8601String(), 'end': v.end.toIso8601String(),
        }).toList(),
      };
      await prefs.setString(_planningStorageKey, jsonEncode(data));
    } catch (error) {
      debugPrint('Impossible de sauvegarder le planning de démonstration : $error');
    }
  }

  // Confirmation du service : les vacations de mai 2026 constituent
  // le calendrier hebdomadaire habituel, applicable toute l'année.
  // Une vacation datée exceptionnelle prévaut sur cette grille.
  ReferenceConsultationSlot? referenceConsultantAt(DateTime at) {
    for (final slot in weeklyVisceralConsultations) {
      if (slot.contains(at)) return slot;
    }
    return null;
  }


  TeamMember? professorById(String? id) {
    for (final person in professors) { if (person.id == id) return person; }
    return null;
  }
  TeamMember? juniorById(String? id) {
    for (final person in juniors) { if (person.id == id) return person; }
    return null;
  }
  DutyDay? dutyOn(DateTime date) => dutyDays[dayKey(date)];
  String? seniorOnName(DateTime date) => dutyOn(date)?.seniorName ?? professorById(dutyOn(date)?.seniorProfessorId)?.name;
  TeamMember? seniorOn(DateTime date) => professorById(dutyOn(date)?.seniorProfessorId);
  static String _normalizeClinician(String name) => name.trim().replaceFirst(RegExp(r'^(Pr|Dr)\s+',caseSensitive:false),'').trim().toUpperCase();
  TeamMember? _matchingProfessor(String seniorName) {
    for (final prof in professors) {
      if (_normalizeClinician(prof.name)==_normalizeClinician(seniorName)) return prof;
    }
    return null;
  }
  /// Un senior peut être responsable aux urgences sans posséder le titre Pr.
  /// Les identifiants PROF- restent inchangés ; SENIOR- désigne les autres seniors.
  String responsibleIdForSenior(String name) =>
      _matchingProfessor(name)?.id ?? 'SENIOR-${_normalizeClinician(name)}';

  TeamMember? responsibleById(String? id) {
    final professor = professorById(id);
    if (professor != null) return professor;
    if (id == null || !id.startsWith('SENIOR-')) return null;
    final name = id.substring('SENIOR-'.length);
    if (!seniorNames.contains(name)) return null;
    return TeamMember(id: id, name: name);
  }

  List<TeamMember> responsibleOptions({required bool forEmergencies}) {
    final options = <TeamMember>[...professors];
    if (forEmergencies) {
      for (final senior in seniorNames) {
        final id = responsibleIdForSenior(senior);
        if (!options.any((x) => x.id == id)) {
          options.add(TeamMember(id: id, name: senior));
        }
      }
    }
    return options..sort((a,b) => a.name.compareTo(b.name));
  }

  bool addSenior(String rawName) {
    final name=_normalizeClinician(rawName);
    if (name.isEmpty || seniorNames.contains(name)) return false;
    seniorNames.add(name);
    seniorNames.sort();notifyListeners();_savePlanning();return true;
  }
  TeamMember? juniorOn(DateTime date) => juniorById(dutyOn(date)?.juniorId);

  bool addProfessor(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty || professors.any((p)=>p.name.toLowerCase()==name.toLowerCase())) return false;
    professors.add(TeamMember(id:'PROF-${++_staffSerial}',name:name));
    professors.sort((a,b)=>a.name.compareTo(b.name)); notifyListeners(); _savePlanning(); return true;
  }
  bool addJunior(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty || juniors.any((p)=>p.name.toLowerCase()==name.toLowerCase())) return false;
    juniors.add(TeamMember(id:'JR-${++_staffSerial}',name:name));
    juniors.sort((a,b)=>a.name.compareTo(b.name)); notifyListeners(); _savePlanning(); return true;
  }
  void setDuty(DateTime date,{String? juniorId,String? seniorProfessorId,String? seniorName}) {
    // Nom du senior sauvegardé séparément du titre de professeur.
    final resolvedName=(seniorName!=null && seniorName.trim().isNotEmpty)
      ? _normalizeClinician(seniorName)
      : professorById(seniorProfessorId)?.name;
    if(resolvedName!=null) addSenior(resolvedName);
    final resolvedProfessor=resolvedName==null ? null : _matchingProfessor(resolvedName)?.id;
    dutyDays[dayKey(date)] = DutyDay(date:DateTime(date.year,date.month,date.day),juniorId:juniorId,
      seniorProfessorId:resolvedProfessor,seniorName:resolvedName);
    notifyListeners();_savePlanning();
  }
  List<LeaveEntry> leavesOn(DateTime date)=>leaves.where((x)=>x.includes(date)).toList();

  bool addLeave({required String doctorName,required DateTime start,required DateTime end}) {
    if(doctorName.trim().isEmpty || end.isBefore(start))return false;
    if(!seniorNames.contains(doctorName) && !juniors.any((m)=>m.name==doctorName))return false;
    leaves.add(LeaveEntry(id:'LEAVE-${++_staffSerial}',doctorName:doctorName,start:DateTime(start.year,start.month,start.day),end:DateTime(end.year,end.month,end.day)));
    notifyListeners();_savePlanning();return true;
  }
  void removeLeave(String id){leaves.removeWhere((l)=>l.id==id);notifyListeners();_savePlanning();}

  bool addVacation({required String professorId,required DateTime start,required DateTime end}) {
    if (professorById(professorId)==null || !end.isAfter(start)) return false;
    vacations.add(ConsultationVacation(id:'VAC-${++_staffSerial}',professorId:professorId,start:start,end:end));
    vacations.sort((a,b)=>a.start.compareTo(b.start)); notifyListeners(); _savePlanning(); return true;
  }
  void deleteVacation(String id){vacations.removeWhere((v)=>v.id==id);notifyListeners();_savePlanning();}

  /// L'admission aux urgences utilise la date d'arrivée et l'astreinte SENIOR.
  /// La consultation utilise l'heure de consultation, pas le jour du bloc.
  /// Les chevauchements ne donnent jamais lieu à une attribution arbitraire.
  ProfessorMatch resolveProfessor(String origin,DateTime at) {
    if (origin=='Urgences') {
      final senior=seniorOnName(at);
      if (senior!=null && senior.trim().isNotEmpty) {
        // Affectation directe du senior, quel que soit son titre (règle service confirmée).
        final id = responsibleIdForSenior(senior);
        return ProfessorMatch(professorId:id,
          explanation:'Médecin senior d’astreinte : $senior, responsable automatiquement attribué le ${dayKey(at)}. Les horaires de relève restent à confirmer.',
          mode:'Astreinte senior',requiresSelection:false);
      }
      return const ProfessorMatch(explanation:'Aucune astreinte senior renseignée pour cette date. Sélectionnez le médecin responsable manuellement.',mode:'À confirmer',requiresSelection:true);
    }
    final matches=vacations.where((v)=>!at.isBefore(v.start)&&at.isBefore(v.end)&&professorById(v.professorId)!=null).toList();
    final ids=matches.map((v)=>v.professorId).toSet();
    if (ids.length==1) return ProfessorMatch(professorId:ids.first,explanation:'Professeur de la vacation de consultation à la date et l’heure indiquées.',mode:'Vacation de consultation',requiresSelection:false);
    if (ids.length>1) return const ProfessorMatch(explanation:'Plusieurs vacations de professeurs se chevauchent. Attribution manuelle obligatoire.',mode:'Conflit de vacations',requiresSelection:true);
    // Grille hebdomadaire permanente, communiquée par le service.
    // Les exceptions datées ont déjà été examinées en priorité.
    final slot=referenceConsultantAt(at);
    if (slot!=null) {
      if(slot.professorName==null) {
        return ProfessorMatch(explanation:'Consultation : ${slot.consultantName}. Le document ne désigne aucun professeur responsable pour ce créneau : attribution manuelle obligatoire.',mode:'Consultant sans professeur identifié',requiresSelection:true);
      }
      final name=slot.professorName!;
      TeamMember? found;
      for (final person in professors) {
        if(person.name.toLowerCase()==name.toLowerCase()){found=person;break;}
      }
      if(found!=null) return ProfessorMatch(professorId:found.id,explanation:'Planning hebdomadaire annuel confirmé : ${slot.consultantName} (${slot.startHour}h–${slot.endHour}h).',mode:'Vacation hebdomadaire',requiresSelection:false);
      return ProfessorMatch(explanation:'Consultant ${slot.consultantName} identifié, mais professeur absent de l’annuaire. Attribution manuelle obligatoire.',mode:'À confirmer',requiresSelection:true);
    }
    return const ProfessorMatch(explanation:'Aucune consultation programmée dans ce créneau (ou dimanche). Attribution manuelle obligatoire.',mode:'Hors vacation',requiresSelection:true);
  }
  void changeProfessor(PatientCase patient,String professorId,String reason) {
    if(responsibleById(professorId)==null || reason.trim().isEmpty) return;
    patient.professorId=professorId;
    patient.assignmentMode='Modification manuelle';
    patient.assignmentExplanation=reason.trim();
    notifyListeners();
  }


  AppStore() {
    // Noms relevés de la grille hebdomadaire annuelle (source : mai 2026).
    // Dr BENGHAIT et Dr LAABOULI sont des consultants, non des professeurs.
    for (final name in ['Pr BENSAAD','Pr GHADDOU','Pr NOURI','Pr CHOUKRI']) {
      addProfessor(name);
    }
    // Photo d'octobre 2026 : seniors nommés, juniors non renseignés.
    for (final doctor in ['LAFKIH','GHADDOU','FAHSI','LAABOULI','BENSAAD']) {addSenior(doctor);}
    for (var i=0; i<october2026SeniorByDay.length; i++) {
      setDuty(DateTime(2026,10,i+1),seniorName:october2026SeniorByDay[i]);
    }
    // Données patients intégralement fictives. Aucun dossier réel dans le prototype.
    final now = DateTime.now();
    DateTime at(int dayOffset, int hour, int minute) => DateTime(now.year, now.month, now.day + dayOffset, hour, minute);
    patients.addAll([
      PatientCase(id:'DEMO-001',name:'Patient Démo A',age:'42',origin:'Urgences',insurance:'FAR',motive:'Douleurs de fosse iliaque droite',history:'Évolution clinique à compléter.',exam:'Examen abdominal à compléter.',investigations:'Imagerie à renseigner.',labs:'Biologie à renseigner.',immediatePlan:'Surveillance et bilan préopératoire.',procedure:procedures[0],blockTiming:'Immédiat',admissionTiming:'Immédiate',beforeUnit:'TC1',beforeBox:'03',afterUnit:'TC1',afterBox:'03',expectedDays:1,blockAt:at(0,16,30),admittedAt:at(0,9,15)),
      PatientCase(id:'DEMO-002',name:'Patient Démo B',age:'55',origin:'Consultation',insurance:'CNSS',motive:'Lithiase vésiculaire symptomatique',history:'Éléments à préciser.',exam:'À compléter.',investigations:'À compléter.',labs:'À compléter.',immediatePlan:'Programmation opératoire.',procedure:procedures[1],blockTiming:'Différé',admissionTiming:'Le jour du bloc',beforeUnit:'HDJCH 1',beforeBox:'02',afterUnit:'HGO',afterBox:'08',expectedDays:1,blockAt:at(1,9,0),admittedAt:at(0,11,0)),
      PatientCase(id:'DEMO-003',name:'Patient Démo C',age:'66',origin:'Urgences',insurance:'Assurance privée',motive:'Occlusion intestinale',history:'À compléter.',exam:'À compléter.',investigations:'À compléter.',labs:'À compléter.',immediatePlan:'Surveillance postopératoire.',procedure:'Autre intervention',blockTiming:'Immédiat',admissionTiming:'Immédiate',beforeUnit:'TC2',beforeBox:'04',afterUnit:'REA ADULTE',afterBox:'06',expectedDays:4,blockAt:at(-2,13,0),admittedAt:at(-2,6,0),stage:CaseStage.postoperative,confidentialEnvelopeDone:true),
      PatientCase(id:'DEMO-004',name:'Patient Démo D',age:'39',origin:'Consultation',insurance:'FAR',motive:'Appendicite opérée',history:'À compléter.',exam:'À compléter.',investigations:'À compléter.',labs:'À compléter.',immediatePlan:'Sortie conditionnelle après évaluation.',procedure:procedures[0],blockTiming:'Différé',admissionTiming:'Le jour du bloc',beforeUnit:'HDJM 1',beforeBox:'05',afterUnit:'TC2',afterBox:'07',expectedDays:1,blockAt:at(-1,10,0),admittedAt:at(-1,7,0),stage:CaseStage.dischargeReady),
    ]);
  }

  List<PatientCase> get active => patients.where((p) => p.isActive).toList();
  List<PatientCase> get theatre => active.where((p) => p.stage == CaseStage.preoperative || p.stage == CaseStage.inTheatre).toList()..sort((a,b) => a.blockAt.compareTo(b.blockAt));
  List<PatientCase> get toDischarge => active.where((p) => p.stage == CaseStage.dischargeReady || p.dischargeDue).toList();
  int get occupiedBoxes => active.where((p) => p.physicallyAdmitted && p.stage != CaseStage.inTheatre).length;

  // Détecte un box déjà occupé; l'inventaire réel des boxes devra être importé par l'administrateur.
  PatientCase? conflictingBox(String unit, String box, {String? exceptPatientId}) {
    final norm = box.trim().toLowerCase();
    if (unit.isEmpty || norm.isEmpty) return null;
    for (final p in active) {
      if (p.id == exceptPatientId || !p.physicallyAdmitted || p.stage == CaseStage.inTheatre) continue;
      if (p.currentUnit == unit && p.currentBox.trim().toLowerCase() == norm) return p;
    }
    return null;
  }

  String nextId() => 'LOCAL-${(patients.length + 1).toString().padLeft(3,'0')}';
  void add(PatientCase patient) { patients.insert(0, patient); notifyListeners(); }
  void refresh() => notifyListeners();
  void updateDocument(PatientCase p, DocumentRequirement requirement, {bool? verified, bool? stamped, bool? notApplicable}) {
    if (!p.isActive) return;
    if (notApplicable == true && !requirement.optional) return;
    final check = p.check(requirement.key);
    if (notApplicable != null) {
      check.notApplicable = notApplicable;
      if (notApplicable) { check.verified = false; check.stamped = null; }
    }
    if (verified != null) {
      check.verified = verified;
      if (!verified) check.stamped = null;
      if (verified) check.notApplicable = false;
    }
    if (stamped != null) { check.stamped = stamped; check.notApplicable = false; }
    check.checkedAt = DateTime.now();
    if (requirement.key == 'pli') p.confidentialEnvelopeDone = check.verified;
    notifyListeners();
  }

  /// L'observation n'est pas persistée dans ce prototype non sécurisé.
  /// Après un report, une modification doit être reportée à nouveau.
  void saveDailyObservation(PatientCase p, DailyObservation note) {
    if (!p.isActive || !note.hasContent) return;
    final existingIndex = p.dailyObservations.indexWhere((item) =>
      item.date.year == note.date.year && item.date.month == note.date.month && item.date.day == note.date.day);
    if (existingIndex >= 0) {
      p.dailyObservations[existingIndex] = note;
    } else {
      p.dailyObservations.add(note);
    }
    p.dailyObservations.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  void setObservationReported(PatientCase p, DailyObservation note, {bool? magica, bool? sillage}) {
    if (!p.isActive) return;
    if (magica != null) {
      note.reportedMagica = magica;
      note.reportedMagicaAt = magica ? DateTime.now() : null;
    }
    if (sillage != null) {
      note.reportedSillage = sillage;
      note.reportedSillageAt = sillage ? DateTime.now() : null;
    }
    notifyListeners();
  }

  void toggleEnvelope(PatientCase p) {
    final requirement = ClinicalDocuments.admission[1];
    updateDocument(p, requirement, verified: !p.check('pli').verified);
  }
  void startTheatre(PatientCase p) { p.stage = CaseStage.inTheatre; notifyListeners(); }
  void finishTheatre(PatientCase p) { p.stage = CaseStage.postoperative; notifyListeners(); }
  void markForDischarge(PatientCase p) { p.stage = CaseStage.dischargeReady; notifyListeners(); }
  void confirmDischarge(PatientCase p, {required String prescription,required String report,required String operationReport}) {
    if (!p.allChecked(ClinicalDocuments.discharge)) return;
    p.dischargePrescription=prescription;p.dischargeReport=report;p.operationReport=operationReport;p.dischargeAt=DateTime.now();p.stage=CaseStage.discharged;notifyListeners();
  }

  /// Pont TEMPORAIRE vers le planning local du prototype. Seul le serveur
  /// fournit le rôle APPROUVÉ; aucun choix local ne procure de droits.
  void activateAuthenticatedDoctor({required String id,required String name,
    required String email,required String role,bool isAdmin=false}) {
    if (!['senior','junior'].contains(role)) return;
    String memberId;
    if (role == 'senior') {
      final seniorName = _normalizeClinician(name);
      addSenior(seniorName);
      memberId = 'SENIOR-$seniorName';
    } else {
      addJunior(name);
      memberId = juniors.firstWhere((m) => m.name.toLowerCase()==name.toLowerCase()).id;
    }
    localProfiles
      ..clear()
      ..add(LocalDoctorProfile(id: id,name: name,email: email,role: role,memberId: memberId,isAdmin:isAdmin));
    activeLocalProfileId = id;
    notifyListeners();
  }

  void clearAuthenticatedProfile() {
    localProfiles.clear();
    activeLocalProfileId = null;
    notifyListeners();
  }

  String _profileSeniorName(LocalDoctorProfile p)=>_normalizeClinician(p.name);
  bool isMyDuty(DateTime d,{LocalDoctorProfile? doctor}){
    final p=doctor??activeLocalProfile; if(p==null)return false;
    final duty=dutyOn(d);if(duty==null)return false;
    return p.isSenior ? seniorOnName(d)==_profileSeniorName(p) : duty.juniorId==p.memberId;
  }
  LeaveEntry? myLeave(DateTime d,{LocalDoctorProfile? doctor}){
    final p=doctor??activeLocalProfile;if(p==null)return null;
    for(final leave in leavesOn(d)){
      if(_normalizeClinician(leave.doctorName)==_normalizeClinician(p.name))return leave;
    }
    return null;
  }

  String _personalSlotKey(LocalDoctorProfile doctor, DateTime date) =>
      '${doctor.id}|${dayKey(date)}';

  /// Tous les créneaux historiques sont présentés en 24H, sans changer
  /// l'affectation médicale de la date.
  String? myServiceShift(DateTime date) =>
      activeLocalProfile != null && isMyDuty(date) ? '24h' : null;

  /// Retourne null en cas de succès. La garde de service 24H est conservée
  /// dans DutyDay (une affectation par date). Les congés restent distincts.
  /// L'attribution des patients par senior n'est pas modifiée.
  String? placePersonalEvent(DateTime target,{
    required String kind,DateTime? from,String shift='24h'
  }){
    final p=activeLocalProfile;if(p==null)return 'Profil médecin indisponible.';
    if(!['garde','conge'].contains(kind))return 'Type inconnu.';
    if(kind=='garde' && shift!='24h')return 'Seule la garde de service 24H est autorisée.';
    final sameDay=from!=null && dayKey(from)==dayKey(target);
    if(from!=null && !sameDay &&
        (kind=='garde' ? !isMyDuty(from) : myLeave(from)==null)) {
      return 'Vous ne pouvez déplacer que vos propres événements.';
    }
    if(kind=='garde'){
      if(myLeave(target)!=null)return 'Congé existant : retirez-le avant d’ajouter une garde.';
      final current=dutyOn(target);
      if(p.isSenior){
        final senior=seniorOnName(target);
        if(senior!=null && senior!=_profileSeniorName(p))return 'Garde senior déjà attribuée à $senior.';
      }else if(current?.juniorId!=null && current!.juniorId!=p.memberId){
        return 'Une garde junior est déjà attribuée à un autre médecin.';
      }
      if(!sameDay && from!=null) {
        final prev=dutyOn(from);
        if(prev!=null) setDuty(from,seniorName:p.isSenior?null:prev.seniorName,
          juniorId:p.isSenior?prev.juniorId:null);
        personalServiceShifts.remove(_personalSlotKey(p,from));
      }
      if(!sameDay) {
        final previous=dutyOn(target);
        setDuty(target,seniorName:p.isSenior?_profileSeniorName(p):previous?.seniorName,
          juniorId:p.isSenior?previous?.juniorId:p.memberId);
      }
      personalServiceShifts[_personalSlotKey(p,target)]='24h';
      _savePlanning();
      notifyListeners();
    }else{
      if(isMyDuty(target))return 'Une garde existe déjà pour vous à cette date.';
      if(myLeave(target)!=null)return 'Un congé est déjà présent à cette date.';
      if(sameDay)return null;
      if(from!=null) {
        final old=myLeave(from)!;
        removeLeave(old.id);
      }
      if(!addLeave(doctorName:p.isSenior?_profileSeniorName(p):p.name,
        start:target,end:target)) {
        return 'Impossible de saisir le congé.';
      }
    }
    return null;
  }

  void removePersonalEvent(DateTime target,String kind){
    final p=activeLocalProfile;if(p==null)return;
    if(kind=='conge') {
      final leave=myLeave(target);
      if(leave!=null)removeLeave(leave.id);
      return;
    }
    if(kind=='garde'&&isMyDuty(target)){
      final old=dutyOn(target);
      if(old!=null)setDuty(target,seniorName:p.isSenior?null:old.seniorName,
        juniorId:p.isSenior?old.juniorId:null);
      personalServiceShifts.remove(_personalSlotKey(p,target));
      _savePlanning();
      notifyListeners();
    }
  }

}

final appStore = AppStore();
