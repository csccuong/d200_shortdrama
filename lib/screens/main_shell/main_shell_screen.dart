import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ads/placement/show_placement_ad.dart';
import '../../core/utils/screen_utils.dart';
import '../../providers/app_providers.dart';
import '../../widgets/exit_app_dialog.dart';
import '../../widgets/home_collapsible_ad.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../rewards/rewards_screen.dart';
import '../shorts/shorts_feed_screen.dart';
import '../watchlist/watchlist_screen.dart';

class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(shellTabIndexProvider);
    final locale = ref.watch(localeProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        FocusManager.instance.primaryFocus?.unfocus();
        if (currentIndex != 0) {
          ref.read(shellTabIndexProvider.notifier).setTab(0);
          return;
        }
        final shouldExit = await ExitAppDialog.show(context);
        if (shouldExit) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: HomeCollapsibleAd(
          isActive: currentIndex == 0,
          body: IndexedStack(
            key: const ValueKey('riverpod_indexed_stack_5tabs'),
            index: currentIndex,
            children: [
              const HomeScreen(key: ValueKey('tab_0_home')),
              ShortsFeedScreen(
                key: const ValueKey('tab_1_foryou'),
                isTabActive: currentIndex == 1,
              ),
              const WatchlistScreen(key: ValueKey('tab_2_mylist')),
              const RewardsScreen(key: ValueKey('tab_3_rewards')),
              const ProfileScreen(key: ValueKey('tab_4_profile')),
            ],
          ),
          navigationBar: _FiveTabBottomBar(
            currentIndex: currentIndex,
            locale: locale,
            onTap: (idx) {
              FocusManager.instance.primaryFocus?.unfocus();
              if (idx == currentIndex) return;
              showInterAllThen(context, ref, () {
                ref.read(shellTabIndexProvider.notifier).setTab(idx);
              });
            },
          ),
        ),
      ),
    );
  }
}

class _FiveTabBottomBar extends StatelessWidget {
  final int currentIndex;
  final LocaleState locale;
  final ValueChanged<int> onTap;

  const _FiveTabBottomBar({
    required this.currentIndex,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        inactiveAsset: 'assets/icons/ic_nav_home.png',
        activeAsset: 'assets/icons/ic_nav_home_selected.png',
        label: locale.tr('nav_home'),
      ),
      (
        inactiveAsset: 'assets/icons/ic_nav_foryou.png',
        activeAsset: 'assets/icons/ic_nav_foryou_selected.png',
        label: locale.tr('nav_shorts'),
      ),
      (
        inactiveAsset: 'assets/icons/ic_nav_mylist.png',
        activeAsset: 'assets/icons/ic_nav_mylist_selected.png',
        label: locale.tr('nav_watchlist'),
      ),
      (
        inactiveAsset: 'assets/icons/ic_nav_rewards.png',
        activeAsset: 'assets/icons/ic_nav_rewards_selected.png',
        label: locale.tr('nav_rewards'),
      ),
      (
        inactiveAsset: 'assets/icons/ic_nav_profile.png',
        activeAsset: 'assets/icons/ic_nav_profile_selected.png',
        label: locale.tr('nav_profile'),
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bottomBarBg,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.6),
        ),
      ),
      child: SizedBox(
        height: 58.h.clamp(56.0, 68.0),
        child: Row(
          children: List.generate(items.length, (idx) {
            final item = items[idx];
            final isSelected = idx == currentIndex;
            final iconSize = 23.r.clamp(19.0, 26.0);

            return Expanded(
              child: InkWell(
                onTap: () => onTap(idx),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      isSelected ? item.activeAsset : item.inactiveAsset,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    SizedBox(height: 4.h.clamp(2.0, 5.0)),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bottomNavLabel(
                        isSelected: isSelected,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
