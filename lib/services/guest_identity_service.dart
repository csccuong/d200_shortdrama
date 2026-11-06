import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'guest_storage_stub.dart'
    if (dart.library.io) 'guest_storage_io.dart'
    if (dart.library.js_interop) 'guest_storage_web.dart';

class GuestIdentity {
  final String guestNumber;
  final String guestId;

  const GuestIdentity({
    required this.guestNumber,
    required this.guestId,
  });

  static final RegExp _numberRegex = RegExp(r'^\d{6}$');
  static final RegExp _idRegex = RegExp(r'^[0-9a-f]{8}$');

  static bool isValid(String? number, String? id) {
    if (number == null || id == null) return false;
    return _numberRegex.hasMatch(number) && _idRegex.hasMatch(id);
  }

  static Random _createRandom() {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  /// Generates a random 6-digit guest number (e.g. `482917`) and
  /// an 8-character lowercase hex guest ID (e.g. `a39c04e7`).
  factory GuestIdentity.generate() {
    final rng = _createRandom();
    final number = (100000 + rng.nextInt(900000)).toString();
    const hexChars = '0123456789abcdef';
    final idBuffer = StringBuffer();
    for (int i = 0; i < 8; i++) {
      idBuffer.write(hexChars[rng.nextInt(16)]);
    }
    return GuestIdentity(
      guestNumber: number,
      guestId: idBuffer.toString(),
    );
  }

  static GuestIdentity? tryParseJson(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) return null;
    try {
      final decoded = json.decode(rawJson);
      if (decoded is! Map<String, dynamic>) return null;
      final number = decoded['guestNumber']?.toString();
      final id = decoded['guestId']?.toString();
      if (!isValid(number, id)) return null;
      return GuestIdentity(guestNumber: number!, guestId: id!);
    } catch (_) {
      return null;
    }
  }

  String toJsonString() => json.encode({
        'guestNumber': guestNumber,
        'guestId': guestId,
      });
}

/// Generates a random [GuestIdentity] on first app launch and persists it
/// permanently on device storage (`SharedPreferences` + local file backup).
class GuestIdentityService {
  static const String _kPrefGuestNumber = 'dxx_guest_number_v1';
  static const String _kPrefGuestId = 'dxx_guest_id_v1';

  GuestIdentity? _cached;

  GuestIdentity get identity {
    if (_cached != null) return _cached!;

    final fromFile = GuestIdentity.tryParseJson(readPersistedGuestJson());
    if (fromFile != null) {
      _cached = fromFile;
      _persistToPrefsAsync(fromFile);
      return fromFile;
    }

    final generated = GuestIdentity.generate();
    _cached = generated;
    writePersistedGuestJson(generated.toJsonString());
    _persistToPrefsAsync(generated);
    return generated;
  }

  Future<GuestIdentity> init() async {
    if (_cached != null) return _cached!;

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final savedNumber = prefs.getString(_kPrefGuestNumber);
      final savedId = prefs.getString(_kPrefGuestId);
      if (GuestIdentity.isValid(savedNumber, savedId)) {
        final loaded = GuestIdentity(
          guestNumber: savedNumber!,
          guestId: savedId!,
        );
        _cached = loaded;
        await writePersistedGuestJson(loaded.toJsonString());
        return loaded;
      }
    } catch (_) {
      // Safe fallback if native plugin isn't linked yet during live Hot Restart.
    }

    final fromFile = GuestIdentity.tryParseJson(readPersistedGuestJson());
    if (fromFile != null) {
      _cached = fromFile;
      if (prefs != null) {
        try {
          await prefs.setString(_kPrefGuestNumber, fromFile.guestNumber);
          await prefs.setString(_kPrefGuestId, fromFile.guestId);
        } catch (_) {}
      }
      return fromFile;
    }

    final generated = GuestIdentity.generate();
    _cached = generated;
    if (prefs != null) {
      try {
        await prefs.setString(_kPrefGuestNumber, generated.guestNumber);
        await prefs.setString(_kPrefGuestId, generated.guestId);
      } catch (_) {}
    }
    await writePersistedGuestJson(generated.toJsonString());
    return generated;
  }

  void _persistToPrefsAsync(GuestIdentity value) {
    Future<void>(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kPrefGuestNumber, value.guestNumber);
        await prefs.setString(_kPrefGuestId, value.guestId);
      } catch (_) {}
    });
  }
}
