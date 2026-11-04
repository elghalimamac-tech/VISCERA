import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/bloc_clinical_record.dart';
import 'package:viscera/clinical_score_engine.dart';

PatientCase patient() => PatientCase(
  id: 'MANUAL-1', name: 'TEST', age: '74',
  origin: 'Consultation', insurance: '', motive: '', history: '',
  exam: '', investigations: '', labs: '', immediatePlan: '',
  procedure: 'Colectomie', blockTiming: 'Différé',
  admissionTiming: 'Programmée', beforeUnit: 'TC1',
  beforeBox: '', afterUnit: 'TC2', afterBox: '',
  expectedDays: 4, blockAt: DateTime(2026, 11, 4),
  fromManualAdmission: true,
);

void main() {
  test('NRS-2002 inclut +1 à partir de 70 ans, pas de score incomplet', () {
    expect(ClinicalScoring.compute('nrs2002',
      {'nutrition':'1','disease':'1'},age:74)?.value, '3');
    expect(ClinicalScoring.compute('nrs2002',
      {'nutrition':'1','disease':'1'},age:69)?.value, '2');
    expect(ClinicalScoring.compute('nrs2002',
      {'nutrition':'1'},age:74), isNull);
    expect(ClinicalScoring.compute('nrs2002',
      {'nutrition':'1','disease':'1'}), isNull);
  });

  test('ARISCAT : 7 paramètres, catégories et données manquantes', () {
    final answers = {'spo2':'8','infection':'0','hb':'11',
      'incision':'15','duration':'16','emergency':'0'};
    final result = ClinicalScoring.compute('ariscat', answers,age:74);
    expect(result?.value, '53');
    expect(result?.interpretation, contains('élevé'));
    expect(ClinicalScoring.compute('ariscat',
      {...answers}..remove('hb'),age:74), isNull);
  });

  test('RCRI : les 6 facteurs sont nécessaires', () {
    final answers = {'surgery':'1','ischemia':'0','heartFailure':'1',
      'stroke':'0','insulin':'0','creatinine':'0'};
    expect(ClinicalScoring.compute('rcri',answers)?.value, '2');
    expect(ClinicalScoring.compute('rcri',
      {...answers}..remove('creatinine')), isNull);
  });

  test('Caprini : total validé saisi, pas de formulaire partiel', () {
    expect(ClinicalScoring.compute('caprini', {'total':'8'})?.value,'8');
    expect(ClinicalScoring.compute('caprini', {'total':'-1'}),isNull);
    expect(ClinicalScoring.compute('caprini', {}),isNull);
  });

  test('NEWS2 : constantes normales, risque élevé, paramètre isolé coté 3', () {
    final normal = {'rr':'16','spo2':'97','oxygen':'no','scale':'1',
      'sbp':'120','pulse':'80','conscious':'alert','temp':'37'};
    expect(ClinicalScoring.compute('news2',normal)?.value,'0');
    final single = {...normal,'rr':'8'};
    expect(ClinicalScoring.compute('news2',single)?.value,'3');
    expect(ClinicalScoring.compute('news2',single)?.parameterAtThree,isTrue);
    final severe = {...normal,'rr':'26','spo2':'90','oxygen':'yes'};
    expect(ClinicalScoring.compute('news2',severe)?.value,'8');
    expect(ClinicalScoring.compute('news2',
      {...normal}..remove('temp')),isNull);
  });

  test('Clavien-Dindo : grade médical et validation des valeurs', () {
    expect(ClinicalScoring.compute('clavien',{'grade':'IIIb'})?.value,'IIIb');
    expect(ClinicalScoring.compute('clavien',{'grade':'VII'}),isNull);
  });

  test('Scores conservés dans clinical_data sans effacer le CFS', () {
    final p = patient()..cfsScore = 5;
    p.clinicalScores['nrs2002'] = {
      'value':'3', 'inputs':{'nutrition':'1','disease':'1'},
      'assessedAt':'2026-11-04T10:00:00Z','schemaVersion':1};
    final encoded=BlocClinicalRecordService.encode(p);
    final restored=patient();
    BlocClinicalRecordService.apply(restored,encoded,1);
    expect(restored.cfsScore,5);
    expect((restored.clinicalScores['nrs2002'] as Map)['value'],'3');
    expect(BlocClinicalRecordService.encode(restored)['clinicalScores'],
      encoded['clinicalScores']);
  });
}
