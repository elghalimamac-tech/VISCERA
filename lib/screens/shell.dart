import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../push_device_registration.dart';
import '../models.dart';
import '../patient_service_groups.dart';
import '../bloc_patient_sync.dart';
import '../manual_admission_service.dart';
import '../store.dart';
import '../theme.dart';
import '../build_info.dart';
import '../branding.dart';
import '../widgets.dart';
import '../patient_card.dart';
import 'intake.dart';
import 'patient_detail.dart';
import 'patient_archives.dart';
import 'planning.dart';
import 'personal_planning.dart';
import 'admin_page.dart';
import 'notification_settings.dart';
import 'notification_inbox.dart';
import '../duty_reminders.dart';
import '../notification_center_service.dart';
import '../notification_bell.dart';
import 'bloc_program_section.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.onChangeHospital});
  final VoidCallback? onChangeHospital;
  @override State<MainShell> createState() => _MainShellState();
}
class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int selected=0;String query='';String filter='Actifs';String unit='Tous';String patientServiceFilter='Tous';
  Timer? _programTimer;
  Timer? _notificationTimer;
  Timer? _serviceArchiveExpiryTimer;
  int _unreadCount = 0;
  String? _lastNotificationUser;
  final NotificationCenterService _notificationCenter = NotificationCenterService();
  bool _syncInProgress = false;
  bool _dischargeDigestShown = false;
  String? _syncProblem;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appStore.addListener(_scheduleServiceArchiveExpiry);
    _scheduleServiceArchiveExpiry();
    unawaited(_refreshUnreadCount());
    _notificationTimer = Timer.periodic(const Duration(seconds: 40),
      (_) => unawaited(_refreshUnreadCount()));
    unawaited(_refreshProgrammedPatients());
    _programTimer = Timer.periodic(const Duration(minutes: 15),
      (_) => unawaited(_refreshProgrammedPatients()));
  }

  /// Programme le prochain retrait VISUEL des patients sortis à H+48.
  /// Aucun dossier clinique n'est supprimé ou modifié dans Supabase.
  void _scheduleServiceArchiveExpiry() {
    _serviceArchiveExpiryTimer?.cancel();
    final now = DateTime.now();
    DateTime? next;
    for (final patient in appStore.patients) {
      if (!patient.isArchived || patient.dischargeAt == null) continue;
      final expiry = patient.dischargeAt!.add(const Duration(days: 2));
      if (expiry.isAfter(now) && (next == null || expiry.isBefore(next))) {
        next = expiry;
      }
    }
    if (next == null) return;
    _serviceArchiveExpiryTimer = Timer(
      next.difference(now) + const Duration(milliseconds: 50), () {
        if (!mounted) return;
        setState(() {});
        _scheduleServiceArchiveExpiry();
      },
    );
  }

  Future<void> _refreshUnreadCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted && _unreadCount != 0) setState(() => _unreadCount = 0);
      return;
    }
    try {
      final count = await _notificationCenter.unreadCount();
      if (!mounted || Supabase.instance.client.auth.currentUser?.id != userId) {
        return;
      }
      if (_unreadCount != count || _lastNotificationUser != userId) {
        setState(() {
          _lastNotificationUser = userId;
          _unreadCount = count;
        });
      }
    } catch (_) {
      // Un défaut réseau n'empêche jamais le travail sur les dossiers.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleServiceArchiveExpiry();
      if (mounted) setState(() {});
      unawaited(_refreshUnreadCount());
    }
  }

  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appStore.removeListener(_scheduleServiceArchiveExpiry);
    _serviceArchiveExpiryTimer?.cancel();
    _notificationTimer?.cancel();
    _programTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshProgrammedPatients() async {
    if (_syncInProgress) return;
    _syncInProgress = true;
    try {
      final records = await Future.wait<List<PatientCase>>([
        ManualAdmissionService().fetch(),
        BlocPatientSync.fetch(),
      ]);
      if (!mounted) return;
      appStore.replaceManualPatients(records[0]);
      appStore.replaceBlocProgramPatients(records[1]);
      setState(() => _syncProblem = null);
      _maybeOpenDischargeDigest();
    } catch (_) {
      if (mounted) setState(() =>
        _syncProblem = 'Impossible de charger les dossiers partagés. Réessayez.');
    } finally {
      _syncInProgress = false;
    }
  }
  // Notification IN-APP au lancement. Seulement les patients réellement
  // admis et opérés, pas les lignes programmées seules.
  void _maybeOpenDischargeDigest() {
    if (_dischargeDigestShown || !mounted) return;
    final due = appStore.patients
        .where((p)=>p.dischargeReviewDueOn(DateTime.now())).toList();
    if (due.isEmpty) return;
    _dischargeDigestShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:const Row(children:[
          Icon(Icons.notifications_active_outlined,color:Color(0xFFA45633)),
          SizedBox(width:10),
          Expanded(child:Text('Sorties à réévaluer aujourd’hui')),
        ]),
        content:ConstrainedBox(
          constraints:const BoxConstraints(maxHeight:360,maxWidth:460),
          child:SingleChildScrollView(child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text('${due.length} dossier(s) hospitalisé(s) ont atteint leur date '
                  'indicative de révision de sortie.'),
              const SizedBox(height:8),
              const Text('Aucune sortie n’est automatique. Vérifier chaque dossier '
                  'et la situation clinique avant toute décision.'),
              const SizedBox(height:12),
              ...due.take(8).map((patient)=>ListTile(
                dense:true,
                leading:const Icon(Icons.folder_open_outlined),
                title:Text(patient.name,maxLines:1,overflow:TextOverflow.ellipsis),
                subtitle:Text(patient.standardizedSurgeryType,
                  maxLines:1,overflow:TextOverflow.ellipsis),
                onTap:(){
                  Navigator.pop(ctx);
                  openCase(patient);
                },
              )),
              if(due.length>8)Text('Et ${due.length-8} autre(s) dossier(s).'),
            ],
          )),
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),
            child:const Text('Fermer')),
          FilledButton(onPressed:(){
            Navigator.pop(ctx);
            setState(()=>selected=1);
          },child:const Text('Voir les patients')),
        ],
      ));
    });
  }

  final GlobalKey<ScaffoldState> shellKey=GlobalKey<ScaffoldState>();
  void openCase(PatientCase p)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PatientDetailPage(patient:p)));
  void openIntake()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const IntakePage()));
  void openArchives()=>Navigator.push(context,
      MaterialPageRoute(builder:(_)=>const PatientArchivesPage()));
  void openPlanning()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PersonalPlanningPage()));
  void openReferencePlanning()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PlanningPage()));
  void openInbox() {
    Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>const NotificationInboxPage()))
      .then((_) { if(mounted) unawaited(_refreshUnreadCount()); });
  }
  void openNotificationSettings()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const NotificationSettingsPage()));
  void openAdmin(){if(appStore.activeLocalProfile?.isVisceraOwner != true)return;Navigator.push(context,MaterialPageRoute(builder:(_)=>const AdminPage()));}

  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:appStore,builder:(context,_)=>Scaffold(
    key:shellKey,
    drawer:_drawer(),
    body:SafeArea(child:IndexedStack(index:selected,children:[_dashboard(),_patientList(),_theatre(),_beds()])),
    bottomNavigationBar:_nav(),
  ));

  // La 3e destination est une action, pas un onglet : elle ouvre
  // le formulaire d'admission sans changer la page active.
  // Les 4 vrais onglets gardent leurs indices historiques (0 à 3).
  Widget _nav()=>NavigationBar(
    height:68,
    selectedIndex:selected>=2 ? selected+1 : selected,
    backgroundColor:Colors.white,
    indicatorColor:VColors.softMint,
    onDestinationSelected:(index){
      if(index==2){openIntake();return;}
      setState(()=>selected=index>2 ? index-1 : index);
    },
    destinations:const [
      NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home_rounded),label:'Accueil'),
      NavigationDestination(icon:Icon(Icons.people_alt_outlined),selectedIcon:Icon(Icons.people_alt_rounded),label:'Patients'),
      NavigationDestination(
        icon:SizedBox(
          width:44,height:44,
          child:DecoratedBox(
            decoration:BoxDecoration(color:VColors.ink,shape:BoxShape.circle),
            child:Icon(Icons.add_rounded,color:Colors.white,size:30),
          ),
        ),
        label:'Admission',
        tooltip:'Nouvelle admission',
      ),
      NavigationDestination(icon:Icon(Icons.medical_services_outlined),selectedIcon:Icon(Icons.medical_services_rounded),label:'Bloc'),
      NavigationDestination(icon:Icon(Icons.bed_outlined),selectedIcon:Icon(Icons.bed_rounded),label:'Lits'),
    ],
  );
  Widget _drawer()=>Drawer(backgroundColor:Colors.white,child:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(17,20,17,18),children:[
    Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:VColors.ink,borderRadius:BorderRadius.circular(20)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      VisceraMark(size:39,onDark:true),SizedBox(height:13),
      Text('VISCERA',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:23,letterSpacing:1)),
      Text('Chirurgie viscérale • HUIM6',style:TextStyle(color:Color(0xFFC9E7DC),fontSize:12)),
    ])),
    const SizedBox(height:23),const Overline('ACTIVITÉ CLINIQUE'),const SizedBox(height:12),
    _drawerItem(Icons.dashboard_outlined,'Tableau de bord',()=>_switchTab(0)),
    _drawerItem(Icons.person_add_alt_1_outlined,'Nouvelle admission',(){Navigator.pop(context);openIntake();}),
    _drawerItem(Icons.folder_copy_outlined,'Patients',()=>_switchTab(1)),
    _drawerItem(Icons.inventory_2_outlined,'Archives',(){
      Navigator.pop(context);
      openArchives();
    }),
    _drawerItem(Icons.medical_services_outlined,'Bloc opératoire',()=>_switchTab(2)),
    _drawerItem(Icons.bed_outlined,'Lits / Boxes',()=>_switchTab(3)),
    _drawerItem(Icons.logout_rounded,'Sorties à préparer',(){Navigator.pop(context);setState((){selected=1;filter='Actifs';});}),
    const SizedBox(height:24),const Overline('ÉQUIPE & PLANIFICATION'),const SizedBox(height:10),
    _drawerItem(Icons.schedule_rounded,'Planning · gardes et congés',(){Navigator.pop(context);openPlanning();}),
    _drawerItem(Icons.notifications_active_outlined,'Alarmes et notifications',(){Navigator.pop(context);openNotificationSettings();}),
    _drawerItem(Icons.notifications_none_rounded,'Centre de notifications',(){Navigator.pop(context);openInbox();}),
    _drawerItem(Icons.event_note_outlined,'Consultations',(){Navigator.pop(context);openReferencePlanning();}),
    _drawerItem(Icons.groups_outlined,'Professeurs et médecins',(){Navigator.pop(context);openReferencePlanning();}),
    if(appStore.activeLocalProfile?.isVisceraOwner == true)...[
      const SizedBox(height:24),const Overline('ESPACE ADMINISTRATEUR'),const SizedBox(height:10),
      _drawerItem(Icons.admin_panel_settings_outlined,'Administration VISCERA',(){Navigator.pop(context);openAdmin();}),
    ],
    if(widget.onChangeHospital!=null)
      _drawerItem(Icons.swap_horiz_rounded,'Changer d’établissement',() async {
        Navigator.pop(context);
        await unregisterCurrentPushDevice();
        if(mounted) widget.onChangeHospital?.call();
      }),
    _drawerItem(Icons.logout_outlined,'Se déconnecter',() async {Navigator.pop(context);await cancelAllDutyReminders();await unregisterCurrentPushDevice();await Supabase.instance.client.auth.signOut();}),
    const SizedBox(height:28),const Divider(color:VColors.line),

  ])));
  void _switchTab(int tab){Navigator.pop(context);setState(()=>selected=tab);}
  Widget _drawerItem(IconData icon,String label,VoidCallback action)=>ListTile(
    dense:true,contentPadding:const EdgeInsets.symmetric(horizontal:10),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
    leading:Icon(icon,color:VColors.ink,size:21),title:Text(label,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:13)),
    trailing:const Icon(Icons.chevron_right_rounded,size:18,color:VColors.muted),onTap:action);
  Widget _scroll(List<Widget> children)=>ListView(padding:const EdgeInsets.fromLTRB(20,23,20,32),children:children);
  Widget _top(String section,String title,{Widget? action})=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[IconButton(tooltip:'Ouvrir le menu',icon:const Icon(Icons.menu_rounded,color:VColors.ink),onPressed:()=>shellKey.currentState?.openDrawer()),
    const SizedBox(width:3),const Expanded(child:VisceraBrandLockup(markSize:31,subtitle:null)),if(action!=null)action]),
    const SizedBox(height:15),Text(title,style:Theme.of(context).textTheme.headlineLarge),const SizedBox(height:5),Text(section,style:const TextStyle(color:VColors.muted,fontSize:13)),
  ]);

  Widget _dashboard(){
    final active=appStore.homeActive;
    final services=patientsByService(active);
    final urgent=appStore.theatre.where((p)=>p.blockTiming=='Immédiat').length;
    final discharge=appStore.toDischarge.length;
    final now=DateTime.now();
    final date='${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';
    return _scroll([
      _top('Patients organisés par unité.','Accueil',
        action:Row(children:[
          VisceraNotificationBell(unreadCount:_unreadCount,onPressed:openInbox),
          IconButton(tooltip:'Équipe et planning',onPressed:openPlanning,
            icon:const Icon(Icons.calendar_month_outlined,color:VColors.ink)),
        ])),
      const SizedBox(height:17),
      VCard(color:VColors.ink,padding:const EdgeInsets.fromLTRB(18,19,18,18),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            const Icon(Icons.local_hospital_outlined,color:VColors.mint,size:22),
            const SizedBox(width:9),
            Expanded(child:Text('CHIRURGIE VISCÉRALE · $date',
              style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800,
                letterSpacing:1,color:VColors.mint))),
          ]),
          const SizedBox(height:13),
          Text('${active.length} patient(s) actif(s)',
            style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,
              color:Colors.white)),
          const SizedBox(height:4),
          Text('${services.length} service(s) dans le suivi actuel',
            style:const TextStyle(color:Colors.white70,fontSize:13)),
          const SizedBox(height:16),
          Row(children:[
            Expanded(child:_heroMetric('Bloc',appStore.theatre.length)),
            const SizedBox(width:8),
            Expanded(child:_heroMetric('Boxes',appStore.occupiedBoxes)),
            const SizedBox(width:8),
            Expanded(child:_heroMetric('Sorties à revoir',discharge)),
          ]),
        ])),
      const SizedBox(height:12),
      Row(children:[
        Expanded(child:_homeShortcut(
          Icons.calendar_month_rounded,'Mon planning',openPlanning,primary:true)),
        if(appStore.activeLocalProfile?.isVisceraOwner==true)...[
          const SizedBox(width:8),
          Expanded(child:_homeShortcut(
            Icons.admin_panel_settings_outlined,'Administration',openAdmin)),
        ],
      ]),
      const SizedBox(height:16),
      SectionHeading('Patients hospitalisés · par service',
        trailing:TextButton(onPressed:()=>setState((){
          selected=1;filter='Actifs';patientServiceFilter='Tous';
        }),child:const Text('Tout voir'))),
      ..._servicePatientSections(active,previewLimit:3),
      if(active.isEmpty)
        const VCard(child:Text('Aucun patient actif actuellement.')),
      if(urgent>0 || discharge>0)...[
        SectionHeading('À traiter'),
        if(urgent>0) VCard(color:VColors.orangeSoft,
          onTap:()=>setState(()=>selected=2),
          padding:const EdgeInsets.all(14),
          child:Row(children:[
            const Icon(Icons.priority_high_rounded,color:Color(0xFFA45633)),
            const SizedBox(width:10),
            Expanded(child:Text('$urgent intervention(s) immédiate(s) à organiser',
              style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13))),
            const Icon(Icons.chevron_right_rounded,color:VColors.ink),
          ])),
        if(discharge>0)...[
          const SizedBox(height:8),
          VCard(color:VColors.orangeSoft,
            onTap:()=>setState((){
              selected=1;filter='Actifs';patientServiceFilter='Tous';
            }),
            padding:const EdgeInsets.all(14),
            child:Row(children:[
              const Icon(Icons.assignment_turned_in_outlined,color:Color(0xFFA45633)),
              const SizedBox(width:10),
              Expanded(child:Text('$discharge dossier(s) à réévaluer pour sortie',
                style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13))),
              const Icon(Icons.chevron_right_rounded,color:VColors.ink),
            ])),
        ],
      ],
    ]);
  }

  Widget _heroMetric(String label,int count)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:11),
    decoration:BoxDecoration(color:Colors.white.withValues(alpha:.11),
      borderRadius:BorderRadius.circular(13)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('$count',style:const TextStyle(color:Colors.white,
        fontSize:19,fontWeight:FontWeight.w900)),
      const SizedBox(height:3),
      Text(label,maxLines:2,overflow:TextOverflow.ellipsis,
        style:const TextStyle(color:Colors.white70,fontSize:10.5)),
    ]),
  );

  Widget _serviceHeader(String service,int count,{VoidCallback? onTap})=>VCard(
    color:VColors.softMint,padding:const EdgeInsets.fromLTRB(13,11,13,11),
    margin:const EdgeInsets.only(top:5,bottom:10),
    onTap:onTap,
    child:Row(children:[
      const Icon(Icons.domain_outlined,color:VColors.ink,size:20),
      const SizedBox(width:10),
      Expanded(child:Text(service,
        style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900,color:VColors.ink))),
      Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
        decoration:BoxDecoration(color:Colors.white,
          borderRadius:BorderRadius.circular(9)),
        child:Text('$count',style:const TextStyle(
          fontSize:12,fontWeight:FontWeight.w900,color:VColors.ink))),
      if(onTap!=null)...[
        const SizedBox(width:6),
        const Icon(Icons.chevron_right_rounded,color:VColors.ink,size:20),
      ],
    ]),
  );

  List<Widget> _servicePatientSections(Iterable<PatientCase> patients,
      {int? previewLimit}) {
    final groups=patientsByService(patients);
    final result=<Widget>[];
    void openService(String service){
      setState((){
        selected=1;filter='Actifs';patientServiceFilter=service;
      });
    }
    for(final entry in groups.entries){
      final service=entry.key, people=entry.value;
      result.add(_serviceHeader(service,people.length,
        onTap:previewLimit==null?null:()=>openService(service)));
      for(final patient in previewLimit==null?people:people.take(previewLimit)){
        result.add(PatientCard(patient:patient,onTap:()=>openCase(patient)));
      }
      if(previewLimit!=null && people.length>previewLimit){
        result.add(Align(alignment:Alignment.centerRight,
          child:TextButton.icon(
            onPressed:()=>openService(service),
            icon:const Icon(Icons.arrow_forward_rounded,size:16),
            label:Text('Voir les ${people.length} patients · $service'))));
      }
    }
    return result;
  }

  Widget _homeShortcut(IconData icon,String title,VoidCallback onTap,
      {bool primary=false})=>SizedBox(height:50,child:FilledButton.icon(
    onPressed:onTap,
    icon:Icon(icon,size:21),
    label:Text(title,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800),
      maxLines:1,overflow:TextOverflow.ellipsis),
    style:FilledButton.styleFrom(
      backgroundColor:primary?VColors.ink:VColors.softMint,
      foregroundColor:primary?Colors.white:VColors.ink,
      padding:const EdgeInsets.symmetric(horizontal:10),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)),
    ),
  ));

  Widget _patientList(){
    final now=DateTime.now();
    final results=appStore.patients.where((p){
      if(!p.isVisibleInServiceOn(now))return false;
      final matches='${p.name} ${p.motive} ${p.id} ${p.currentUnit} ${p.currentBox}'
        .toLowerCase().contains(query.toLowerCase());
      final byType=filter=='Tous' ||
        (filter=='Programmés'&&p.isProgrammed) ||
        (filter=='Actifs'&&p.isActive) ||
        (filter=='Sortis récents'&&p.isArchived) ||
        (filter=='Non admis'&&p.isOmitted);
      return matches && byType &&
        (patientServiceFilter=='Tous'||patientService(p)==patientServiceFilter);
    }).toList()..sort((a,b){
      if(a.isActive!=b.isActive)return a.isActive?-1:1;
      final aDate=a.hospitalizationStartDate??a.blockAt;
      final bDate=b.hospitalizationStartDate??b.blockAt;
      return bDate.compareTo(aDate);
    });
    final allServices=['Tous',...hospitalUnits.map((e)=>e.code),unassignedPatientService];
    if(patientServiceFilter!='Tous'&&!allServices.contains(patientServiceFilter)){
      allServices.add(patientServiceFilter);
    }
    return _scroll([
      _top('Patients et dossiers actifs, par unité.','Patients'),
      const SizedBox(height:20),
      TextField(onChanged:(v)=>setState(()=>query=v),
        decoration:const InputDecoration(
          hintText:'Nom, motif, box ou service…',
          prefixIcon:Icon(Icons.search_rounded))),
      const SizedBox(height:12),
      SingleChildScrollView(scrollDirection:Axis.horizontal,
        child:Row(children:['Actifs','Tous','Programmés','Non admis'].map((v)=>
          Padding(padding:const EdgeInsets.only(right:7),
            child:ChoiceChip(label:Text(v),selected:filter==v,
              selectedColor:VColors.softMint,showCheckmark:false,
              onSelected:(_)=>setState(()=>filter=v)))).toList())),
      const SizedBox(height:10),
      const Text('SERVICE',style:TextStyle(color:VColors.muted,
        letterSpacing:1.5,fontSize:11,fontWeight:FontWeight.w800)),
      const SizedBox(height:6),
      SingleChildScrollView(scrollDirection:Axis.horizontal,
        child:Row(children:allServices.map((v)=>Padding(
          padding:const EdgeInsets.only(right:7),
          child:ChoiceChip(label:Text(v=='Tous'?'Tous les services':v),
            selected:patientServiceFilter==v,selectedColor:VColors.softMint,
            showCheckmark:false,
            onSelected:(_)=>setState(()=>patientServiceFilter=v)))).toList())),
      const SizedBox(height:10),
      Row(children:[
        Expanded(child:Text(_syncProblem ??
          '${results.length} dossier(s) · classés par service',
          style:const TextStyle(color:VColors.muted,fontSize:12))),
        IconButton(tooltip:'Actualiser les dossiers',
          onPressed:()=>unawaited(_refreshProgrammedPatients()),
          icon:const Icon(Icons.refresh_rounded)),
        TextButton(onPressed:openArchives,
          child:const Text('Archives')),
      ]),
      ..._servicePatientSections(results),
      if(results.isEmpty)
        const VCard(child:Text('Aucun patient dans ce service et ces filtres.')),
    ]);
  }

  Widget _theatre(){
    final cases=appStore.theatre;
    final review=cases.where((p)=>p.isPostopReviewDay(DateTime.now())).toList();
    final upcoming=cases.where((p)=>!p.isPostopReviewDay(DateTime.now())).toList();
    return _scroll([_top('Interventions urgentes et programmées.','Programme du bloc'),const SizedBox(height:22),
      const BlocProgramSection(),
      const SizedBox(height:12),
      SectionHeading('Suivi clinique du service'),
      Row(children:[Expanded(child:Text(_syncProblem ?? 'Admissions manuelles et programmes officiels',
        style:const TextStyle(fontSize:12,color:VColors.muted))),
        IconButton(tooltip:'Actualiser les admissions et programmes',onPressed:()=>unawaited(_refreshProgrammedPatients()),icon:const Icon(Icons.refresh))]),
      const SizedBox(height:10),
      VCard(color:VColors.softMint,child:Row(children:[const Icon(Icons.calendar_month_outlined,color:VColors.ink),const SizedBox(width:12),Expanded(child:Text('${cases.length} intervention(s) à organiser',style:const TextStyle(fontWeight:FontWeight.w800)))])),
      if(review.isNotEmpty)...[
        SectionHeading('Admission postopératoire à confirmer'),
        const VCard(color:VColors.orangeSoft,
          child:Text('Programme du jour : confirmer individuellement le retour postopératoire avant de valider le séjour.')),
        ...patientsByService(review).entries.expand((group)=><Widget>[
          _serviceHeader(group.key,group.value.length),
          ...group.value.map((p)=>VCard(
            margin:const EdgeInsets.only(bottom:10),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(p.name,style:Theme.of(context).textTheme.titleMedium),
              const SizedBox(height:5),Text(p.effectiveProcedure),
              const SizedBox(height:8),
              const Text('Postopératoire à confirmer'),
              OutlinedButton(onPressed:()=>openCase(p),
                child:const Text('Vérifier le dossier')),
            ]))),
        ]),
      ],
      SectionHeading('À opérer'),
      ...patientsByService(upcoming).entries.expand((group)=><Widget>[
        _serviceHeader(group.key,group.value.length),
        ...group.value.map((p)=>_theatreCard(p)),
      ]),
      if(cases.isEmpty)const VCard(child:Text('Aucune intervention en attente.')),

      SectionHeading('Postopératoire du jour / après bloc'),
       ..._servicePatientSections(appStore.active.where((p)=>p.isPostOp)),
    ]);
  }

  Widget _theatreCard(PatientCase p)=>VCard(
    margin:const EdgeInsets.only(bottom:10),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Expanded(child:Text(p.name,style:Theme.of(context).textTheme.titleMedium)),
        VTag(p.blockTiming=='Immédiat'?'URGENT':'PROGRAMMÉ',
          warn:p.blockTiming=='Immédiat'),
      ]),
      const SizedBox(height:9),
      Text(p.effectiveProcedure,style:const TextStyle(fontSize:13)),
      const SizedBox(height:7),
      HospitalizationDayCounter(patient:p),
      const SizedBox(height:6),
      Text('Responsable admission : ${appStore.responsibleById(p.professorId)?.name??'À attribuer'} · Responsable bloc : ${appStore.responsibleById(p.blockResponsibleId)?.name??(p.programSurgeon.isNotEmpty?p.programSurgeon:'À attribuer')}',
        style:const TextStyle(fontSize:12,color:VColors.muted)),
      const SizedBox(height:8),
      Text(_formatDate(p.blockAt),
        style:const TextStyle(color:VColors.muted,fontSize:12)),
      const SizedBox(height:13),
      Row(children:[
        OutlinedButton(onPressed:()=>openCase(p),child:const Text('Dossier')),
        const SizedBox(width:8),
        if(p.stage==CaseStage.preoperative)
          FilledButton.tonal(onPressed:()=>_startTheatre(p),
            child:const Text('Entrée au bloc'))
        else if(p.stage==CaseStage.inTheatre)
          FilledButton.tonal(onPressed:()=>_finishTheatre(p),
            child:const Text('Fin du bloc')),
      ]),
    ]));

  Widget _beds(){
    final patients=appStore.active.where((p)=>p.physicallyAdmitted && p.currentUnit.trim().isNotEmpty &&
      p.currentBox.trim().isNotEmpty && p.stage!=CaseStage.inTheatre && (unit=='Tous'||p.currentUnit==unit)).toList()
      ..sort((a,b)=>a.currentBox.compareTo(b.currentBox));
    final occupied=appStore.active.where((p)=>p.physicallyAdmitted && p.currentUnit.trim().isNotEmpty &&
      p.currentBox.trim().isNotEmpty && p.stage!=CaseStage.inTheatre).toList();
    return _scroll([_top('Localisation pré- et postopératoire.','Gestion des lits'),const SizedBox(height:22),
      VCard(color:VColors.softMint,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Icon(Icons.bed_outlined),const SizedBox(width:9),Text('${occupied.length} box attribué(s)',style:const TextStyle(fontWeight:FontWeight.w800))]),const SizedBox(height:8),const Text('Les capacités et boxes disponibles seront configurés par le service. Aucun taux d’occupation fictif.',style:TextStyle(fontSize:12,color:VColors.muted))])),
      const SizedBox(height:13),SizedBox(height:44,child:ListView(scrollDirection:Axis.horizontal,children:['Tous',...hospitalUnits.map((e)=>e.code)].map((v)=>Padding(padding:const EdgeInsets.only(right:7),child:ChoiceChip(label:Text(v),selected:unit==v,onSelected:(_)=>setState(()=>unit=v),selectedColor:VColors.softMint,showCheckmark:false))).toList())),
      SectionHeading('Occupation actuelle'),
      ...patientsByService(patients).entries.expand((group)=><Widget>[
        _serviceHeader(group.key,group.value.length),
        ...group.value.map((p)=>VCard(
          margin:const EdgeInsets.only(bottom:10),
          onTap:()=>openCase(p),
          child:Row(children:[
            Container(width:63,height:60,alignment:Alignment.center,
              decoration:BoxDecoration(color:VColors.softMint,
                borderRadius:BorderRadius.circular(15)),
              child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                const Text('BOX',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,
                  letterSpacing:1,color:VColors.muted)),
                Text(p.currentBox,style:const TextStyle(
                  fontWeight:FontWeight.w800,fontSize:20)),
              ])),
            const SizedBox(width:13),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(p.name,style:Theme.of(context).textTheme.titleMedium),
              const SizedBox(height:5),
              Text('${p.currentUnit} • ${p.stage.label}',
                style:const TextStyle(fontSize:12,color:VColors.muted)),
              const SizedBox(height:6),
              HospitalizationDayCounter(patient:p),
            ])),
            const Icon(Icons.chevron_right_rounded,color:VColors.muted),
          ]))),
      ]),
      if(patients.isEmpty)const VCard(child:Text('Aucun box occupé dans ce filtre.')),

    ]);
  }

  Future<void> _startTheatre(PatientCase p) async {
    // La vérification complète a lieu dans le dossier patient.
    if(!p.canConfirmTheatreEntry) {
      _error('Documents d’admission incomplets. Ouvrez le dossier du patient pour vérifier les pièces avant l’entrée au bloc.');
      return;
    }
    if(await showConfirmation(context,title:'Entrée au bloc',
      message:'Les documents ont été vérifiés. Confirmer l’entrée réelle au bloc de ${p.name} ?',
      action:'Confirmer') && p.canConfirmTheatreEntry) {
      appStore.startTheatre(p);
    }
  }
  Future<void> _finishTheatre(PatientCase p) async { final conflict=appStore.conflictingBox(p.afterUnit,p.afterBox,exceptPatientId:p.id);if(conflict!=null){_error('Le box ${p.afterBox} de ${p.afterUnit} est déjà attribué à ${conflict.name}.');return;}if(await showConfirmation(context,title:'Fin d’intervention',message:'Transférer ${p.name} vers ${p.afterUnit}, box ${p.afterBox} ?',action:'Valider'))appStore.finishTheatre(p);}
  void _error(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  void _about()=>showAboutDialog(context:context,applicationName:'VISCERA',applicationVersion:'0.14 · $visceraBuildShort',applicationIcon:const VisceraMark(size:50),children:[const Text('Accès réservé au staff médical approuvé. Programmes opératoires et admissions manuelles synchronisés dans Supabase.')]);
}

String _formatDate(DateTime date)=>'${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}  •  ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
