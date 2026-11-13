import 'drama_card.dart';
import 'pagination.dart';

/// A category section shelf on the home screen (e.g., "Billionaire & CEO").
class CategorySection {
  final String slug;
  final String title;
  final String icon;
  final List<DramaCard> items;

  CategorySection({
    required this.slug,
    this.title = '',
    this.icon = '',
    this.items = const [],
  });

  factory CategorySection.fromJson(Map<String, dynamic> json) {
    return CategorySection(
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) =>
                  DramaCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Full response for GET /v1/home — the super-aggregated home screen API.
class HomeResponse {
  final List<DramaCard> banners;
  final List<DramaCard> continueWatching;
  final List<DramaCard> trending;
  final List<DramaCard> mostViewed;
  final List<DramaCard> mostFavorited;
  final List<DramaCard> recommended;
  final Pagination? recommendedPagination;
  final List<DramaCard> newReleases;
  final List<DramaCard> vipExclusive;
  final List<Map<String, dynamic>> categories;
  final List<CategorySection> categorySections;

  HomeResponse({
    this.banners = const [],
    this.continueWatching = const [],
    this.trending = const [],
    this.mostViewed = const [],
    this.mostFavorited = const [],
    this.recommended = const [],
    this.recommendedPagination,
    this.newReleases = const [],
    this.vipExclusive = const [],
    this.categories = const [],
    this.categorySections = const [],
  });

  factory HomeResponse.fromJson(Map<String, dynamic> json) {
    List<DramaCard> parseCards(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => DramaCard.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return HomeResponse(
      banners: parseCards(json['banners']),
      continueWatching: parseCards(json['continue_watching']),
      trending: parseCards(json['trending']),
      mostViewed: parseCards(json['most_viewed']),
      mostFavorited: parseCards(json['most_favorited']),
      recommended: parseCards(json['recommended']),
      recommendedPagination: json['recommended_pagination'] != null
          ? Pagination.fromJson(
              json['recommended_pagination'] as Map<String, dynamic>)
          : null,
      newReleases: parseCards(json['new_releases']),
      vipExclusive: parseCards(json['vip_exclusive']),
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
      categorySections: (json['category_sections'] as List<dynamic>?)
              ?.map((e) =>
                  CategorySection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
