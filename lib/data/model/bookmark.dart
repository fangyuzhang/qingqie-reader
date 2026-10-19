/// 书签（一书多签，记录章节与摘录）。
class Bookmark {
  const Bookmark({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.excerpt,
    this.offsetValue = 0,
    this.createdAt = 0,
  });

  final int? id;
  final int bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String excerpt; // 书签所在段落前的一段文字，便于识别
  final double offsetValue;
  final int createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'book_id': bookId,
    'chapter_index': chapterIndex,
    'chapter_title': chapterTitle,
    'excerpt': excerpt,
    'offset_value': offsetValue,
    'created_at': createdAt,
  };

  factory Bookmark.fromMap(Map<String, Object?> m) => Bookmark(
    id: m['id'] as int?,
    bookId: m['book_id'] as int,
    chapterIndex: m['chapter_index'] as int? ?? 0,
    chapterTitle: m['chapter_title'] as String? ?? '',
    excerpt: m['excerpt'] as String? ?? '',
    offsetValue: (m['offset_value'] as num?)?.toDouble() ?? 0,
    createdAt: m['created_at'] as int? ?? 0,
  );
}
