import '../../models/drama_card.dart';
import '../../models/episode_detail.dart';

/// Shared helper to determine episode lock status and enforce sequential
/// reward-ad unlocking across the episode grid and vertical player.
class EpisodeUnlockHelper {
  EpisodeUnlockHelper._();

  static Map<int, EpisodeItem> indexByNumber(List<EpisodeItem> episodes) {
    return <int, EpisodeItem>{
      for (final e in episodes) e.episodeNumber: e,
    };
  }

  static bool isEpisodeUnlocked({
    required int episodeNo,
    required DramaCard drama,
    required Map<int, EpisodeItem> episodesByNumber,
    bool isVip = false,
    Set<int> locallyUnlockedEpisodes = const {},
    bool fullDramaUnlocked = false,
  }) {
    if (isVip || fullDramaUnlocked) return true;
    if (locallyUnlockedEpisodes.contains(episodeNo)) return true;
    final item = episodesByNumber[episodeNo];
    if (item != null) {
      return !item.isLocked && (item.isUnlocked || item.isFreeTier);
    }
    return episodeNo <= drama.freeEpisodesCount;
  }

  /// Returns the lowest episode number in `1..totalEpisodes` that is still
  /// locked, or `null` if all episodes are unlocked.
  static int? findFirstLockedEpisode({
    required int totalEpisodes,
    required DramaCard drama,
    required Map<int, EpisodeItem> episodesByNumber,
    bool isVip = false,
    Set<int> locallyUnlockedEpisodes = const {},
    bool fullDramaUnlocked = false,
  }) {
    if (isVip || fullDramaUnlocked) return null;
    for (int ep = 1; ep <= totalEpisodes; ep++) {
      if (!isEpisodeUnlocked(
        episodeNo: ep,
        drama: drama,
        episodesByNumber: episodesByNumber,
        isVip: isVip,
        locallyUnlockedEpisodes: locallyUnlockedEpisodes,
        fullDramaUnlocked: fullDramaUnlocked,
      )) {
        return ep;
      }
    }
    return null;
  }
}
