/// 书籍来源：本地导入 / 书源网络。
enum BookOrigin { local, network }

/// 书籍格式。
enum BookFormat { txt, epub, web }

/// 书架中的一本书（本地与网络书共用一张表，见 docs/03）。
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.intro,
    required this.origin,
    required this.format,
    this.coverPath,
    this.localPath,
    this.sourceId,
    this.bookUrl,
    this.categoryId = 1,
    this.chapterCount = 0,
    this.tocJson,
    this.addedAt = 0,
    this.lastReadAt = 0,
  });

  final int id;
  final String title;
  final String author;
  final String intro;
  final BookOrigin origin;
  final BookFormat format;
  final String? coverPath; // EPUB 解出的封面文件路径
  final String? localPath; // 本地原文件路径（仅本地书）
  final int? sourceId; // 书源 id（仅网络书）
  final String? bookUrl; // 详情页 URL（仅网络书）
  final int categoryId;
  final int chapterCount;
  final String? tocJson; // 网络书目录缓存（JSON 数组）
  final int addedAt;
  final int lastReadAt;

  bool get isLocal => origin == BookOrigin.local;

  static BookOrigin originFromName(String v) =>
      v == 'local' ? BookOrigin.local : BookOrigin.network;

  static BookFormat formatFromName(String v) => switch (v) {
    'txt' => BookFormat.txt,
    'epub' => BookFormat.epub,
    _ => BookFormat.web,
  };

  static String originName(BookOrigin v) => v == BookOrigin.local ? 'local' : 'network';

  static String formatName(BookFormat v) => switch (v) {
    BookFormat.txt => 'txt',
    BookFormat.epub => 'epub',
    BookFormat.web => 'web',
  };

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'author': author,
    'intro': intro,
    'cover_path': coverPath,
    'origin': originName(origin),
    'format': formatName(format),
    'local_path': localPath,
    'source_id': sourceId,
    'book_url': bookUrl,
    'category_id': categoryId,
    'chapter_count': chapterCount,
    'toc_json': tocJson,
    'added_at': addedAt,
    'last_read_at': lastReadAt,
  };

  factory Book.fromMap(Map<String, Object?> m) => Book(
    id: m['id'] as int,
    title: m['title'] as String? ?? '',
    author: m['author'] as String? ?? '',
    intro: m['intro'] as String? ?? '',
    coverPath: m['cover_path'] as String?,
    origin: originFromName(m['origin'] as String? ?? 'local'),
    format: formatFromName(m['format'] as String? ?? 'txt'),
    localPath: m['local_path'] as String?,
    sourceId: m['source_id'] as int?,
    bookUrl: m['book_url'] as String?,
    categoryId: m['category_id'] as int? ?? 1,
    chapterCount: m['chapter_count'] as int? ?? 0,
    tocJson: m['toc_json'] as String?,
    addedAt: m['added_at'] as int? ?? 0,
    lastReadAt: m['last_read_at'] as int? ?? 0,
  );

  Book copyWith({
    String? title,
    String? author,
    String? intro,
    String? coverPath,
    int? categoryId,
    int? chapterCount,
    String? tocJson,
    int? lastReadAt,
  }) => Book(
    id: id,
    title: title ?? this.title,
    author: author ?? this.author,
    intro: intro ?? this.intro,
    origin: origin,
    format: format,
    coverPath: coverPath ?? this.coverPath,
    localPath: localPath,
    sourceId: sourceId,
    bookUrl: bookUrl,
    categoryId: categoryId ?? this.categoryId,
    chapterCount: chapterCount ?? this.chapterCount,
    tocJson: tocJson ?? this.tocJson,
    addedAt: addedAt,
    lastReadAt: lastReadAt ?? this.lastReadAt,
  );
}
