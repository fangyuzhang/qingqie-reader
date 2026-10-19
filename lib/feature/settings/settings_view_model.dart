import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/repository/backup_repository.dart';
import '../../data/repository/book_source_repository.dart';
import '../../data/repository/bookshelf_repository.dart';
import '../../data/local/preferences_store.dart';

/// 设置 ViewModel：备份/恢复、主题、统计。
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required BookshelfRepository bookshelf,
    required BookSourceRepository sources,
    required BackupRepository backup,
    PreferencesStore? prefs,
  })  : _bookshelf = bookshelf,
        _sources = sources,
        _backup = backup,
        _prefs = prefs ?? PreferencesStore.instance;

  final BookshelfRepository _bookshelf;
  final BookSourceRepository _sources;
  final BackupRepository _backup;
  final PreferencesStore _prefs;

  String themeMode = 'system'; // system / light / dark
  int bookCount = 0;
  int sourceCount = 0;
  int noteCount = 0;
  String? message;

  Future<void> load() async {
    themeMode = await _prefs.read(PreferencesStore.keyThemeMode) ?? 'system';
    final books = (await _bookshelf.books()).valueOrNull ?? const [];
    final sources = (await _sources.all()).valueOrNull ?? const [];
    final notes = (await _backup.export()).valueOrNull;
    bookCount = books.length;
    sourceCount = sources.length;
    noteCount = _countNotes(notes);
    notifyListeners();
  }

  static int _countNotes(String? backupJson) {
    if (backupJson == null) return 0;
    try {
      final map = jsonDecode(backupJson) as Map<String, dynamic>;
      final list = map['notes'];
      return list is List ? list.length : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> setThemeMode(String mode) async {
    themeMode = mode;
    notifyListeners();
    await _prefs.write(PreferencesStore.keyThemeMode, mode);
  }

  /// 导出备份到应用目录，返回路径。
  Future<String?> exportBackup() async {
    final res = await _backup.export();
    return res.when(
      ok: (text) async {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final stamp = DateTime.now().millisecondsSinceEpoch;
          final file = File('${dir.path}/qingqie-backup-$stamp.json');
          await file.writeAsString(text);
          message = '备份已保存：${file.path}';
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

  /// 从 JSON 文件恢复。
  Future<void> importBackup() async {
    List<PlatformFile> files;
    try {
      files = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
    } catch (_) {
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
      message = '文件读取失败';
      notifyListeners();
      return;
    }
    final res = await _backup.import(text);
    res.when(
      ok: (report) async {
        message = '恢复完成：书籍 ${report.books} · 书源 ${report.sources} · 书签 ${report.bookmarks} · 笔记 ${report.notes}';
        await load();
      },
      err: (e) => message = e.message,
    );
    notifyListeners();
  }

  void consumeMessage() => message = null;
}
