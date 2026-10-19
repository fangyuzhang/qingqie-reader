/// 书架分类（在读 / 想读 / 读完…用户可增删）。
class BookCategory {
  const BookCategory({required this.id, required this.name, this.sort = 0, this.createdAt = 0});

  final int id;
  final String name;
  final int sort;
  final int createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'sort': sort,
    'created_at': createdAt,
  };

  factory BookCategory.fromMap(Map<String, Object?> m) => BookCategory(
    id: m['id'] as int,
    name: m['name'] as String? ?? '',
    sort: m['sort'] as int? ?? 0,
    createdAt: m['created_at'] as int? ?? 0,
  );
}
