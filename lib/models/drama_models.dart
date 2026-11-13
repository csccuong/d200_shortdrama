class EpisodeInfo {
  final int episodeNo;
  final String videoFile;
  final bool bundledInAssets;
  final bool isLocked;
  final Map<String, String> subtitles;

  const EpisodeInfo({
    required this.episodeNo,
    required this.videoFile,
    required this.bundledInAssets,
    required this.isLocked,
    required this.subtitles,
  });

  factory EpisodeInfo.fromJson(Map<String, dynamic> json) {
    final rawSubs = json['subtitles'] as Map<String, dynamic>? ?? {};
    return EpisodeInfo(
      episodeNo: (json['episodeNo'] as num?)?.toInt() ?? 1,
      videoFile: json['videoFile'] as String? ?? '',
      bundledInAssets: json['bundledInAssets'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? false,
      subtitles: rawSubs.map((k, v) => MapEntry(k, v.toString())),
    );
  }
}

class Drama {
  final int index;
  final String slug;
  final String dramaId;
  final String title;
  final String description;
  final double score;
  final int viewCount;
  final int releaseYear;
  final int totalEpisodes;
  final int bundledEpisodes;
  final String posterFile;
  final String posterRemoteUrl;
  final List<String> tags;
  final List<EpisodeInfo> episodes;

  const Drama({
    required this.index,
    required this.slug,
    required this.dramaId,
    required this.title,
    required this.description,
    required this.score,
    required this.viewCount,
    required this.releaseYear,
    required this.totalEpisodes,
    required this.bundledEpisodes,
    required this.posterFile,
    required this.posterRemoteUrl,
    required this.tags,
    required this.episodes,
  });

  String get posterAssetPath => '';

  String get formattedViews {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K';
    }
    return viewCount.toString();
  }

  factory Drama.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List<dynamic>? ?? [];
    final rawEps = json['episodes'] as List<dynamic>? ?? [];
    return Drama(
      index: (json['index'] as num?)?.toInt() ?? 0,
      slug: json['slug'] as String? ?? '',
      dramaId: json['dramaId']?.toString() ?? '',
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 9.5,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      releaseYear: (json['releaseYear'] as num?)?.toInt() ?? 2026,
      totalEpisodes: (json['totalEpisodes'] as num?)?.toInt() ?? rawEps.length,
      bundledEpisodes: (json['bundledEpisodes'] as num?)?.toInt() ?? 5,
      posterFile: json['posterFile'] as String? ?? 'poster.jpg',
      posterRemoteUrl: json['posterRemoteUrl'] as String? ?? '',
      tags: rawTags.map((e) => e.toString()).toList(),
      episodes: rawEps
          .map((e) => EpisodeInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });
}
