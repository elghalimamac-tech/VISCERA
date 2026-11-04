import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/hospital_site.dart';
import 'package:viscera/screens/hospital_selection.dart';

void main() {
  test('HUIM6 est le seul établissement clinique actif', () {
    expect(HospitalSite.huim6.isAvailableForDoctors, isTrue);
    expect(HospitalSite.huick.isAvailableForDoctors, isFalse);
  });

  testWidgets('Le choix est accessible au démarrage sur écran étroit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 730));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    HospitalSite? site;
    await tester.pumpWidget(MaterialApp(
      home:HospitalSelectionPage(onSelected:(value)=>site=value),
    ));
    expect(find.text('Choisissez votre établissement'),findsOneWidget);
    expect(find.text('HUIM6 Bouskoura'),findsOneWidget);
    expect(find.text('HUICK Casablanca'),findsOneWidget);
    expect(find.textContaining('En travaux'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.ensureVisible(
      find.byKey(const Key('hospital-choice-huick')));
    await tester.tap(find.byKey(const Key('hospital-choice-huick')));
    expect(site,HospitalSite.huick);
  });

  testWidgets('La sélection HUIM6 reste disponible',(tester) async {
    HospitalSite? site;
    await tester.pumpWidget(MaterialApp(home:
      HospitalSelectionPage(onSelected:(value)=>site=value),
    ));
    await tester.tap(find.byKey(const Key('hospital-choice-huim6')));
    expect(site,HospitalSite.huim6);
    expect(tester.takeException(),isNull);
  });
}
