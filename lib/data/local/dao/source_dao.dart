import 'package:sqflite/sqflite.dart';

import '../../model/book_source.dart';
import 'app_database.dart';

/// 书源 DAO（YAML 原文存储）。
class SourceDao {
  SourceDao(this._db);
  final AppDatabase _db;

  Future<Database> get _d => _db.database;

  Future<int> insert(BookSource source) async {
    final db = await _d;
    return db.insert('book_sources', source.toDb());
  }

  Future<void> update(BookSource source) async {
    final db = await _d;
    await db.update(
      'book_sources',
      source.toDb(),
      where: 'id = ?',
      whereArgs: [source.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _d;
    await db.delete('book_sources', where: 'id = ?', whereArgs: [id]);
  }

  /// 全部书源：启用优先，再按 sort。
  Future<List<BookSource>> all() async {
    final db = await _d;
    final rows = await db.query('book_sources', orderBy: 'enabled DESC, sort ASC, id ASC');
    return rows.map(BookSource.fromDb).toList();
  }

  Future<BookSource?> byId(int id) async {
    final db = await _d;
    final rows = await db.query('book_sources', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return BookSource.fromDb(rows.first);
  }

  Future<void> setEnabled(int id, bool enabled) async {
    final db = await _d;
    await db.update(
      'book_sources',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 重排：把 id 移到目标位置（整体重写 sort）。
  Future<void> reorder(List<int> orderedIds) async {
    final db = await _d;
    final batch = db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(
        'book_sources',
        {'sort': i},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }
}
