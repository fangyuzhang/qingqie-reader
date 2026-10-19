import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../core/app_error.dart';
import '../../core/result.dart';
import '../model/chapter.dart';
import '../parser/epub_parser.dart';
import '../parser/txt_parser.dart';
import '../remote/charset_decoder.dart';

/// 导入结果（本地书通用）。
class ImportedBook {
  const ImportedBook({
    required this.title,
    this.author = '',
    this.intro = '',
    required this.chapters,
    this.cover,
    required this.isEpub,
  });

  final String title;
  final String author;
  final String intro;
  final List<Chapter> chapters;
  final Uint8List? cover;
  final bool isEpub;
}

/// 本地书籍导入服务：文件选择 → 大小校验 → 格式分派解析。
/// 【原项目保留】按扩展名限额与友好文案的设计移植自 book_import_limits.dart；
/// 【重构】文件选择从 SAF MethodChannel 改为 file_picker，减少原生依赖。
class LocalImportService {
  const LocalImportService();

  /// 单书大小上限（TXT 32MB / EPUB 64MB）。
  static const int maxTxtBytes = 32 * 1024 * 1024;
  static const int maxEpubBytes = 64 * 1024 * 1024;

  static const List<String> allowedExtensions = ['txt', 'epub'];

  /// 弹出文件选择器并解析。用户取消返回 cancelled。
  Future<Result<ImportedBook>> pickAndImport() async {
    List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '打开文件选择器'));
    }
    if (files.isEmpty) {
      return const Result.err(AppError(AppErrorKind.cancelled, '已取消选择文件'));
    }
    final picked = files.first;
    final name = picked.name;
    final lower = name.toLowerCase();
    final isTxt = lower.endsWith('.txt');
    final isEpub = lower.endsWith('.epub');
    if (!isTxt && !isEpub) {
      return const Result.err(AppError(AppErrorKind.parse, '仅支持 TXT 与 EPUB 文件'));
    }
    Uint8List bytes;
    try {
      final data = await picked.readAsBytes();
      if (data.isEmpty) {
        return const Result.err(AppError(AppErrorKind.file, '无法读取文件内容，请重新选择'));
      }
      bytes = data;
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '读取文件'));
    }
    if (bytes.isEmpty) {
      return const Result.err(AppError(AppErrorKind.file, '文件为空'));
    }
    final limit = isEpub ? maxEpubBytes : maxTxtBytes;
    if (bytes.length > limit) {
      return Result.err(AppError(
        AppErrorKind.file,
        '文件超过 ${limit ~/ (1024 * 1024)} MiB 上限，请选择更小的文件',
      ));
    }
    if (isEpub) {
      final res = EpubParser.parse(bytes);
      return res.when(
        ok: (book) => Result.ok(ImportedBook(
          title: book.title,
          author: book.author,
          intro: book.intro,
          chapters: book.chapters,
          cover: book.cover,
          isEpub: true,
        )),
        err: (e) => Result.err(e),
      );
    }
    // TXT：先做编码检测再解析
    final decoded = await CharsetDecoder.decodeText(bytes);
    return decoded.when(
      ok: (text) {
        final res = TxtParser.parse(name, text);
        return res.when(
          ok: (book) => Result.ok(ImportedBook(
            title: book.title,
            author: book.author,
            chapters: book.chapters,
            isEpub: false,
          )),
          err: (e) => Result.err(e),
        );
      },
      err: (e) => Result.err(e),
    );
  }

  /// 从给定路径导入（书源页/恢复等场景备用）。
  Future<Result<ImportedBook>> importFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return const Result.err(AppError(AppErrorKind.file, '文件不存在'));
    }
    final name = file.uri.pathSegments.isEmpty ? path : file.uri.pathSegments.last;
    final lower = name.toLowerCase();
    final bytes = await file.readAsBytes();
    if (lower.endsWith('.epub')) {
      final res = EpubParser.parse(bytes);
      return res.when(
        ok: (book) => Result.ok(ImportedBook(
          title: book.title,
          author: book.author,
          intro: book.intro,
          chapters: book.chapters,
          cover: book.cover,
          isEpub: true,
        )),
        err: (e) => Result.err(e),
      );
    }
    final decoded = await CharsetDecoder.decodeText(bytes);
    return decoded.when(
      ok: (text) {
        final res = TxtParser.parse(name, text);
        return res.when(
          ok: (book) => Result.ok(ImportedBook(
            title: book.title,
            author: book.author,
            chapters: book.chapters,
            isEpub: false,
          )),
          err: (e) => Result.err(e),
        );
      },
      err: (e) => Result.err(e),
    );
  }
}
