import 'dart:async';
import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/const/ad_id_extension.dart';
import '../../ads/const/ad_id_name.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../services/shared_preference_service.dart';

class LanguageVariantModel {
  final String variantId;
  final String title;
  final String nativeName;
  final String languageCode;
  final String countryCode;

  const LanguageVariantModel({
    required this.variantId,
    required this.title,
    required this.nativeName,
    required this.languageCode,
    required this.countryCode,
  });
}

class LanguageGroupModel {
  final String groupId;
  final String title;
  final String nativeName;
  final String languageCode;
  final String? singleCountryCode;
  final List<LanguageVariantModel> variants;

  const LanguageGroupModel({
    required this.groupId,
    required this.title,
    required this.nativeName,
    required this.languageCode,
    this.singleCountryCode,
    this.variants = const [],
  });

  bool get isDropdown => variants.isNotEmpty;
}

class LanguageController extends ChangeNotifier {
  static const List<LanguageGroupModel> supportedGroups = [
    LanguageGroupModel(
      groupId: 'ar',
      title: 'العربية',
      nativeName: 'Arabic',
      languageCode: 'ar',
      variants: [
        LanguageVariantModel(
          variantId: 'ar_SA',
          title: 'العربية (السعودية)',
          nativeName: 'Arabic (Saudi Arabia)',
          languageCode: 'ar',
          countryCode: 'sa',
        ),
        LanguageVariantModel(
          variantId: 'ar_EG',
          title: 'العربية (مصر)',
          nativeName: 'Arabic (Egypt)',
          languageCode: 'ar',
          countryCode: 'eg',
        ),
        LanguageVariantModel(
          variantId: 'ar_AE',
          title: 'العربية (الإمارات)',
          nativeName: 'Arabic (UAE)',
          languageCode: 'ar',
          countryCode: 'ae',
        ),
      ],
    ),
    LanguageGroupModel(
      groupId: 'es',
      title: 'Español',
      nativeName: 'Spanish',
      languageCode: 'es',
      variants: [
        LanguageVariantModel(
          variantId: 'es_ES',
          title: 'Español (España)',
          nativeName: 'Spanish (Spain)',
          languageCode: 'es',
          countryCode: 'es',
        ),
        LanguageVariantModel(
          variantId: 'es_MX',
          title: 'Español (México)',
          nativeName: 'Spanish (Mexico)',
          languageCode: 'es',
          countryCode: 'mx',
        ),
        LanguageVariantModel(
          variantId: 'es_AR',
          title: 'Español (Argentina)',
          nativeName: 'Spanish (Argentina)',
          languageCode: 'es',
          countryCode: 'ar',
        ),
      ],
    ),
    LanguageGroupModel(
      groupId: 'pt',
      title: 'Português',
      nativeName: 'Portuguese',
      languageCode: 'pt',
      variants: [
        LanguageVariantModel(
          variantId: 'pt_BR',
          title: 'Português (Brasil)',
          nativeName: 'Portuguese (Brazil)',
          languageCode: 'pt',
          countryCode: 'br',
        ),
        LanguageVariantModel(
          variantId: 'pt_PT',
          title: 'Português (Portugal)',
          nativeName: 'Portuguese (Portugal)',
          languageCode: 'pt',
          countryCode: 'pt',
        ),
      ],
    ),
    LanguageGroupModel(
      groupId: 'vi',
      title: 'Tiếng Việt',
      nativeName: 'Vietnamese',
      languageCode: 'vi',
      singleCountryCode: 'vn',
    ),
    LanguageGroupModel(
      groupId: 'fr',
      title: 'Français',
      nativeName: 'French',
      languageCode: 'fr',
      singleCountryCode: 'fr',
    ),
    LanguageGroupModel(
      groupId: 'de',
      title: 'Deutsch',
      nativeName: 'German',
      languageCode: 'de',
      singleCountryCode: 'de',
    ),
    LanguageGroupModel(
      groupId: 'ko',
      title: '한국어',
      nativeName: 'Korean',
      languageCode: 'ko',
      singleCountryCode: 'kr',
    ),
    LanguageGroupModel(
      groupId: 'ja',
      title: '日本語',
      nativeName: 'Japanese',
      languageCode: 'ja',
      singleCountryCode: 'jp',
    ),
    LanguageGroupModel(
      groupId: 'th',
      title: 'ภาษาไทย',
      nativeName: 'Thai',
      languageCode: 'th',
      singleCountryCode: 'th',
    ),
    LanguageGroupModel(
      groupId: 'en',
      title: 'English',
      nativeName: 'English',
      languageCode: 'en',
      variants: [
        LanguageVariantModel(
          variantId: 'en_US',
          title: 'English (US)',
          nativeName: 'English',
          languageCode: 'en',
          countryCode: 'us',
        ),
        LanguageVariantModel(
          variantId: 'en_GB',
          title: 'English (UK)',
          nativeName: 'English',
          languageCode: 'en',
          countryCode: 'gb',
        ),
        LanguageVariantModel(
          variantId: 'en_IN',
          title: 'English (India)',
          nativeName: 'English',
          languageCode: 'en',
          countryCode: 'in',
        ),
      ],
    ),
  ];

  final List<LanguageGroupModel> groups = [];
  bool isFirstLaunch = false;
  String? expandedGroupId;
  String? selectedLanguageCode;
  String? selectedVariantId;
  bool showEnglishHandHint = true;

  bool isShowClickAds = false;
  bool isShouldShowNext = false;
  bool isShouldShowAds = true;
  bool isLoading = false;
  bool canClick = false;
  bool _isDisposed = false;

  Timer? _nextDelayTimer;
  Timer? _loadingTimer;
  StreamSubscription<AdEvent>? _adEventSubscription;

  bool get hasSelection =>
      selectedLanguageCode != null && selectedVariantId != null;

  Future<void> init({
    required bool firstLaunch,
    required String currentLangCode,
  }) async {
    isFirstLaunch = firstLaunch;
    groups
      ..clear()
      ..addAll(supportedGroups);
    expandedGroupId = null;
    showEnglishHandHint = true;

    if (!isFirstLaunch) {
      final savedVariant =
          await SharedPreferenceService.getSavedLanguageVariantOrNull();
      _preselectCurrent(currentLangCode, savedVariant);
      isLoading = false;
      canClick = true;
      isShouldShowNext = true;
      _notify();
      return;
    }

    selectedLanguageCode = null;
    selectedVariantId = null;

    final shouldPreloadAds =
        AppConstants.isMobilePlatform && !AppConstants.isPremiumUser.value;

    if (!shouldPreloadAds) {
      isLoading = false;
      canClick = true;
      _notify();
      return;
    }

    isLoading = true;
    canClick = false;
    _notify();

    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(milliseconds: 2500), () {
      isLoading = false;
      canClick = true;
      _notify();
    });

    _listenAdEvents();
  }

  void _preselectCurrent(String langCode, String? savedVariant) {
    final matchIdx = groups.indexWhere((g) => g.languageCode == langCode);
    final group = matchIdx >= 0 ? groups[matchIdx] : groups.first;
    selectedLanguageCode = group.languageCode;

    if (group.isDropdown) {
      final hasMatchingVariant = savedVariant != null &&
          group.variants.any((v) => v.variantId == savedVariant);
      selectedVariantId =
          hasMatchingVariant ? savedVariant : group.variants.first.variantId;
    } else {
      selectedVariantId = group.groupId;
    }
  }

  void _listenAdEvents() {
    if (!AppConstants.isMobilePlatform) return;
    _adEventSubscription?.cancel();
    _adEventSubscription = EasyAds.instance.onEvent.listen((event) {
      if (event.adUnitId == MyAdIdName.nativeLanguage.getId ||
          event.adUnitId == MyAdIdName.nativeLanguageHigh.getId) {
        if (event.type == AdEventType.adLoaded ||
            event.type == AdEventType.adFailedToLoad) {
          if (isLoading) {
            _loadingTimer?.cancel();
            isLoading = false;
            canClick = true;
            _notify();
          }
        }
      } else if (event.adUnitId == MyAdIdName.nativeLanguageClick.getId ||
          event.adUnitId == MyAdIdName.nativeLanguageClickHigh.getId) {
        if (event.type == AdEventType.adLoaded ||
            event.type == AdEventType.adFailedToLoad) {
          _revealNextAfterShortDelay();
        }
      }
    });
  }

  void _revealNextAfterShortDelay() {
    if (isShouldShowNext) return;
    _nextDelayTimer?.cancel();
    _nextDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!isShouldShowNext) {
        isShouldShowNext = true;
        _notify();
      }
    });
  }

  void onToggleDropdownGroup(LanguageGroupModel group) {
    if (!canClick || isLoading) return;
    showEnglishHandHint = false;
    if (expandedGroupId == group.groupId) {
      expandedGroupId = null;
    } else {
      expandedGroupId = group.groupId;
    }
    _notify();
  }

  void onSelectSingleGroup(LanguageGroupModel group) {
    if (!canClick || isLoading) return;
    showEnglishHandHint = false;
    _applySelection(
      langCode: group.languageCode,
      variantId: group.groupId,
    );
  }

  void onSelectVariant(LanguageVariantModel variant) {
    if (!canClick || isLoading) return;
    showEnglishHandHint = false;
    _applySelection(
      langCode: variant.languageCode,
      variantId: variant.variantId,
    );
  }

  void _applySelection({
    required String langCode,
    required String variantId,
  }) {
    if (!isFirstLaunch ||
        !AppConstants.isMobilePlatform ||
        AppConstants.isPremiumUser.value ||
        isShowClickAds) {
      selectedLanguageCode = langCode;
      selectedVariantId = variantId;
      isShouldShowNext = true;
      _notify();
      return;
    }

    // First selection on first launch: switch Native Ad to native_language_click
    selectedLanguageCode = langCode;
    selectedVariantId = variantId;
    isShowClickAds = true;
    isShouldShowNext = false;
    _notify();

    _nextDelayTimer?.cancel();
    _nextDelayTimer = Timer(const Duration(seconds: 3), () {
      if (!isShouldShowNext) {
        isShouldShowNext = true;
        _notify();
      }
    });
  }

  void onAdImpression() {
    _revealNextAfterShortDelay();
  }

  void onSelectBack(BuildContext context) {
    if (isLoading) return;
    Navigator.of(context).pop();
  }

  Future<void> onClickNext(
    BuildContext context, {
    required WidgetRef ref,
    required VoidCallback onNavigateNext,
  }) async {
    if (!canClick || isLoading) return;
    final code = selectedLanguageCode;
    final variant = selectedVariantId;
    if (code != null) {
      AppConstants.selectedLanguageCode = code;
      await SharedPreferenceService.setSelectedLanguageCode(code);
      if (variant != null) {
        await SharedPreferenceService.setSelectedLanguageVariant(variant);
      }
      ref.read(localeProvider.notifier).setAppLanguage(code);

      if (ref.read(sessionProvider).asData?.value.isInitialized == true) {
        unawaited(
          Future(() async {
            await ref.read(accountProvider.notifier).updateSettings(
                  appLanguage: code,
                  subtitleLanguage: code,
                );
            await Future.wait([
              ref.read(homeProvider.notifier).fetchHome(code),
              ref.read(feedProvider.notifier).fetchInitialFeed(code),
              ref.read(rewardsProvider.notifier).fetchOverview(code),
            ]);
          }),
        );
      }
    }

    if (!context.mounted) return;
    if (!isFirstLaunch) {
      Navigator.of(context).pop();
    } else {
      onNavigateNext();
    }
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _nextDelayTimer?.cancel();
    _loadingTimer?.cancel();
    _adEventSubscription?.cancel();
    super.dispose();
  }
}
