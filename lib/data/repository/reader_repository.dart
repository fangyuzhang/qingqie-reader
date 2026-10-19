import 'dart:convert';

import '../../core/app_error.dart';
import '../../core/result.dart';
import '../file/book_file_store.dart';
import '../local/dao/bookmark_dao.dart';
import '../local/dao/note_dao.dart';
import '../local/dao/progress_dao.dart';
import '../local/app_database.dart';
import '../local/preferences_store.dart';
import '../model/book.dart';
import '../model/book_source.dart';
import '../model/bookmark.dart';
import '../model/chapter.dart';
import '../model/note.dart';
import '../model/reading_progress.dart';
import '../model/reader_settings.dart';
import '../parser/book_source_engine.dart';
import '../remote/http_client.dart';

/// 阅读 Repository：章节加载（本地/网络）、进度、书签、笔记、阅读设置。
class ReaderRepository {
  ReaderRepository({
    BookFileStore? fileStore,
    ProgressDao? progressDao,
    BookmarkDao? bookmarkDao,
    NoteDao? noteDao,
    BookSourceEngine? engine,
    PreferencesStore? prefs,
  })  : _files = fileStore ?? BookFileStore.instance,
        _progress = progressDao ?? ProgressDao(AppDatabase.instance),
        _bookmarks = bookmarkDao ?? BookmarkDao(AppDatabase.instance),
        _notes = noteDao ?? NoteDao(AppDatabase.instance),
        _engine = engine ?? BookSourceEngine(AppHttpClient.instance),
        _prefs = prefs ?? PreferencesStore.instance;

  final BookFileStore _files;
  final ProgressDao _progress;
  final BookmarkDao _bookmarks;
  final NoteDao _notes;
  final BookSourceEngine _engine;
  final PreferencesStore _prefs;

  // ---- 章节 ----

  Future<Result<List<Chapter>>> chapters(Book book) => _files.readChapters(book.id);

  /// 读取正文：本地缓存优先；网络书且无缓存时按书源抓取并回填。
  Future<Result<String>> chapterBody(Book book, int index) async {
    final cached = await _files.readChapters(book.id);
    final chapters = cached.valueOrNull;
    if (chapters != null && index >= 0 && index < chapters.length && chapters[index].hasBody) {
      return Result.ok(chapters[index].body);
    }
    if (book.isLocal) {
      return const Result.err(AppError(AppErrorKind.file, '章节缓存缺失，请重新导入书籍'));
    }
    if (chapters == null || index < 0 || index >= chapters.length) {
      return const Result.err(AppError(AppErrorKind.parse, '章节不存在'));
    }
    final chapter = chapters[index];
    final res = await _engine.content(bookSourceRef(book), chapter);
    return res.when(
      ok: (body) async {
        await _files.writeChapterBody(book.id, index, body);
        return Result.ok(body);
      },
      err: (e) => Result.err(e),
    );
  }

  /// 网络书抓取目录并写缓存。
  Future<Result<List<Chapter>>> fetchToc(Book book) async {
    if (book.bookUrl == null) {
      return const Result.err(AppError(AppErrorKind.parse, '书籍缺少详情页地址'));
    }
    final res = await _engine.toc(bookSourceRef(book), book.bookUrl!);
    return res.when(
      ok: (chapters) async {
        await _files.writeChapters(book.id, chapters);
        return Result.ok(chapters);
      },
      err: (e) => Result.err(e),
    );
  }

  /// 由 sourceId 反查书源规则（网络书阅读/抓取用）。
  /// 注意：为避免 ReaderRepository 直接依赖 SourceDao 造成环依赖，
  /// 由上层（ReaderViewModel）通过 setSourceResolver 注入。
  BookSourceResolver? _sourceResolver;
  void setSourceResolver(BookSourceResolver resolver) => _sourceResolver = resolver;

  BookSource bookSourceRef(Book book) {
    final resolver = _sourceResolver;
    if (resolver == null) {
      throw const AppError(AppErrorKind.unknown, '书源解析器未初始化');
    }
    return resolver(book.sourceId ?? 0);
  }

  // ---- 进度 ----

  Future<Result<ReadingProgress?>> progress(int bookId) async {
    try {
      return Result.ok(await _progress.byBook(bookId));
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '读取进度'));
    }
  }

  Future<Result<void>> saveProgress(ReadingProgress progress) async {
    try {
      await _progress.upsert(progress.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch));
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '保存进度'));
    }
  }

  // ---- 书签 ----

  Future<Result<List<Bookmark>>> bookmarks(int bookId) async {
    try {
      return Result.ok(await _bookmarks.byBook(bookId));
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '读取书签'));
    }
  }

  Future<Result<int>> addBookmark(Bookmark mark) async {
    try {
      return Result.ok(await _bookmarks.insert(mark));
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '添加书签'));
    }
  }

  Future<Result<void>> removeBookmark(int id) async {
    try {
      await _bookmarks.delete(id);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '删除书签'));
    }
  }

  // ---- 笔记（划线/批注/书摘）----

  Future<Result<List<Note>>> notes(int bookId, int chapterIndex) async {
    try {
      return Result.ok(await _notes.byBookChapter(bookId, chapterIndex));
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '读取笔记'));
    }
  }

  Future<Result<List<Note>>> allNotes() async {
    try {
      return Result.ok(await _notes.all());
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '读取笔记'));
    }
  }

  Future<Result<int>> addNote(Note note) async {
    try {
      return Result.ok(await _notes.insert(note));
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '保存笔记'));
    }
  }

  Future<Result<void>> removeNote(int id) async {
    try {
      await _notes.delete(id);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '删除笔记'));
    }
  }

  Future<Result<int>> noteCount() async {
    try {
      return Result.ok(await _notes.countAll());
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '统计笔记'));
    }
  }

  // ---- 阅读设置 ----

  Future<Result<ReaderSettings>> loadSettings() async {
    try {
      final text = await _prefs.read(PreferencesStore.keyReaderSettings);
      if (text == null || text.isEmpty) return const Result.ok(ReaderSettings());
      return Result.ok(ReaderSettings.fromJson(jsonDecode(text) as Map<String, dynamic>));
    } catch (_) {
      // 设置损坏时回退默认值，不阻塞阅读
      return const Result.ok(ReaderSettings());
    }
  }

  Future<Result<void>> saveSettings(ReaderSettings settings) async {
    try {
      await _prefs.write(PreferencesStore.keyReaderSettings, jsonEncode(settings.toJson()));
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '保存阅读设置'));
    }
  }
}

/// 由上层注入的「sourceId → 书源规则」解析器（避免 Repository 之间环依赖）。
typedef BookSourceResolver = BookSource Function(int sourceId);
