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

  static LanguageOption getLanguageOption(String code) {
    return supportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => supportedLanguages.first,
    );
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
