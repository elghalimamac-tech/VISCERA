import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/branding.dart';

void main() {
  test('Logos SVG haute définition intégrés, sans anciens tracés', () {
    for (final name in ['viscera-symbol.svg', 'viscera-symbol-light.svg']) {
      final content = File('assets/branding/$name').readAsStringSync();
      expect(content, contains('viewBox="220 287 810 677"'));
      expect(content, contains('linearGradient'));
      expect(content, contains('L860,327'));
      expect(content, isNot(contains('M804 47 L668 47')));
    }
    final icon = File('assets/branding/viscera-app-icon.svg').readAsStringSync();
    expect(icon, contains('viewBox="0 0 1024 1024"'));
    expect(icon, contains('fill="#00C9BF"'));
    expect(icon, contains('viewBox="220 287 810 677"'));
  });

  testWidgets('Symbole SVG vectoriel visible en version claire et foncée',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Row(children: [
        VisceraMark(size: 60),
        VisceraMark(size: 60,onDark: true),
      ])),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(VisceraMark), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
