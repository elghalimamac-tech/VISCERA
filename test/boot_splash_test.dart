import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/boot_splash.dart';
import 'package:viscera/branding.dart';

void main() {
  testWidgets('VISCERA splash : logo sombre et barre de chargement',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: VisceraBootSplash(message: 'Connexion sécurisée…'),
    ));
    expect(find.byType(VisceraMark), findsOneWidget);
    expect(find.text('VISCERA'), findsOneWidget);
    expect(find.text('CHIRURGIE VISCÉRALE'), findsOneWidget);
    expect(find.text('Connexion sécurisée…'), findsOneWidget);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, isNull);
    expect(indicator.backgroundColor, const Color(0xFFDFEFF1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Messages du chargement sont réellement réactifs',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: VisceraBootSplash(message: 'Restauration du planning…'),
    ));
    expect(find.text('Restauration du planning…'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
      home: VisceraBootSplash(message: 'Ouverture de VISCERA…'),
    ));
    expect(find.text('Ouverture de VISCERA…'), findsOneWidget);
  });
}
