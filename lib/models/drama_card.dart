/// Standardized drama card model matching EXACTLY the JSON from API spec Section 4.
///
/// Every list endpoint (`/v1/home`, `/v1/dramas`, `/v1/feed/for-you`, etc.)
/// returns this same shape so the app only needs one `DramaCard.fromJson()`.
class DramaCategory {
  final String slug;
  final String name;
  final String icon;
  final bool isPrimary;

  DramaCategory({
    required this.slug,
    required this.name,
    this.icon = '',
    this.isPrimary = false,
  });

  factory DramaCategory.fromJson(Map<String, dynamic> json) {
    return DramaCategory(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

class DramaTag {
  final String slug;
  final String name;

  DramaTag({required this.slug, required this.name});

  factory DramaTag.fromJson(Map<String, dynamic> json) {
    return DramaTag(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class ContinueWatchingInfo {
  final int episodeNumber;
  final int positionSec;
  final int durationSec;
  final int percentWatched;

  ContinueWatchingInfo({
    required this.episodeNumber,
    required this.positionSec,
    required this.durationSec,
    required this.percentWatched,
  });

  factory ContinueWatchingInfo.fromJson(Map<String, dynamic> json) {
    return ContinueWatchingInfo(
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
      positionSec: (json['position_sec'] as num?)?.toInt() ?? 0,
      durationSec: (json['duration_sec'] as num?)?.toInt() ?? 0,
      percentWatched: (json['percent_watched'] as num?)?.round() ?? 0,
    );
  }
}

class DramaCard {
  final String id;
  final String dramaId;
  final String title;
  final String description;
  final String coverUrl;
  final String language;
  final String category;
  final String categorySlug;
  final int totalEpisodes;
  final int readyEpisodes;
  final bool isCompleted;
  final bool isVip;
  final int freeEpisodesCount;
  final int unlockCoinCost;
  final int popularity;
  final double rating;
  final int? trendingRank;
  final int viewCount;
  final int favoriteCount;
  final int watchLaterCount;
  final int likeCount;
  final int shareCount;
  final String originCountry;
  final String countryName;
  final String countryFlag;
  final String region;
  final String audioMode;
  final String audience;
  final List<String> availableSubLangs;
  final bool hasRequestedSub;
  final List<DramaCategory> categories;
  final List<DramaTag> tags;
  final bool isFavorited;
  final bool inMyList;
  final bool isInWatchLater;
  final bool isLiked;
  final ContinueWatchingInfo? continueWatching;

  ContinueWatchingInfo? get watchProgress => continueWatching;

  DramaCard({
    String? id,
    required this.dramaId,
    required this.title,
    this.description = '',
    this.coverUrl = '',
    this.language = '',
    this.category = '',
    this.categorySlug = '',
    this.totalEpisodes = 0,
    this.readyEpisodes = 0,
    this.isCompleted = false,
    this.isVip = false,
    this.freeEpisodesCount = 0,
    this.unlockCoinCost = 0,
    this.popularity = 0,
    this.rating = 0.0,
    this.trendingRank,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.watchLaterCount = 0,
    this.likeCount = 0,
    this.shareCount = 0,
    this.originCountry = '',
    this.countryName = '',
    this.countryFlag = '',
    this.region = '',
    this.audioMode = '',
    this.audience = '',
    this.availableSubLangs = const [],
    this.hasRequestedSub = false,
    this.categories = const [],
    this.tags = const [],
    this.isFavorited = false,
    this.inMyList = false,
    this.isInWatchLater = false,
    this.isLiked = false,
    ContinueWatchingInfo? continueWatching,
    ContinueWatchingInfo? watchProgress,
  })  : id = id ?? dramaId,
        continueWatching = continueWatching ?? watchProgress;

  DramaCard copyWith({
    String? id,
    String? dramaId,
    String? title,
    String? description,
    String? coverUrl,
    String? language,
    String? category,
    String? categorySlug,
    int? totalEpisodes,
    int? readyEpisodes,
    bool? isCompleted,
    bool? isVip,
    int? freeEpisodesCount,
    int? unlockCoinCost,
    int? popularity,
    double? rating,
    int? trendingRank,
    int? viewCount,
    int? favoriteCount,
    int? watchLaterCount,
    int? likeCount,
    int? shareCount,
    String? originCountry,
    String? countryName,
    String? countryFlag,
    String? region,
    String? audioMode,
    String? audience,
    List<String>? availableSubLangs,
    bool? hasRequestedSub,
    List<DramaCategory>? categories,
    List<DramaTag>? tags,
    bool? isFavorited,
    bool? inMyList,
    bool? isInWatchLater,
    bool? isLiked,
    ContinueWatchingInfo? continueWatching,
  }) {
    return DramaCard(
      id: id ?? this.id,
      dramaId: dramaId ?? this.dramaId,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      language: language ?? this.language,
      category: category ?? this.category,
      categorySlug: categorySlug ?? this.categorySlug,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      readyEpisodes: readyEpisodes ?? this.readyEpisodes,
      isCompleted: isCompleted ?? this.isCompleted,
      isVip: isVip ?? this.isVip,
      freeEpisodesCount: freeEpisodesCount ?? this.freeEpisodesCount,
      unlockCoinCost: unlockCoinCost ?? this.unlockCoinCost,
      popularity: popularity ?? this.popularity,
      rating: rating ?? this.rating,
      trendingRank: trendingRank ?? this.trendingRank,
      viewCount: viewCount ?? this.viewCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      watchLaterCount: watchLaterCount ?? this.watchLaterCount,
      likeCount: likeCount ?? this.likeCount,
      shareCount: shareCount ?? this.shareCount,
      originCountry: originCountry ?? this.originCountry,
      countryName: countryName ?? this.countryName,
      countryFlag: countryFlag ?? this.countryFlag,
      region: region ?? this.region,
      audioMode: audioMode ?? this.audioMode,
      audience: audience ?? this.audience,
      availableSubLangs: availableSubLangs ?? this.availableSubLangs,
      hasRequestedSub: hasRequestedSub ?? this.hasRequestedSub,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      isFavorited: isFavorited ?? this.isFavorited,
      inMyList: inMyList ?? this.inMyList,
      isInWatchLater: isInWatchLater ?? this.isInWatchLater,
      isLiked: isLiked ?? this.isLiked,
      continueWatching: continueWatching ?? this.continueWatching,
    );
  }

  factory DramaCard.fromJson(Map<String, dynamic> json) {
    final resolvedId = (json['id'] ?? json['drama_id'])?.toString() ?? '';
    final resolvedDramaId = (json['drama_id'] ?? json['id'])?.toString() ?? '';
    final rawProgress = json['watch_progress'] ?? json['continue_watching'];

    return DramaCard(
      id: resolvedId,
      dramaId: resolvedDramaId,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      coverUrl: (json['thumbnail'] ?? json['cover_url']) as String? ?? '',
      language: json['language'] as String? ?? '',
      category: json['category'] as String? ?? '',
      categorySlug: json['category_slug'] as String? ?? '',
      totalEpisodes: (json['total_episodes'] as num?)?.toInt() ?? 0,
      readyEpisodes: (json['ready_episodes'] as num?)?.toInt() ?? 0,
      isCompleted: (json['complete'] ?? json['is_completed']) as bool? ?? false,
      isVip: (json['is_vip_exclusive'] ?? json['is_vip']) as bool? ?? false,
      freeEpisodesCount:
          ((json['free_episodes'] ?? json['free_episodes_count']) as num?)
                  ?.toInt() ??
              0,
      unlockCoinCost: (json['unlock_coin_cost'] as num?)?.toInt() ?? 0,
      popularity: (json['popularity'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      trendingRank:
          ((json['trending_rank'] ?? json['rank']) as num?)?.toInt(),
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      favoriteCount: (json['favorite_count'] as num?)?.toInt() ?? 0,
      watchLaterCount: (json['watch_later_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      shareCount: (json['share_count'] as num?)?.toInt() ?? 0,
      originCountry: json['origin_country'] as String? ?? '',
      countryName: json['country_name'] as String? ?? '',
      countryFlag: json['country_flag'] as String? ?? '',
      region: json['region'] as String? ?? '',
      audioMode: json['audio_mode'] as String? ?? '',
      audience: json['audience'] as String? ?? '',
      availableSubLangs: (json['available_sub_langs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      hasRequestedSub: json['has_requested_sub'] as bool? ?? false,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) =>
                  DramaCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => DramaTag.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isFavorited: json['is_favorited'] as bool? ?? false,
      inMyList:
          (json['is_in_my_list'] ?? json['in_my_list']) as bool? ?? false,
      isInWatchLater: json['is_in_watch_later'] as bool? ?? false,
      isLiked: json['is_liked'] as bool? ?? false,
      continueWatching: rawProgress is Map<String, dynamic>
          ? ContinueWatchingInfo.fromJson(rawProgress)
          : null,
    );
  }
}
