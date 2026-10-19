import 'package:sqflite/sqflite.dart';

import '../../model/note.dart';
import 'app_database.dart';

/// 笔记 DAO（划线/批注/书摘）。
class NoteDao {
  NoteDao(this._db);
  final AppDatabase _db;

  Future<Database> get _d => _db.database;

  Future<int> insert(Note note) async {
    final db = await _d;
    return db.insert('notes', note.toMap());
  }

  Future<void> delete(int id) async {
    final db = await _d;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> byBook(int bookId) async {
    final db = await _d;
    final rows = await db.query(
      'notes',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'chapter_index ASC, created_at ASC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> byBookChapter(int bookId, int chapterIndex) async {
    final db = await _d;
    final rows = await db.query(
      'notes',
      where: 'book_id = ? AND chapter_index = ?',
      whereArgs: [bookId, chapterIndex],
      orderBy: 'created_at ASC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<int> countAll() async {
    final db = await _d;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM notes');
    return result.first['c'] as int? ?? 0;
  }

  Future<List<Note>> all() async {
    final db = await _d;
    final rows = await db.query('notes', orderBy: 'created_at DESC');
    return rows.map(Note.fromMap).toList();
  }
}
