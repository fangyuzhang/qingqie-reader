/// 阅读进度（一书一行）。
/// offsetValue 语义随阅读模式：滚动模式=滚动像素，分页模式=页码。
class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    this.chapterIndex = 0,
    this.chapterTitle = '',
    this.offsetValue = 0,
    this.percent = 0,
    this.updatedAt = 0,
  });

  final int bookId;
  final int chapterIndex;
  final String chapterTitle;
  final double offsetValue;
  final double percent;
  final int updatedAt;

  Map<String, Object?> toMap() => {
    'book_id': bookId,
    'chapter_index': chapterIndex,
    'chapter_title': chapterTitle,
    'offset_value': offsetValue,
    'percent': percent,
    'updated_at': updatedAt,
  };

  factory ReadingProgress.fromMap(Map<String, Object?> m) => ReadingProgress(
    bookId: m['book_id'] as int,
    chapterIndex: m['chapter_index'] as int? ?? 0,
    chapterTitle: m['chapter_title'] as String? ?? '',
    offsetValue: (m['offset_value'] as num?)?.toDouble() ?? 0,
    percent: (m['percent'] as num?)?.toDouble() ?? 0,
    updatedAt: m['updated_at'] as int? ?? 0,
  );

  ReadingProgress copyWith({
    int? chapterIndex,
    String? chapterTitle,
    double? offsetValue,
    double? percent,
    int? updatedAt,
  }) => ReadingProgress(
    bookId: bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    chapterTitle: chapterTitle ?? this.chapterTitle,
    offsetValue: offsetValue ?? this.offsetValue,
    percent: percent ?? this.percent,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
