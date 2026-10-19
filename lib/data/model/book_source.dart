import 'package:yaml/yaml.dart';

/// 从动态 map 取值并安全转为 String（null 视为空串）。
String _str(dynamic v) => v == null ? '' : v.toString();

/// 从动态值转为可写的 String→dynamic map（非 map 视为空 map）。
Map<String, dynamic> _plainMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// 书源解析失败（带中文原因，导入时直接展示给用户）。
class BookSourceParseFailure implements Exception {
  const BookSourceParseFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 搜索规则。
class SearchRule {
  const SearchRule({
    required this.url,
    this.method = 'GET',
    required this.list,
    required this.title,
    this.bookUrl = '',
    this.cover = '',
    this.author = '',
    this.intro = '',
  });

  final String url;
  final String method;
  final String list;
  final String title;
  final String bookUrl;
  final String cover;
  final String author;
  final String intro;

  static SearchRule fromMap(Map<String, dynamic> m) {
    final url = _str(m['url']);
    if (url.isEmpty) throw const BookSourceParseFailure('search.url 不能为空');
    if (!url.contains('{{key}}')) {
      throw const BookSourceParseFailure('search.url 必须包含 {{key}} 占位符');
    }
    final list = _str(m['list']);
    if (list.isEmpty) throw const BookSourceParseFailure('search.list 不能为空');
    return SearchRule(
      url: url,
      method: (_str(m['method']).toUpperCase()) == 'POST' ? 'POST' : 'GET',
      list: list,
      title: _str(m['title']).isEmpty ? _str(m['bookUrl']) : _str(m['title']),
      bookUrl: _str(m['bookUrl']),
      cover: _str(m['cover']),
      author: _str(m['author']),
      intro: _str(m['intro']),
    );
  }
}

/// 章节列表规则。
class TocRule {
  const TocRule({
    this.url = '',
    required this.list,
    required this.title,
    required this.chapterUrl,
    this.next = '',
  });

  final String url; // 留空 = 直接用书籍详情页
  final String list;
  final String title;
  final String chapterUrl;
  final String next;

  static TocRule fromMap(Map<String, dynamic> m) {
    final list = _str(m['list']);
    if (list.isEmpty) throw const BookSourceParseFailure('toc.list 不能为空');
    return TocRule(
      url: _str(m['url']),
      list: list,
      title: _str(m['title']),
      chapterUrl: _str(m['chapterUrl']),
      next: _str(m['next']),
    );
  }
}

/// 正则清洗规则。
class ReplaceRule {
  const ReplaceRule({required this.pattern, this.replacement = ''});
  final String pattern;
  final String replacement;

  static ReplaceRule fromMap(Map<String, dynamic> m) {
    final p = _str(m['pattern']);
    if (p.isEmpty) throw const BookSourceParseFailure('content.replace[].pattern 不能为空');
    return ReplaceRule(pattern: p, replacement: _str(m['replacement']));
  }
}

/// 正文规则。
class ContentRule {
  const ContentRule({required this.list, this.next = '', this.replace = const []});

  final String list;
  final String next;
  final List<ReplaceRule> replace;

  static ContentRule fromMap(Map<String, dynamic> m) {
    final list = _str(m['list']);
    if (list.isEmpty) throw const BookSourceParseFailure('content.list 不能为空');
    final rawReplace = m['replace'];
    final replace = <ReplaceRule>[];
    if (rawReplace is List) {
      for (final item in rawReplace) {
        if (item is Map) {
          replace.add(ReplaceRule.fromMap(_plainMap(item)));
        }
      }
    }
    return ContentRule(list: list, next: _str(m['next']), replace: replace);
  }
}

/// 书源（声明式 YAML 规则 + 管理字段）。
class BookSource {
  const BookSource({
    this.id,
    required this.name,
    required this.url,
    this.group = '',
    this.enabled = true,
    this.sort = 0,
    required this.rawYaml,
    required this.search,
    required this.toc,
    required this.content,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  final int? id;
  final String name;
  final String url;
  final String group;
  final bool enabled;
  final int sort;
  final String rawYaml; // 原始 YAML 文本（导出时原样返回，便于人工维护）
  final SearchRule search;
  final TocRule toc;
  final ContentRule content;
  final int createdAt;
  final int updatedAt;

  /// 从 YAML/JSON 文本解析书源（导入入口）。
  static BookSource fromYamlText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw const BookSourceParseFailure('书源内容为空');
    Map<String, dynamic> root;
    try {
      final loaded = loadYaml(trimmed);
      if (loaded is YamlMap) {
        root = _plainMap(loaded);
      } else if (loaded is Map) {
        root = _plainMap(loaded);
      } else {
        throw const BookSourceParseFailure('书源不是合法的 YAML/JSON 对象');
      }
    } on BookSourceParseFailure {
      rethrow;
    } catch (e) {
      throw BookSourceParseFailure('YAML 解析失败：$e');
    }
    return fromMap(root, rawYaml: trimmed);
  }

  static BookSource fromMap(Map<String, dynamic> m, {String rawYaml = ''}) {
    final name = _str(m['bookSourceName']);
    if (name.isEmpty) throw const BookSourceParseFailure('缺少 bookSourceName');
    final url = _str(m['bookSourceUrl']);
    if (url.isEmpty) throw const BookSourceParseFailure('缺少 bookSourceUrl');
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      throw const BookSourceParseFailure('bookSourceUrl 仅支持 http/https');
    }
    final search = m['search'];
    final toc = m['toc'];
    final content = m['content'];
    if (search is! Map) throw const BookSourceParseFailure('缺少 search 规则');
    if (toc is! Map) throw const BookSourceParseFailure('缺少 toc 规则');
    if (content is! Map) throw const BookSourceParseFailure('缺少 content 规则');
    return BookSource(
      name: name,
      url: url,
      group: _str(m['bookSourceGroup']),
      enabled: m['enabled'] != false,
      rawYaml: rawYaml,
      search: SearchRule.fromMap(_plainMap(search)),
      toc: TocRule.fromMap(_plainMap(toc)),
      content: ContentRule.fromMap(_plainMap(content)),
    );
  }

  /// 数据库行 → 模型（rule_yaml 重新解析，保证规则与原文一致）。
  factory BookSource.fromDb(Map<String, Object?> row) {
    final yamlText = row['rule_yaml'] as String? ?? '';
    final base = BookSource.fromYamlText(yamlText);
    return BookSource(
      id: row['id'] as int?,
      name: base.name,
      url: base.url,
      group: base.group,
      enabled: (row['enabled'] as int? ?? 1) == 1,
      sort: row['sort'] as int? ?? 0,
      rawYaml: yamlText,
      search: base.search,
      toc: base.toc,
      content: base.content,
      createdAt: row['created_at'] as int? ?? 0,
      updatedAt: row['updated_at'] as int? ?? 0,
    );
  }

  Map<String, Object?> toDb() => {
    'id': id,
    'name': name,
    'url': url,
    'src_group': group,
    'enabled': enabled ? 1 : 0,
    'sort': sort,
    'rule_yaml': rawYaml,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  /// 导出：直接返回原文（不重新序列化，保留注释与格式）。
  String toYamlText() => rawYaml;

  BookSource copyWith({bool? enabled, int? sort, int? id}) => BookSource(
    id: id ?? this.id,
    name: name,
    url: url,
    group: group,
    enabled: enabled ?? this.enabled,
    sort: sort ?? this.sort,
    rawYaml: rawYaml,
    search: search,
    toc: toc,
    content: content,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  // ---- 内部工具 ----

  static String _str(Object? v) => v is String ? v.trim() : '';

  /// YamlMap/嵌套 Map → 纯 `Map<String, dynamic>`。
  static Map<String, dynamic> _plainMap(Map<dynamic, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      out[k.toString()] = v is Map ? _plainMap(v) : v;
    });
    return out;
  }
}
