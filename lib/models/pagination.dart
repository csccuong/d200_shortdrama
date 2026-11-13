/// Page-based pagination used by most list endpoints.
class Pagination {
  final int page;
  final int pageSize;
  final int total;
  final bool hasMore;

  Pagination({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasMore,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

/// Cursor-based pagination used by the For You feed.
class CursorPagination {
  final String nextCursor;
  final bool hasMore;

  CursorPagination({
    required this.nextCursor,
    required this.hasMore,
  });

  factory CursorPagination.fromJson(Map<String, dynamic> json) {
    return CursorPagination(
      nextCursor: json['next_cursor'] as String? ?? '',
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}
