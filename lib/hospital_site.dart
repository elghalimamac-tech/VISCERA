/// Etablissements VISCERA. Le schema actuel et les donnees existantes
/// appartiennent exclusivement a HUIM6. HUICK reste en preparation jusqu'a
/// l'installation d'un cloisonnement RLS verifie cote serveur.
enum HospitalSite { huim6, huick }

extension HospitalSiteLabel on HospitalSite {
  String get name => switch (this) {
    HospitalSite.huim6 => 'HUIM6 Bouskoura',
    HospitalSite.huick => 'HUICK Casablanca',
  };

  String get shortName => switch (this) {
    HospitalSite.huim6 => 'HUIM6',
    HospitalSite.huick => 'HUICK',
  };

  String get description => switch (this) {
    HospitalSite.huim6 => 'Hôpital Universitaire International Mohammed VI · Bouskoura',
    HospitalSite.huick => 'Hôpital Universitaire International Cheikh Khalifa · Casablanca',
  };

  bool get isAvailableForDoctors => this == HospitalSite.huim6;
}
