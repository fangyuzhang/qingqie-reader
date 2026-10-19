import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/app_error.dart';
import '../../core/result.dart';
import '../local/dao/book_dao.dart';
import '../local/dao/bookmark_dao.dart';
import '../local/dao/note_dao.dart';
import '../local/dao/progress_dao.dart';
import '../local/dao/source_dao.dart';
import '../local/app_database.dart';

/// 备份恢复统计。
class RestoreReport {
  const RestoreReport({
    required this.books,
    required this.categories,
    required this.sources,
    required this.bookmarks,
    required this.notes,
  });
  final int books;
  final int categories;
  final int sources;
  final int bookmarks;
  final int notes;
}

/// 书架数据备份/恢复 Repository。
/// 备份内容：分类、书籍、进度、书签、笔记、书源（不含本地原文件与章节缓存）。
/// 格式与上限设计移植自原项目 library_backup.dart（format/version/createdAt + 4MiB）。
class BackupRepository {
  BackupRepository({
    BookDao? bookDao,
    ProgressDao? progressDao,
    BookmarkDao? bookmarkDao,
    NoteDao? noteDao,
    SourceDao? sourceDao,
  })  : _books = bookDao ?? BookDao(AppDatabase.instance),
        _progress = progressDao ?? ProgressDao(AppDatabase.instance),
        _bookmarks = bookmarkDao ?? BookmarkDao(AppDatabase.instance),
        _notes = noteDao ?? NoteDao(AppDatabase.instance),
        _sources = sourceDao ?? SourceDao(AppDatabase.instance);

  final BookDao _books;
  final ProgressDao _progress;
  final BookmarkDao _bookmarks;
  final NoteDao _notes;
  final SourceDao _sources;

  static const String formatTag = 'qingqie-backup';
  static const int backupVersion = 1;
  static const int maxBytes = 4 * 1024 * 1024;

  /// 导出为 JSON 文本。
  Future<Result<String>> export() async {
    try {
      final db = await AppDatabase.instance.database;
      final categories = (await _books.categories()).map((c) => c.toMap()).toList();
      final books = (await _books.all()).map((b) => b.toMap()).toList();
      final progressRows = await db.query('reading_progress');
      final bookmarkRows = await db.query('bookmarks');
      final noteRows = await db.query('notes');
      final sourceRows = await db.query('book_sources');
      final text = jsonEncode({
        'format': formatTag,
        'version': backupVersion,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'categories': categories,
        'books': books,
        'reading_progress': progressRows,
        'bookmarks': bookmarkRows,
        'notes': noteRows,
        'book_sources': sourceRows,
      });
      if (utf8.encode(text).length > maxBytes) {
        return const Result.err(AppError(AppErrorKind.file, '备份超过 4 MiB，请清理后重试'));
      }
      return Result.ok(text);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '导出备份'));
    }
  }

  /// 从 JSON 文本恢复（按 id 覆盖写入）。
  Future<Result<RestoreReport>> import(String text) async {
    Map<String, dynamic> raw;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) throw const FormatException('备份格式不正确');
      raw = decoded;
      if (raw['format'] != formatTag) throw const FormatException('不是青茄阅读的备份文件');
      final version = raw['version'];
      if (version is! int || version < 1 || version > backupVersion) {
        throw const FormatException('备份版本不受支持');
      }
    } on FormatException catch (e) {
      return Result.err(AppError(AppErrorKind.parse, e.message));
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '解析备份'));
    }
    try {
      final db = await AppDatabase.instance.database;
      var books = 0, categories = 0, sources = 0, bookmarks = 0, notes = 0;
      await db.transaction((txn) async {
        for (final row in _mapList(raw['categories'])) {
          await txn.insert('categories', row, conflictAlgorithm: ConflictAlgorithm.replace);
          categories++;
        }
        for (final row in _mapList(raw['books'])) {
          await txn.insert('books', row, conflictAlgorithm: ConflictAlgorithm.replace);
          books++;
        }
        for (final row in _mapList(raw['reading_progress'])) {
          await txn.insert('reading_progress', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final row in _mapList(raw['bookmarks'])) {
          await txn.insert('bookmarks', row, conflictAlgorithm: ConflictAlgorithm.replace);
          bookmarks++;
        }
        for (final row in _mapList(raw['notes'])) {
          await txn.insert('notes', row, conflictAlgorithm: ConflictAlgorithm.replace);
          notes++;
        }
        for (final row in _mapList(raw['book_sources'])) {
          await txn.insert('book_sources', row, conflictAlgorithm: ConflictAlgorithm.replace);
          sources++;
        }
      });
      return Result.ok(RestoreReport(
        books: books,
        categories: categories,
        sources: sources,
        bookmarks: bookmarks,
        notes: notes,
      ));
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '恢复备份'));
    }
  }

  static List<Map<String, Object?>> _mapList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, Object?>.from(e))
        .toList();
  }
}
