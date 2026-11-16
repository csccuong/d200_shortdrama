import '../constants/app_constants.dart';
import '../../models/drama_models.dart';
import 'language_pack.dart';
import 'locales/l10n_ar.dart';
import 'locales/l10n_de.dart';
import 'locales/l10n_en.dart';
import 'locales/l10n_es.dart';
import 'locales/l10n_fr.dart';
import 'locales/l10n_ja.dart';
import 'locales/l10n_ko.dart';
import 'locales/l10n_pt.dart';
import 'locales/l10n_th.dart';
import 'locales/l10n_vi.dart';

export 'language_pack.dart';
export 'locales/l10n_ar.dart';
export 'locales/l10n_de.dart';
export 'locales/l10n_en.dart';
export 'locales/l10n_es.dart';
export 'locales/l10n_fr.dart';
export 'locales/l10n_ja.dart';
export 'locales/l10n_ko.dart';
export 'locales/l10n_pt.dart';
export 'locales/l10n_th.dart';
export 'locales/l10n_vi.dart';

/// Central Localization Manager aggregating individual locale files from `lib/core/l10n/locales/`.
class AppStrings {
  AppStrings._();

  static const List<LanguagePack> allPacks = [
    viLanguagePack,
    enLanguagePack,
    koLanguagePack,
    jaLanguagePack,
    thLanguagePack,
    esLanguagePack,
    ptLanguagePack,
    frLanguagePack,
    deLanguagePack,
    arLanguagePack,
  ];

  static final Map<String, LanguagePack> _packsByCode = {
    for (final pack in allPacks) pack.code: pack,
  };

  static const List<LanguageOption> supportedLanguages = [
    LanguageOption(code: 'vi', name: 'Tiếng Việt', flag: '🇻🇳'),
    LanguageOption(code: 'en', name: 'English', flag: '🇺🇸'),
    LanguageOption(code: 'ko', name: '한국어', flag: '🇰🇷'),
    LanguageOption(code: 'ja', name: '日本語', flag: '🇯🇵'),
    LanguageOption(code: 'th', name: 'ภาษาไทย', flag: '🇹🇭'),
    LanguageOption(code: 'es', name: 'Español', flag: '🇪🇸'),
    LanguageOption(code: 'pt', name: 'Português', flag: '🇧🇷'),
    LanguageOption(code: 'fr', name: 'Français', flag: '🇫🇷'),
    LanguageOption(code: 'de', name: 'Deutsch', flag: '🇩🇪'),
    LanguageOption(code: 'ar', name: 'العربية', flag: '🇸🇦'),
  ];

  static LanguagePack getPack(String code) {
    return _packsByCode[code] ?? enLanguagePack;
  }

  static String genericError([String? langCode]) {
    return tr(langCode ?? AppConstants.selectedLanguageCode, 'generic_error_toast');
  }

  static String normalizeLangCode(String code) => code.trim().toLowerCase();

  static String baseLangCode(String code) {
    final norm = normalizeLangCode(code);
    if (norm.isEmpty) return '';
    return norm.split(RegExp(r'[-_]')).first;
  }

  static const Map<String, LanguageOption> _extraSubtitleLanguageOptions = {
    'id': LanguageOption(code: 'id', name: 'Bahasa Indonesia', flag: '🇮🇩'),
    'ms': LanguageOption(code: 'ms', name: 'Bahasa Melayu', flag: '🇲🇾'),
    'tr': LanguageOption(code: 'tr', name: 'Türkçe', flag: '🇹🇷'),
    'zh': LanguageOption(code: 'zh', name: '中文', flag: '🇨🇳'),
    'hi': LanguageOption(code: 'hi', name: 'हिन्दी', flag: '🇮🇳'),
    'ru': LanguageOption(code: 'ru', name: 'Русский', flag: '🇷🇺'),
    'it': LanguageOption(code: 'it', name: 'Italiano', flag: '🇮🇹'),
  };

  static LanguageOption getLanguageOption(String code) {
    final norm = normalizeLangCode(code);
    final base = baseLangCode(code);
    for (final l in supportedLanguages) {
      if (l.code.toLowerCase() == norm) return l;
    }
    if (base.isNotEmpty) {
      for (final l in supportedLanguages) {
        if (l.code.toLowerCase() == base) return l;
      }
    }
    final extra = _extraSubtitleLanguageOptions[norm] ??
        _extraSubtitleLanguageOptions[base];
    if (extra != null) return extra;
    final resolved = norm.isNotEmpty ? norm : 'en';
    if (resolved == 'en') {
      return supportedLanguages.firstWhere((l) => l.code == 'en');
    }
    return LanguageOption(
      code: resolved,
      name: resolved.toUpperCase(),
      flag: '🌐',
    );
  }

  /// Resolves the best subtitle item for [preferredLang], falling back to
  /// English (`en`), then [isDefault], then the first item.
  static T? resolveSubtitleCandidate<T>(
    List<T> items,
    String Function(T) codeOf,
    String preferredLang, {
    bool Function(T)? isDefault,
  }) {
    if (items.isEmpty) return null;

    T? findByLang(String target) {
      final norm = normalizeLangCode(target);
      final base = baseLangCode(target);
      if (norm.isEmpty) return null;
      for (final item in items) {
        if (normalizeLangCode(codeOf(item)) == norm) return item;
      }
      if (base.isNotEmpty) {
        for (final item in items) {
          if (baseLangCode(codeOf(item)) == base) return item;
        }
      }
      return null;
    }

    return findByLang(preferredLang) ??
        findByLang('en') ??
        (isDefault != null ? items.where(isDefault).firstOrNull : null) ??
        items.first;
  }

  static String tr(String langCode, String key) {
    final pack = getPack(langCode);
    return pack.ui[key] ?? enLanguagePack.ui[key] ?? key;
  }

  static String trTag(String langCode, String rawTag) {
    final pack = getPack(langCode);
    return pack.tags[rawTag] ?? enLanguagePack.tags[rawTag] ?? rawTag;
  }

  static String dramaTitle(String langCode, Drama drama) {
    final pack = getPack(langCode);
    return pack.dramaTitles[drama.slug] ?? drama.title;
  }

  static String dramaDescription(String langCode, Drama drama) {
    final pack = getPack(langCode);
    return pack.dramaDescriptions[drama.slug] ?? drama.description;
  }
}
