import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_error.dart';
import '../../core/result.dart';
import '../model/chapter.dart';

/// 书籍文件存储：章节 JSON 缓存 + 封面。
/// 布局：<appDocuments>/books/<bookId>/chapters.json | cover.<ext>
class BookFileStore {
  BookFileStore._();
  static final BookFileStore instance = BookFileStore._();

  Future<Directory> _bookDir(int bookId) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'books', '$bookId'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 写入章节列表（导入/抓取目录后调用）。
  Future<Result<void>> writeChapters(int bookId, List<Chapter> chapters) async {
    try {
      final dir = await _bookDir(bookId);
      final file = File(p.join(dir.path, 'chapters.json'));
      final json = jsonEncode(chapters.map((c) => c.toJson()).toList());
      await file.writeAsString(json);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '保存章节缓存'));
    }
  }

  /// 读取章节列表（本地书与已缓存目录的网络书）。
  Future<Result<List<Chapter>>> readChapters(int bookId) async {
    try {
      final dir = await _bookDir(bookId);
      final file = File(p.join(dir.path, 'chapters.json'));
      if (!await file.exists()) {
        return const Result.err(AppError(AppErrorKind.file, '章节缓存不存在，请重新导入'));
      }
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      final chapters = <Chapter>[];
      for (var i = 0; i < list.length; i++) {
        chapters.add(Chapter.fromJson(i, list[i] as Map<String, dynamic>));
      }
      return Result.ok(chapters);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '读取章节缓存'));
    }
  }

  /// 回填某章正文（网络书抓取后落盘）。
  Future<Result<void>> writeChapterBody(int bookId, int index, String body) async {
    try {
      final dir = await _bookDir(bookId);
      final file = File(p.join(dir.path, 'chapters.json'));
      if (!await file.exists()) {
        return const Result.err(AppError(AppErrorKind.file, '章节缓存不存在'));
      }
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      if (index < 0 || index >= list.length) {
        return const Result.err(AppError(AppErrorKind.parse, '章节索引越界'));
      }
      (list[index] as Map<String, dynamic>)['body'] = body;
      await file.writeAsString(jsonEncode(list));
      return const Result.ok(null);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '保存正文缓存'));
    }
  }

  /// 保存封面，返回文件路径。
  Future<Result<String>> writeCover(int bookId, Uint8List bytes, String ext) async {
    try {
      final dir = await _bookDir(bookId);
      final file = File(p.join(dir.path, 'cover.$ext'));
      await file.writeAsBytes(bytes);
      return Result.ok(file.path);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '保存封面'));
    }
  }

  /// 删除整本书的文件缓存。
  Future<void> deleteBook(int bookId) async {
    try {
      final root = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(root.path, 'books', '$bookId'));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // 文件清理失败不阻塞数据库删除
    }
  }
}
