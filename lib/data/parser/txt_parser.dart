import '../../core/app_error.dart';
import '../../core/result.dart';
import '../model/chapter.dart';

/// TXT 解析结果。
class TxtBook {
  const TxtBook({required this.title, this.author = '', required this.chapters});
  final String title;
  final String author;
  final List<Chapter> chapters;
}

/// TXT 解析：编码已在 CharsetDecoder 处理，这里只做章节拆分。
///
/// 【原项目保留】章节/卷标题正则、10000 章上限、10 万字自动分片策略移植自
/// wenku8-src local_text_import.dart；
/// 【新增】作者行识别（原项目不提取 TXT 作者）。
class TxtParser {
  const TxtParser._();

  static const int maxChapters = 10000;
  static const int maxChapterChars = 100000;
  static const int maxHeadingLength = 90;

  static final RegExp _chapterRe = RegExp(
    r'^(第[零〇一二三四五六七八九十百千万两0-9０-９]+[章节回幕话話]|chapter\s+\d+|序章|序言|楔子|尾声|尾聲|后记|後記|番外)',
    caseSensitive: false,
  );
  static final RegExp _volumeRe = RegExp(
    r'^(第[零〇一二三四五六七八九十百千万两0-9０-９]+[卷部]|volume\s+\d+)',
    caseSensitive: false,
  );
  static final RegExp _authorRe = RegExp(
    r'^\s*(?:作者|作\s*者|Author)\s*[:：]\s*(.+)$',
    caseSensitive: false,
  );

  /// fileName: 原始文件名（用于推导书名）；text: 已解码文本。
  static Result<TxtBook> parse(String fileName, String text) {
    final baseName = fileName.replaceAll('\\', '/').split('/').last;
    var title = baseName.replaceFirst(RegExp(r'\.txt$', caseSensitive: false), '');
    if (title.trim().isEmpty) title = '未命名书籍';
    if (title.length > 2048) title = title.substring(0, 2048);

    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final chapters = <Chapter>[];
    final paragraphs = <String>[];
    var length = 0;
    var part = 0;
    var author = '';

    void flush() {
      if (paragraphs.isEmpty) return;
      if (chapters.length >= maxChapters) {
        throw const FormatException('TXT 章节超过 $maxChapters 个，请拆分原书后导入');
      }
      chapters.add(
        Chapter(
          index: chapters.length,
          title: part == 0 ? title : '$title · 片段 ${part + 1}',
          body: paragraphs.join('\n\n'),
        ),
      );
      part++;
      length = 0;
      paragraphs.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final value = raw.trim();
      if (value.isEmpty) continue;
      // 前 20 行内识别作者
      if (i < 20 && author.isEmpty) {
        final m = _authorRe.firstMatch(value);
        if (m != null) {
          author = m.group(1)!.trim();
          if (author.length > 64) author = author.substring(0, 64);
          continue;
        }
      }
      if (value.length <= maxHeadingLength && _volumeRe.hasMatch(value)) {
        // 卷标题：作为章节分组起点（MVP 不单独存储卷信息）
        flush();
        title = value;
        part = 0;
      } else if (value.length <= maxHeadingLength && _chapterRe.hasMatch(value)) {
        flush();
        title = value;
        part = 0;
      } else {
        paragraphs.add(value);
        length += value.length + 2;
        if (length >= maxChapterChars) flush();
      }
    }
    flush();

    if (chapters.isEmpty) {
      return const Result.err(AppError(AppErrorKind.parse, '文件中没有可阅读的正文'));
    }
    return Result.ok(TxtBook(title: title, author: author, chapters: chapters));
  }
}
