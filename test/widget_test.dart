import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/main.dart';

void main() {
  testWidgets('Écran de configuration sans identifiants Supabase', (tester) async {
    await tester.pumpWidget(const VisceraApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('Configuration VISCERA requise'), findsOneWidget);
  });
}
