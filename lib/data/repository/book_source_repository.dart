import '../../core/app_error.dart';
import '../../core/result.dart';
import '../local/dao/source_dao.dart';
import '../local/app_database.dart';
import '../model/book_source.dart';
import '../parser/book_source_engine.dart';
import '../remote/http_client.dart';

/// 批量导入结果。
class ImportReport {
  const ImportReport({required this.added, required this.errors});
  final int added;
  final List<String> errors;
}

/// 书源 Repository：CRUD、导入导出、启停、排序、在线校验。
class BookSourceRepository {
  BookSourceRepository({
    SourceDao? sourceDao,
    BookSourceEngine? engine,
  })  : _dao = sourceDao ?? SourceDao(AppDatabase.instance),
        _engine = engine ?? BookSourceEngine(AppHttpClient.instance);

  final SourceDao _dao;
  final BookSourceEngine _engine;

  Future<Result<List<BookSource>>> all() async {
    try {
      return Result.ok(await _dao.all());
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '读取书源'));
    }
  }

  Future<Result<BookSource?>> byId(int id) async {
    try {
      return Result.ok(await _dao.byId(id));
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '读取书源'));
    }
  }

  /// 新增书源（YAML/JSON 文本）。
  Future<Result<BookSource>> add(String text) async {
    BookSource source;
    try {
      source = BookSource.fromYamlText(text);
    } on BookSourceParseFailure catch (e) {
      return Result.err(AppError(AppErrorKind.parse, '书源解析失败：${e.message}'));
    }
    // 重名检查
    final existing = (await all()).valueOrNull ?? const [];
    if (existing.any((s) => s.name == source.name && s.url == source.url)) {
      return const Result.err(AppError(AppErrorKind.unknown, '已存在同名同地址的书源'));
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final sort = existing.isEmpty ? 0 : existing.last.sort + 1;
    source = BookSource(
      name: source.name,
      url: source.url,
      group: source.group,
      enabled: source.enabled,
      sort: sort,
      rawYaml: source.rawYaml,
      search: source.search,
      toc: source.toc,
      content: source.content,
      createdAt: now,
      updatedAt: now,
    );
    try {
      final id = await _dao.insert(source);
      return Result.ok(source.copyWith(id: id));
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '保存书源'));
    }
  }

  Future<Result<void>> update(BookSource source) async {
    try {
      await _dao.update(source.copyWith());
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '更新书源'));
    }
  }

  Future<Result<void>> remove(int id) async {
    try {
      await _dao.delete(id);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '删除书源'));
    }
  }

  Future<Result<void>> setEnabled(int id, bool enabled) async {
    try {
      await _dao.setEnabled(id, enabled);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '切换书源状态'));
    }
  }

  /// 上移/下移（delta = -1 / +1），整体重排 sort。
  Future<Result<void>> move(int id, int delta) async {
    try {
      final all = (await this.all()).valueOrNull ?? const [];
      final idx = all.indexWhere((s) => s.id == id);
      if (idx < 0) return const Result.err(AppError(AppErrorKind.unknown, '书源不存在'));
      final target = idx + delta;
      if (target < 0 || target >= all.length) return const Result.ok(null);
      final next = List<BookSource>.from(all);
      final item = next.removeAt(idx);
      next.insert(target, item);
      await _dao.reorder(next.map((s) => s.id ?? 0).toList());
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '书源排序'));
    }
  }

  /// 批量导入：多文档 YAML（--- 分隔）或 JSON 数组。
  Future<Result<ImportReport>> importText(String text) async {
    var added = 0;
    final errors = <String>[];
    final chunks = _splitDocuments(text);
    for (final chunk in chunks) {
      final res = await add(chunk);
      res.when(
        ok: (_) => added++,
        err: (e) => errors.add(e.message),
      );
    }
    return Result.ok(ImportReport(added: added, errors: errors));
  }

  /// 导出全部书源为 YAML 文本（多文档）。
  Future<Result<String>> exportYaml() async {
    final all = (await this.all()).valueOrNull;
    if (all == null) return const Result.err(AppError(AppErrorKind.unknown, '读取书源失败'));
    if (all.isEmpty) return const Result.ok('');
    final buffer = StringBuffer();
    for (var i = 0; i < all.length; i++) {
      if (i > 0) buffer.writeln('---');
      buffer.writeln(all[i].toYamlText());
    }
    return Result.ok(buffer.toString());
  }

  /// 在线校验（真实搜索探测）。
  Future<Result<String>> validate(int id) async {
    final source = (await byId(id)).valueOrNull;
    if (source == null) return const Result.err(AppError(AppErrorKind.unknown, '书源不存在'));
    final res = await _engine.validate(source);
    return res.when(
      ok: (report) => Result.ok(report.message),
      err: (e) => Result.err(e),
    );
  }

  /// 按 --- 分割多文档 YAML；JSON 数组整体作为一个文档。
  static List<String> _splitDocuments(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('[')) {
      // JSON 数组：逐条拆分
      try {
        final list = _jsonArray(trimmed);
        return list;
      } catch (_) {
        return const [];
      }
    }
    return trimmed
        .split(RegExp(r'^---\s*$', multiLine: true))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<String> _jsonArray(String text) {
    // 逐个 JSON 对象提取（避免引入额外依赖，按花括号配平切分）
    final out = <String>[];
    var depth = 0;
    var start = -1;
    var inString = false;
    var escaped = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inString) {
      if (escaped) {
        escaped = false;
      } else if (c == '\\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
        continue;
      }
      if (c == '"') {
        inString = true;
      } else if (c == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0 && start >= 0) {
          out.add(text.substring(start, i + 1));
          start = -1;
        }
      }
    }
    return out;
  }
}
