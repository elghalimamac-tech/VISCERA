import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/models.dart';
import 'package:viscera/screens/daily_observations.dart';

PatientCase _patient() => PatientCase(
  id:'BLOC-OBS-TEST', name:'PATIENT TEST', age:'50',
  origin:'Consultation', insurance:'CNSS', motive:'Douleur initiale',
  history:'Interrogatoire initial', exam:'Examen initial',
  investigations:'Imagerie initiale', labs:'Bilan initial',
  immediatePlan:'Surveillance',
  procedure:'Colectomie', blockTiming:'Différé',
  admissionTiming:'Admission automatique',
  beforeUnit:'TC1', beforeBox:'01', afterUnit:'TC1', afterBox:'01',
  expectedDays:4, blockAt:DateTime(2026,11,5),
  admittedAt:DateTime(2026,11,5),
  fromBlocProgram:true,stage:CaseStage.postoperative,
);

void main() {
  test('Jour admission séparé des notes quotidiennes, tri du plus récent',
      () {
    final patient=_patient();
    patient.dailyObservations.addAll([
      DailyObservation(date:DateTime(2026,11,6),
        clinicalExam:'J2'),
      DailyObservation(date:DateTime(2026,11,5),
        clinicalExam:'Observation initiale'),
      DailyObservation(date:DateTime(2026,11,7),
        clinicalExam:'J3'),
    ]);
    expect(admissionObservationFor(patient)?.clinicalExam,
      'Observation initiale');
    expect(currentObservationsFor(patient)
      .map((note)=>note.clinicalExam).toList(), ['J3','J2']);
    expect(patient.dailyObservations,hasLength(3));
  });

  testWidgets('Magica et Sillage apparaissent dans une seule case',
      (tester) async {
    final patient=_patient();
    final note=DailyObservation(date:DateTime(2026,11,6),
      clinicalExam:'Surveillance',biology:{'crp':100,'wbc':12,'hb':10.2});
    patient.dailyObservations.add(note);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body:SingleChildScrollView(child:DailyObservationCard(
        patient:patient,observation:note)),
    )));
    expect(find.byType(CheckboxListTile),findsOneWidget);
    expect(find.text('Reporté sur Magica / Sillage'),findsOneWidget);
    expect(find.textContaining('CRP : 100'),findsOneWidget);
    expect(find.textContaining('Hémoglobine : 10.2'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
