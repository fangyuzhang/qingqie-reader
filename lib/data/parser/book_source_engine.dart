import 'package:html/parser.dart' as html;

import '../../core/app_error.dart';
import '../../core/result.dart';
import '../model/book_source.dart';
import '../model/chapter.dart';
import '../model/search_item.dart';
import '../remote/http_client.dart';
import 'html_rule_parser.dart';

/// 书源校验报告（书源管理页「校验」按钮）。
class SourceCheckReport {
  const SourceCheckReport({required this.ok, required this.message, this.hitCount = 0});
  final bool ok;
  final String message;
  final int hitCount;
}

/// 书源引擎：按 YAML 规则执行 搜索 / 目录 / 正文 三类抓取。
/// 安全约束：仅 http/https、无脚本执行、翻页上限 5、大小上限由 HttpClient 控制。
class BookSourceEngine {
  BookSourceEngine(this._http);
  final AppHttpClient _http;

  static const int _maxFollowPages = 5;

  /// 在线搜索。
  Future<Result<List<SearchItem>>> search(BookSource src, String keyword) async {
    final url = src.search.url
        .replaceAll('{{key}}', Uri.encodeQueryComponent(keyword))
        .replaceAll('{{page}}', '1');
    final res = await _http.requestText(
      url,
      method: src.search.method,
      form: src.search.method == 'POST' ? {'key': keyword, 'page': '1'} : null,
      maxBytes: 1024 * 1024,
    );
    final text = res.valueOrNull;
    if (text == null) return Result.err(res.errorOrNull!);
    final doc = html.parse(text);
    final out = <SearchItem>[];
    for (final el in RuleParser.selectAll(doc, src.search.list)) {
      final title = RuleParser.extract(el, src.search.title) ?? '';
      final bookUrl = RuleParser.absoluteUrl(src.url, RuleParser.extract(el, src.search.bookUrl) ?? '');
      if (title.isEmpty || bookUrl.isEmpty) continue;
      out.add(SearchItem(
        title: title,
        author: RuleParser.extract(el, src.search.author) ?? '',
        intro: RuleParser.extract(el, src.search.intro) ?? '',
        bookUrl: bookUrl,
        coverUrl: RuleParser.absoluteUrl(src.url, RuleParser.extract(el, src.search.cover) ?? ''),
        sourceId: src.id ?? 0,
        sourceName: src.name,
      ));
    }
    return Result.ok(out);
  }

  /// 获取章节列表（跟随 toc.next 翻页，最多 5 页）。
  Future<Result<List<Chapter>>> toc(BookSource src, String bookUrl) async {
    final chapters = <Chapter>[];
    var page = 0;
    var url = src.toc.url.isEmpty ? bookUrl : _fillBookUrl(src.toc.url, bookUrl);
    while (url.isNotEmpty && page < _maxFollowPages) {
      page++;
      final res = await _http.requestText(url);
      final text = res.valueOrNull;
      if (text == null) return Result.err(res.errorOrNull!);
      final doc = html.parse(text);
      for (final el in RuleParser.selectAll(doc, src.toc.list)) {
        final title = RuleParser.extract(el, src.toc.title) ?? '';
        final chapterUrl =
            RuleParser.absoluteUrl(src.url, RuleParser.extract(el, src.toc.chapterUrl) ?? '');
        if (title.isEmpty || chapterUrl.isEmpty) continue;
        chapters.add(Chapter(index: chapters.length, title: title, url: chapterUrl));
      }
      if (src.toc.next.isEmpty) break;
      final next = RuleParser.absoluteUrl(src.url, RuleParser.extract(doc.body, src.toc.next) ?? '');
      if (next.isEmpty || next == url) break;
      url = next;
    }
    if (chapters.isEmpty) {
      return const Result.err(AppError(AppErrorKind.parse, '未解析到章节，请检查书源规则'));
    }
    return Result.ok(chapters);
  }

  /// 获取正文（跟随 content.next 翻页，应用 replace 清洗）。
  Future<Result<String>> content(BookSource src, Chapter chapter) async {
    final buffer = <String>[];
    var page = 0;
    var url = chapter.url;
    while (url.isNotEmpty && page < _maxFollowPages) {
      page++;
      final res = await _http.requestText(url);
      final text = res.valueOrNull;
      if (text == null) return Result.err(res.errorOrNull!);
      final doc = html.parse(text);
      final parts = <String>[];
      for (final el in RuleParser.selectAll(doc, src.content.list)) {
        final t = el.text.replaceAll(RegExp(r'[ \t\u3000]+'), ' ').trim();
        if (t.isNotEmpty) parts.add(t);
      }
      if (parts.isEmpty) break;
      buffer.add(parts.join('\n\n'));
      if (src.content.next.isEmpty) break;
      final next = RuleParser.absoluteUrl(src.url, RuleParser.extract(doc.body, src.content.next) ?? '');
      if (next.isEmpty || next == url) break;
      url = next;
    }
    if (buffer.isEmpty) {
      return const Result.err(AppError(AppErrorKind.parse, '未解析到正文，请检查书源规则'));
    }
    var text = buffer.join('\n\n');
    // 正则清洗（按顺序执行；非法正则跳过而不是崩溃）
    for (final r in src.content.replace) {
      try {
        text = text.replaceAll(RegExp(r.pattern, dotAll: true), r.replacement);
      } on FormatException {
        // 忽略非法正则，保留其他清洗规则
      }
    }
    return Result.ok(text.trim());
  }

  /// 校验书源：先请求首页，再真实搜索「的」字探测规则命中。
  Future<Result<SourceCheckReport>> validate(BookSource src) async {
    final home = await _http.requestText(src.url, maxBytes: 512 * 1024);
    if (home case Err(:final error)) return Result.err(error);
    final result = await search(src, '的');
    return result.when(
      ok: (items) => Result.ok(SourceCheckReport(
        ok: items.isNotEmpty,
        message: items.isEmpty ? '站点可访问，但搜索规则未命中（请检查规则）' : '校验通过',
        hitCount: items.length,
      )),
      err: (e) => Result.ok(SourceCheckReport(ok: false, message: '站点可访问，但搜索失败：${e.message}')),
    );
  }

  String _fillBookUrl(String template, String bookUrl) =>
      template.replaceAll('{{bookUrl}}', bookUrl);
}
