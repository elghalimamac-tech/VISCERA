import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'store.dart';
import 'doctor_registration_options.dart';
import 'push_device_registration.dart';

/// La gestion des mots de passe et les liens de confirmation sont assurés
/// par Supabase Auth, pas par le téléphone ou SharedPreferences.
/// Toute autorisation médicale provient de doctor_profiles.approved_role,
/// jamais de raw_user_meta_data / requested_role.
enum AuthScreen { login, signup, confirmation, forgot, reset, loading, pending, approved }

class DoctorAuthController extends ChangeNotifier {
  DoctorAuthController(this.client) {
    _subscription = client.auth.onAuthStateChange.listen((change) {
      if (change.event == AuthChangeEvent.passwordRecovery) {
        ++_version;
        screen = AuthScreen.reset;
        busy = false;
        notifyListeners();
        return;
      }
      if (change.event == AuthChangeEvent.signedOut) {
        appStore.clearAuthenticatedProfile();
        screen = AuthScreen.login;
        busy = false;
        notifyListeners();
      } else if (change.event == AuthChangeEvent.signedIn ||
          change.event == AuthChangeEvent.userUpdated ||
          change.event == AuthChangeEvent.initialSession ||
          change.event == AuthChangeEvent.tokenRefreshed) {
        unawaited(refreshAccess());
      }
    }, onError: (Object error, StackTrace stackTrace) {
      message = 'Connexion interrompue. Réessayez lorsque le réseau est disponible.';
      busy = false;
      notifyListeners();
    });
    unawaited(refreshAccess());
  }

  factory DoctorAuthController.fromSingleton() => DoctorAuthController(Supabase.instance.client);

  final SupabaseClient client;
  late final StreamSubscription<AuthState> _subscription;
  AuthScreen screen = AuthScreen.loading;
  bool busy = false;
  String? message;
  String? pendingEmail;
  String? requestedRole;
  String? approvedRole;
  String? approvalStatus;
  int _version = 0;

  void go(AuthScreen destination) {
    message = null;
    screen = destination;
    notifyListeners();
  }

  String? _validatePassword(String input) {
    if (input.length < 12) return 'Utilisez au moins 12 caractères.';
    return null;
  }

  Future<void> refreshAccess() async {
    final version = ++_version;
    final user = client.auth.currentUser;
    if (user == null) {
      appStore.clearAuthenticatedProfile();
      if (screen != AuthScreen.confirmation && screen != AuthScreen.forgot) {
        screen = AuthScreen.login;
      }
      busy = false;
      notifyListeners();
      return;
    }
    if (screen == AuthScreen.reset) return;
    if (user.emailConfirmedAt == null) {
      pendingEmail = user.email;
      screen = AuthScreen.confirmation;
      appStore.clearAuthenticatedProfile();
      notifyListeners();
      return;
    }
    screen = AuthScreen.loading;
    notifyListeners();
    try {
      final profile = await client.from('doctor_profiles')
          .select('display_name, first_name, last_name, junior_category, internship_passage, senior_title, approved_role, requested_role, approval_status')
          .eq('user_id', user.id)
          .maybeSingle();
      if (version != _version) return;
      if (profile == null) {
        appStore.clearAuthenticatedProfile();
        screen = AuthScreen.pending;
        message = 'Profil absent. Contactez l’administrateur du service.';
      } else {
        requestedRole = profile['requested_role'] as String?;
        approvedRole = profile['approved_role'] as String?;
        approvalStatus = profile['approval_status'] as String?;
        if (approvalStatus == 'approved' &&
            ['junior', 'senior'].contains(approvedRole)) {
          appStore.activateAuthenticatedDoctor(
            id: user.id,
            name: profile['display_name'] as String? ?? 'Médecin',
            email: user.email ?? '',
            role: approvedRole!,
          );
          screen = AuthScreen.approved;
        } else {
          appStore.clearAuthenticatedProfile();
          screen = AuthScreen.pending;
        }
      }
    } catch (_) {
      if (version != _version) return;
      appStore.clearAuthenticatedProfile();
      screen = AuthScreen.pending;
      message = 'Impossible de vérifier les autorisations. Réessayez en ligne.';
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async => _execute(() async {
        await client.auth.signInWithPassword(email: email.trim().toLowerCase(), password: password);
        await refreshAccess();
      });

  /// Le grade et le titre sont uniquement déclaratifs jusqu'à l'approbation.
  Future<bool> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
    String? juniorCategory,
    int? internshipPassage,
    String? seniorTitle,
  }) async {
    final error = _validatePassword(password);
    if (error != null) { message = error; notifyListeners(); return false; }
    final first = firstName.trim().replaceAll(RegExp(r'\\s+'), ' ');
    final last = lastName.trim().replaceAll(RegExp(r'\\s+'), ' ');
    if (first.length < 2 || last.length < 2 || first.length > 70 || last.length > 70) {
      message = 'Renseignez séparément un prénom et un nom valides (2 à 70 caractères).';
      notifyListeners();
      return false;
    }
    final gradeError = validateMedicalGrade(
      role: role,
      juniorCategory: juniorCategory,
      internshipPassage: internshipPassage,
      seniorTitle: seniorTitle,
    );
    if (gradeError != null) { message = gradeError; notifyListeners(); return false; }
    final medicalTitle = role == 'junior' ? 'Dr' : seniorTitle!;
    final redirectUrl = kIsWeb
        ? '${Uri.base.origin}${Uri.base.path}'
        : 'viscera://auth-callback/';
    final metadata = <String, dynamic>{
      'first_name': first,
      'last_name': last,
      'display_name': '$medicalTitle $first $last',
      'requested_role': role,
      if (role == 'junior') 'junior_category': juniorCategory,
      if (role == 'junior' && internshipPassage != null) 'internship_passage': internshipPassage,
      if (role == 'senior') 'senior_title': seniorTitle,
    };
    return _execute(() async {
      await client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: redirectUrl,
        data: metadata,
      );
      pendingEmail = email.trim().toLowerCase();
      screen = AuthScreen.confirmation;
    });
  }

  Future<bool> resendConfirmation() async => _execute(() async {
    final email = pendingEmail ?? client.auth.currentUser?.email;
    if (email == null || email.isEmpty) throw StateError('Adresse email inconnue.');
    await client.auth.resend(type: OtpType.signup, email: email);
    message = 'Si cette adresse est éligible, un nouveau lien a été envoyé.';
  });

  Future<bool> forgotPassword(String email) async => _execute(() async {
    pendingEmail = email.trim().toLowerCase();
    await client.auth.resetPasswordForEmail(
      pendingEmail!, redirectTo: kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : 'viscera://auth-callback/',
    );
    message = 'Si un compte correspond à cette adresse, un email de réinitialisation a été envoyé.';
  });

  Future<bool> setNewPassword(String password) async {
    final error = _validatePassword(password);
    if (error != null) { message = error; notifyListeners(); return false; }
    return _execute(() async {
      await client.auth.updateUser(UserAttributes(password: password));
      await client.auth.signOut();
      screen = AuthScreen.login;
      message = 'Mot de passe modifié. Connectez-vous avec votre nouveau mot de passe.';
    });
  }

  Future<bool> signOut() async => _execute(() async {
    ++_version;
    await unregisterCurrentPushDevice();
    await client.auth.signOut();
    appStore.clearAuthenticatedProfile();
    screen = AuthScreen.login;
  });

  Future<bool> _execute(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    message = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AuthException catch (e) {
      message = switch (e.statusCode) {
        '429' => 'Trop de tentatives. Réessayez plus tard.',
        _ => e.message,
      };
      return false;
    } catch (_) {
      message = 'Action impossible. Vérifiez votre connexion et réessayez.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
