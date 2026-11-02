import 'package:flutter/material.dart';
import '../duty_reminders.dart';
import '../store.dart';
import '../branding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_inbox.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});
  @override State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  DutyAlarmPreferences preferences = const DutyAlarmPreferences();
  bool busy = true;
  String? status;
  Map<String,dynamic> deviceStatus = {};
  bool checkingDevice = false;
  Map<String,bool> pushTypes = {'program_updates':true,'urgent_admissions':true,'access_updates':true,'discharge_review':true};
  bool pushBusy = false;
  String? get userId => appStore.activeLocalProfile?.id;

  @override void initState() {
    super.initState();
    _load();
    _loadPush();
    _checkDevice();
  }

  Future<void> _load() async {
    final id = userId;
    if (id == null) return;
    final value = await loadDutyAlarmPreferences(id);
    if (mounted) setState(() { preferences = value; busy = false; });
  }


  Future<void> _checkDevice() async {
    if(!dutyAlarmSupported)return;
    setState(()=>checkingDevice=true);
    try {
      final value=await dutyAlarmDeviceStatus();
      if(mounted)setState(()=>deviceStatus=value);
    } catch (_) {
      if(mounted)setState(()=>status='Impossible de lire les autorisations Android.');
    } finally {
      if(mounted)setState(()=>checkingDevice=false);
    }
  }

  Future<void> _loadPush() async {
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id == null) return;
    try {
      final data = await Supabase.instance.client
        .from('viscera_notification_preferences')
        .select('program_updates,urgent_admissions,access_updates,discharge_review')
        .eq('user_id',id).maybeSingle();
      if (data != null && mounted) setState(() {
        for (final kind in pushTypes.keys) {
          pushTypes[kind] = data[kind] == true;
        }
      });
    } catch (_) {
      // Indisponibilité réseau : garder les réglages par défaut.
    }
  }

  Future<void> _setPushType(String kind,bool value) async {
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id == null || pushBusy) return;
    final before = pushTypes[kind] ?? true;
    setState(() { pushTypes[kind] = value; pushBusy = true; });
    try {
      await Supabase.instance.client
        .from('viscera_notification_preferences')
        .upsert({'user_id':id, ...pushTypes},onConflict:'user_id');
    } catch (_) {
      if (mounted) {
        setState(() => pushTypes[kind] = before);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enregistrement des préférences push impossible.')));
      }
    } finally {
      if (mounted) setState(() => pushBusy = false);
    }
  }

  Future<void> _save() async {
    final id = userId;
    if (id == null || busy) return;
    setState(() { busy = true; status = null; });
    try {
      await saveDutyAlarmPreferences(id, preferences);
      // Supprimer les anciens déclenchements avant de reconstruire les rappels.
      await cancelAllDutyReminders();
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
        SwitchListTile(
          secondary: const Icon(Icons.alarm_rounded),
          title: const Text('Alarme forte plein écran'),
          subtitle: const Text('Sonnerie répétée jusqu’à 3 minutes, '
            'écran dédié et boutons Arrêter / Reporter 10 min. '
            'Fonction disponible sur Android uniquement.'),
          value: preferences.loudFullScreen,
          onChanged: busy || !preferences.enabled || !dutyAlarmSupported
              ? null : (v) => setState(() =>
                  preferences = preferences.copyWith(loudFullScreen:v)),
        ),
        if(dutyAlarmSupported) ...[
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.volume_up_rounded),
            title: const Text('Volume des alarmes Android'),
            subtitle: Text(deviceStatus['maxVolume'] is num &&
                    (deviceStatus['maxVolume'] as num)>0
                ? 'Niveau actuel : '+(((deviceStatus['volume'] as num? ?? 0) /
                  (deviceStatus['maxVolume'] as num))*100).round().toString()+' %'
                : 'Consultez le volume Alarme du téléphone.'),
            trailing: TextButton(
              onPressed: () async {
                await openDutyAlarmVolumeSettings();
                if(mounted) _checkDevice();
              },
              child: const Text('Régler'),
            ),
          ),
          ListTile(
            leading: Icon(deviceStatus['fullScreen']==true
              ? Icons.check_circle_outline : Icons.phonelink_ring_outlined),
            title: const Text('Affichage sur écran verrouillé'),
            subtitle: Text(deviceStatus['fullScreen']==true
                ? 'Accès plein écran autorisé sur cet appareil'
                : 'Autorisation spéciale Android nécessaire'),
            trailing: TextButton(
              onPressed: () async {
                await openDutyFullScreenSettings();
                if(mounted) _checkDevice();
              },
              child: const Text('Autoriser'),
            ),
          ),
          ListTile(
            leading: Icon(deviceStatus['exact']==true
                ? Icons.check_circle_outline : Icons.schedule),
            title: const Text('Horaires des alarmes'),
            subtitle: Text(deviceStatus['exact']==true
              ? 'Alarmes exactes autorisées'
              : 'Précision limitée : Android peut retarder une alarme. '
                'Enregistrez les rappels pour demander l’autorisation.'),
          ),
          OutlinedButton.icon(
            onPressed: checkingDevice ? null : _checkDevice,
            icon: const Icon(Icons.rule_rounded),
            label: const Text('Vérifier les autorisations de mon téléphone'),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : _save,
          icon: const Icon(Icons.alarm_on_rounded),
          label: const Text('Enregistrer et reprogrammer'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : () async {
            try {
              final result = await testDutyAlarm();
              if (mounted) setState(() => status = result);
            } catch (_) {
              if (mounted) setState(() => status =
                'Test impossible sur ce téléphone. Vérifiez les autorisations Android.');
            }
          },
          icon: const Icon(Icons.notification_add_outlined),
          label: const Text('Tester la sonnerie forte et le plein écran'),
        ),
        if (status != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(status!, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const Divider(height: 38),
        const Text('NOTIFICATIONS IMPORTANTES',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        SwitchListTile(
          secondary: const Icon(Icons.event_note_outlined),
          title: const Text('Programme opératoire'),
          subtitle: const Text('Nouveau programme ou mise à jour publiée'),
          value: pushTypes['program_updates'] ?? true,
          onChanged: pushBusy ? null : (v) => _setPushType('program_updates',v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.emergency_outlined),
          title: const Text('Admissions urgentes'),
          subtitle: const Text('Réservées aux médecins seniors approuvés'),
          value: pushTypes['urgent_admissions'] ?? true,
          onChanged: pushBusy ? null : (v) => _setPushType('urgent_admissions',v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.verified_user_outlined),
          title: const Text('Accès et validation'),
          subtitle: const Text('Validation de compte et demandes administrateur'),
          value: pushTypes['access_updates'] ?? true,
          onChanged: pushBusy ? null : (v) => _setPushType('access_updates',v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.event_available_outlined),
          title: const Text('Révision des sorties'),
          subtitle: const Text('Rappel générique au seuil J1 ou à partir de J4, selon le type de chirurgie'),
          value: pushTypes['discharge_review'] ?? true,
          onChanged: pushBusy ? null : (v) => _setPushType('discharge_review',v),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context,MaterialPageRoute(
            builder: (_) => const NotificationInboxPage())),
          icon: const Icon(Icons.inbox_outlined),
          label: const Text('Ouvrir le centre de notifications'),
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
