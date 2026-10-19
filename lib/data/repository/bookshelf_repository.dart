import '../../core/app_error.dart';
import '../../core/result.dart';
import '../file/book_file_store.dart';
import '../file/local_import_service.dart';
import '../local/dao/book_dao.dart';
import '../local/app_database.dart';
import '../model/book.dart';
import '../model/category.dart';
import '../model/chapter.dart';

/// 书架 Repository：分类/书籍 CRUD、本地导入、网络书加入、删除。
/// UI 与 ViewModel 只面对本类，不直接接触 DAO 与文件。
class BookshelfRepository {
  BookshelfRepository({
    BookDao? bookDao,
    BookFileStore? fileStore,
    LocalImportService? importService,
  })  : _dao = bookDao ?? BookDao(AppDatabase.instance),
        _files = fileStore ?? BookFileStore.instance,
        _importer = importService ?? const LocalImportService();

  final BookDao _dao;
  final BookFileStore _files;
  final LocalImportService _importer;

  Future<void> ensureReady() => _dao.ensureDefaultCategory();

  // ---- 分类 ----

  Future<Result<List<BookCategory>>> categories() async {
    try {
      return Result.ok(await _dao.categories());
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '读取分类'));
    }
  }

  Future<Result<int>> createCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const Result.err(AppError(AppErrorKind.unknown, '分类名不能为空'));
    if (trimmed.length > 32) return const Result.err(AppError(AppErrorKind.unknown, '分类名过长'));
    try {
      final all = await _dao.categories();
      final sort = all.isEmpty ? 0 : all.last.sort + 1;
      return Result.ok(await _dao.insertCategory(trimmed, sort));
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '创建分类'));
    }
  }

  Future<Result<void>> renameCategory(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const Result.err(AppError(AppErrorKind.unknown, '分类名不能为空'));
    try {
      await _dao.renameCategory(id, trimmed);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '重命名分类'));
    }
  }

  /// 删除分类：书籍由外键回到默认分组（id=1 不可删）。
  Future<Result<void>> deleteCategory(int id) async {
    if (id <= 1) return const Result.err(AppError(AppErrorKind.unknown, '默认分组不可删除'));
    try {
      await _dao.deleteCategory(id);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '删除分类'));
    }
  }

  // ---- 书架 ----

  Future<Result<List<Book>>> books({int? categoryId, String? query}) async {
    try {
      if (query != null && query.trim().isNotEmpty) {
        return Result.ok(await _dao.search(query.trim()));
      }
      if (categoryId != null && categoryId > 0) {
        return Result.ok(await _dao.byCategory(categoryId));
      }
      return Result.ok(await _dao.all());
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '读取书架'));
    }
  }

  Future<Result<Book?>> book(int id) async {
    try {
      return Result.ok(await _dao.byId(id));
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '读取书籍'));
    }
  }

  /// 本地导入：picker → 解析 → 落库 → 写章节缓存。返回书架中的书。
  Future<Result<Book>> importLocalBook({int categoryId = 1}) async {
    final imported = await _importer.pickAndImport();
    return imported.when(
      ok: (book) => _persistLocal(book, categoryId: categoryId),
      err: (e) => Result.err(e),
    );
  }

  Future<Result<Book>> _persistLocal(ImportedBook book, {int categoryId = 1}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final format = book.isEpub ? BookFormat.epub : BookFormat.txt;
      final id = await _dao.insert(Book(
        id: 0,
        title: book.title,
        author: book.author,
        intro: book.intro,
        origin: BookOrigin.local,
        format: format,
        categoryId: categoryId,
        chapterCount: book.chapters.length,
        addedAt: now,
      ));
      // 章节缓存 + 封面落盘
      await _files.writeChapters(id, book.chapters);
      String? coverPath;
      if (book.cover != null) {
        coverPath = (await _files.writeCover(id, book.cover!, 'jpg')).valueOrNull;
      }
      final saved = Book(
        id: id,
        title: book.title,
        author: book.author,
        intro: book.intro,
        origin: BookOrigin.local,
        format: format,
        coverPath: coverPath,
        categoryId: categoryId,
        chapterCount: book.chapters.length,
        addedAt: now,
      );
      await _dao.update(saved);
      return Result.ok(saved);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '导入书籍'));
    }
  }

  /// 网络书加入书架（书源搜索 → 目录已抓取）。
  Future<Result<Book>> addNetworkBook({
    required int sourceId,
    required String sourceName,
    required String bookUrl,
    required String title,
    String author = '',
    String intro = '',
    required List<Chapter> chapters,
    int categoryId = 1,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await _dao.insert(Book(
        id: 0,
        title: title.isEmpty ? '未命名书籍' : title,
        author: author,
        intro: intro,
        origin: BookOrigin.network,
        format: BookFormat.web,
        sourceId: sourceId,
        bookUrl: bookUrl,
        categoryId: categoryId,
        chapterCount: chapters.length,
        tocJson: '[]',
        addedAt: now,
      ));
      await _files.writeChapters(id, chapters);
      final saved = Book(
        id: id,
        title: title.isEmpty ? '未命名书籍' : title,
        author: author,
        intro: intro,
        origin: BookOrigin.network,
        format: BookFormat.web,
        sourceId: sourceId,
        bookUrl: bookUrl,
        categoryId: categoryId,
        chapterCount: chapters.length,
        tocJson: '[]',
        addedAt: now,
      );
      return Result.ok(saved);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '加入书架'));
    }
  }

  Future<Result<void>> moveBook(int bookId, int categoryId) async {
    try {
      final book = await _dao.byId(bookId);
      if (book == null) return const Result.err(AppError(AppErrorKind.unknown, '书籍不存在'));
      await _dao.update(book.copyWith(categoryId: categoryId));
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '移动分组'));
    }
  }

  /// 删除书籍：数据库行 + 文件缓存（进度/书签/笔记由外键级联删除）。
  Future<Result<void>> removeBook(int bookId) async {
    try {
      await _dao.delete(bookId);
      await _files.deleteBook(bookId);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '删除书籍'));
    }
  }

  Future<Result<void>> touchLastRead(int bookId) async {
    try {
      await _dao.touchLastRead(bookId, DateTime.now().millisecondsSinceEpoch);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '更新阅读时间'));
    }
  }
}
