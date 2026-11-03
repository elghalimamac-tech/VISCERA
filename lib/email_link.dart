/// Portail HTTPS unique et accessible dans le navigateur des téléphones.
/// Les liens de validation ne dépendent plus de l'association du schéma viscera://.
const visceraConfirmationWebUrl =
    'https://elghalimamac-tech.github.io/VISCERA/';

/// Identifie les liens de validation directs, y compris ceux ouverts via
/// un routeur Web utilisant déjà #/auth/confirm?... (GitHub Pages).
/// Aucun jeton n'est envoyé au serveur de fichiers : il reste dans #.
enum VisceraEmailLinkType { signup, recovery }

class VisceraEmailLink {
  const VisceraEmailLink({required this.type, required this.tokenHash});
  final VisceraEmailLinkType type;
  final String tokenHash;
}

VisceraEmailLink? parseVisceraEmailLink(Uri uri) {
  final fragment = uri.fragment;
  if (fragment.isEmpty || !fragment.contains('token_hash=')) return null;
  final queryStart = fragment.indexOf('?');
  final query = queryStart >= 0
      ? fragment.substring(queryStart + 1)
      : fragment.startsWith('?') ? fragment.substring(1) : fragment;
  final values = Uri.splitQueryString(query);
  final hash = values['token_hash'];
  final type = values['type'];

  if (hash == null || hash.length < 16 || hash.length > 4096) return null;
  if (type == 'signup' || type == 'email') {
    return VisceraEmailLink(type: VisceraEmailLinkType.signup, tokenHash: hash);
  }
  if (type == 'recovery') {
    return VisceraEmailLink(type: VisceraEmailLinkType.recovery, tokenHash: hash);
  }
  return null;
}
