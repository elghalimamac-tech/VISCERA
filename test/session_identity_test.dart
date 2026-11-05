import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/session_identity.dart';

void main() {
  test('Le nom affiche Bonjour Dr ou Pr sans doubler le titre', () {
    expect(visceraSessionGreeting('Dr ARAQI HOUSSAINI'), 'Bonjour Dr ARAQI HOUSSAINI');
    expect(visceraSessionGreeting('Pr BENSAAD'), 'Bonjour Pr BENSAAD');
    expect(visceraSessionGreeting('  Pr   GHADDOU  '), 'Bonjour Pr GHADDOU');
    expect(visceraSessionGreeting('MÉDECIN TEST'), 'Bonjour Dr MÉDECIN TEST');
    expect(visceraSessionGreeting(''), 'Bonjour');
  });

  test('Le menu ne réutilise pas un profil d une autre session', () {
    expect(visceraSessionMatchesProfile(
      authenticatedUserId: 'user-1', profileUserId: 'user-1'), isTrue);
    expect(visceraSessionMatchesProfile(
      authenticatedUserId: 'user-2', profileUserId: 'user-1'), isFalse);
    expect(visceraSessionMatchesProfile(
      authenticatedUserId: null, profileUserId: 'user-1'), isFalse);
    expect(visceraSessionMatchesProfile(
      authenticatedUserId: 'user-1', profileUserId: null), isFalse);
  });
}
