import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/bloc_clinical_record.dart';
import 'package:viscera/models.dart';
import 'package:viscera/specialist_opinions.dart';

PatientCase example({bool imported = true, CaseStage stage = CaseStage.preoperative}) =>
  PatientCase(
    id: imported ? 'BLOC-123' : 'LOCAL-TEST',
    name: 'PATIENT FICTIF',
    age: '52', origin: 'Urgences', insurance: 'CNSS',
    motive: 'Exemple', history: '', exam: '', investigations: '', labs: '',
    immediatePlan: '', procedure: 'Intervention fictive',
    blockTiming: 'Différé', admissionTiming: 'Confirmée',
    beforeUnit: 'TC1', beforeBox: '01',
    afterUnit: 'TC2', afterBox: '02', expectedDays: 3,
    blockAt: DateTime(2026, 11, 3, 9),
    admittedAt: DateTime(2026, 11, 2),
    fromBlocProgram: imported,
    stage: stage,
  );

void main() {
  test('Plusieurs avis par séjour, même service, avec statuts indépendants', () {
    final patient = example();
    patient.specialistOpinions.addAll([
      SpecialistOpinion(id:'1',service:'Cardiologie',
        requestedAt:DateTime(2026,11,3)),
      SpecialistOpinion(id:'2',service:'Cardiologie',
        done:true,requestedAt:DateTime(2026,11,3),
        doneAt:DateTime(2026,11,3,15)),
      SpecialistOpinion(id:'3',service:'Pneumologie',
        requestedAt:DateTime(2026,11,3)),
    ]);
    expect(patient.specialistOpinions, hasLength(3));
    final stored = BlocClinicalRecordService.encode(patient);
    final copy = example();
    BlocClinicalRecordService.apply(copy,stored,2);
    expect(copy.specialistOpinions,hasLength(3));
    expect(copy.specialistOpinions[0].service,'Cardiologie');
    expect(copy.specialistOpinions[0].done,isFalse);
    expect(copy.specialistOpinions[1].done,isTrue);
    expect(copy.specialistOpinions[1].doneAt,
      DateTime(2026,11,3,15));
    expect(copy.specialistOpinions[2].service,'Pneumologie');
    expect(copy.clinicalVersion,2);
  });

  test('Ancien dossier : liste d’avis vide et valeurs malformées ignorées', () {
    final patient = example();
    final data = BlocClinicalRecordService.encode(patient);
    data.remove('specialistOpinions');
    BlocClinicalRecordService.apply(patient,data,1);
    expect(patient.specialistOpinions,isEmpty);

    data['specialistOpinions'] = [
      {'id':'alpha','service':'Médecine interne','done':true,
        'requestedAt':'2026-11-03T09:00:00'},
      {'id':'alpha','service':'Médecine interne','done':false},
      {'id':'','service':'','done':true},
    ];
    BlocClinicalRecordService.apply(patient,data,2);
    expect(patient.specialistOpinions,hasLength(1));
    expect(patient.specialistOpinions.single.done,isTrue);
  });

  testWidgets('Ajouter un avis puis le passer de Non fait à Fait',
      (tester) async {
    final patient = example(imported:false);
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:SpecialistOpinionsCard(patient:patient)),
    )));
    expect(find.text('Aucun avis spécialisé demandé durant ce séjour.'),
      findsOneWidget);
    await tester.tap(find.byKey(const Key('add-specialist-opinion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('specialist-opinion-service')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cardiologie').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter cet avis'));
    await tester.pumpAndSettle();

    expect(patient.specialistOpinions,hasLength(1));
    expect(patient.specialistOpinions.single.service,'Cardiologie');
    expect(patient.specialistOpinions.single.done,isFalse);
    expect(find.text('1 avis · 0 fait(s)'),findsOneWidget);
    await tester.tap(find.text('Fait'));
    await tester.pumpAndSettle();
    expect(patient.specialistOpinions.single.done,isTrue);
    expect(patient.specialistOpinions.single.doneAt,isNotNull);
    expect(find.text('1 avis · 1 fait(s)'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Dossier archivé : avis visibles mais non modifiables',
      (tester) async {
    final patient = example(stage:CaseStage.discharged);
    patient.specialistOpinions.add(SpecialistOpinion(
      id:'avis-1',service:'Infectiologie',
      done:true,doneAt:DateTime(2026,11,3),
    ));
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:SpecialistOpinionsCard(
        patient:patient,readOnly:true)),
    )));
    expect(find.text('Infectiologie'), findsOneWidget);
    expect(find.byKey(const Key('add-specialist-opinion')), findsNothing);
    final buttons=tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(buttons.every((button)=>button.onSelected==null),isTrue);
  });
}
