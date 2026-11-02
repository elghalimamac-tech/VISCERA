import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../branding.dart';

/// Boîte d'alertes : chaque médecin ne voit que ses notifications (RLS).
class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key});
  @override State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  late Future<List<Map<String, dynamic>>> _items;
  @override void initState() { super.initState(); _refresh(); }

  void _refresh() {
    _items = _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    final response = await Supabase.instance.client
      .from('viscera_notifications')
      .select('id,kind,title,body,created_at,read_at')
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .limit(100);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _markRead(String id) async {
    try {
      await Supabase.instance.client.from('viscera_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
      if (mounted) setState(_refresh);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de marquer la notification comme lue.')));
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const VisceraPageTitle('Centre de notifications'),
      actions: [IconButton(
        tooltip: 'Actualiser',
        icon: const Icon(Icons.refresh),
        onPressed: () => setState(_refresh),
      )],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text(
            'Notifications indisponibles. Vérifiez votre connexion et réessayez.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('Aucune notification.'));
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            final unread = item['read_at'] == null;
            return ListTile(
              leading: Icon(unread
                ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
              title: Text(item['title'] as String? ?? 'VISCERA',
                style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w500)),
              subtitle: Text(item['body'] as String? ?? ''),
              trailing: unread ? const Icon(Icons.circle, size: 9) : null,
              onTap: unread ? () => _markRead(item['id'] as String) : null,
            );
          },
        );
      },
    ),
  );
}
