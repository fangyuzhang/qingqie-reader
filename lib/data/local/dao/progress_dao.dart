import 'package:sqflite/sqflite.dart';

import '../../model/reading_progress.dart';
import 'app_database.dart';

/// 阅读进度 DAO（一书一行，upsert 语义）。
class ProgressDao {
  ProgressDao(this._db);
  final AppDatabase _db;

  Future<Database> get _d => _db.database;

  Future<ReadingProgress?> byBook(int bookId) async {
    final db = await _d;
    final rows = await db.query(
      'reading_progress',
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ReadingProgress.fromMap(rows.first);
  }

  Future<void> upsert(ReadingProgress progress) async {
    final db = await _d;
    await db.insert(
      'reading_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteByBook(int bookId) async {
    final db = await _d;
    await db.delete('reading_progress', where: 'book_id = ?', whereArgs: [bookId]);
  }
}
