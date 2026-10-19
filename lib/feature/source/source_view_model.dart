import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/model/book_source.dart';
import '../../data/repository/book_source_repository.dart';

/// 书源管理 ViewModel：CRUD + 导入导出 + 启停 + 排序 + 校验。
class SourceViewModel extends ChangeNotifier {
  SourceViewModel(this._repo);

  final BookSourceRepository _repo;

  List<BookSource> sources = const [];
  bool loading = false;
  String? message;
  int? validatingId;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    final res = await _repo.all();
    sources = res.valueOrNull ?? const [];
    loading = false;
    notifyListeners();
  }

  void consumeMessage() => message = null;

  Future<void> add(String yamlText) async {
    final res = await _repo.add(yamlText);
    res.when(
      ok: (_) async {
        await load();
        message = '书源已添加';
      },
      err: (e) => message = e.message,
    );
    notifyListeners();
  }

  /// 从文件导入（yaml/yml/json）。
  Future<void> importFromFile() async {
    List<PlatformFile> files;
    try {
      files = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['yaml', 'yml', 'json'],
      );
    } catch (e) {
      message = '无法打开文件选择器';
      notifyListeners();
      return;
    }
    if (files.isEmpty) {
      message = '已取消选择';
      notifyListeners();
      return;
    }
    String text;
    try {
      final data = await files.first.readAsBytes();
      if (data == null || data.isEmpty) {
        message = '文件为空';
        notifyListeners();
        return;
      }
      text = utf8.decode(data);
    } catch (_) {
      message = '文件读取失败（请确认是 UTF-8 编码的 YAML/JSON）';
      notifyListeners();
      return;
    }
    final res = await _repo.importText(text);
    res.when(
      ok: (report) async {
        await load();
        message = report.errors.isEmpty
            ? '成功导入 ${report.added} 条书源'
            : '导入 ${report.added} 条，失败 ${report.errors.length} 条：${report.errors.first}';
      },
      err: (e) => message = e.message,
    );
    notifyListeners();
  }

  /// 导出到应用目录，返回文件路径。
  Future<String?> exportToFile() async {
    final res = await _repo.exportYaml();
    return res.when(
      ok: (text) async {
        if (text.trim().isEmpty) {
          message = '没有可导出的书源';
          notifyListeners();
          return null;
        }
        try {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/qingqie-sources.yaml');
          await file.writeAsString(text);
          message = '已导出到：${file.path}';
          notifyListeners();
          return file.path;
        } catch (_) {
          message = '导出失败，请检查存储空间';
          notifyListeners();
          return null;
        }
      },
      err: (e) {
        message = e.message;
        notifyListeners();
        return null;
      },
    );
  }

  Future<void> toggle(BookSource source) async {
    await _repo.setEnabled(source.id ?? 0, !source.enabled);
    await load();
  }

  Future<void> remove(BookSource source) async {
    await _repo.remove(source.id ?? 0);
    await load();
    message = '已删除《${source.name}》';
    notifyListeners();
  }

  Future<void> move(BookSource source, int delta) async {
    await _repo.move(source.id ?? 0, delta);
    await load();
  }

  Future<void> validate(BookSource source) async {
    validatingId = source.id;
    notifyListeners();
    final res = await _repo.validate(source.id ?? 0);
    res.when(
      ok: (msg) => message = msg,
      err: (e) => message = e.message,
    );
    validatingId = null;
    notifyListeners();
  }
}
