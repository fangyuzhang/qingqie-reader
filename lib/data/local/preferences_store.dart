import 'package:shared_preferences/shared_preferences.dart';

/// 轻量偏好存储（阅读设置等非结构化配置）。
/// 结构化数据（书架/进度/书签/笔记/书源）一律走 sqflite，不放在这里。
class PreferencesStore {
  PreferencesStore._();
  static final PreferencesStore instance = PreferencesStore._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async => _prefs ??= await SharedPreferences.getInstance();

  static const String keyReaderSettings = 'reader_settings';
  static const String keyThemeMode = 'theme_mode'; // system / light / dark

  Future<String?> read(String key) async => (await _p).getString(key);

  Future<void> write(String key, String value) async => (await _p).setString(key, value);

  Future<void> remove(String key) async => (await _p).remove(key);
}
