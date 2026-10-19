import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html;
import 'package:xml/xml.dart';

import '../../core/app_error.dart';
import '../../core/result.dart';
import '../model/chapter.dart';

/// EPUB 解析结果。
class EpubBook {
  const EpubBook({required this.title, this.author = '', this.intro = '', required this.chapters, this.cover});
  final String title;
  final String author;
  final String intro;
  final List<Chapter> chapters;
  final Uint8List? cover; // 封面图片字节（jpg/png）
}

/// EPUB 解析：zip 解包 → container.xml → OPF → spine/NCX → 正文抽取。
/// 仅依赖稳定 API（archive / xml / html 三件套）。
class EpubParser {
  const EpubParser._();

  static const int maxChapters = 5000;

  static Result<EpubBook> parse(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final files = <String, Uint8List>{};
      for (final entry in archive) {
        if (!entry.isFile) continue;
        // archive 4.x 的 readBytes() 返回可空字节
        final data = entry.readBytes();
        if (data == null || data.isEmpty) continue;
        files[entry.name.replaceAll('\\', '/')] = data;
      }
      if (files.isEmpty) {
        return const Result.err(AppError(AppErrorKind.parse, 'EPUB 内容为空或已损坏'));
      }

      // 1. META-INF/container.xml → OPF 路径
      final container = files['META-INF/container.xml'] ?? files['meta-inf/container.xml'];
      if (container == null) {
        return const Result.err(AppError(AppErrorKind.parse, '不是有效的 EPUB（缺少 container.xml）'));
      }
      final containerDoc = XmlDocument.parse(utf8.decode(container));
      final rootFile = containerDoc.rootElement.descendants
          .whereType<XmlElement>()
          .firstWhere((e) => e.name.local == 'rootfile', orElse: () => throw const FormatException('EPUB 缺少 rootfile'));
      final opfPath = rootFile.getAttribute('full-path') ?? '';
      if (opfPath.isEmpty) {
        return const Result.err(AppError(AppErrorKind.parse, 'EPUB rootfile 路径无效'));
      }
      final opfBytes = files[opfPath] ?? files[opfPath.toLowerCase()];
      if (opfBytes == null) {
        return const Result.err(AppError(AppErrorKind.parse, 'EPUB 内容文件缺失：$opfPath'));
      }
      final opf = XmlDocument.parse(utf8.decode(opfBytes));
      final opfDir = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';

      // 2. metadata
      String metaText(String local) {
        for (final e in opf.rootElement.descendants.whereType<XmlElement>()) {
          if (e.name.local == local) return e.innerText.trim();
        }
        return '';
      }

      final title = metaText('title');
      final author = metaText('creator');
      final intro = metaText('description');

      // 3. manifest: id → (href, media-type, properties)
      final manifest = <String, ({String href, String type, String props})>{};
      final manifestEl = _childByLocal(opf.rootElement, 'manifest');
      if (manifestEl != null) {
        for (final item in manifestEl.children.whereType<XmlElement>()) {
          if (item.name.local != 'item') continue;
          final id = item.getAttribute('id');
          final href = item.getAttribute('href');
          if (id == null || href == null) continue;
          manifest[id] = (
            href: href,
            type: item.getAttribute('media-type') ?? '',
            props: item.getAttribute('properties') ?? '',
          );
        }
      }

      // 4. 封面：properties 含 cover-image，或 id 为 cover/cover-image
      Uint8List? cover;
      for (final entry in manifest.entries) {
        final isCover = entry.value.props.contains('cover-image') ||
            entry.key == 'cover' ||
            entry.key == 'cover-image';
        if (!isCover) continue;
        final resolved = _resolve(opfDir, entry.value.href);
        final data = files[resolved] ?? files[resolved.toLowerCase()];
        if (data != null && data.isNotEmpty) {
          cover = data;
          break;
        }
      }

      // 5. NCX 目录（navMap）或 EPUB3 nav
      final tocEntries = _readToc(opf, manifest, files, opfDir);

      // 6. spine 阅读顺序
      final spine = <String>[];
      final spineEl = _childByLocal(opf.rootElement, 'spine');
      if (spineEl != null) {
        for (final e in spineEl.children.whereType<XmlElement>()) {
          if (e.name.local != 'itemref') continue;
          final idref = e.getAttribute('idref');
          if (idref != null && manifest.containsKey(idref)) spine.add(idref);
        }
      }
      if (spine.isEmpty) {
        return const Result.err(AppError(AppErrorKind.parse, 'EPUB 缺少阅读顺序（spine）'));
      }

      // 7. 逐章抽取正文
      final chapters = <Chapter>[];
      for (final idref in spine) {
        if (chapters.length >= maxChapters) break;
        final item = manifest[idref]!;
        if (!item.type.contains('html')) continue;
        final path = _resolve(opfDir, item.href);
        final data = files[path] ?? files[path.toLowerCase()];
        if (data == null) continue;
        final body = _extractText(utf8.decode(data, allowMalformed: true));
        if (body.isEmpty) continue;
        // 标题：NCX 中 src 指向该文件的条目，否则用书名
        var chapterTitle = '';
        for (final t in tocEntries) {
          if (_samePath(t.src, path) || _samePath(t.src, item.href)) {
            chapterTitle = t.title;
            break;
          }
        }
        if (chapterTitle.isEmpty) chapterTitle = '第 ${chapters.length + 1} 章';
        chapters.add(Chapter(index: chapters.length, title: chapterTitle, body: body));
      }

      if (chapters.isEmpty) {
        return const Result.err(AppError(AppErrorKind.parse, 'EPUB 中没有可阅读的正文'));
      }
      return Result.ok(EpubBook(
        title: title.isEmpty ? '未命名书籍' : title,
        author: author,
        intro: intro,
        chapters: chapters,
        cover: cover,
      ));
    } on FormatException catch (e) {
      return Result.err(AppError.wrap(e, context: 'EPUB 解析'));
    } catch (e) {
      return Result.err(AppError.wrap(e, context: 'EPUB 解析'));
    }
  }

  /// NCX / nav 目录条目。
  static List<({String title, String src})> _readToc(
    XmlDocument opf,
    Map<String, ({String href, String type, String props})> manifest,
    Map<String, Uint8List> files,
    String opfDir,
  ) {
    final out = <({String title, String src})>[];
    // EPUB2 NCX
    for (final entry in manifest.entries) {
      if (!entry.value.type.contains('dtbncx+xml')) continue;
      final data = files[_resolve(opfDir, entry.value.href)];
      if (data == null) continue;
      try {
        final ncx = XmlDocument.parse(utf8.decode(data));
        for (final navPoint in ncx.rootElement.descendants.whereType<XmlElement>()) {
          if (navPoint.name.local != 'navPoint') continue;
          var title = '';
          var src = '';
          for (final child in navPoint.descendants.whereType<XmlElement>()) {
            if (child.name.local == 'text' && title.isEmpty) title = child.innerText.trim();
            if (child.name.local == 'content' && src.isEmpty) {
              src = child.getAttribute('src') ?? '';
            }
          }
          if (title.isNotEmpty && src.isNotEmpty) out.add((title: title, src: src));
        }
      } catch (_) {
        // NCX 损坏时退回 spine 顺序命名
      }
      break;
    }
    // EPUB3 nav（properties="nav"）
    if (out.isEmpty) {
      for (final entry in manifest.entries) {
        if (!entry.value.props.contains('nav')) continue;
        final data = files[_resolve(opfDir, entry.value.href)];
        if (data == null) continue;
        try {
          final doc = html.parse(utf8.decode(data));
          for (final a in doc.querySelectorAll('nav a')) {
            final title = a.text.trim();
            final src = a.attributes['href'] ?? '';
            if (title.isNotEmpty && src.isNotEmpty) out.add((title: title, src: src));
          }
        } catch (_) {
          // 忽略
        }
        break;
      }
    }
    return out;
  }

  /// 从 XHTML 抽取段落文本：块级元素逐个取文本，跳过嵌套块（防重复）。
  static String _extractText(String xhtml) {
    final doc = html.parse(xhtml);
    doc.querySelectorAll('script, style').forEach((e) => e.remove());
    final blocks = doc.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li, blockquote');
    final paragraphs = <String>[];
    for (final el in blocks) {
      // 若内部还有块级子元素，交给子元素处理，避免重复
      if (el.querySelector('p, h1, h2, h3, h4, h5, h6, li, blockquote') != null) continue;
      final t = el.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (t.isNotEmpty) paragraphs.add(t);
    }
    if (paragraphs.isEmpty) {
      // 没有块级结构时退回全文（按换行切分）
      final text = doc.body?.text ?? '';
      for (final line in text.split('\n')) {
        final t = line.trim();
        if (t.isNotEmpty) paragraphs.add(t);
      }
    }
    return paragraphs.join('\n\n');
  }

  static String _resolve(String baseDir, String href) {
    final clean = href.split('#').first;
    if (clean.startsWith('/')) return clean.substring(1);
    return '$baseDir$clean';
  }

  /// 按本地名找直接子元素（避免依赖 parent 的类型窄化）。
  static XmlElement? _childByLocal(XmlElement parent, String local) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.name.local == local) return child;
    }
    return null;
  }

  static bool _samePath(String a, String b) {
    String norm(String s) => s.split('#').first.replaceAll('./', '').replaceFirst('/', '');
    return norm(a) == norm(b) || a.split('/').last == b.split('/').last;
  }
}
