import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';

import '../../core/app_error.dart';
import '../../core/result.dart';

  /// TXT 编码检测与解码。
  ///
  /// 【新增】原项目 local_text_import.dart 直接用 utf8.decoder 硬解码，GBK/GB18030
  /// 小说会乱码（实际靠原生 document bridge 预先转码）。本项目在 Dart 层完成检测：
  /// BOM → UTF-8 严格试探 → GB18030（超集，兼容 GBK）→ 友好报错。
  /// 注：中文 TXT 实际只有 UTF-8 / GB18030 两类主流编码，UTF-16 场景罕见，暂不支持。
class CharsetDecoder {
  const CharsetDecoder._();

  static const List<int> _utf8Bom = [0xEF, 0xBB, 0xBF];

  static Future<Result<String>> decodeText(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return const Result.err(AppError(AppErrorKind.parse, '文件为空'));
    }
    // 1. UTF-8 BOM
    if (_hasPrefix(bytes, _utf8Bom)) {
      try {
        return Result.ok(_stripBom(utf8.decode(bytes.sublist(3))));
      } catch (e) {
        return Result.err(AppError.wrap(e, context: 'UTF-8 解码'));
      }
    }
    // 2. UTF-8 严格试探
    try {
      return Result.ok(_stripBom(utf8.decode(bytes)));
    } catch (_) {
      // 不是 UTF-8，继续尝试 GB18030
    }
    // 3. GB18030（Android 原生 Charset，兼容 GBK）
    try {
      final text = await CharsetConverter.decode('GB18030', bytes);
      if (text != null && text.isNotEmpty) {
        return Result.ok(_stripBom(text));
      }
    } catch (_) {
      // 平台不支持时落到统一报错
    }
    return const Result.err(
      AppError(AppErrorKind.parse, '无法识别文本编码（支持 UTF-8 / UTF-16 / GB18030）'),
    );
  }

  static bool _hasPrefix(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static String _stripBom(String s) =>
      s.startsWith('\uFEFF') ? s.substring(1) : s;
}
