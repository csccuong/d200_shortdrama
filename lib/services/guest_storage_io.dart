import 'dart:io';

const String _kGuestFileName = 'dxx_guest_identity_v1.json';

File _resolvePersistentFile() {
  try {
    if (Platform.isAndroid) {
      // On Android, Directory.systemTemp is /data/user/0/<pkg>/cache (or code_cache).
      // Sibling /files is Context.getFilesDir() (persistent internal app storage).
      final filesDir = Directory('${Directory.systemTemp.parent.path}/files');
      if (filesDir.existsSync()) {
        return File('${filesDir.path}/$_kGuestFileName');
      }
    } else if (Platform.isIOS) {
      // On iOS, Directory.systemTemp is <Sandbox>/tmp.
      // Sibling /Documents is NSDocumentDirectory (persistent app storage).
      final docsDir =
          Directory('${Directory.systemTemp.parent.path}/Documents');
      if (docsDir.existsSync()) {
        return File('${docsDir.path}/$_kGuestFileName');
      }
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        final dir = Directory('$appData\\dxx_shortdrama');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return File('${dir.path}\\$_kGuestFileName');
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        final dir =
            Directory('$home/Library/Application Support/dxx_shortdrama');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return File('${dir.path}/$_kGuestFileName');
      }
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        final dir = Directory('$home/.local/share/dxx_shortdrama');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return File('${dir.path}/$_kGuestFileName');
      }
    }
  } catch (_) {}

  return File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}$_kGuestFileName',
  );
}

String? readPersistedGuestJson() {
  try {
    final file = _resolvePersistentFile();
    if (file.existsSync()) {
      return file.readAsStringSync();
    }
  } catch (_) {}
  return null;
}

Future<void> writePersistedGuestJson(String jsonContent) async {
  try {
    final file = _resolvePersistentFile();
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(jsonContent, flush: true);
  } catch (_) {}
}
