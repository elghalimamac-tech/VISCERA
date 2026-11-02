import 'package:flutter/material.dart';

/// Affiche l'action de nettoyage uniquement quand le serveur a confirmé
/// que le compte actif possède un rôle administrateur approuvé.
class AdminClearNotificationsAction extends StatelessWidget {
  const AdminClearNotificationsAction({
    super.key,
    required this.permission,
    required this.busy,
    required this.onClear,
  });

  final Future<bool> permission;
  final bool busy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: permission,
    builder: (context, snapshot) {
      // Jamais de bouton pendant la vérification, en cas d'erreur ou
      // lorsque le médecin n'est pas administrateur.
      if (snapshot.data != true) return const SizedBox.shrink();
      return TextButton.icon(
        key: const Key('clear_all_notifications'),
        onPressed: busy ? null : onClear,
        icon: const Icon(Icons.delete_sweep_outlined, size: 20),
        label: const Text('Tout effacer'),
      );
    },
  );
}
