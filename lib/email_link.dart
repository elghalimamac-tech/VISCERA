/// Identifie les liens de vérification VISCERA dans l'URL du navigateur.
/// Le jeton n'est jamais journalisé ni transmis à un autre site.
enum VisceraEmailLinkType { signup, recovery }

class VisceraEmailLink {
  const VisceraEmailLink({required this.type, required this.tokenHash});
  final VisceraEmailLinkType type;
  final String tokenHash;
}

/// Le fragment # n'est pas envoyé au serveur GitHub Pages.
VisceraEmailLink? parseVisceraEmailLink(Uri uri) {
  final fragment = uri.fragment;
  if (fragment.isEmpty || !fragment.contains('token_hash=')) return null;

  final values = Uri.splitQueryString(
    fragment.startsWith('?') ? fragment.substring(1) : fragment,
  );
  final hash = values['token_hash'];
  final type = values['type'];

  if (hash == null || hash.length < 16 || hash.length > 4096) return null;
  if (type == 'signup') {
    return VisceraEmailLink(type: VisceraEmailLinkType.signup, tokenHash: hash);
  }
  if (type == 'recovery') {
    return VisceraEmailLink(type: VisceraEmailLinkType.recovery, tokenHash: hash);
  }
  return null;
}
