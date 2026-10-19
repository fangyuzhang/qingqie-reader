/// 笔记类型：划线 / 批注 / 书摘（对齐蜗牛读书交互，见 HTML 原型验证结论）。
enum NoteType { mark, annot, excerpt }

/// 一条笔记（划线/批注/书摘）。
class Note {
  const Note({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.type,
    this.color = 'yellow',
    required this.text,
    this.thought = '',
    this.createdAt = 0,
  });

  final int? id;
  final int bookId;
  final int chapterIndex;
  final NoteType type;
  final String color; // yellow / mint / pink / violet
  final String text; // 被标注的原文
  final String thought; // 想法（仅批注）
  final int createdAt;

  static NoteType typeFromName(String v) => switch (v) {
    'annot' => NoteType.annot,
    'excerpt' => NoteType.excerpt,
    _ => NoteType.mark,
  };

  static String typeName(NoteType v) => switch (v) {
    NoteType.mark => 'mark',
    NoteType.annot => 'annot',
    NoteType.excerpt => 'excerpt',
  };

  Map<String, Object?> toMap() => {
    'id': id,
    'book_id': bookId,
    'chapter_index': chapterIndex,
    'type': typeName(type),
    'color': color,
    'text': text,
    'thought': thought,
    'created_at': createdAt,
  };

  factory Note.fromMap(Map<String, Object?> m) => Note(
    id: m['id'] as int?,
    bookId: m['book_id'] as int,
    chapterIndex: m['chapter_index'] as int? ?? 0,
    type: typeFromName(m['type'] as String? ?? 'mark'),
    color: m['color'] as String? ?? 'yellow',
    text: m['text'] as String? ?? '',
    thought: m['thought'] as String? ?? '',
    createdAt: m['created_at'] as int? ?? 0,
  );
}
