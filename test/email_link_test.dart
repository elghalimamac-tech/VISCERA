import 'package:flutter_test/flutter_test.dart';
import 'package:viscera/email_link.dart';

void main() {
  test('le lien de confirmation VISCERA est reconnu', () {
    final link = parseVisceraEmailLink(
      Uri.parse('https://elghalimamac-tech.github.io/VISCERA/#token_hash=0123456789abcdef&type=signup'),
    );
    expect(link?.type, VisceraEmailLinkType.signup);
    expect(link?.tokenHash, '0123456789abcdef');
  });

  test('le lien de récupération VISCERA est reconnu', () {
    final link = parseVisceraEmailLink(
      Uri.parse('https://elghalimamac-tech.github.io/VISCERA/#token_hash=0123456789abcdef&type=recovery'),
    );
    expect(link?.type, VisceraEmailLinkType.recovery);
  });

  test('une URL sans jeton ou avec type inconnu est rejetée', () {
    expect(parseVisceraEmailLink(Uri.parse('https://example.com/VISCERA/')), isNull);
    expect(parseVisceraEmailLink(
      Uri.parse('https://example.com/VISCERA/#token_hash=0123456789abcdef&type=admin'),
    ), isNull);
    expect(parseVisceraEmailLink(
      Uri.parse('https://example.com/VISCERA/#token_hash=abc&type=recovery'),
    ), isNull);
  });
}
