import 'package:sqflite/sqflite.dart';

import '../../model/book.dart';
import '../../model/category.dart';
import 'app_database.dart';

/// 书架/分类 DAO。所有 SQL 只出现在 DAO 层。
class BookDao {
  BookDao(this._db);
  final AppDatabase _db;

  Future<Database> get _d => _db.database;

  Future<int> insert(Book book) async {
    final db = await _d;
    return db.insert('books', book.toMap());
  }

  Future<void> update(Book book) async {
    final db = await _d;
    await db.update('books', book.toMap(), where: 'id = ?', whereArgs: [book.id]);
  }

  Future<void> delete(int id) async {
    final db = await _d;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  Future<Book?> byId(int id) async {
    final db = await _d;
    final rows = await db.query('books', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  /// 全部书籍：最近阅读优先，其次新加入。
  Future<List<Book>> all() async {
    final db = await _d;
    final rows = await db.query('books', orderBy: 'last_read_at DESC, added_at DESC, id DESC');
    return rows.map(Book.fromMap).toList();
  }

  Future<List<Book>> byCategory(int categoryId) async {
    final db = await _d;
    final rows = await db.query(
      'books',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'last_read_at DESC, added_at DESC, id DESC',
    );
    return rows.map(Book.fromMap).toList();
  }

  /// 本地搜索：书名/作者模糊匹配。
  Future<List<Book>> search(String keyword) async {
    final db = await _d;
    final like = '%$keyword%';
    final rows = await db.query(
      'books',
      where: 'title LIKE ? OR author LIKE ?',
      whereArgs: [like, like],
      orderBy: 'last_read_at DESC, id DESC',
    );
    return rows.map(Book.fromMap).toList();
  }

  Future<void> touchLastRead(int id, int timestamp) async {
    final db = await _d;
    await db.update('books', {'last_read_at': timestamp}, where: 'id = ?', whereArgs: [id]);
  }

  // ---- 分类 ----

  Future<int> insertCategory(String name, int sort) async {
    final db = await _d;
    return db.insert('categories', {
      'name': name,
      'sort': sort,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> renameCategory(int id, String name) async {
    final db = await _d;
    await db.update('categories', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  /// 删除分类： books.category_id 外键 ON DELETE SET DEFAULT 自动回到默认分组。
  Future<void> deleteCategory(int id) async {
    final db = await _d;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<BookCategory>> categories() async {
    final db = await _d;
    final rows = await db.query('categories', orderBy: 'sort ASC, id ASC');
    return rows.map(BookCategory.fromMap).toList();
  }

  /// 首次运行写入默认分类（幂等）。
  Future<void> ensureDefaultCategory() async {
    final db = await _d;
    final rows = await db.query('categories', limit: 1);
    if (rows.isNotEmpty) return;
    await db.insert('categories', {
      'name': '默认分组',
      'sort': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
