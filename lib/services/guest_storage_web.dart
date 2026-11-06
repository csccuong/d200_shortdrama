import 'dart:js_interop';

@JS('window.localStorage.getItem')
external JSString? _localStorageGetItem(JSString key);

@JS('window.localStorage.setItem')
external void _localStorageSetItem(JSString key, JSString value);

const String _kGuestStorageKey = 'dxx_shortdrama_guest_identity_v1';

String? readPersistedGuestJson() {
  try {
    return _localStorageGetItem(_kGuestStorageKey.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

Future<void> writePersistedGuestJson(String jsonContent) async {
  try {
    _localStorageSetItem(_kGuestStorageKey.toJS, jsonContent.toJS);
  } catch (_) {}
}
