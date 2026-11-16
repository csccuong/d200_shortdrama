import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Matches [event] to an active fullscreen ad route by [expectedType] and its
/// raw/resolved ad unit IDs. Falls back cleanly if an event carries no ID.
bool isMatchingFullscreenAdEvent(
  AdEvent event, {
  required AdUnitType expectedType,
  required String rawAdId,
  required String resolvedId,
  String? currentAdUnitId,
}) {
  if (event.adUnitType != expectedType) return false;
  final eventUnitId = event.adUnitId;
  if (eventUnitId == null || eventUnitId.isEmpty) {
    return true;
  }
  return eventUnitId == rawAdId ||
      eventUnitId == resolvedId ||
      (currentAdUnitId != null && eventUnitId == currentAdUnitId);
}

/// Shared modal loading indicator shown while an interstitial or rewarded ad
/// is fetched on demand.
class EasyFullscreenAdLoadingCard extends StatelessWidget {
  const EasyFullscreenAdLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: const Color(0xE614151C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0x1FFFFFFF),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Lottie.asset(
                    'assets/json/loading_ads.json',
                    package: 'easy_ads_flutter',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Lottie.asset(
                        'assets/json/loading_ads.json',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Loading Ads...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
