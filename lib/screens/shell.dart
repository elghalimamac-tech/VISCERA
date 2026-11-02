import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../push_device_registration.dart';
import '../models.dart';
import '../bloc_patient_sync.dart';
import '../manual_admission_service.dart';
import '../store.dart';
import '../theme.dart';
import '../build_info.dart';
import '../branding.dart';
import '../widgets.dart';
import 'intake.dart';
import 'patient_detail.dart';
import 'planning.dart';
import 'personal_planning.dart';
import 'admin_page.dart';
import 'notification_settings.dart';
import 'notification_inbox.dart';
import '../duty_reminders.dart';
import '../notification_center_service.dart';
import '../notification_bell.dart';

class MainShell extends StatefulWidget { const MainShell({super.key}); @override State<MainShell> createState()=>_MainShellState(); }
class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int selected=0;String query='';String filter='Tous';String unit='Tous';
  Timer? _programTimer;
  Timer? _notificationTimer;
  int _unreadCount = 0;
  String? _lastNotificationUser;
  final NotificationCenterService _notificationCenter = NotificationCenterService();
  bool _syncInProgress = false;
  bool _dischargeDigestShown = false;
  String? _syncProblem;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshUnreadCount());
    _notificationTimer = Timer.periodic(const Duration(seconds: 40),
      (_) => unawaited(_refreshUnreadCount()));
    unawaited(_refreshProgrammedPatients());
    _programTimer = Timer.periodic(const Duration(minutes: 15),
      (_) => unawaited(_refreshProgrammedPatients()));
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
      unawaited(_refreshUnreadCount());
    }
  }

  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final active=appStore.active;final urgent=appStore.theatre.where((p)=>p.blockTiming=='Immédiat').length;
    return _scroll([
      _top('Votre service, en un regard.','Vue d’ensemble',action:Row(children:[VisceraNotificationBell(unreadCount:_unreadCount,onPressed:openInbox),IconButton(tooltip:'Équipe et planning',onPressed:openPlanning,icon:const Icon(Icons.calendar_month_outlined,color:VColors.ink)),CircleAvatar(backgroundColor:VColors.softMint,child:IconButton(tooltip:'À propos',onPressed:()=>_about(),icon:const Icon(Icons.shield_outlined,color:VColors.ink)))])),
      const SizedBox(height:12),
      Row(children:[
        Expanded(flex:3,child:_homeShortcut(
          Icons.calendar_month_rounded,'Mon planning',openPlanning,
          primary:true)),
        if(appStore.activeLocalProfile?.isVisceraOwner == true)...[
          const SizedBox(width:8),
          Expanded(flex:2,child:_homeShortcut(
            Icons.admin_panel_settings_outlined,'Admin',openAdmin)),
        ],
      ]),
      const SizedBox(height:16),
      Row(children:[
        Expanded(child:Text('Aujourd’hui',style:Theme.of(context).textTheme.titleLarge)),
        TextButton.icon(onPressed:openIntake,icon:const Icon(Icons.add_rounded),label:const Text('Nouvelle admission')),
      ]),const SizedBox(height:7),
      Row(children:[Expanded(child:_stat('Patients actifs','${active.length}',Icons.people_alt_outlined)),const SizedBox(width:9),Expanded(child:_stat('Bloc à venir','${appStore.theatre.length}',Icons.medical_services_outlined))]),
      const SizedBox(height:9),Row(children:[Expanded(child:_stat('Boxes occupés','${appStore.occupiedBoxes}',Icons.bed_outlined)),const SizedBox(width:9),Expanded(child:_stat('Sorties à revoir','${appStore.toDischarge.length}',Icons.assignment_turned_in_outlined,attention:appStore.toDischarge.isNotEmpty))]),
      SectionHeading('Accès rapides'),
      Row(children:[
        Expanded(child:_quick(Icons.medical_services_outlined,'Bloc',()=>setState(()=>selected=2))),const SizedBox(width:9),
        Expanded(child:_quick(Icons.bed_outlined,'Lits',()=>setState(()=>selected=3))),const SizedBox(width:9),
        Expanded(child:_quick(Icons.assignment_turned_in_outlined,'Sorties',()=>setState(()=>selected=1))),
      ]),
      if(urgent>0)...[SectionHeading('À prioriser'),VCard(color:VColors.orangeSoft,onTap:()=>setState(()=>selected=2),child:Row(children:[const Icon(Icons.priority_high_rounded,color:Color(0xFFA45633)),const SizedBox(width:12),Expanded(child:Text('$urgent patient(s) avec bloc immédiat à organiser',style:const TextStyle(fontWeight:FontWeight.w700))),const Icon(Icons.chevron_right_rounded)]))],
      if(appStore.toDischarge.isNotEmpty)...[SectionHeading('Sorties à réévaluer'),...appStore.toDischarge.take(2).map((p)=>PatientTile(patient:p,onTap:()=>openCase(p)))],
      SectionHeading('Admissions automatiques du programme',trailing:TextButton(onPressed:()=>setState((){selected=1;filter='Actifs';}),child:const Text('Tout voir'))),
      ...appStore.active.where((p)=>p.fromBlocProgram).take(4).map((p)=>PatientTile(patient:p,onTap:()=>openCase(p))),
      if(appStore.active.where((p)=>p.fromBlocProgram).isEmpty)const VCard(child:Text('Aucun programme opératoire actif chargé.')),
      SectionHeading('Dossiers en cours',trailing:TextButton(onPressed:()=>setState((){selected=1;filter='Actifs';}),child:const Text('Tout voir'))),...active.take(4).map((p)=>PatientTile(patient:p,onTap:()=>openCase(p))),
      if(active.isEmpty)const VCard(child:Text('Aucun patient actif. Créez votre première admission.')),

    ]);
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

  Widget _quick(IconData icon,String title,VoidCallback onTap)=>VCard(onTap:onTap,
      padding:const EdgeInsets.symmetric(horizontal:8,vertical:18),child:Column(children:[Icon(icon,color:VColors.ink,size:25),
      const SizedBox(height:8),Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12))]));
  Widget _stat(String label,String value,IconData icon,{bool attention=false})=>VCard(padding:const EdgeInsets.all(14),color:attention?VColors.orangeSoft:Colors.white,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,size:20,color:attention?const Color(0xFFA45633):VColors.muted),const SizedBox(height:14),Text(value,style:const TextStyle(fontSize:29,fontWeight:FontWeight.w800,letterSpacing:-1,color:VColors.ink)),const SizedBox(height:3),Text(label,style:const TextStyle(fontSize:11,color:VColors.muted))]));

  Widget _patientList(){
    final results=appStore.patients.where((p){
      final matches='${p.name} ${p.motive} ${p.id} ${p.beforeUnit} ${p.afterUnit}'.toLowerCase().contains(query.toLowerCase());
      return matches && (filter=='Tous'||(filter=='Programmés'&&p.isProgrammed)||(filter=='Actifs'&&p.isActive)||(filter=='Sortis'&&p.stage==CaseStage.discharged)||(filter=='Non admis'&&p.isOmitted));
    }).toList();
    return _scroll([_top('Dossiers et suivi individuel.','Patients'),const SizedBox(height:22),TextField(onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(hintText:'Rechercher nom, motif, box...',prefixIcon:Icon(Icons.search_rounded),hintStyle:TextStyle(color:VColors.muted))),const SizedBox(height:14),
      Wrap(spacing:8,children:['Tous','Programmés','Actifs','Non admis','Sortis'].map((v)=>ChoiceChip(label:Text(v),selected:filter==v,onSelected:(_)=>setState(()=>filter=v),selectedColor:VColors.softMint,showCheckmark:false)).toList()),
      Row(children:[Expanded(child:Text(_syncProblem ?? 'Dossiers partagés synchronisés depuis Supabase',
        style:const TextStyle(fontSize:11,color:VColors.muted))),
        IconButton(tooltip:'Actualiser les dossiers partagés',onPressed:()=>unawaited(_refreshProgrammedPatients()),icon:const Icon(Icons.refresh))]),
      SectionHeading('${results.length} patient(s)'),...results.map((p)=>PatientTile(patient:p,onTap:()=>openCase(p))),if(results.isEmpty)const VCard(child:Text('Aucun patient trouvé.')),
    ]);
  }

  Widget _theatre(){
    final cases=appStore.theatre;
    final review=cases.where((p)=>p.isPostopReviewDay(DateTime.now())).toList();
    final upcoming=cases.where((p)=>!p.isPostopReviewDay(DateTime.now())).toList();
    return _scroll([_top('Interventions urgentes et programmées.','Programme du bloc'),const SizedBox(height:22),
      Row(children:[Expanded(child:Text(_syncProblem ?? 'Admissions manuelles et programmes officiels',
        style:const TextStyle(fontSize:12,color:VColors.muted))),
        IconButton(tooltip:'Actualiser les admissions et programmes',onPressed:()=>unawaited(_refreshProgrammedPatients()),icon:const Icon(Icons.refresh))]),
      const SizedBox(height:10),
      VCard(color:VColors.softMint,child:Row(children:[const Icon(Icons.calendar_month_outlined,color:VColors.ink),const SizedBox(width:12),Expanded(child:Text('${cases.length} intervention(s) à organiser',style:const TextStyle(fontWeight:FontWeight.w800)))])),
      if(review.isNotEmpty)...[
        SectionHeading('Admission postopératoire à confirmer'),
        const VCard(color:VColors.orangeSoft,
          child:Text('Programme du jour : confirmer individuellement le retour postopératoire avant de valider le séjour.')),
        ...review.map((p)=>VCard(
          margin:const EdgeInsets.only(bottom:10),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(p.name,style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:5),Text(p.procedure),
            const SizedBox(height:8),
            const Text('Postopératoire à confirmer'),
            OutlinedButton(onPressed:()=>openCase(p),
              child:const Text('Vérifier le dossier')),
          ]),
        )),
      ],
      SectionHeading('À opérer'),...upcoming.map((p)=>VCard(margin:const EdgeInsets.only(bottom:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Expanded(child:Text(p.name,style:Theme.of(context).textTheme.titleMedium)),VTag(p.blockTiming=='Immédiat'?'URGENT':'PROGRAMMÉ',warn:p.blockTiming=='Immédiat')]),
        const SizedBox(height:9),Text(p.procedure,style:const TextStyle(fontSize:13)),const SizedBox(height:6),Text('Responsable admission : ${appStore.responsibleById(p.professorId)?.name??'À attribuer'} · Responsable bloc : ${appStore.responsibleById(p.blockResponsibleId)?.name??(p.programSurgeon.isNotEmpty?p.programSurgeon:'À attribuer')}',style:const TextStyle(fontSize:12,color:VColors.muted)),const SizedBox(height:8),Text(_formatDate(p.blockAt),style:const TextStyle(color:VColors.muted,fontSize:12)),
        const SizedBox(height:13),Row(children:[OutlinedButton(onPressed:()=>openCase(p),child:const Text('Dossier')),const SizedBox(width:8),if(p.stage==CaseStage.preoperative)FilledButton.tonal(onPressed:()=>_startTheatre(p),child:const Text('Entrée au bloc')) else if(p.stage==CaseStage.inTheatre)FilledButton.tonal(onPressed:()=>_finishTheatre(p),child:const Text('Fin du bloc'))])
      ]))),if(cases.isEmpty)const VCard(child:Text('Aucune intervention en attente.')),
      SectionHeading('Postopératoire du jour / après bloc'),
       ...appStore.active.where((p)=>p.isPostOp).map((p)=>PatientTile(patient:p,onTap:()=>openCase(p))),
    ]);
  }

  Widget _beds(){
    final patients=appStore.active.where((p)=>p.physicallyAdmitted && p.currentUnit.trim().isNotEmpty &&
      p.currentBox.trim().isNotEmpty && p.stage!=CaseStage.inTheatre && (unit=='Tous'||p.currentUnit==unit)).toList();
    final occupied=appStore.active.where((p)=>p.physicallyAdmitted && p.currentUnit.trim().isNotEmpty &&
      p.currentBox.trim().isNotEmpty && p.stage!=CaseStage.inTheatre).toList();
    return _scroll([_top('Localisation pré- et postopératoire.','Gestion des lits'),const SizedBox(height:22),
      VCard(color:VColors.softMint,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Icon(Icons.bed_outlined),const SizedBox(width:9),Text('${occupied.length} box attribué(s)',style:const TextStyle(fontWeight:FontWeight.w800))]),const SizedBox(height:8),const Text('Les capacités et boxes disponibles seront configurés par le service. Aucun taux d’occupation fictif.',style:TextStyle(fontSize:12,color:VColors.muted))])),
      const SizedBox(height:13),SizedBox(height:44,child:ListView(scrollDirection:Axis.horizontal,children:['Tous',...hospitalUnits.map((e)=>e.code)].map((v)=>Padding(padding:const EdgeInsets.only(right:7),child:ChoiceChip(label:Text(v),selected:unit==v,onSelected:(_)=>setState(()=>unit=v),selectedColor:VColors.softMint,showCheckmark:false))).toList())),
      SectionHeading('Occupation actuelle'),...patients.map((p)=>VCard(margin:const EdgeInsets.only(bottom:10),onTap:()=>openCase(p),child:Row(children:[Container(width:63,height:60,alignment:Alignment.center,decoration:BoxDecoration(color:VColors.softMint,borderRadius:BorderRadius.circular(15)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Text('BOX',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1,color:VColors.muted)),Text(p.currentBox,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:20))])),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.name,style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:5),Text('${p.currentUnit} • ${p.stage.label}',style:const TextStyle(fontSize:12,color:VColors.muted))])),const Icon(Icons.chevron_right_rounded,color:VColors.muted)]))),
      if(patients.isEmpty)const VCard(child:Text('Aucun box occupé dans ce filtre.')),
      SectionHeading('Unités configurées'),VCard(child:Wrap(spacing:7,runSpacing:7,children:hospitalUnits.map((u)=>VTag(u.code)).toList())),
    ]);
  }

  Future<void> _startTheatre(PatientCase p) async { if(await showConfirmation(context,title:'Entrée au bloc',message:'Confirmer l’entrée au bloc de ${p.name} ? La localisation sera actualisée.',action:'Confirmer'))appStore.startTheatre(p); }
  Future<void> _finishTheatre(PatientCase p) async { final conflict=appStore.conflictingBox(p.afterUnit,p.afterBox,exceptPatientId:p.id);if(conflict!=null){_error('Le box ${p.afterBox} de ${p.afterUnit} est déjà attribué à ${conflict.name}.');return;}if(await showConfirmation(context,title:'Fin d’intervention',message:'Transférer ${p.name} vers ${p.afterUnit}, box ${p.afterBox} ?',action:'Valider'))appStore.finishTheatre(p);}
  void _error(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  void _about()=>showAboutDialog(context:context,applicationName:'VISCERA',applicationVersion:'0.14 · $visceraBuildShort',applicationIcon:const VisceraMark(size:50),children:[const Text('Accès réservé au staff médical approuvé. Programmes opératoires et admissions manuelles synchronisés dans Supabase.')]);
}

String _formatDate(DateTime date)=>'${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}  •  ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
