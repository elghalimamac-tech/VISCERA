import 'package:flutter/material.dart';
import '../branding.dart';
import '../notification_center_service.dart';
import '../admin_clear_notifications_action.dart';

/// Toutes les notifications persistées pour le médecin connecté (Supabase RLS).
class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key});
  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  final NotificationCenterService _service = NotificationCenterService();
  late Future<List<Map<String, dynamic>>> _items;
  late Future<bool> _canClearAll;
  bool _busy = false;
  bool _unreadOnly = false;
  int _limit = 80;

  @override
  void initState() {
    super.initState();
    _items = _service.fetch(limit: _limit);
    _canClearAll = _service.canClearAll();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _items = _service.fetch(limit: _limit, unreadOnly: _unreadOnly);
    });
  }

  Future<void> _markRead(String id) async {
    if (_busy) return;
    try {
      await _service.markRead(id);
      _refresh();
    } catch (_) {
      if (mounted) _notice('Impossible de marquer la notification comme lue.');
    }
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _clearAll() async {
    if (_busy) return;
    // Vérification supplémentaire, indispensable si le rôle a été révoqué
    // depuis l'ouverture de cet écran.
    try {
      if (!await _service.canClearAll()) return;
    } catch (_) {
      if (mounted) _notice('Accès administrateur impossible à vérifier.');
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Administrateur · Effacer toutes mes notifications ?'),
        content: const Text(
          'Les notifications seront retirées de votre centre sur tous vos '
          'appareils. Cette action ne peut pas être annulée. '
          'Les dossiers patients et les alarmes de garde programmées '
          'ne seront pas modifiés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.clearAll();
      if (!mounted) return;
      _limit = 80;
      _refresh();
      _notice('Toutes vos notifications ont été effacées.');
    } catch (_) {
      if (mounted) _notice('Effacement impossible. Vérifiez votre connexion.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _dateLabel(BuildContext context, Object? source) {
    final date = DateTime.tryParse(source?.toString() ?? '');
    if (date == null) return '';
    final local = date.toLocal();
    final formattedDate = MaterialLocalizations.of(context).formatMediumDate(local);
    final hour = TimeOfDay.fromDateTime(local).format(context);
    return '$formattedDate · $hour';
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'program_updates':
        return Icons.event_note_outlined;
      case 'urgent_admissions':
        return Icons.emergency_outlined;
      case 'discharge_review':
        return Icons.event_available_outlined;
      case 'discharge_confirmed':
        return Icons.logout_rounded;
      case 'access_updates':
        return Icons.verified_user_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const VisceraPageTitle('Notifications'),
      actions: [
        IconButton(
          tooltip: 'Actualiser les notifications',
          onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 5),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Toutes'),
                        selected: !_unreadOnly,
                        onSelected: _busy ? null : (_) {
                          setState(() {
                            _unreadOnly = false;
                            _limit = 80;
                            _items = _service.fetch(limit: _limit);
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Non lues'),
                        selected: _unreadOnly,
                        onSelected: _busy ? null : (_) {
                          setState(() {
                            _unreadOnly = true;
                            _limit = 80;
                            _items = _service.fetch(
                              limit: _limit, unreadOnly: true);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                AdminClearNotificationsAction(
                  permission: _canClearAll,
                  busy: _busy,
                  onClear: _clearAll,
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Notifications indisponibles. '
                              'Vérifiez votre connexion.'),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _refresh,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none_rounded,
                              size: 42, color: Color(0xFF617A80)),
                          SizedBox(height: 14),
                          Text('Aucune notification',
                              style: TextStyle(fontWeight: FontWeight.w800,
                                  fontSize: 17)),
                          SizedBox(height: 6),
                          Text('Les nouvelles alertes VISCERA '
                              'apparaîtront ici.',
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: items.length + (items.length >= _limit ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () {
                            setState(() {
                              _limit += 80;
                              _items = _service.fetch(
                                limit: _limit, unreadOnly: _unreadOnly);
                            });
                          },
                          icon: const Icon(Icons.expand_more_rounded),
                          label: const Text('Afficher plus de notifications'),
                        ),
                      );
                    }
                    final item = items[index];
                    final unread = item['read_at'] == null;
                    final id = item['id'] as String;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 7),
                      leading: CircleAvatar(
                        backgroundColor: unread
                            ? const Color(0xFFEAF6F7)
                            : const Color(0xFFF1F4F4),
                        child: Icon(_iconFor(item['kind'] as String? ?? ''),
                            color: const Color(0xFF083B46)),
                      ),
                      title: Text(
                        item['title'] as String? ?? 'VISCERA',
                        style: TextStyle(fontWeight:
                            unread ? FontWeight.w800 : FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),
                          Text(item['body'] as String? ?? ''),
                          const SizedBox(height: 5),
                          Text(_dateLabel(context, item['created_at']),
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF617A80))),
                        ],
                      ),
                      trailing: unread
                          ? const Icon(Icons.circle,
                              color: Color(0xFF13B8B0), size: 10)
                          : null,
                      onTap: unread && !_busy ? () => _markRead(id) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
