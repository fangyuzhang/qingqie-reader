import 'package:sqflite/sqflite.dart';

import '../../model/bookmark.dart';
import '../app_database.dart';

/// 书签 DAO。
class BookmarkDao {
  BookmarkDao(this._db);
  final AppDatabase _db;

  Future<Database> get _d => _db.database;

  Future<int> insert(Bookmark mark) async {
    final db = await _d;
    return db.insert('bookmarks', mark.toMap());
  }

  Future<void> delete(int id) async {
    final db = await _d;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Bookmark>> byBook(int bookId) async {
    final db = await _d;
    final rows = await db.query(
      'bookmarks',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'chapter_index ASC, created_at ASC',
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<List<Bookmark>> all() async {
    final db = await _d;
    final rows = await db.query('bookmarks', orderBy: 'created_at DESC');
    return rows.map(Bookmark.fromMap).toList();
  }
}
