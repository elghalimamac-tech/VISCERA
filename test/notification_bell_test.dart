import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/notification_bell.dart';

void main() {
  testWidgets('La cloche affiche le nombre non lu et ouvre le centre',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: VisceraNotificationBell(
        unreadCount: 7, onPressed: () => opened++,
      )),
    ));
    expect(find.byKey(const Key('home_notifications_button')), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home_notifications_button')));
    expect(opened, 1);
  });

  testWidgets('Sans alerte, la cloche ne montre pas de compteur',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: VisceraNotificationBell(
        unreadCount: 0, onPressed: () {},
      )),
    ));
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('Le compteur est lisible même au-delà de 99',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: VisceraNotificationBell(
        unreadCount: 132, onPressed: () {},
      )),
    ));
    expect(find.text('99+'), findsOneWidget);
  });
}
