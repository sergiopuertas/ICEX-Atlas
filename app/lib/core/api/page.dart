/// Página de una lista paginada por cursor (keyset). `nextCursor == null` → no hay más.
class CursorPage<T> {
  const CursorPage({required this.items, this.nextCursor, this.total});

  factory CursorPage.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) =>
      CursorPage(
        items: (json['items'] as List? ?? const [])
            .map((e) => parse(Map<String, dynamic>.from(e as Map)))
            .toList(),
        nextCursor: json['next_cursor'] as String?,
        total: (json['total'] as num?)?.toInt(),
      );

  final List<T> items;
  final String? nextCursor;
  final int? total;

  bool get hasMore => nextCursor != null;

  CursorPage<T> append(CursorPage<T> next) => CursorPage(
    items: [...items, ...next.items],
    nextCursor: next.nextCursor,
    total: next.total ?? total,
  );
}
