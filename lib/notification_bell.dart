import 'package:flutter/material.dart';

/// Bouton de l'accueil partagé par Android et Flutter Web.
class VisceraNotificationBell extends StatelessWidget {
  const VisceraNotificationBell({
    super.key,
    required this.unreadCount,
    required this.onPressed,
  });
  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('home_notifications_button'),
    tooltip: unreadCount > 0
        ? '$unreadCount notification(s) non lue(s)'
        : 'Ouvrir le centre de notifications',
    onPressed: onPressed,
    icon: Badge(
      isLabelVisible: unreadCount > 0,
      label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
      backgroundColor: const Color(0xFF13B8B0),
      textColor: const Color(0xFF083B46),
      child: const Icon(Icons.notifications_none_rounded,
          color: Color(0xFF083B46), size: 26),
    ),
  );
}
