import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../store.dart';
import '../theme.dart';

/// Tous les comptes Auth, même ceux dont le profil médical est absent.
/// Les actions sensibles ne sont accessibles qu'au propriétaire de VISCERA ;
/// chaque requête est à nouveau autorisée dans la fonction serveur.
class AdminUsersPanel extends StatefulWidget {
  const AdminUsersPanel({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<AdminUsersPanel> createState() => _AdminUsersPanelState();
}

class _AdminUsersPanelState extends State<AdminUsersPanel> {
  late Future<List<Map<String, dynamic>>> _users;
  bool _busy = false;
  String _search = '';
  bool get _isOwner => appStore.activeLocalProfile?.isVisceraOwner == true;

  @override
  void initState() {
    super.initState();
    _users = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final response =
        await Supabase.instance.client.rpc('viscera_admin_all_users');
    if (response is! List) throw StateError('Liste indisponible');
    return response.map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  void _refresh() {
    if (mounted) setState(() => _users = _load());
  }

  void _notice(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFF9B2634) : null,
      duration: const Duration(seconds: 6),
    ));
  }

  Future<void> _perform(
    Map<String, dynamic> doctor,
    String action, {
    Map<String, dynamic> extra = const {},
  }) async {
    if (_busy || !_isOwner || doctor['is_owner'] == true) return;
    setState(() => _busy = true);
    try {
      final result = await Supabase.instance.client.functions.invoke(
        'viscera-admin-users',
        body: {
          'action': action,
          'target_id': doctor['user_id'],
          ...extra,
        },
      );
      if (result.data is! Map || result.data['success'] != true) {
        throw StateError('Action refusée par le serveur');
      }
      _notice(switch (action) {
        'delete' => 'Compte définitivement supprimé.',
        'set_password' => 'Mot de passe modifié avec succès.',
        'set_admin' => extra['is_admin'] == true
            ? 'Permission ADMIN accordée.'
            : 'Permission ADMIN retirée.',
        _ => 'Modification enregistrée.',
      });
      _refresh();
      widget.onChanged();
    } catch (_) {
      _notice(
        action == 'delete'
          ? 'Suppression impossible : vérifiez les liens avec les dossiers '
            'patients, les fichiers du compte ou les autorisations.'
          : 'Action refusée. Vérifiez vos droits et la connexion au serveur.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> doctor) async {
    if (!_isOwner || doctor['is_owner'] == true || _busy) return;
    final confirmation = TextEditingController();
    bool typedCorrectly = false;
    final label = (doctor['display_name'] as String?) ?? 'ce compte';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFB42332)),
            SizedBox(width: 9),
            Expanded(child: Text('Supprimer définitivement ?')),
          ]),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vous allez supprimer le compte de $label '
                'et son accès VISCERA. Cette opération est irréversible.'),
              const SizedBox(height: 10),
              const Text('Les dossiers médicaux reliés à ce compte '
                'ne seront jamais effacés par cette action.',
                style: TextStyle(color: VColors.muted, fontSize: 12)),
              const SizedBox(height: 17),
              const Text('Pour confirmer, réécrivez exactement SUPPRIMER :',
                style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: confirmation,
                autofocus: true,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'SUPPRIMER',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    setDialogState(() => typedCorrectly = value == 'SUPPRIMER'),
              ),
            ],
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: typedCorrectly
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42332),
              ),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Supprimer définitivement'),
            ),
          ],
        ),
      ),
    );
    confirmation.dispose();
    if (accepted == true && mounted) {
      await _perform(doctor, 'delete', extra: {'confirmation': 'SUPPRIMER'});
    }
  }

  Future<void> _changePassword(Map<String, dynamic> doctor) async {
    if (!_isOwner || doctor['is_owner'] == true || _busy) return;
    final formKey = GlobalKey<FormState>();
    final password = TextEditingController();
    final repetition = TextEditingController();
    bool hidden = true;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Changer le mot de passe'),
          content: SingleChildScrollView(
            child: Form(key: formKey, child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor['email'] as String? ?? 'Utilisateur VISCERA',
                  style: const TextStyle(color: VColors.muted)),
                const SizedBox(height: 10),
                const Text('Le nouveau mot de passe sera appliqué '
                  'directement au compte Supabase Auth. Ne le partagez '
                  'que par un canal sécurisé.',
                  style: TextStyle(fontSize: 12, color: VColors.muted)),
                const SizedBox(height: 15),
                TextFormField(
                  controller: password,
                  obscureText: hidden,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    suffixIcon: IconButton(
                      icon: Icon(hidden ? Icons.visibility : Icons.visibility_off),
                      tooltip: 'Afficher / masquer',
                      onPressed: () => setDialogState(() => hidden = !hidden),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 12) {
                      return 'Au moins 12 caractères requis.';
                    }
                    if (value.length > 128 || value.trim() != value) {
                      return '128 caractères maximum, sans espaces aux extrémités.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: repetition,
                  obscureText: hidden,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                  ),
                  validator: (value) => value == password.text
                      ? null : 'Les deux mots de passe sont différents.',
                ),
              ],
            )),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(dialogContext, password.text);
                }
              },
              child: const Text('Modifier le mot de passe'),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    repetition.dispose();
    if (result != null && mounted) {
      await _perform(doctor, 'set_password', extra: {'password': result});
    }
  }

  Future<void> _setAdmin(Map<String, dynamic> doctor) async {
    if (!_isOwner || doctor['is_owner'] == true || _busy) return;
    final granted = doctor['is_admin'] == true;
    if (!granted && doctor['approval_status'] != 'approved') {
      _notice('Approuvez d’abord le compte médecin avant de lui '
        'accorder le rôle ADMIN.', error: true);
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(granted ? 'Retirer la permission ADMIN ?'
            : 'Accorder la permission ADMIN ?'),
        content: Text(granted
          ? 'Ce médecin perdra son accès à la page Administration. '
            'Son accès médical normal reste inchangé.'
          : 'Ce médecin pourra consulter les comptes VISCERA et '
            'approuver ou désactiver des inscriptions. '
            'La suppression de comptes, les mots de passe et la gestion '
            'des permissions ADMIN resteront réservés au propriétaire.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(granted ? 'Retirer ADMIN' : 'Accorder ADMIN'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await _perform(doctor, 'set_admin',
        extra: {'is_admin': !granted});
    }
  }

  String _status(Map<String, dynamic> user) {
    if (user['is_owner'] == true) return 'Propriétaire principal';
    if (user['is_admin'] == true) return 'Administrateur';
    return switch (user['approval_status'] as String?) {
      'approved' => 'Actif',
      'disabled' => 'Désactivé',
      'pending' => 'En attente',
      _ => 'Sans profil médical',
    };
  }

  Widget _account(Map<String, dynamic> user) {
    final ownerAccount = user['is_owner'] == true;
    final isAdmin = user['is_admin'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E9E5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: VColors.softMint,
            child: Icon(isAdmin ? Icons.admin_panel_settings_outlined
              : Icons.person_outline, color: VColors.ink),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((user['display_name'] as String?) ?? 'Utilisateur',
                style: const TextStyle(
                  fontWeight: FontWeight.w800, color: VColors.ink)),
              const SizedBox(height: 3),
              Text(user['email'] as String? ?? 'E-mail non renseigné',
                style: const TextStyle(fontSize: 12, color: VColors.muted)),
              const SizedBox(height: 3),
              Text(_status(user), style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          )),
        ]),
        if (_isOwner && !ownerAccount) ...[
          const SizedBox(height: 11),
          Wrap(spacing: 7, runSpacing: 7, children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _changePassword(user),
              icon: const Icon(Icons.lock_reset, size: 17),
              label: const Text('Mot de passe'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _setAdmin(user),
              icon: Icon(isAdmin ? Icons.remove_moderator_outlined
                : Icons.admin_panel_settings_outlined, size: 17),
              label: Text(isAdmin ? 'Retirer ADMIN' : 'Donner ADMIN'),
            ),
            TextButton.icon(
              onPressed: _busy ? null : () => _deleteUser(user),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB42332)),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Supprimer'),
            ),
          ]),
        ] else if (ownerAccount)
          const Padding(
            padding: EdgeInsets.only(top: 9),
            child: Text('Compte principal protégé',
              style: TextStyle(color: VColors.muted, fontSize: 11)),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF0F5F2),
      border: Border.all(color: const Color(0xFFDDE9E2)),
      borderRadius: BorderRadius.circular(17),
    ),
    child: ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.manage_accounts_outlined, color: VColors.ink),
      title: const Text('Tous les utilisateurs VISCERA',
        style: TextStyle(fontWeight: FontWeight.w800, color: VColors.ink)),
      subtitle: const Text('Comptes Auth · rôles · sécurité',
        style: TextStyle(color: VColors.muted, fontSize: 12)),
      childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
      children: [
        const Divider(),
        if (!_isOwner) const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('Consultation des comptes. Les modifications sensibles '
            'sont réservées au propriétaire principal.',
            style: TextStyle(color: VColors.muted, fontSize: 12)),
        ),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Nom ou adresse e-mail',
            prefixIcon: Icon(Icons.search),
            filled: true, fillColor: Colors.white,
          ),
          onChanged: (value) => setState(() => _search = value.toLowerCase()),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _users,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(22),
                child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Column(children: [
                const Text('Impossible de charger les comptes.'),
                TextButton.icon(onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer')),
              ]);
            }
            final users = (snapshot.data ?? []).where((entry) {
              final text =
                  '${entry['display_name'] ?? ''} ${entry['email'] ?? ''}'
                    .toLowerCase();
              return text.contains(_search.trim());
            }).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Text('${users.length} utilisateur(s)',
                      style: const TextStyle(color: VColors.muted)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Actualiser les utilisateurs',
                      onPressed: _busy ? null : _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ]),
                ),
                if (users.isEmpty)
                  const Padding(padding: EdgeInsets.all(18),
                    child: Center(child: Text('Aucun utilisateur trouvé.')))
                else ...users.map(_account),
              ],
            );
          },
        ),
      ],
    ),
  );
}
