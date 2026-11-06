class LanguageOption {
  final String code;
  final String name;
  final String flag;

  const LanguageOption({
    required this.code,
    required this.name,
    required this.flag,
  });
}

/// Complete localization bundle for a single language (`vi`, `en`, `ko`, `ja`, `th`, `es`, `pt`, `fr`, `de`, `ar`).
class LanguagePack {
  final String code;
  final String name;
  final String flag;
  final Map<String, String> ui;
  final Map<String, String> tags;
  final Map<String, String> dramaTitles;
  final Map<String, String> dramaDescriptions;

  const LanguagePack({
    required this.code,
    required this.name,
    required this.flag,
    required this.ui,
    required this.tags,
    required this.dramaTitles,
    required this.dramaDescriptions,
  });

  LanguageOption get option => LanguageOption(
        code: code,
        name: name,
        flag: flag,
      );
}
