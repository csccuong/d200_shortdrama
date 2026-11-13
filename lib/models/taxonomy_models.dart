/// A master category (e.g., "Billionaire & CEO").
class CategoryInfo {
  final String slug;
  final String name;
  final String icon;
  final int count;

  CategoryInfo({
    required this.slug,
    required this.name,
    this.icon = '',
    this.count = 0,
  });

  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    return CategoryInfo(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

/// A sub-tag (e.g., "#Mafia").
class TagInfo {
  final String slug;
  final String name;

  TagInfo({required this.slug, required this.name});

  factory TagInfo.fromJson(Map<String, dynamic> json) {
    return TagInfo(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

/// Country facet for the filter bottom sheet.
class FacetCountry {
  final String code;
  final String name;
  final String flag;
  final int count;

  FacetCountry({
    required this.code,
    required this.name,
    this.flag = '',
    this.count = 0,
  });

  factory FacetCountry.fromJson(Map<String, dynamic> json) {
    return FacetCountry(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      flag: json['flag'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

/// Region facet (asia / western / other).
class FacetRegion {
  final String code;
  final String name;
  final int count;

  FacetRegion({
    required this.code,
    required this.name,
    this.count = 0,
  });

  factory FacetRegion.fromJson(Map<String, dynamic> json) {
    return FacetRegion(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

/// Audio mode facet (subtitles / dubbed / hardsub).
class FacetAudioMode {
  final String code;
  final String name;
  final int count;

  FacetAudioMode({
    required this.code,
    required this.name,
    this.count = 0,
  });

  factory FacetAudioMode.fromJson(Map<String, dynamic> json) {
    return FacetAudioMode(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

/// Sort option facet.
class FacetSort {
  final String code;
  final String name;

  FacetSort({required this.code, required this.name});

  factory FacetSort.fromJson(Map<String, dynamic> json) {
    return FacetSort(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

/// Aggregated filter facets from /v1/app/init → taxonomy.facets.
class TaxonomyFacets {
  final List<FacetCountry> countries;
  final List<FacetRegion> regions;
  final List<FacetAudioMode> audioModes;
  final List<FacetSort> sorts;

  TaxonomyFacets({
    this.countries = const [],
    this.regions = const [],
    this.audioModes = const [],
    this.sorts = const [],
  });

  factory TaxonomyFacets.fromJson(Map<String, dynamic> json) {
    return TaxonomyFacets(
      countries: (json['countries'] as List<dynamic>?)
              ?.map((e) =>
                  FacetCountry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      regions: (json['regions'] as List<dynamic>?)
              ?.map((e) =>
                  FacetRegion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      audioModes: (json['audio_modes'] as List<dynamic>?)
              ?.map((e) =>
                  FacetAudioMode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      sorts: (json['sorts'] as List<dynamic>?)
              ?.map(
                  (e) => FacetSort.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Full taxonomy from /v1/app/init → taxonomy.
class Taxonomy {
  final List<CategoryInfo> categories;
  final List<TagInfo> tags;
  final TaxonomyFacets facets;

  Taxonomy({
    this.categories = const [],
    this.tags = const [],
    TaxonomyFacets? facets,
  }) : facets = facets ?? TaxonomyFacets();

  factory Taxonomy.fromJson(Map<String, dynamic> json) {
    return Taxonomy(
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) =>
                  CategoryInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tags: (json['tags'] as List<dynamic>?)
              ?.map(
                  (e) => TagInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      facets: json['facets'] != null
          ? TaxonomyFacets.fromJson(
              json['facets'] as Map<String, dynamic>)
          : null,
    );
  }
}
