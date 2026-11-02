// Native placeholder: browser functions must never be called on Android or iOS.
String permission() => 'unsupported';
String? currentToken() => null;
Future<String?> subscribe(String vapidKey) async => null;
Future<void> deleteToken() async {}
