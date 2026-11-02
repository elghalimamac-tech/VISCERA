import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/admin_clear_notifications_action.dart';

void main() {
  const actionKey = Key('clear_all_notifications');

  testWidgets('Médecin non-administrateur : Tout effacer invisible',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminClearNotificationsAction(
        permission: Future<bool>.value(false),
        busy: false,
        onClear: () => attempts++,
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(actionKey), findsNothing);
    expect(attempts, 0);
  });

  testWidgets('Autorisation en attente ou erreur : bouton caché',
      (tester) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminClearNotificationsAction(
        permission: pending.future,
        busy: false,
        onClear: () {},
      )),
    ));
    expect(find.byKey(actionKey), findsNothing);
    pending.completeError(StateError('Connexion refusée'));
    await tester.pumpAndSettle();
    expect(find.byKey(actionKey), findsNothing);
  });

  testWidgets('Administrateur approuvé : bouton disponible et fonctionnel',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminClearNotificationsAction(
        permission: Future<bool>.value(true),
        busy: false,
        onClear: () => calls++,
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(actionKey), findsOneWidget);
    await tester.tap(find.byKey(actionKey));
    expect(calls, 1);
  });

  testWidgets('Administrateur : action désactivée durant effacement',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminClearNotificationsAction(
        permission: Future<bool>.value(true),
        busy: true,
        onClear: () {},
      )),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
  });
}
