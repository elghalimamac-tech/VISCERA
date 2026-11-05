/// Présentation du compte médical actuellement authentifié dans VISCERA.
/// N'ajoute jamais un deuxième titre si Supabase a déjà fourni Dr ou Pr.
String visceraSessionGreeting(String? displayName) {
  final name = (displayName ?? '').trim().replaceAll(RegExp(r'\\s+'), ' ');
  if (name.isEmpty) return 'Bonjour';
  if (RegExp(r'^(Dr|Pr)(?:\\s|$)', caseSensitive: false).hasMatch(name)) {
    return 'Bonjour $name';
  }
  return 'Bonjour Dr $name';
}

/// Empêche d'afficher le profil d'une autre identité pendant un changement de
/// session ou une déconnexion en cours.
bool visceraSessionMatchesProfile({
  required String? authenticatedUserId,
  required String? profileUserId,
}) =>
    authenticatedUserId != null &&
    authenticatedUserId.isNotEmpty &&
    profileUserId == authenticatedUserId;
