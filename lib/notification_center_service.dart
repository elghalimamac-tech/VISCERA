import 'package:supabase_flutter/supabase_flutter.dart';

/// Accès aux alertes VISCERA privées du médecin connecté.
/// L'archivage ne supprime aucun dossier, ni aucune alarme de garde Android.
class NotificationCenterService {
  NotificationCenterService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<int> unreadCount() async {
    if (_userId == null) return 0;
    final value = await _client.rpc('viscera_unread_notification_count');
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  Future<List<Map<String, dynamic>>> fetch({
    int limit = 80,
    bool unreadOnly = false,
  }) async {
    final id = _userId;
    if (id == null) return [];
    var query = _client
        .from('viscera_notifications')
        .select('id,kind,title,body,created_at,read_at')
        .eq('user_id', id)
        .isFilter('dismissed_at', null);
    if (unreadOnly) query = query.isFilter('read_at', null);
    final data = await query
        .order('created_at', ascending: false)
        .range(0, limit - 1);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> markRead(String notificationId) async {
    final id = _userId;
    if (id == null) return;
    await _client.from('viscera_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId)
        .eq('user_id', id)
        .isFilter('dismissed_at', null);
  }

  /// Le statut admin vient d'une ligne protégée de doctor_profiles,
  /// pas d'un champ utilisateur modifiable dans le JWT.
  Future<bool> canClearAll() async {
    final id = _userId;
    if (id == null) return false;
    final profile = await _client.from('doctor_profiles')
        .select('is_admin,approval_status')
        .eq('user_id', id)
        .maybeSingle();
    return profile?['is_admin'] == true &&
        profile?['approval_status'] == 'approved';
  }

  /// Archive toutes les notifications visibles du compte, sans limite de page.
  /// Les enregistrements sont conservés côté serveur pour l'audit et
  /// ne réapparaissent pas au prochain lancement.
  Future<void> clearAll() async {
    final id = _userId;
    if (id == null || !await canClearAll()) {
      throw StateError('Cette action est réservée à l’administrateur VISCERA.');
    }
    await _client.from('viscera_notifications')
        .update({'dismissed_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', id)
        .isFilter('dismissed_at', null);
  }
}
