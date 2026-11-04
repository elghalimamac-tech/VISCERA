import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/bloc_clinical_record.dart';

PatientCase fixture() => PatientCase(
  id: 'BLOC-44', name: 'PATIENT TEST', age: '79',
  origin: 'Consultation', insurance: 'CNSS',
  motive: '', history: '', exam: '', investigations: '',
  labs: '', immediatePlan: '', procedure: 'Colectomie',
  blockTiming: 'Différé', admissionTiming: 'Admission automatique',
  beforeUnit: 'TC1', beforeBox: '',
  afterUnit: 'TC2', afterBox: '', expectedDays: 4,
  blockAt: DateTime(2026, 11, 4), fromBlocProgram: true,
);

void main() {
  test('Le CFS, l’autonomie, l’ASA et les évaluations restent dans le dossier', () {
    final original = fixture();
    original.cfsScore = 6;
    original.cfsBaselineDate = DateTime(2026, 10, 20);
    original.cfsAssessedAt = DateTime(2026, 11, 4, 8, 30);
    original.asaClass = 'III';
    original.comorbiditySummary = 'HTA, diabète';
    original.nutritionAssessmentStatus = 'faite';
    original.geriatricAssessmentStatus = 'a_evaluer';
    final clinicalData = BlocClinicalRecordService.encode(original);
    expect(clinicalData['cfsScore'], 6);
    expect(clinicalData['cfsBaselineDate'], '2026-10-20');
    expect(clinicalData['asaClass'], 'III');
    expect(clinicalData['procedureOverride'], '');
    final restored = fixture();
    BlocClinicalRecordService.apply(restored, clinicalData, 3);
    expect(restored.cfsScore, 6);
    expect(restored.cfsBaselineDate, DateTime(2026,10,20));
    expect(restored.cfsAssessedAt, DateTime(2026,11,4,8,30));
    expect(restored.asaClass, 'III');
    expect(restored.comorbiditySummary, 'HTA, diabète');
    expect(restored.nutritionAssessmentStatus, 'faite');
    expect(restored.geriatricAssessmentStatus, 'a_evaluer');
    expect(restored.requiresFrailtyAttention, isTrue);
  });

  test('Un dossier ancien sans CFS reste lisible et sans alerte', () {
    final oldData = BlocClinicalRecordService.encode(fixture())
      ..remove('cfsScore')
      ..remove('cfsBaselineDate')
      ..remove('nutritionAssessmentStatus')
      ..remove('geriatricAssessmentStatus');
    final restored = fixture();
    BlocClinicalRecordService.apply(restored, oldData, 2);
    expect(restored.cfsScore, isNull);
    expect(restored.requiresFrailtyAttention, isFalse);
    expect(restored.nutritionAssessmentStatus, 'a_evaluer');
    expect(restored.geriatricAssessmentStatus, 'a_evaluer');
  });

  test('Un score CFS hors bornes et une classe ASA invalide sont ignorés', () {
    final badData = BlocClinicalRecordService.encode(fixture());
    badData['cfsScore'] = 12;
    badData['asaClass'] = 'VII';
    badData['nutritionAssessmentStatus'] = 'automatique';
    final restored = fixture();
    BlocClinicalRecordService.apply(restored, badData, 1);
    expect(restored.cfsScore, isNull);
    expect(restored.asaClass, isEmpty);
    expect(restored.nutritionAssessmentStatus, 'a_evaluer');
  });

  test('CFS 9 signale un besoin d’attention sans calcul automatique', () {
    final patient = fixture();
    expect(patient.requiresFrailtyAttention, isFalse);
    patient.cfsScore = 9;
    expect(patient.requiresFrailtyAttention, isTrue);
    patient.cfsScore = 4;
    expect(patient.requiresFrailtyAttention, isFalse);
  });
}
