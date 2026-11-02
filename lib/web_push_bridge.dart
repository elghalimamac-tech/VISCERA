// JS interoperability is imported only by Flutter Web.
import 'dart:js_interop';

@JS('visceraWebPushPermission')
external JSString _permission();

@JS('visceraWebPushCurrentToken')
external JSString? _currentToken();

@JS('visceraWebPushSubscribe')
external JSPromise<JSString?> _subscribe(JSString vapidKey);

@JS('visceraWebPushDeleteToken')
external JSPromise<JSBoolean> _deleteToken();

String permission() => _permission().toDart;

String? currentToken() => _currentToken()?.toDart;

Future<String?> subscribe(String vapidKey) async {
  final value = await _subscribe(vapidKey.toJS).toDart;
  return value?.toDart;
}

Future<void> deleteToken() async {
  await _deleteToken().toDart;
}
