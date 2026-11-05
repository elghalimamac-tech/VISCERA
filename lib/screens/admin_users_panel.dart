import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../doctor_registration_options.dart';
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
  bool get _isAdmin => appStore.activeLocalProfile?.isAdmin == true;

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

  /// Même liste de grades et de passages que lors de l'inscription.
  /// L'autorisation réelle est contrôlée dans la fonction SQL côté serveur.
  Future<void> _editGrade(Map<String, dynamic> doctor) async {
    if (_busy || !_isAdmin || doctor['is_owner'] == true ||
        doctor['requested_role'] != 'junior' ||
        (doctor['is_admin'] == true && !_isOwner)) return;

    final previousCategory = doctor['junior_category'] as String?;
    final previousPassage =
        (doctor['internship_passage'] as num?)?.toInt();
    String? category = juniorCategories.containsKey(previousCategory)
        ? previousCategory : null;
    int? passage = passagesForCategory(category).contains(previousPassage)
        ? previousPassage : null;
    final formKey = GlobalKey<FormState>();

    final selection = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier le grade du médecin'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctor['display_name'] as String? ?? 'Médecin VISCERA',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(doctor['email'] as String? ?? '',
                    style: const TextStyle(
                      fontSize: 12, color: VColors.muted)),
                  const SizedBox(height: 15),
                  const Text('Sélectionnez le grade réel du médecin. '
                    'Les choix sont identiques à ceux de l’inscription.',
                    style: TextStyle(fontSize: 12, color: VColors.muted)),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Grade médical',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Interne ou résident'),
                    items: juniorCategories.entries.map((entry) =>
                      DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value,
                          overflow: TextOverflow.ellipsis),
                      ),
                    ).toList(),
                    validator: (value) => value == null
                        ? 'Choisissez le grade du médecin.' : null,
                    onChanged: (value) => setDialogState(() {
                      category = value;
                      passage = null;
                    }),
                  ),
                  if (passagesForCategory(category).isNotEmpty) ...[
                    const SizedBox(height: 13),
                    DropdownButtonFormField<int>(
                      key: ValueKey(category),
                      value: passage,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Passage d’internat',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Choisir le passage'),
                      items: passagesForCategory(category).map((number) =>
                        DropdownMenuItem<int>(
                          value: number,
                          child: Text(gradeLabel(category, number)
                            .split('— ').last),
                        ),
                      ).toList(),
                      validator: (value) => value == null
                          ? 'Choisissez le passage.' : null,
                      onChanged: (value) => setDialogState(() {
                        passage = value;
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                if (validateMedicalGrade(
                  role: 'junior',
                  juniorCategory: category,
                  internshipPassage: passage,
                ) != null) return;
                Navigator.pop(dialogContext,
                  {'category': category, 'passage': passage});
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (selection == null || !mounted) return;
    if (selection['category'] == previousCategory &&
        selection['passage'] == previousPassage) return;

    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc(
        'viscera_admin_update_junior_grade',
        params: {
          'p_target': doctor['user_id'],
          'p_category': selection['category'],
          'p_passage': selection['passage'],
        },
      );
      _notice('Grade médical mis à jour : '
        '${gradeLabel(selection['category'] as String?,
          selection['passage'] as int?)}');
      _refresh();
      widget.onChanged();
    } on PostgrestException {
      _notice('Modification refusée : vérifiez vos autorisations '
        'ou la catégorie sélectionnée.', error: true);
    } catch (_) {
      _notice('Impossible d’enregistrer le grade. '
        'Vérifiez la connexion.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAdmin(Map<String, dynamic> doctor) async {
    if (!_isOwner || doctor['is_owner'] == true || _busy) return;
    final granted = doctor['is_admin'] == true;
    if (!granted && doctor['approval_status'] != 'approved') {
      _notice('Approuvez d’abord le médecin avant de lui donner ADMIN.',
        error: true);
      return;
    }
    // La confirmation écrite est nécessaire seulement pour ACCORDER ADMIN.
    final controller = TextEditingController();
    bool phraseValide = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text(granted
              ? 'Retirer la permission ADMIN ?'
              : 'Confirmer la permission ADMIN'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(doctor['display_name'] as String? ?? 'Médecin VISCERA',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(doctor['email'] as String? ?? '',
                  style: const TextStyle(color: VColors.muted)),
                const SizedBox(height: 15),
                Text(granted
                    ? 'Ce médecin perdra ses droits administrateur. '
                      'Son accès médical restera inchangé.'
                    : 'Ce médecin pourra consulter les comptes VISCERA '
                      'et approuver ou bloquer des inscriptions. '
                      'La suppression des comptes et les autorisations '
                      'sensibles restent réservées au propriétaire.'),
                if (!granted) ...[
                  const SizedBox(height: 17),
                  const Text('Pour accorder ces droits, écrivez exactement :',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  const SelectableText('DONNER ADMIN',
                    style: TextStyle(fontWeight: FontWeight.w900,
                      letterSpacing: 1.2, color: VColors.ink)),
                  const SizedBox(height: 9),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Confirmation',
                      hintText: 'DONNER ADMIN',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                      updateDialog(() => phraseValide = value == 'DONNER ADMIN'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: granted || phraseValide
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              icon: Icon(granted
                  ? Icons.remove_moderator_outlined
                  : Icons.admin_panel_settings_outlined),
              label: Text(granted ? 'Retirer ADMIN' : 'Donner ADMIN'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (accepted == true && mounted) {
      await _perform(doctor, 'set_admin', extra: {
        'is_admin': !granted,
        if (!granted) 'confirmation': 'DONNER ADMIN',
      });
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
    final admin = user['is_admin'] == true;
    final isJunior = user['requested_role'] == 'junior';
    final grade = isJunior
        ? gradeLabel(user['junior_category'] as String?,
            (user['internship_passage'] as num?)?.toInt())
        : user['requested_role'] == 'senior'
            ? 'Senior · ${user['senior_title'] ?? 'Dr'}'
            : 'Profil médical non renseigné';
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE1E9E5)),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
        leading: CircleAvatar(
          backgroundColor: VColors.softMint,
          child: Icon(admin ? Icons.admin_panel_settings_outlined
              : Icons.person_outline, color: VColors.ink),
        ),
        title: Text((user['display_name'] as String?) ?? 'Utilisateur',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800,
            color: VColors.ink, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(user['email'] as String? ?? 'E-mail non renseigné',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: VColors.muted)),
            const SizedBox(height: 3),
            Text(_status(user), style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: user['approval_status'] == 'approved'
                  ? const Color(0xFF117C57) : VColors.muted)),
          ],
        ),
        children: [
          const Divider(height: 15),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(grade.isNotEmpty ? grade : 'Grade non renseigné',
              style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: VColors.ink)),
          ),
          if (ownerAccount)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Align(alignment: Alignment.centerLeft,
                child: Text('Compte principal protégé',
                  style: TextStyle(fontSize: 12, color: VColors.muted))),
            ),
          if (!ownerAccount) ...[
            if (_isAdmin && isJunior && (!admin || _isOwner)) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _editGrade(user),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier le grade'),
                ),
              ),
            ],
            if (_isOwner) ...[
              const SizedBox(height: 9),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Sécurité du compte',
                  style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w800, color: VColors.muted)),
              ),
              const SizedBox(height: 7),
              Wrap(spacing: 7, runSpacing: 7, children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _changePassword(user),
                  icon: const Icon(Icons.lock_reset, size: 17),
                  label: const Text('Mot de passe'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _setAdmin(user),
                  icon: Icon(admin ? Icons.remove_moderator_outlined
                    : Icons.admin_panel_settings_outlined, size: 17),
                  label: Text(admin ? 'Retirer ADMIN' : 'Donner ADMIN'),
                ),
              ]),
              const Divider(height: 24),
              Align(alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _deleteUser(user),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB42332)),
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text('Supprimer définitivement'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        decoration: InputDecoration(
          hintText: 'Rechercher par nom ou e-mail',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCE6E0)),
          ),
        ),
        onChanged: (value) => setState(() => _search = value.toLowerCase()),
      ),
      const SizedBox(height: 13),
      if (!_isOwner)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Les modifications de sécurité des comptes sont '
            'réservées au propriétaire principal.',
            style: TextStyle(fontSize: 12, color: VColors.muted)),
        ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _users,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return Column(children: [
              const Text('Impossible de charger les utilisateurs.'),
              TextButton.icon(
                onPressed: _refresh, icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ]);
          }
          final all = snapshot.data ?? [];
          final users = all.where((entry) {
            final haystack =
              '${entry['display_name'] ?? ''} ${entry['email'] ?? ''}'.toLowerCase();
            return haystack.contains(_search.trim());
          }).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(
                  '${users.length} compte(s) · Touchez un compte pour les actions',
                  style: const TextStyle(color: VColors.muted, fontSize: 12),
                )),
                IconButton(
                  tooltip: 'Actualiser les comptes',
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ]),
              const SizedBox(height: 6),
              if (users.isEmpty)
                const Padding(padding: EdgeInsets.all(28),
                  child: Center(child: Text('Aucun compte trouvé.')))
              else ...users.map(_account),
            ],
          );
        },
      ),
    ],
  );
}
