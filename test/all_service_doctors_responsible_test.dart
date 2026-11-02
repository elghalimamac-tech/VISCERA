import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/store.dart';
import 'package:viscera/models.dart';
import 'package:viscera/planning_models.dart';
import 'package:viscera/bloc_clinical_record.dart';

PatientCase sample() => PatientCase(
  id:'TEST-DOCTORS',name:'Patient test fictif',age:'—',
  origin:'Consultation',insurance:'À préciser',
  motive:'',history:'',exam:'',investigations:'',labs:'',immediatePlan:'',
  procedure:'LV',blockTiming:'Différé',admissionTiming:'À confirmer',
  beforeUnit:'',beforeBox:'',afterUnit:'',afterBox:'',
  expectedDays:1,blockAt:DateTime(2026,11,5),
  programSurgeon:'Dr CHIRURGIEN TEST',fromBlocProgram:true,
);

void main() {
  test('Les consultations incluent Dr BENGHAIT et Dr LAABOULI', () {
    final doctors=appStore.responsibleOptions(forEmergencies:false);
    expect(doctors.any((d)=>d.name=='Dr BENGHAIT'),isTrue);
    expect(doctors.any((d)=>d.name=='Dr LAABOULI'),isTrue);
    expect(doctors.any((d)=>d.name=='Pr BENSAAD'),isTrue);
    expect(doctors.any((d)=>d.name=='FAHSI'),isTrue);
    final doctor=appStore.responsibleIdForName('Dr BENGHAIT');
    expect(appStore.responsibleById(doctor)?.name,'Dr BENGHAIT');
  });

  test('Les médecins du programme et les juniors rejoignent le même sélecteur', () {
    final patient=sample();
    final junior=TeamMember(id:'JR-TEST-CHECK',name:'Dr JUNIOR TEST');
    appStore.patients.add(patient);
    appStore.juniors.add(junior);
    try {
      final names=appStore.responsibleOptions(forEmergencies:false)
        .map((x)=>x.name).toList();
      expect(names,contains('Dr CHIRURGIEN TEST'));
      expect(names,contains('Dr JUNIOR TEST'));
      expect(appStore.responsibleById(
        appStore.responsibleIdForName('Dr CHIRURGIEN TEST'))?.name,
        'Dr CHIRURGIEN TEST');
    } finally {
      appStore.patients.remove(patient);
      appStore.juniors.remove(junior);
    }
  });

  test('L’admission et le bloc sont indépendants et persistés', () {
    final patient=sample();
    patient.professorId=appStore.responsibleIdForName('Dr BENGHAIT');
    patient.blockResponsibleId=appStore.responsibleIdForName('FAHSI');
    expect(patient.professorId,isNot(patient.blockResponsibleId));
    final data=BlocClinicalRecordService.encode(patient);
    final reloaded=sample();
    BlocClinicalRecordService.apply(reloaded,data,1);
    expect(reloaded.professorId,patient.professorId);
    expect(reloaded.blockResponsibleId,patient.blockResponsibleId);
  });

  test('Une ancienne fiche sans responsable du bloc reste lisible', () {
    final patient=sample();
    final data=BlocClinicalRecordService.encode(patient)
      ..remove('blockResponsibleId');
    final reloaded=sample();
    BlocClinicalRecordService.apply(reloaded,data,1);
    expect(reloaded.blockResponsibleId,isNull);
    expect(reloaded.programSurgeon,'Dr CHIRURGIEN TEST');
  });
}
