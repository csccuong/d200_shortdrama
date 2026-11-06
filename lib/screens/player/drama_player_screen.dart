import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ads/const/ad_id_extension.dart';
import '../../ads/const/ad_id_name.dart';
import '../../ads/nativefull/native_full_screen.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/screen_utils.dart';
import '../../models/drama_models.dart';
import '../../providers/app_providers.dart';
import '../../services/firebase_remote_config_service.dart';
import '../../widgets/episode_selector_sheet.dart';
import '../../widgets/floating_drama_native_ad.dart';
import '../../widgets/player_settings_sheet.dart';
import '../../widgets/short_video_item.dart';

class DramaPlayerScreen extends ConsumerStatefulWidget {
  final Drama drama;
  final int initialEpisode;

  const DramaPlayerScreen({
    super.key,
    required this.drama,
    this.initialEpisode = 1,
  });

  @override
  ConsumerState<DramaPlayerScreen> createState() => _DramaPlayerScreenState();
}

class _DramaPlayerScreenState extends ConsumerState<DramaPlayerScreen> {
  static const int _nativeFullEveryEpisodes = 2;

  late PageController _pageController;
  late int _currentEpisode;
  int _episodeChangesSinceNativeFull = 0;
  bool _nativeFullOpen = false;

  @override
  void initState() {
    super.initState();
    _currentEpisode =
        widget.initialEpisode.clamp(1, widget.drama.totalEpisodes);
    _pageController = PageController(initialPage: _currentEpisode - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(watchlistProvider.notifier)
            .recordWatchHistory(widget.drama.slug, _currentEpisode);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToEpisode(int epNo) {
    final target = epNo.clamp(1, widget.drama.totalEpisodes);
    setState(() {
      _currentEpisode = target;
    });
    _pageController.jumpToPage(target - 1);
  }

  Future<void> _openEpisodeSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => EpisodeSelectorSheet(
        drama: widget.drama,
        currentEpisode: _currentEpisode,
        onSelectEpisode: _jumpToEpisode,
      ),
    );
  }

  bool get _canShowNativeFull {
    if (!AppConstants.isMobilePlatform) return false;
    if (AppConstants.isPremiumUser.value || ref.read(userWalletProvider).isVip) {
      return false;
    }
    if (!FirebaseRemoteConfigService.getBoolConfigByKey(
      FirebaseRemoteConfigService.native_full,
    )) {
      return false;
    }
    final adId = MyAdIdName.nativeFull.getId;
    return adId.isNotEmpty && adId != 'null';
  }

  void _onEpisodeChanged() {
    if (_nativeFullOpen || !_canShowNativeFull) return;
    _episodeChangesSinceNativeFull++;
    if (_episodeChangesSinceNativeFull < _nativeFullEveryEpisodes) return;
    _episodeChangesSinceNativeFull = 0;
    _nativeFullOpen = true;
    setState(() {});
    _presentNativeFull();
  }

  Future<void> _presentNativeFull() async {
    final navigator = Navigator.of(context);
    await navigator.push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (routeContext, _, _) {
          return NativeFullScreen(
            nativeFullId: MyAdIdName.nativeFull.getId,
            adIdName: MyAdIdName.nativeFull,
            handleNavigate: () {
              final routeNav = Navigator.of(routeContext);
              if (routeNav.canPop()) routeNav.pop();
            },
          );
        },
      ),
    );
    _nativeFullOpen = false;
    if (mounted) setState(() {});
  }

  void _onVideoEnded() {
    final autoPlay = ref.read(userWalletProvider).autoPlayNext;
    if (autoPlay && _currentEpisode < widget.drama.totalEpisodes) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: AppScreenUtils.adaptiveScrollPhysics,
            itemCount: widget.drama.totalEpisodes,
            onPageChanged: (index) {
              setState(() {
                _currentEpisode = index + 1;
              });
              ref
                  .read(watchlistProvider.notifier)
                  .recordWatchHistory(widget.drama.slug, _currentEpisode);
              _onEpisodeChanged();
            },
            itemBuilder: (context, index) {
              final epNo = index + 1;
              return ShortVideoItem(
                drama: widget.drama,
                episodeNo: epNo,
                isActive: _currentEpisode == epNo && !_nativeFullOpen,
                onVideoEnded: _onVideoEnded,
                onOpenEpisodeList: _openEpisodeSheet,
                showFullDramaButton: false,
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      AppScreenUtils.isIOS
                          ? Icons.arrow_back_ios_new_rounded
                          : Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                      size: 20.sp,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.dramaTitle(widget.drama),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.playerHeaderTitle,
                        ),
                        Text(
                          '${locale.tr('episode_prefix')} $_currentEpisode / ${widget.drama.totalEpisodes}',
                          style: AppTextStyles.playerHeaderSubtitle,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openEpisodeSheet,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.overlayMedium,
                      foregroundColor: AppColors.textPrimary,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                    ),
                    icon: Icon(Icons.list_rounded, size: 17.sp),
                    label: Text(
                      locale.tr('select_episode'),
                      style: AppTextStyles.buttonMedium,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  GestureDetector(
                    onTap: () => PlayerSettingsSheet.show(context),
                    child: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: const BoxDecoration(
                        color: AppColors.overlayMedium,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: AppColors.textPrimary,
                        size: 19.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
          FloatingDramaNativeAd(
            dramaSlug: widget.drama.slug,
            episodeNo: _currentEpisode,
            hold: _nativeFullOpen,
          ),
        ],
      ),
    );
  }
}
