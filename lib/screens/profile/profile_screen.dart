import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/screen_utils.dart';
import '../../fo/language/language_activity.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../widgets/bottom_native_all_ad.dart';
import '../../widgets/drama_network_image.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const String _imgGuest = 'assets/images/img_guest.png';
  static const String _icLanguage = 'assets/icons/ic_language.png';
  static const String _icRateApp = 'assets/icons/ic_rateapp.png';
  static const String _icTerms = 'assets/icons/ic_terms.png';
  static const String _icPolicy = 'assets/icons/ic_policy.png';

  ProviderSubscription<AsyncValue<SessionState>>? _sessionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureLoaded();
    });
    _sessionSub = ref.listenManual<AsyncValue<SessionState>>(
      sessionProvider,
      (prev, next) {
        final wasReady = prev?.value?.isInitialized ?? false;
        final isReady = next.value?.isInitialized ?? false;
        if (!wasReady && isReady) {
          _ensureLoaded();
        }
      },
    );
  }

  @override
  void dispose() {
    _sessionSub?.close();
    super.dispose();
  }

  void _ensureLoaded() {
    if (ref.read(sessionProvider).value?.isInitialized != true) return;
    final accState = ref.read(accountProvider);
    if (accState.profile == null && !accState.isLoadingProfile) {
      ref.read(accountProvider.notifier).fetchProfile();
    }
    final rewAsync = ref.read(rewardsProvider);
    final rewState = rewAsync.value;
    if (!rewAsync.isLoading && rewState?.overview == null) {
      ref
          .read(rewardsProvider.notifier)
          .fetchOverview(AppConstants.selectedLanguageCode);
    }
  }

  Future<void> _onRefresh() async {
    final ready = await ensureSessionForUserAction(ref);
    if (!ready || !mounted) return;
    await Future.wait([
      ref.read(accountProvider.notifier).fetchProfile(),
      ref
          .read(rewardsProvider.notifier)
          .fetchOverview(AppConstants.selectedLanguageCode),
      ref.read(mylistProvider.notifier).fetchFavorites(),
      ref.read(mylistProvider.notifier).fetchHistory(),
    ]);
  }

  void _copyUid(BuildContext context, LocaleState locale, String uid) {
    Clipboard.setData(ClipboardData(text: uid));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${locale.tr('id_copied_toast')}: $uid'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.surfaceSheet,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRateAppDialog(BuildContext context, LocaleState locale) {
    int selectedStars = 5;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              backgroundColor: AppColors.surfaceSheet,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.r),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              _icRateApp,
                              width: 22.w,
                              height: 22.w,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              locale.tr('menu_rate_app'),
                              style: AppTextStyles.h3,
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(dialogCtx),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppColors.textMuted,
                            size: 20.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      locale.tr('rate_dialog_desc'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall,
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (idx) {
                        final filled = idx < selectedStars;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedStars = idx + 1),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5.w),
                            child: Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: AppColors.gold,
                              size: 34.sp,
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 20.h),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(dialogCtx);
                        try {
                          ref.read(eventTrackerProvider).track(
                            'rate_app',
                            sourceScreen: 'profile',
                            props: {'stars': selectedStars},
                          );
                        } catch (_) {}
                        _showToast(locale.tr('rate_thanks_toast'));
                      },
                      child: Container(
                        width: double.infinity,
                        height: 42.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(22.r),
                        ),
                        child: Text(
                          locale.tr('rate_submit_btn'),
                          style: AppTextStyles.exploreButtonText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPrivacyPolicy(
    BuildContext context,
    LocaleState locale,
  ) async {
    final uri = Uri.parse(AppConstants.privacyPolicyUrl);
    for (final mode in const [
      LaunchMode.inAppBrowserView,
      LaunchMode.externalApplication,
    ]) {
      try {
        if (await launchUrl(uri, mode: mode)) return;
      } catch (e) {
        debugPrint('Privacy policy launch ($mode) failed: $e');
      }
    }
    if (!context.mounted) return;
    _showLegalSheet(
      context,
      title: locale.tr('menu_privacy'),
      content: locale.tr('privacy_content'),
      iconAsset: _icPolicy,
    );
  }

  void _showLegalSheet(
    BuildContext context, {
    required String title,
    required String content,
    required String iconAsset,
  }) {
    final bottomInset = AppScreenUtils.bottomSafeInset(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(maxHeight: 0.72.sh),
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h + bottomInset),
          decoration: BoxDecoration(
            color: AppColors.surfaceSheet,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(),
              Row(
                children: [
                  Image.asset(
                    iconAsset,
                    width: 22.w,
                    height: 22.w,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(child: Text(title, style: AppTextStyles.h3)),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textWhite60,
                      size: 20.sp,
                    ),
                  ),
                ],
              ),
              Divider(color: AppColors.borderLight, height: 16.h),
              Flexible(
                child: SingleChildScrollView(
                  physics: AppScreenUtils.adaptiveScrollPhysics,
                  child: Text(
                    content,
                    style: AppTextStyles.bodyRegular.copyWith(height: 1.55),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAuthSheet(BuildContext context, {bool initialRegister = false}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => _AuthBottomSheet(
        initialRegister: initialRegister,
        onSuccess: (msg) => _showToast(msg),
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, UserProfile? profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => _EditProfileSheet(
        profile: profile,
        onSaved: (msg) => _showToast(msg),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceSheet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        title: Text('Sign Out', style: AppTextStyles.h3),
        content: Text(
          'Switch back to anonymous guest session on this device?',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref.read(accountProvider.notifier).logout();
    if (!mounted) return;
    _showToast(
      ok ? 'Signed out cleanly' : 'Could not sign out right now',
      isError: !ok,
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceSheet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22.sp),
            SizedBox(width: 8.w),
            Text('Delete Account', style: AppTextStyles.h3),
          ],
        ),
        content: Text(
          'This permanently deletes your account data, coins, VIP status, favorites, and watch history. A fresh guest profile will be created if you continue.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref.read(accountProvider.notifier).deleteAccount();
    if (!mounted) return;
    _showToast(
      ok
          ? 'Account deleted. Started fresh guest session.'
          : (ref.read(accountProvider).errorMessage ?? 'Delete failed'),
      isError: !ok,
    );
  }

  // TODO(IAP): Re-enable when VIP banner is restored with IAP.
  // String _formatVipSubtitle(LocaleState locale, WalletState wallet, UserProfile? profile) {
  //   final isVip = wallet.isVip || (profile?.isVip ?? false);
  //   final exp = wallet.vipExpiresAt ?? profile?.vipExpiresAt;
  //   if (isVip && exp != null && exp.isNotEmpty) {
  //     final shortDate = exp.length >= 10 ? exp.substring(0, 10) : exp;
  //     return 'Expires $shortDate';
  //   }
  //   return locale.tr('vip_enjoy_benefits');
  // }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final legacyWallet = ref.watch(userWalletProvider);
    final wallet = ref.watch(walletProvider);
    final accountState = ref.watch(accountProvider);
    final rewardsState = ref.watch(rewardsProvider);
    final mylistState = ref.watch(mylistProvider);
    final guest = ref.watch(guestIdentityProvider);

    final profile = accountState.profile;
    final isGuest = profile?.isGuest ?? true;
    final isVip = wallet.isVip || (profile?.isVip ?? false) || legacyWallet.isVip;
    final totalCoins =
        wallet.totalCoins > 0 ? wallet.totalCoins : (profile?.totalCoins ?? 0);
    final uid = (profile != null && profile.userUid.isNotEmpty)
        ? profile.userUid
        : guest.guestId;
    final displayName = (profile?.displayName != null &&
            profile!.displayName!.trim().isNotEmpty)
        ? profile.displayName!.trim()
        : (profile?.email?.isNotEmpty == true
            ? profile!.email!
            : '${locale.tr('guest_prefix')}_${guest.guestNumber}');

    final favCount = (profile?.favoritesCount ?? 0) > 0
        ? profile!.favoritesCount
        : mylistState.favorites.length;
    final laterCount = (profile?.watchLaterCount ?? 0) > 0
        ? profile!.watchLaterCount
        : mylistState.watchLater.length;
    final watchedCount = (profile?.watchedDramasCount ?? 0) > 0
        ? profile!.watchedDramasCount
        : mylistState.history.length;
    final streak = rewardsState.value?.overview?.checkin.streak ??
        profile?.checkinStreak ??
        0;

    final settings = profile?.settings ??
        UserSettings(
          appLanguage: AppConstants.selectedLanguageCode,
          subtitleLanguage: AppConstants.selectedLanguageCode,
          autoPlayNext: legacyWallet.autoPlayNext,
        );

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceSheet,
                onRefresh: _onRefresh,
                child: ListView(
                  physics: AlwaysScrollableScrollPhysics(
                    parent: AppScreenUtils.adaptiveScrollPhysics,
                  ),
                  padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 28.h),
                  children: [
                    // 1. Top "Profile" Header + Coins & Sign-In Pill
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            locale.tr('nav_profile'),
                            style: AppTextStyles.h1,
                          ),
                        ),
                        GestureDetector(
                          // TODO(IAP): Re-enable tap to Rewards when IAP is integrated.
                          // onTap: () => ref
                          //     .read(shellTabIndexProvider.notifier)
                          //     .setTab(3),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 5.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(18.r),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.monetization_on_rounded,
                                  color: AppColors.gold,
                                  size: 16.sp,
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  '$totalCoins',
                                  style: TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isGuest) ...[
                          SizedBox(width: 8.w),
                          GestureDetector(
                            onTap: () => _showAuthSheet(context),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 11.w,
                                vertical: 5.h,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(18.r),
                              ),
                              child: Text(
                                'Sign In',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    SizedBox(height: 14.h),

                    // 2. Avatar + Name + Account Badge & Copyable UID
                    Row(
                      children: [
                        if (profile?.avatarUrl != null &&
                            profile!.avatarUrl!.trim().isNotEmpty)
                          ClipOval(
                            child: DramaNetworkImage(
                              imageUrl: profile.avatarUrl!,
                              width: 62.w,
                              height: 62.w,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Image.asset(
                            _imgGuest,
                            width: 62.w,
                            height: 62.w,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.profileGuestName,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 7.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isVip
                                          ? AppColors.gold
                                              .withValues(alpha: 0.2)
                                          : AppColors.surfaceCard,
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(
                                        color: isVip
                                            ? AppColors.gold
                                            : AppColors.borderLight,
                                      ),
                                    ),
                                    child: Text(
                                      isVip
                                          ? 'VIP'
                                          : (isGuest
                                              ? 'GUEST'
                                              : profile!.authProvider
                                                  .toUpperCase()),
                                      style: TextStyle(
                                        color: isVip
                                            ? AppColors.gold
                                            : AppColors.textSecondary,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!isGuest &&
                                  profile?.email != null &&
                                  profile!.email!.isNotEmpty &&
                                  profile.email != displayName) ...[
                                SizedBox(height: 2.h),
                                Text(
                                  profile.email!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                              SizedBox(height: 4.h),
                              GestureDetector(
                                onTap: () => _copyUid(context, locale, uid),
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${locale.tr('id_label')}: $uid',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.profileIdLabel,
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    Icon(
                                      Icons.copy_rounded,
                                      color: AppColors.profileIdText,
                                      size: 14.sp,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: isGuest ? 'Sign In' : 'Edit Profile',
                          onPressed: () => isGuest
                              ? _showAuthSheet(context)
                              : _showEditProfileSheet(context, profile),
                          icon: Icon(
                            isGuest
                                ? Icons.person_add_alt_1_rounded
                                : Icons.edit_outlined,
                            color: AppColors.textWhite70,
                            size: 20.sp,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12.h),

                    // 3. Compact Stats Strip (Favorites / Watch Later / Watched / Streak)
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 9.h,
                        horizontal: 8.w,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.profileTileBg,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          _StatCell(
                            value: '$favCount',
                            label: 'My List',
                            onTap: () => ref
                                .read(shellTabIndexProvider.notifier)
                                .setTab(2),
                          ),
                          _StatDivider(),
                          _StatCell(
                            value: '$laterCount',
                            label: 'Later',
                            onTap: () => ref
                                .read(shellTabIndexProvider.notifier)
                                .setTab(2),
                          ),
                          _StatDivider(),
                          _StatCell(
                            value: '$watchedCount',
                            label: 'Watched',
                            onTap: () => ref
                                .read(shellTabIndexProvider.notifier)
                                .setTab(2),
                          ),
                          _StatDivider(),
                          _StatCell(
                            value: '${streak}d',
                            label: 'Streak',
                            valueColor: AppColors.gold,
                            // TODO(IAP): Re-enable tap to Rewards check-in in v2.
                            // onTap: () => ref
                            //     .read(shellTabIndexProvider.notifier)
                            //     .setTab(3),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 12.h),

                    // TODO(IAP): Re-enable Golden "Unlock VIP" Banner Card when IAP is integrated.
                    // 4. Golden "Unlock VIP" Banner Card
                    // GestureDetector(
                    //   onTap: () =>
                    //       ref.read(shellTabIndexProvider.notifier).setTab(3),
                    //   child: Container(
                    //     padding: EdgeInsets.symmetric(
                    //       horizontal: 14.w,
                    //       vertical: 12.h,
                    //     ),
                    //     decoration: BoxDecoration(
                    //       gradient: AppColors.profileVipGoldGradient,
                    //       borderRadius: BorderRadius.circular(14.r),
                    //     ),
                    //     child: Row(
                    //       children: [
                    //         Transform.rotate(
                    //           angle: -0.14,
                    //           child: Image.asset(
                    //             'assets/images/vip_crown.png',
                    //             width: 44.w,
                    //             height: 44.w,
                    //             fit: BoxFit.contain,
                    //           ),
                    //         ),
                    //         SizedBox(width: 10.w),
                    //         Expanded(
                    //           child: Column(
                    //             crossAxisAlignment: CrossAxisAlignment.start,
                    //             children: [
                    //               Text(
                    //                 isVip
                    //                     ? locale.tr('vip_activated_title')
                    //                     : locale.tr('unlock_vip_title'),
                    //                 maxLines: 1,
                    //                 overflow: TextOverflow.ellipsis,
                    //                 style: AppTextStyles.vipBannerTitle,
                    //               ),
                    //               SizedBox(height: 2.h),
                    //               Text(
                    //                 _formatVipSubtitle(locale, wallet, profile),
                    //                 maxLines: 1,
                    //                 overflow: TextOverflow.ellipsis,
                    //                 style: AppTextStyles.vipBannerSubtitle,
                    //               ),
                    //             ],
                    //           ),
                    //         ),
                    //         SizedBox(width: 8.w),
                    //         Container(
                    //           height: 34.h,
                    //           padding: EdgeInsets.symmetric(horizontal: 18.w),
                    //           alignment: Alignment.center,
                    //           decoration: BoxDecoration(
                    //             color: AppColors.vipActivateBtnBg,
                    //             borderRadius: BorderRadius.circular(18.r),
                    //           ),
                    //           child: Text(
                    //             isVip
                    //                 ? locale.tr('plan_active')
                    //                 : locale.tr('activate_btn'),
                    //             style: AppTextStyles.vipActivateButton,
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                    //
                    // SizedBox(height: 14.h),

                    // 5. Primary Menu Items (menu_language stays immediately visible above the fold)
                    _ProfileMenuTile(
                      iconAsset: _icLanguage,
                      title: locale.tr('menu_language'),
                      onTap: () => ref
                          .read(navigationServiceProvider)
                          .push(
                            context,
                            const LanguageActivity(isFirstLaunch: false),
                          ),
                    ),
                    SizedBox(height: 10.h),

                    if (isGuest)
                      _ActionMenuTile(
                        icon: Icons.login_rounded,
                        iconColor: AppColors.primary,
                        title: 'Sign In / Create Account',
                        subtitle: 'Sync coins, VIP & favorites across devices',
                        onTap: () => _showAuthSheet(context),
                      )
                    else ...[
                      _ActionMenuTile(
                        icon: Icons.manage_accounts_rounded,
                        iconColor: AppColors.gold,
                        title: 'Edit Profile & Password',
                        subtitle: 'Update name, gender, birth year or password',
                        onTap: () => _showEditProfileSheet(context, profile),
                      ),
                      SizedBox(height: 10.h),
                      _ActionMenuTile(
                        icon: Icons.logout_rounded,
                        iconColor: AppColors.textSecondary,
                        title: 'Sign Out',
                        subtitle: 'Return to anonymous guest session',
                        onTap: () => _confirmLogout(context),
                      ),
                    ],

                    SizedBox(height: 12.h),

                    // 6. Playback & Streaming Preferences (synced with /v1/me/settings)
                    _PlaybackSettingsCard(
                      settings: settings,
                      onChanged: ({
                        bool? autoPlayNext,
                        bool? wifiOnly,
                        String? videoQuality,
                      }) {
                        ref.read(accountProvider.notifier).updateSettings(
                              autoPlayNext: autoPlayNext,
                              wifiOnly: wifiOnly,
                              videoQuality: videoQuality,
                            );
                      },
                    ),

                    SizedBox(height: 12.h),

                    // 7. Support & Legal Tiles
                    _ProfileMenuTile(
                      iconAsset: _icRateApp,
                      title: locale.tr('menu_rate_app'),
                      onTap: () => _showRateAppDialog(context, locale),
                    ),
                    SizedBox(height: 10.h),
                    _ProfileMenuTile(
                      iconAsset: _icTerms,
                      title: locale.tr('menu_terms'),
                      onTap: () => _showLegalSheet(
                        context,
                        title: locale.tr('menu_terms'),
                        content: locale.tr('terms_content'),
                        iconAsset: _icTerms,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    _ProfileMenuTile(
                      iconAsset: _icPolicy,
                      title: locale.tr('menu_privacy'),
                      onTap: () => _openPrivacyPolicy(context, locale),
                    ),

                    SizedBox(height: 12.h),

                    // 8. Danger Zone: Delete Account
                    _ActionMenuTile(
                      icon: Icons.delete_forever_rounded,
                      iconColor: AppColors.error,
                      titleColor: AppColors.error,
                      title: 'Delete Account',
                      subtitle: 'Permanently erase account & reset device session',
                      trailingLoading: accountState.isAuthenticating,
                      onTap: accountState.isAuthenticating
                          ? null
                          : () => _confirmDeleteAccount(context),
                    ),
                  ],
                ),
              ),
            ),
            // TODO(IAP): Restore tabIndex: 4 when Rewards tab is re-enabled.
            const BottomNativeAllAd(tabIndex: 3),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40.w,
        height: 4.h,
        margin: EdgeInsets.only(bottom: 14.h),
        decoration: BoxDecoration(
          color: AppColors.textWhite24,
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _StatCell({
    required this.value,
    required this.label,
    this.onTap,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24.h,
      color: AppColors.borderLight,
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final String iconAsset;
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.iconAsset,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.profileTileBg,
      borderRadius: BorderRadius.circular(12.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
          child: Row(
            children: [
              Image.asset(
                iconAsset,
                width: 22.w,
                height: 22.w,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.profileMenuTitle,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.profileChevron,
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color? titleColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool trailingLoading;

  const _ActionMenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
    this.trailingLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.profileTileBg,
      borderRadius: BorderRadius.circular(12.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22.sp),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.profileMenuTitle.copyWith(
                        color: titleColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5.sp,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingLoading)
                SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.profileChevron,
                  size: 20.sp,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackSettingsCard extends StatelessWidget {
  final UserSettings settings;
  final void Function({
    bool? autoPlayNext,
    bool? wifiOnly,
    String? videoQuality,
  }) onChanged;

  const _PlaybackSettingsCard({
    required this.settings,
    required this.onChanged,
  });

  static const List<String> _qualities = ['auto', '1080p', '720p', '480p'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.profileTileBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Playback & Streaming',
            style: AppTextStyles.h3.copyWith(fontSize: 14.sp),
          ),
          SizedBox(height: 8.h),
          _SettingsSwitchRow(
            icon: Icons.skip_next_rounded,
            label: 'Auto-play next episode',
            value: settings.autoPlayNext,
            onChanged: (v) => onChanged(autoPlayNext: v),
          ),
          Divider(color: AppColors.borderLight, height: 12.h),
          _SettingsSwitchRow(
            icon: Icons.wifi_rounded,
            label: 'Stream over Wi-Fi only',
            value: settings.wifiOnly,
            onChanged: (v) => onChanged(wifiOnly: v),
          ),
          Divider(color: AppColors.borderLight, height: 14.h),
          Text(
            'Preferred Video Quality',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: _qualities.map((q) {
              final selected =
                  settings.videoQuality.toLowerCase() == q.toLowerCase();
              return GestureDetector(
                onTap: () => onChanged(videoQuality: q),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color:
                          selected ? AppColors.primary : AppColors.borderLight,
                    ),
                  ),
                  child: Text(
                    q.toUpperCase(),
                    style: TextStyle(
                      color:
                          selected ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 11.5.sp,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textWhite70, size: 20.sp),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.profileMenuTitle.copyWith(fontSize: 13.5.sp),
          ),
        ),
        Switch.adaptive(
          value: value,
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withValues(alpha: 0.45),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _AuthBottomSheet extends ConsumerStatefulWidget {
  final bool initialRegister;
  final ValueChanged<String> onSuccess;

  const _AuthBottomSheet({
    required this.initialRegister,
    required this.onSuccess,
  });

  @override
  ConsumerState<_AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends ConsumerState<_AuthBottomSheet> {
  late bool _isRegister;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _birthYearCtrl = TextEditingController();
  String? _selectedGender;
  bool _obscurePassword = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _isRegister = widget.initialRegister;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _birthYearCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _localError = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _localError = 'Password must be at least 6 characters.');
      return;
    }

    int? birthYear;
    if (_isRegister && _birthYearCtrl.text.trim().isNotEmpty) {
      birthYear = int.tryParse(_birthYearCtrl.text.trim());
      if (birthYear == null || birthYear < 1920 || birthYear > 2020) {
        setState(() => _localError = 'Enter a valid birth year (1920-2020).');
        return;
      }
    }

    setState(() => _localError = null);
    final notifier = ref.read(accountProvider.notifier);
    final ok = _isRegister
        ? await notifier.register(
            email: email,
            password: password,
            displayName:
                _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
            gender: _selectedGender,
            birthYear: birthYear,
          )
        : await notifier.login(email: email, password: password);

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      widget.onSuccess(
        _isRegister ? 'Account created & linked!' : 'Signed in successfully!',
      );
    } else {
      setState(() {
        _localError =
            ref.read(accountProvider).errorMessage ?? 'Authentication failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accState = ref.watch(accountProvider);
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom + AppScreenUtils.bottomSafeInset(context);

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surfaceSheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHandle(),
            Row(
              children: [
                _ModeChip(
                  label: 'Sign In',
                  selected: !_isRegister,
                  onTap: () => setState(() {
                    _isRegister = false;
                    _localError = null;
                  }),
                ),
                SizedBox(width: 8.w),
                _ModeChip(
                  label: 'Create Account',
                  selected: _isRegister,
                  onTap: () => setState(() {
                    _isRegister = true;
                    _localError = null;
                  }),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textWhite60),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _SheetTextField(
              controller: _emailCtrl,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 10.h),
            _SheetTextField(
              controller: _passwordCtrl,
              label: 'Password',
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                  size: 18.sp,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            if (_isRegister) ...[
              SizedBox(height: 10.h),
              _SheetTextField(
                controller: _nameCtrl,
                label: 'Display Name (optional)',
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      dropdownColor: AppColors.surfaceSheet,
                      decoration: _fieldDecoration('Gender (optional)'),
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _selectedGender = v),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _SheetTextField(
                      controller: _birthYearCtrl,
                      label: 'Birth Year',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
            if (_localError != null) ...[
              SizedBox(height: 10.h),
              Text(
                _localError!,
                style: TextStyle(color: AppColors.error, fontSize: 12.sp),
              ),
            ],
            SizedBox(height: 16.h),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: Size(double.infinity, 44.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22.r),
                ),
              ),
              onPressed: accState.isAuthenticating ? null : _submit,
              child: accState.isAuthenticating
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isRegister ? 'Create Account' : 'Sign In',
                      style: AppTextStyles.exploreButtonText,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserProfile? profile;
  final ValueChanged<String> onSaved;

  const _EditProfileSheet({
    required this.profile,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _birthYearCtrl;
  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  String? _gender;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile?.displayName ?? '');
    _birthYearCtrl = TextEditingController(
      text: widget.profile?.birthYear?.toString() ?? '',
    );
    _gender = widget.profile?.gender;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthYearCtrl.dispose();
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    int? birthYear;
    if (_birthYearCtrl.text.trim().isNotEmpty) {
      birthYear = int.tryParse(_birthYearCtrl.text.trim());
      if (birthYear == null || birthYear < 1920 || birthYear > 2020) {
        setState(() => _error = 'Enter a valid birth year (1920-2020).');
        return;
      }
    }
    final curPwd = _currentPwdCtrl.text;
    final newPwd = _newPwdCtrl.text;
    if (newPwd.isNotEmpty && (curPwd.isEmpty || newPwd.length < 6)) {
      setState(
        () => _error = 'Provide current password and new password (6+ chars).',
      );
      return;
    }

    setState(() => _error = null);
    final ok = await ref.read(accountProvider.notifier).updateProfile(
          displayName: _nameCtrl.text.trim(),
          gender: _gender,
          birthYear: birthYear,
          currentPassword: curPwd.isNotEmpty ? curPwd : null,
          newPassword: newPwd.isNotEmpty ? newPwd : null,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      widget.onSaved('Profile updated');
    } else {
      setState(() {
        _error = ref.read(accountProvider).errorMessage ?? 'Update failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accState = ref.watch(accountProvider);
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom + AppScreenUtils.bottomSafeInset(context);

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surfaceSheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHandle(),
            Row(
              children: [
                Text('Edit Profile', style: AppTextStyles.h3),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textWhite60),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            _SheetTextField(controller: _nameCtrl, label: 'Display Name'),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: const ['male', 'female', 'other']
                            .contains(_gender)
                        ? _gender
                        : null,
                    dropdownColor: AppColors.surfaceSheet,
                    decoration: _fieldDecoration('Gender'),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _SheetTextField(
                    controller: _birthYearCtrl,
                    label: 'Birth Year',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Text(
              'Change Password (optional)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
            ),
            SizedBox(height: 8.h),
            _SheetTextField(
              controller: _currentPwdCtrl,
              label: 'Current Password',
              obscureText: true,
            ),
            SizedBox(height: 10.h),
            _SheetTextField(
              controller: _newPwdCtrl,
              label: 'New Password',
              obscureText: true,
            ),
            if (_error != null) ...[
              SizedBox(height: 10.h),
              Text(
                _error!,
                style: TextStyle(color: AppColors.error, fontSize: 12.sp),
              ),
            ],
            SizedBox(height: 16.h),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: Size(double.infinity, 44.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22.r),
                ),
              ),
              onPressed: accState.isLoadingProfile ? null : _save,
              child: accState.isLoadingProfile
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Save Changes', style: AppTextStyles.exploreButtonText),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String label, {Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12.5.sp),
    filled: true,
    fillColor: AppColors.surfaceCard,
    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
    suffixIcon: suffixIcon,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
  );
}

class _SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  const _SheetTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5.sp),
      decoration: _fieldDecoration(label, suffixIcon: suffixIcon),
    );
  }
}
