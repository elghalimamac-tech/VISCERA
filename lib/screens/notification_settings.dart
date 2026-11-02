import 'package:flutter/material.dart';
import '../duty_reminders.dart';
import '../store.dart';
import '../branding.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});
  @override State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  DutyAlarmPreferences preferences = const DutyAlarmPreferences();
  bool busy = true;
  String? status;
  String? get userId => appStore.activeLocalProfile?.id;

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = userId;
    if (id == null) return;
    final value = await loadDutyAlarmPreferences(id);
    if (mounted) setState(() { preferences = value; busy = false; });
  }

  Future<void> _save() async {
    final id = userId;
    if (id == null || busy) return;
    setState(() { busy = true; status = null; });
    try {
      await saveDutyAlarmPreferences(id, preferences);
      // Le planning est propre à l'utilisateur connecté.
      // On recalcule ce mois et les deux prochains pour les gardes déjà enregistrées.
      final now = DateTime.now();
      final messages = <String>[];
      for (var i = 0; i < 3; i++) {
        final month = DateTime(now.year, now.month + i);
        messages.add(await scheduleDutyReminders(month,
          plannedDutyDays(month, appStore.isMyDuty), settings: preferences));
      }
      if (mounted) setState(() => status = messages.first);
    } catch (_) {
      if (mounted) setState(() => status =
        'Impossible de programmer les alarmes. Vérifiez les autorisations Android.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _timeOption(String label, int value, void Function(int?) changed) =>
      ListTile(
        title: Text(label),
        trailing: DropdownButton<int>(
          value: value,
          items: List.generate(24, (i) => DropdownMenuItem(
            value: i,
            child: Text('${i.toString().padLeft(2, '0')}:00'),
          )),
          onChanged: changed,
        ),
      );

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const VisceraPageTitle('Alarmes et notifications')),
    body: SafeArea(child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('ALARMES PERSONNELLES DE GARDE',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        const Text('Rappels locaux des gardes de service de 24 h. '
            'Ils fonctionnent sans connexion, sous réserve des autorisations Android.'),
        if (busy) const LinearProgressIndicator(),
        SwitchListTile(
          title: const Text('Activer les alarmes de garde'),
          subtitle: const Text('Désactive tous les rappels programmés'),
          value: preferences.enabled,
          onChanged: busy ? null : (v) => setState(() =>
              preferences = preferences.copyWith(enabled: v)),
        ),
        SwitchListTile(
          title: const Text('Rappel la veille'),
          subtitle: const Text('Par défaut à 18 h'),
          value: preferences.previousDay,
          onChanged: busy || !preferences.enabled ? null : (v) =>
              setState(() => preferences = preferences.copyWith(previousDay: v)),
        ),
        if (preferences.enabled && preferences.previousDay)
          _timeOption('Heure la veille', preferences.previousHour,
            busy ? (_) {} : (v) => setState(() =>
              preferences = preferences.copyWith(previousHour: v))),
        SwitchListTile(
          title: const Text('Rappel le jour de garde'),
          subtitle: const Text('Par défaut à 7 h'),
          value: preferences.sameDay,
          onChanged: busy || !preferences.enabled ? null : (v) =>
              setState(() => preferences = preferences.copyWith(sameDay: v)),
        ),
        if (preferences.enabled && preferences.sameDay)
          _timeOption('Heure du jour J', preferences.sameDayHour,
            busy ? (_) {} : (v) => setState(() =>
              preferences = preferences.copyWith(sameDayHour: v))),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : _save,
          icon: const Icon(Icons.alarm_on_rounded),
          label: const Text('Enregistrer et reprogrammer'),
        ),
        if (status != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(status!, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const Divider(height: 38),
        const Text('NOTIFICATIONS IMPORTANTES',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const ListTile(
          leading: Icon(Icons.event_note_outlined),
          title: Text('Programme opératoire'),
          subtitle: Text('Nouvelle programmation ou changement de programme'),
        ),
        const ListTile(
          leading: Icon(Icons.emergency_outlined),
          title: Text('Urgences opératoires'),
          subtitle: Text('Notification générique réservée aux seniors autorisés'),
        ),
        const ListTile(
          leading: Icon(Icons.verified_user_outlined),
          title: Text('Accès au service'),
          subtitle: Text('Demandes d’accès administrateur, validation ou refus'),
        ),
        const Text('Les alertes push nécessitent Firebase, une connexion réseau '
          'et l’autorisation des notifications. Aucun nom ni information clinique '
          'de patient ne doit apparaître sur l’écran verrouillé.',
          style: TextStyle(fontSize: 12, color: Colors.black54)),
        if (!dutyAlarmSupported)
          const Padding(padding: EdgeInsets.only(top: 14),
            child: Text('Les alarmes locales sont disponibles sur Android.')),
      ],
    )),
  );
}
