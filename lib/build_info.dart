/// Identifiant du code compilé : identique pour Android et Web si les deux
/// fichiers proviennent du même commit sur la branche principale GitHub.
const visceraBuildSha = String.fromEnvironment(
  'VISCERA_BUILD_SHA', defaultValue: 'development');

String get visceraBuildShort =>
    visceraBuildSha.length > 8 ? visceraBuildSha.substring(0, 8) : visceraBuildSha;
