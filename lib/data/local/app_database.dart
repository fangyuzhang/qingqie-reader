import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 应用数据库单例（sqflite）。
/// 表结构见 docs/03-数据库表结构设计.md，DDL 与文档逐字一致。
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String dbName = 'qingqie.db';
  static const int dbVersion = 1;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, dbName),
      version: dbVersion,
      // 外键约束需要每个连接单独开启
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        final batch = db.batch();
        _createAll(batch);
        await batch.commit(noResult: true);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 迁移策略：只增不改。示例（v2 预留）：
        // if (oldVersion < 2) { await db.execute('CREATE TABLE ...'); }
      },
    );
  }

  static void _createAll(Batch batch) {
    // 分类表
    batch.execute('''
      CREATE TABLE categories (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        sort       INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    // 书架表
    batch.execute('''
      CREATE TABLE books (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        title         TEXT    NOT NULL,
        author        TEXT    NOT NULL DEFAULT '',
        intro         TEXT    NOT NULL DEFAULT '',
        cover_path    TEXT,
        origin        TEXT    NOT NULL,
        format        TEXT    NOT NULL,
        local_path    TEXT,
        source_id     INTEGER,
        book_url      TEXT,
        category_id   INTEGER NOT NULL DEFAULT 1,
        chapter_count INTEGER NOT NULL DEFAULT 0,
        toc_json      TEXT,
        added_at      INTEGER NOT NULL,
        last_read_at  INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET DEFAULT
      )
    ''');
    batch.execute('CREATE INDEX idx_books_category ON books(category_id)');
    batch.execute('CREATE INDEX idx_books_origin ON books(origin)');
    // 阅读进度表
    batch.execute('''
      CREATE TABLE reading_progress (
        book_id        INTEGER PRIMARY KEY,
        chapter_index  INTEGER NOT NULL DEFAULT 0,
        chapter_title  TEXT    NOT NULL DEFAULT '',
        offset_value   REAL    NOT NULL DEFAULT 0,
        percent        REAL    NOT NULL DEFAULT 0,
        updated_at     INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');
    // 书签表
    batch.execute('''
      CREATE TABLE bookmarks (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id        INTEGER NOT NULL,
        chapter_index  INTEGER NOT NULL,
        chapter_title  TEXT    NOT NULL DEFAULT '',
        excerpt        TEXT    NOT NULL DEFAULT '',
        offset_value   REAL    NOT NULL DEFAULT 0,
        created_at     INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('CREATE INDEX idx_bookmarks_book ON bookmarks(book_id)');
    // 书源表
    batch.execute('''
      CREATE TABLE book_sources (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        url        TEXT    NOT NULL,
        src_group  TEXT    NOT NULL DEFAULT '',
        enabled    INTEGER NOT NULL DEFAULT 1,
        sort       INTEGER NOT NULL DEFAULT 0,
        rule_yaml  TEXT    NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    // 笔记表
    batch.execute('''
      CREATE TABLE notes (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id       INTEGER NOT NULL,
        chapter_index INTEGER NOT NULL,
        type          TEXT    NOT NULL,
        color         TEXT    NOT NULL DEFAULT 'yellow',
        text          TEXT    NOT NULL,
        thought       TEXT    NOT NULL DEFAULT '',
        created_at    INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('CREATE INDEX idx_notes_book ON notes(book_id)');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
