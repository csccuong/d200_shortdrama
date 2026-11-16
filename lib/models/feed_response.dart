import 'drama_card.dart';
import 'play_response.dart';
import 'stream_bundle.dart';

/// Preview info embedded in each For You feed item.
class PreviewInfo {
  final int episodeNumber;
  final int durationSec;
  final bool hasStream;
  final String videoUrl;
  final List<SubtitleTrack> subtitles;
  final int expiresInSec;
  final int? expiresAt;
  final DateTime expireAt;
  final bool watchFullDramaCta;
  final int watchFullDramaTargetEpisode;

  int get streamExpiresIn => expiresInSec;

  bool get isStreamExpired => DateTime.now().isAfter(expireAt);

  PreviewInfo({
    this.episodeNumber = 1,
    this.durationSec = 0,
    this.hasStream = true,
    this.videoUrl = '',
    this.subtitles = const [],
    int? expiresInSec,
    int streamExpiresIn = StreamBundle.defaultForYouTtlSec,
    this.expiresAt,
    DateTime? expireAt,
    this.watchFullDramaCta = false,
    this.watchFullDramaTargetEpisode = 1,
  })  : expiresInSec = expiresInSec ?? streamExpiresIn,
        expireAt = expireAt ??
            StreamBundle.computeSafeExpireAt(expiresInSec ?? streamExpiresIn);

  StreamBundle toStreamBundle() => StreamBundle(
        videoUrl: videoUrl,
        subtitles: subtitles,
        expiresInSec: expiresInSec,
        expiresAt: expiresAt,
        expireAt: expireAt,
      );

  factory PreviewInfo.fromJson(Map<String, dynamic> json) {
    final videoUrl = json['video_url']?.toString() ?? '';
    final ttl = StreamBundle.parseTtlSec(
      json,
      defaultTtlSec: StreamBundle.defaultForYouTtlSec,
    );
    return PreviewInfo(
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 1,
      durationSec: (json['duration_sec'] as num?)?.toInt() ?? 0,
      hasStream: json['has_stream'] as bool? ?? videoUrl.isNotEmpty,
      videoUrl: videoUrl,
      subtitles: (json['subtitles'] as List<dynamic>?)
              ?.whereType<Map<dynamic, dynamic>>()
              .map(
                (e) => SubtitleTrack.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const [],
      expiresInSec: ttl,
      expiresAt: StreamBundle.parseExpiresAtUnix(json),
      expireAt: StreamBundle.computeSafeExpireAt(ttl),
      watchFullDramaCta:
          json['watch_full_drama_cta'] as bool? ?? false,
      watchFullDramaTargetEpisode:
          (json['watch_full_drama_target_episode'] as num?)?.toInt() ?? 1,
    );
  }
}

/// A DramaCard extended with a preview for the For You vertical feed.
class ForYouItem extends DramaCard {
  final PreviewInfo? preview;

  bool get isStreamExpired => preview?.isStreamExpired ?? false;

  ForYouItem({
    super.id,
    required super.dramaId,
    required super.title,
    super.description,
    super.coverUrl,
    super.language,
    super.category,
    super.categorySlug,
    super.totalEpisodes,
    super.readyEpisodes,
    super.isCompleted,
    super.isVip,
    super.freeEpisodesCount,
    super.unlockCoinCost,
    super.popularity,
    super.rating,
    super.trendingRank,
    super.viewCount,
    super.favoriteCount,
    super.watchLaterCount,
    super.likeCount,
    super.shareCount,
    super.originCountry,
    super.countryName,
    super.countryFlag,
    super.region,
    super.audioMode,
    super.audience,
    super.availableSubLangs,
    super.hasRequestedSub,
    super.categories,
    super.tags,
    super.isFavorited,
    super.inMyList,
    super.isInWatchLater,
    super.isLiked,
    super.continueWatching,
    this.preview,
  });

  factory ForYouItem.fromJson(Map<String, dynamic> json) {
    final base = DramaCard.fromJson(json);
    return ForYouItem(
      id: base.id,
      dramaId: base.dramaId,
      title: base.title,
      description: base.description,
      coverUrl: base.coverUrl,
      language: base.language,
      category: base.category,
      categorySlug: base.categorySlug,
      totalEpisodes: base.totalEpisodes,
      readyEpisodes: base.readyEpisodes,
      isCompleted: base.isCompleted,
      isVip: base.isVip,
      freeEpisodesCount: base.freeEpisodesCount,
      unlockCoinCost: base.unlockCoinCost,
      popularity: base.popularity,
      rating: base.rating,
      trendingRank: base.trendingRank,
      viewCount: base.viewCount,
      favoriteCount: base.favoriteCount,
      watchLaterCount: base.watchLaterCount,
      likeCount: base.likeCount,
      shareCount: base.shareCount,
      originCountry: base.originCountry,
      countryName: base.countryName,
      countryFlag: base.countryFlag,
      region: base.region,
      audioMode: base.audioMode,
      audience: base.audience,
      availableSubLangs: base.availableSubLangs,
      hasRequestedSub: base.hasRequestedSub,
      categories: base.categories,
      tags: base.tags,
      isFavorited: base.isFavorited,
      inMyList: base.inMyList,
      isInWatchLater: base.isInWatchLater,
      isLiked: base.isLiked,
      continueWatching: base.continueWatching,
      preview: json['preview'] != null
          ? PreviewInfo.fromJson(
              json['preview'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Full response for GET /v1/feed/for-you.
class FeedResponse {
  final List<ForYouItem> items;
  final String cohort;
  final String nextCursor;
  final bool hasMore;

  FeedResponse({
    this.items = const [],
    this.cohort = '',
    this.nextCursor = '',
    this.hasMore = false,
  });

  factory FeedResponse.fromJson(Map<String, dynamic> json) {
    return FeedResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) =>
                  ForYouItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      cohort: json['cohort'] as String? ?? '',
      nextCursor: json['next_cursor'] as String? ?? '',
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}
