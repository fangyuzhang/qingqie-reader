import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/app_error.dart';
import '../../core/result.dart';

/// 网络客户端（dio 封装）。
/// 约束：所有网络请求必须经过本类，Widget/ViewModel 不得直接持有 Dio。
class AppHttpClient {
  AppHttpClient._() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.plain,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 12; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/124.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9',
        },
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );
  }

  static final AppHttpClient instance = AppHttpClient._();

  late final Dio _dio;

  /// GET/POST 文本（书源抓取统一入口）。
  Future<Result<String>> requestText(
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    Map<String, String>? form,
    int maxBytes = 2 * 1024 * 1024,
  }) async {
    try {
      final res = await _dio.request<dynamic>(
        url,
        options: Options(method: method, headers: headers),
        data: form == null ? null : FormData.fromMap(form),
      );
      final data = res.data;
      if (data is! String) {
        return const Result.err(AppError(AppErrorKind.parse, '目标返回的不是文本内容'));
      }
      if (data.length > maxBytes) {
        return Result.err(
          AppError(AppErrorKind.network, '页面过大（>${maxBytes ~/ 1024}KB），已停止抓取'),
        );
      }
      return Result.ok(data);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '网络请求'));
    }
  }

  /// GET 二进制（EPUB 封面等）。
  Future<Result<Uint8List>> requestBytes(String url, {int maxBytes = 4 * 1024 * 1024}) async {
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = res.data;
      if (data == null) {
        return const Result.err(AppError(AppErrorKind.parse, '目标返回内容为空'));
      }
      final bytes = Uint8List.fromList(data);
      if (bytes.length > maxBytes) {
        return const Result.err(AppError(AppErrorKind.network, '文件过大，已停止下载'));
      }
      return Result.ok(bytes);
    } catch (e) {
      return Result.err(AppError.wrap(e, context: '下载'));
    }
  }
}
