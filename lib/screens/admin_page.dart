import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../branding.dart';
import '../doctor_registration_options.dart';
import '../store.dart';
import '../theme.dart';
import 'admin_users_panel.dart';

/// Administration VISCERA : validations et gestion des comptes séparées.
/// Chaque opération est autorisée sur le serveur, pas par l'interface seule.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<List<Map<String, dynamic>>> _list;
  String _section = 'validations';
  String _filter = 'pending';
  String _search = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _list = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final data =
        await Supabase.instance.client.rpc('viscera_admin_all_users');
    if (data is! List) throw StateError('Réponse inattendue du serveur');
    return data.map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  void _refresh() {
    if (mounted) setState(() => _list = _load());
  }

  Future<void> _pullRefresh() async {
    final data = await _load();
    if (mounted) setState(() => _list = Future.value(data));
  }

  String _grade(Map<String, dynamic> doctor) {
    if (doctor['requested_role'] == 'senior') {
      return 'Senior · ${doctor['senior_title'] ?? 'Dr'}';
    }
    final category = doctor['junior_category'] as String?;
    if (category == null) return 'Junior · Grade non renseigné';
    return gradeLabel(
      category, (doctor['internship_passage'] as num?)?.toInt());
  }

  String _status(String? value) => switch (value) {
    'approved' => 'Actif',
    'disabled' => 'Désactivé',
    _ => 'En attente',
  };

  Future<String> _notifyApproval(String targetId) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'viscera-send-approval-email', body: {'target_id': targetId});
      final data = response.data;
      if (data is Map && data['sent'] == true) {
        return 'E-mail de validation envoyé.';
      }
      if (data is Map && data['already_sent'] == true) {
        return 'E-mail de validation déjà envoyé.';
      }
      return 'Compte approuvé. E-mail de validation toujours en attente.';
    } catch (_) {
      return 'Compte approuvé, mais mail non envoyé. '
        'Vérifiez Brevo et réessayez depuis ce dossier.';
    }
  }

  Future<void> _retryApprovalEmail(Map<String, dynamic> doctor) async {
    if (_saving || doctor['approval_status'] != 'approved') return;
    setState(() => _saving = true);
    try {
      final message = await _notifyApproval(doctor['user_id'] as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _change(Map<String, dynamic> doctor, String action) async {
    if (_saving || doctor['is_admin'] == true) return;
    final name = doctor['display_name'] as String? ?? 'ce médecin';
    final label = switch (action) {
      'approve' => 'Approuver',
      'disable' => 'Désactiver',
      _ => 'Remettre en attente',
    };
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$label ce médecin ?'),
        content: Text(action == 'approve'
            ? 'Confirmez avoir vérifié l’identité médicale, '
              'l’adresse e-mail et le rattachement professionnel de '
              '$name par un canal indépendant.'
            : 'Confirmer : $label — $name ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(label)),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.rpc('viscera_admin_review_doctor',
        params: {'p_target': doctor['user_id'], 'p_action': action});
      final notice = action == 'approve'
          ? await _notifyApproval(doctor['user_id'] as String)
          : 'Action « $label » enregistrée.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(notice), duration: const Duration(seconds: 7)));
      _refresh();
    } on PostgrestException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Action refusée : droits insuffisants '
            'ou compte protégé.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Connexion impossible au serveur.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _metric(int value, String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE1E9E5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: VColors.ink, size: 18),
        const SizedBox(height: 9),
        Text('$value', style: const TextStyle(
          fontSize: 24, height: 1.1, fontWeight: FontWeight.w900,
          color: VColors.ink)),
        const SizedBox(height: 3),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: VColors.muted, fontSize: 11)),
      ],
    ),
  );

  Widget _navButton({
    required String value,
    required String title,
    required IconData icon,
  }) {
    final selected = _section == value;
    final text = Text(title,
      maxLines: 1, overflow: TextOverflow.ellipsis);
    return Expanded(
      child: selected
        ? FilledButton.icon(
            onPressed: () => setState(() => _section = value),
            icon: Icon(icon, size: 18),
            label: text,
            style: FilledButton.styleFrom(
              backgroundColor: VColors.ink,
              padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: 13)),
          )
        : OutlinedButton.icon(
            onPressed: () => setState(() => _section = value),
            icon: Icon(icon, size: 18),
            label: text,
            style: OutlinedButton.styleFrom(
              foregroundColor: VColors.ink,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: 13)),
          ),
    );
  }

  Widget _doctor(Map<String, dynamic> doctor) {
    final state = doctor['approval_status'] as String? ?? 'pending';
    final admin = doctor['is_admin'] == true;
    final color = state == 'approved'
        ? const Color(0xFF157453) : const Color(0xFFA36724);
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE1E9E5)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                backgroundColor: VColors.softMint,
                child: Icon(admin
                    ? Icons.admin_panel_settings_outlined
                    : Icons.person_outline, color: VColors.ink)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctor['display_name'] as String? ?? 'Médecin',
                    style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w800, color: VColors.ink)),
                  const SizedBox(height: 4),
                  Text(doctor['email'] as String? ?? 'E-mail indisponible',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12,
                      color: VColors.muted)),
                  const SizedBox(height: 4),
                  Text(_grade(doctor), style: const TextStyle(
                    fontSize: 12, color: VColors.muted)),
                ],
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Icon(state == 'approved'
                  ? Icons.check_circle_outline
                  : Icons.info_outline, color: color, size: 16),
              const SizedBox(width: 7),
              Expanded(child: Text(admin
                  ? (doctor['is_owner'] == true
                      ? 'Administrateur principal' : 'Administrateur')
                  : _status(state),
                style: TextStyle(fontSize: 12,
                  color: color, fontWeight: FontWeight.w700))),
            ]),
            if (!admin) ...[
              const SizedBox(height: 13),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (state != 'approved')
                  FilledButton.icon(
                    onPressed: _saving ? null
                        : () => _change(doctor, 'approve'),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(state == 'disabled'
                        ? 'Réactiver' : 'Approuver'),
                  ),
                if (state != 'disabled')
                  OutlinedButton.icon(
                    onPressed: _saving ? null
                        : () => _change(doctor, 'disable'),
                    icon: const Icon(Icons.block, size: 17),
                    label: const Text('Désactiver'),
                  ),
                if (state == 'disabled')
                  TextButton(
                    onPressed: _saving ? null
                        : () => _change(doctor, 'pending'),
                    child: const Text('Remettre en attente')),
                if (state == 'approved')
                  TextButton.icon(
                    onPressed: _saving ? null
                        : () => _retryApprovalEmail(doctor),
                    icon: const Icon(Icons.mail_outline, size: 17),
                    label: const Text('Réessayer le mail')),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reviewSection(List<Map<String, dynamic>> accounts) {
    final results = accounts.where((account) {
      if (account['approval_status'] == 'orphan') return false;
      if (_filter != 'all' && account['approval_status'] != _filter) {
        return false;
      }
      final terms =
          '${account['display_name'] ?? ''} ${account['email'] ?? ''}'
          .toLowerCase();
      return terms.contains(_search.trim().toLowerCase());
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Validation des inscriptions', style: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w800, color: VColors.ink)),
        const SizedBox(height: 5),
        const Text('Vérifiez l’identité et le rattachement professionnel '
          'avant d’autoriser l’accès médical.',
          style: TextStyle(fontSize: 12, color: VColors.muted)),
        const SizedBox(height: 15),
        TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher un médecin ou un e-mail',
            prefixIcon: const Icon(Icons.search),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE1E9E5)),
            ),
          ),
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: 13),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final option in const [
              ('pending', 'En attente'),
              ('approved', 'Actifs'),
              ('disabled', 'Désactivés'),
              ('all', 'Tous'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  selected: _filter == option.$1,
                  label: Text(option.$2),
                  selectedColor: VColors.softMint,
                  onSelected: (_) => setState(() => _filter = option.$1),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Text('${results.length} médecin(s)',
          style: const TextStyle(color: VColors.muted, fontSize: 12)),
        const SizedBox(height: 12),
        if (results.isEmpty)
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('Aucun médecin dans cette catégorie.',
              style: TextStyle(color: VColors.muted)),
          )
        else ...results.map(_doctor),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (appStore.activeLocalProfile?.isAdmin != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administration')),
        body: const Center(
          child: Text('Accès réservé aux administrateurs approuvés.')),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F6),
        title: const VisceraPageTitle('Administration VISCERA'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _saving ? null : _refresh,
            icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _list,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 38,
                  color: VColors.muted),
                const SizedBox(height: 12),
                const Text('Impossible de charger l’administration.',
                  textAlign: TextAlign.center),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _refresh, child: const Text('Réessayer')),
              ],
            ));
          }
          final accounts = snapshot.data ?? [];
          final pending = accounts.where((d) =>
              d['approval_status'] == 'pending').length;
          final active = accounts.where((d) =>
              d['approval_status'] == 'approved').length;
          final disabled = accounts.where((d) =>
              d['approval_status'] == 'disabled').length;

          return RefreshIndicator(
            onRefresh: _pullRefresh,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
                  children: [
                    const Text('Espace administrateur',
                      style: TextStyle(fontSize: 25,
                        fontWeight: FontWeight.w900, color: VColors.ink)),
                    const SizedBox(height: 4),
                    const Text('Chirurgie viscérale · Deux hôpitaux',
                      style: TextStyle(fontSize: 12, color: VColors.muted)),
                    const SizedBox(height: 17),
                    Row(children: [
                      Expanded(child: _metric(pending, 'En attente',
                        Icons.hourglass_empty)),
                      const SizedBox(width: 9),
                      Expanded(child: _metric(active, 'Actifs',
                        Icons.verified_outlined)),
                      const SizedBox(width: 9),
                      Expanded(child: _metric(disabled, 'Désactivés',
                        Icons.block_outlined)),
                    ]),
                    const SizedBox(height: 20),
                    Row(children: [
                      _navButton(
                        value: 'validations', title: 'Inscriptions',
                        icon: Icons.how_to_reg_outlined),
                      const SizedBox(width: 9),
                      _navButton(
                        value: 'users', title: 'Utilisateurs',
                        icon: Icons.manage_accounts_outlined),
                    ]),
                    const SizedBox(height: 22),
                    if (_section == 'validations')
                      _reviewSection(accounts)
                    else ...[
                      const Text('Gestion des utilisateurs',
                        style: TextStyle(fontSize: 19,
                          fontWeight: FontWeight.w800, color: VColors.ink)),
                      const SizedBox(height: 5),
                      const Text('Ouvrez la fiche d’un compte pour voir '
                        'ses informations et ses actions autorisées.',
                        style: TextStyle(fontSize: 12,
                          color: VColors.muted)),
                      const SizedBox(height: 16),
                      AdminUsersPanel(onChanged: _refresh),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
