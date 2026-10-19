import 'package:flutter_test/flutter_test.dart';
import 'package:qingqie_reader/data/model/book_source.dart';

/// 书源 YAML 解析单元测试（纯 Dart，无 Flutter 绑定）。
/// 覆盖：正常解析、必填校验、协议校验、{{key}} 占位符校验。
void main() {
  const validYaml = '''
bookSourceName: 测试书源
bookSourceUrl: https://www.example.com
bookSourceGroup: 测试
enabled: true
search:
  url: "https://www.example.com/search?q={{key}}&page={{page}}"
  method: GET
  list: "ul.novel-list > li"
  title: "h3 a::text"
  bookUrl: "h3 a::attr(href)"
toc:
  list: "#chapter-list li a"
  title: "::text"
  chapterUrl: "::attr(href)"
content:
  list: "#chapter-content p"
  replace:
    - pattern: "本章未完.*"
      replacement: ""
''';

  group('BookSource.fromYamlText', () {
    test('解析合法 YAML', () {
      final source = BookSource.fromYamlText(validYaml);
      expect(source.name, '测试书源');
      expect(source.url, 'https://www.example.com');
      expect(source.group, '测试');
      expect(source.enabled, isTrue);
      expect(source.search.method, 'GET');
      expect(source.toc.list, '#chapter-list li a');
      expect(source.content.replace, hasLength(1));
      expect(source.content.replace.first.pattern, '本章未完.*');
    });

    test('JSON 形式同样可解析（YAML 是 JSON 超集）', () {
      final jsonText = '''
{
  "bookSourceName": "JSON 书源",
  "bookSourceUrl": "https://www.example.com",
  "search": {"url": "https://www.example.com/s?q={{key}}", "list": "li"},
  "toc": {"list": "a"},
  "content": {"list": "p"}
}''';
      final source = BookSource.fromYamlText(jsonText);
      expect(source.name, 'JSON 书源');
      expect(source.search.title, isEmpty); // 未提供 title 时回退为空
    });

    test('缺少必填字段抛出中文错误', () {
      expect(
        () => BookSource.fromYamlText('bookSourceUrl: https://a.com'),
        throwsA(isA<BookSourceParseFailure>()
            .having((e) => e.message, 'message', contains('bookSourceName'))),
      );
    });

    test('非 http 协议被拒绝', () {
      expect(
        () => BookSource.fromYamlText(
          'bookSourceName: x\nbookSourceUrl: file:///etc\nsearch: {url: "u?q={{key}}", list: "li"}\ntoc: {list: "a"}\ncontent: {list: "p"}',
        ),
        throwsA(isA<BookSourceParseFailure>()
            .having((e) => e.message, 'message', contains('http'))),
      );
    });

    test('search.url 缺少 {{key}} 被拒绝', () {
      expect(
        () => BookSource.fromYamlText(
          'bookSourceName: x\nbookSourceUrl: https://a.com\nsearch: {url: "https://a.com/s", list: "li"}\ntoc: {list: "a"}\ncontent: {list: "p"}',
        ),
        throwsA(isA<BookSourceParseFailure>()
            .having((e) => e.message, 'message', contains('{{key}}'))),
      );
    });
  });
}
