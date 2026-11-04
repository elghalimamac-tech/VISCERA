import 'package:flutter/material.dart';
import '../auth_controller.dart';
import '../doctor_registration_options.dart';
import '../push_device_registration.dart';
import '../theme.dart';
import '../build_info.dart';
import '../branding.dart';
import '../hospital_site.dart';
import '../store.dart';
import 'shell.dart';

/// Rappel de délivrabilité affiché pour les deux parcours d'e-mail Auth.
/// Indépendant de Supabase : testable avant l'envoi et sur écran étroit.
class AuthEmailSpamReminder extends StatelessWidget {
  const AuthEmailSpamReminder({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 8, bottom: 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.mark_email_unread_outlined, size: 18, color: Color(0xFF007A80)),
      SizedBox(width: 9),
      Expanded(child: Text(
        'Vérifier vos spams. Consultez également le dossier « Courrier indésirable » si vous ne recevez pas le message.',
        key: Key('auth-spam-reminder'),
        style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF274B59)),
      )),
    ]),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.hospital = HospitalSite.huim6,
    this.onChangeHospital});
  final HospitalSite hospital;
  final VoidCallback? onChangeHospital;
  @override State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final DoctorAuthController auth;
  final email = TextEditingController();
  final password = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final confirmation = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String role = 'junior';
  String? juniorCategory;
  int? internshipPassage;
  String seniorTitle = 'Dr';
  bool visible = false;

  @override
  void initState() {
    super.initState();
    // Constructeur : écoute le lien de confirmation / récupération Supabase.
    auth = DoctorAuthController.fromSingleton();
  }

  @override
  void dispose() {
    auth.dispose();
    email.dispose(); password.dispose(); firstName.dispose(); lastName.dispose(); confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: auth,
    builder: (context, _) {
      if (auth.screen == AuthScreen.approved) {
        if (widget.hospital == HospitalSite.huick) {
          return _huickMaintenance();
        }
        return const PushDeviceRegistration(child: MainShell());
      }
      return Scaffold(
        backgroundColor: const Color(0xFFF3F6F7),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 38),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _brand(),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.fromLTRB(22, 27, 22, 26),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDCE5E8)),
                        ),
                        child: _screen(),
                      ),
                      const SizedBox(height: 21),
                      Text('VISCERA · ' + widget.hospital.name +
                         ' · Accès réservé aux professionnels autorisés.\nVersion $visceraBuildShort',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, height: 1.5, color: VColors.muted)),
                      if(widget.onChangeHospital!=null)...[
                        const SizedBox(height:10),
                        TextButton.icon(
                          key:const Key('change-hospital-auth'),
                          onPressed:widget.onChangeHospital,
                          icon:const Icon(Icons.swap_horiz_rounded,size:18),
                          label:const Text('Changer d’établissement')),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );


  /// Dans cette phase, HUICK est volontairement isole de tous les services
  /// cliniques existants. Ne jamais monter MainShell / BlocPatientSync ici
  /// tant que les migrations hospital_id et les RLS ne sont pas verifiees.
  Widget _huickMaintenance() {
    final isAdmin = appStore.activeLocalProfile?.isVisceraOwner == true;
    return Scaffold(
      backgroundColor: VColors.background,
      appBar: AppBar(
        title:const Text('VISCERA · HUICK'),
        backgroundColor:VColors.background,
      ),
      body:SafeArea(child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:540),
        child:SingleChildScrollView(
          padding:const EdgeInsets.all(24),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            const Center(child:VisceraBrandLockup(markSize:53,subtitle:null)),
            const SizedBox(height:32),
            const Icon(Icons.construction_rounded,size:52,color:Color(0xFFA45633)),
            const SizedBox(height:14),
            Text('HUICK Casablanca · En travaux',
              textAlign:TextAlign.center,
              style:Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height:12),
            Text(isAdmin
              ? 'Accès administrateur autorisé pour préparer le futur espace HUICK. '
                'Les admissions, les données cliniques et le programme du bloc '
                'ne sont pas encore ouverts : aucune donnée HUIM6 n’est affichée.'
              : 'L’espace HUICK est actuellement en travaux et ne permet pas '
                'encore l’accès aux utilisateurs. Accès réservé à '
                'l’administrateur principal pendant sa préparation.',
              textAlign:TextAlign.center,
              style:const TextStyle(fontSize:14,color:VColors.muted,height:1.6)),
            const SizedBox(height:25),
            if(isAdmin)Container(
              padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(
                color:VColors.softMint,
                borderRadius:BorderRadius.circular(16)),
              child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('Préparation de HUICK',style:TextStyle(
                  fontWeight:FontWeight.w800,fontSize:15,color:VColors.ink)),
                SizedBox(height:8),
                Text('À configurer : unités et boxes, médecins, plannings, '
                  'programmes opératoires et autorisations serveur. '
                  'Aucun dossier HUIM6 ne peut être utilisé ici.',
                  style:TextStyle(fontSize:12,color:VColors.ink,height:1.5)),
              ]),
            ),
            const SizedBox(height:18),
            if(widget.onChangeHospital!=null)
              FilledButton.icon(
                key:const Key('change-hospital-from-huick'),
                onPressed:widget.onChangeHospital,
                icon:const Icon(Icons.swap_horiz_rounded),
                label:const Text('Changer d’établissement')),
            const SizedBox(height:12),
            OutlinedButton.icon(
              onPressed:()=>auth.signOut(),
              icon:const Icon(Icons.logout_outlined),
              label:const Text('Se déconnecter')),
          ]),
        ),
      ))),
    );
  }

  Widget _brand() => const VisceraBrandLockup(markSize: 49);

  Widget _screen() {
    switch (auth.screen) {
      case AuthScreen.loading:
        return const SizedBox(height: 175, child: Center(child: CircularProgressIndicator()));
      case AuthScreen.login:
        return _login();
      case AuthScreen.signup:
        return _signup();
      case AuthScreen.confirmation:
        return _confirmation();
      case AuthScreen.forgot:
        return _forgot();
      case AuthScreen.reset:
        return _reset();
      case AuthScreen.pending:
        return _pending();
      case AuthScreen.approved:
        return const SizedBox.shrink();
    }
  }

  Widget _title(String title, String description) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.8, color: Color(0xFF142B38))),
    const SizedBox(height: 7),
    Text(description, style: const TextStyle(color: VColors.muted, fontSize: 13, height: 1.5)),
    const SizedBox(height: 24),
  ]);

  Widget _input(TextEditingController controller, String label, {bool obscure = false, TextInputType? type}) {
    return Padding(padding: const EdgeInsets.only(bottom: 15),child: TextFormField(
      controller: controller, obscureText: obscure && !visible,
      keyboardType: type,
      autocorrect: false,
      enableSuggestions: !obscure,
      autofillHints: obscure ? const [AutofillHints.password] : type==TextInputType.emailAddress ? const [AutofillHints.email] : null,
      decoration: InputDecoration(labelText: label,
        suffixIcon: obscure ? IconButton(
          tooltip: visible ? 'Masquer le mot de passe' : 'Afficher le mot de passe',
          icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => visible = !visible)) : null),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
        if (type==TextInputType.emailAddress && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) return 'Email invalide';
        if (obscure && v.length < 12 && auth.screen != AuthScreen.login) return '12 caractères minimum';
        return null;
      },
    ));
  }

  Widget _notice() => auth.message == null ? const SizedBox.shrink() : Padding(
    padding: const EdgeInsets.only(bottom: 15), child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF1F6F7), borderRadius: BorderRadius.circular(8)),
    child: Text(auth.message!, style: const TextStyle(color: Color(0xFF274B59),fontSize: 12,height: 1.5)),
  ));

  /// Rappel visible pour les liens d'inscription et de récupération :
  /// les filtres e-mail peuvent classer les messages transactionnels en spam.
  Widget _action(String label, VoidCallback callback) => SizedBox(
    height: 52, child: FilledButton(onPressed: auth.busy ? null : callback,
      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF142B38)),
      child: auth.busy ? const SizedBox(width: 20,height: 20,child: CircularProgressIndicator(strokeWidth: 2,color: Colors.white)) : Text(label)));

  bool _valid() => formKey.currentState?.validate() ?? false;

  Widget _login() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _title('Connexion', widget.hospital == HospitalSite.huick
        ? 'Accès administrateur uniquement. L’espace clinique HUICK est en travaux.'
        : 'Retrouvez votre planning personnel et vos outils de service.'),
    _input(email, 'Adresse email', type: TextInputType.emailAddress),
    _input(password, 'Mot de passe', obscure: true),
    Align(alignment: Alignment.centerRight, child: TextButton(
      onPressed: () => auth.go(AuthScreen.forgot), child: const Text('Mot de passe oublié ?'))),
    _notice(),
    _action('Se connecter', () { if (_valid()) auth.signIn(email.text, password.text); }),
    const SizedBox(height: 18),
    if(widget.hospital == HospitalSite.huim6)
      Row(mainAxisAlignment: MainAxisAlignment.center,children: [
        const Text('Pas encore de compte ? '),
        TextButton(onPressed: ()=>auth.go(AuthScreen.signup),child: const Text('S’inscrire')),
      ]),
  ]);

  Widget _signup() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _title('Créer mon compte', 'Gestion des patients — Chirurgie viscérale, HUIM6 Bouskoura. Inscription réservée aux médecins du service.'),
    const Text('Statut médical', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    const SizedBox(height: 9),
    SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'junior', label: Text('Junior'), icon: Icon(Icons.person_outline)),
        ButtonSegment(value: 'senior', label: Text('Senior'), icon: Icon(Icons.medical_services_outlined)),
      ],
      selected: {role},
      onSelectionChanged: (selected) => setState(() {
        role = selected.first;
        juniorCategory = null;
        internshipPassage = null;
        seniorTitle = 'Dr';
      }),
    ),
    const SizedBox(height: 18),
    if (role == 'junior') ...[
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('Titre : Dr (automatique pour tous les juniors)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: VColors.ink)),
      ),
      DropdownButtonFormField<String>(
        value: juniorCategory,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Catégorie du junior'),
        hint: const Text('Choisir une catégorie'),
        items: juniorCategories.entries.map((entry) => DropdownMenuItem(
          value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis),
        )).toList(),
        validator: (value) => value == null ? 'Sélectionnez votre catégorie' : null,
        onChanged: (value) => setState(() {
          juniorCategory = value;
          internshipPassage = null;
        }),
      ),
      const SizedBox(height: 15),
      if (passagesForCategory(juniorCategory).isNotEmpty) ...[
        DropdownButtonFormField<int>(
          key: ValueKey(juniorCategory),
          value: internshipPassage,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Passage d’internat'),
          hint: const Text('Choisir le passage'),
          items: passagesForCategory(juniorCategory).map((passage) => DropdownMenuItem(
            value: passage,
            child: Text(gradeLabel(juniorCategory, passage).split('— ').last),
          )).toList(),
          validator: (value) => value == null ? 'Sélectionnez votre passage' : null,
          onChanged: (value) => setState(() => internshipPassage = value),
        ),
        const SizedBox(height: 15),
      ],
    ] else ...[
      DropdownButtonFormField<String>(
        value: seniorTitle,
        decoration: const InputDecoration(labelText: 'Titre avant le nom'),
        items: seniorTitles.map((title) => DropdownMenuItem(
          value: title,
          child: Text(title),
        )).toList(),
        onChanged: (value) => setState(() => seniorTitle = value ?? 'Dr'),
      ),
      const SizedBox(height: 15),
    ],
    _input(firstName, 'Prénom'),
    _input(lastName, 'Nom'),
    _input(email, 'Email professionnel', type: TextInputType.emailAddress),
    _input(password, 'Mot de passe (12 caractères minimum)', obscure: true),
    _input(confirmation, 'Confirmer le mot de passe', obscure: true),
    const SizedBox(height: 2),
    _notice(),
    _action('Créer mon compte', () {
      if (!_valid()) return;
      if (password.text != confirmation.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Les mots de passe sont différents.')),
        );
        return;
      }
      auth.signUp(
        firstName: firstName.text,
        lastName: lastName.text,
        email: email.text,
        password: password.text,
        role: role,
        juniorCategory: role == 'junior' ? juniorCategory : null,
        internshipPassage: role == 'junior' ? internshipPassage : null,
        seniorTitle: role == 'senior' ? seniorTitle : null,
      );
    }),
    TextButton(onPressed: () => auth.go(AuthScreen.login),
      child: const Text('J’ai déjà un compte')),
  ]);

  Widget _confirmation() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Icon(Icons.mark_email_unread_outlined,color: Color(0xFF007A80),size:47),
    const SizedBox(height: 15),
    _title('Vérifiez votre adresse e-mail', 'Vous allez recevoir un message VISCERA. Cliquez sur « Confirmer mon adresse e-mail » pour valider votre inscription.'),
    const AuthEmailSpamReminder(),
    if(auth.pendingEmail!=null)
      Text(auth.pendingEmail!,textAlign:TextAlign.center,
        style:const TextStyle(fontWeight:FontWeight.w700))
    else
      _input(email,'Adresse e-mail utilisée pour l’inscription',
        type:TextInputType.emailAddress),
    const SizedBox(height: 16),
    _notice(),
    _action('Renvoyer l’e-mail de validation',
      ()=>auth.resendConfirmation(emailOverride: email.text)),
    const SizedBox(height: 14),
    OutlinedButton(onPressed: ()=>auth.refreshAccess(),child: const Text('J’ai confirmé mon email')),
    TextButton(onPressed:()=>auth.go(AuthScreen.login),child: const Text('Retour à la connexion')),
  ]);

  Widget _forgot() => Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
    const Icon(Icons.lock_reset_outlined,size:43,color:Color(0xFF007A80)),
    const SizedBox(height:12),
    _title('Mot de passe oublié ?', 'Indiquez votre adresse e-mail. Vous recevrez un message VISCERA pour choisir un nouveau mot de passe.'),
    const AuthEmailSpamReminder(),
    _input(email,'Adresse email',type:TextInputType.emailAddress),
    _notice(),
    _action('Recevoir l’e-mail de réinitialisation',(){if(_valid())auth.forgotPassword(email.text);}),
    TextButton(onPressed:()=>auth.go(AuthScreen.login),child: const Text('Retour à la connexion')),
  ]);

  Widget _reset() => Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
    _title('Définir un nouveau mot de passe', 'Lien vérifié. Choisissez un mot de passe d’au moins 12 caractères, puis confirmez-le.'),
    _input(password,'Nouveau mot de passe',obscure:true),
    _input(confirmation,'Confirmer le mot de passe',obscure:true),
    _notice(),
    _action('Enregistrer et revenir à la connexion',(){
      if(!_valid())return;
      if(password.text!=confirmation.text){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Les mots de passe sont différents.')));return;}
      auth.setNewPassword(password.text);
    }),
  ]);

  Widget _pending() => Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
    const Icon(Icons.admin_panel_settings_outlined,size:46,color:Color(0xFF007A80)),
    const SizedBox(height:12),
    _title('Accès en attente', 'Votre email est confirmé. Le responsable du service doit valider votre compte.'),
    Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFFF0F6F8),borderRadius:BorderRadius.circular(9)),
      child:Text('Statut demandé : ${auth.requestedRole == 'senior' ? 'Senior' : 'Junior'}\nAucun dossier patient accessible avant validation.',style:const TextStyle(fontSize:13,height:1.7))),
    const SizedBox(height:16),_notice(),
    _action('Actualiser mon accès',()=>auth.refreshAccess()),
    const SizedBox(height:12),
    OutlinedButton(onPressed:()=>auth.signOut(),child:const Text('Se déconnecter')),
  ]);
}
