import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

/// 错误分类：UI 层据此选择提示图标与重试策略。
enum AppErrorKind {
  network, // 网络不通 / DNS / 连接被拒
  timeout, // 超时
  parse, // 文件格式 / 编码 / 规则解析失败
  file, // 文件读写失败（权限、空间）
  database, // 本地数据库失败
  cancelled, // 用户主动取消
  unknown, // 未分类
}

/// 全应用统一错误对象。
///
/// 约束（来自任务书）：Repository 捕获的一切异常都必须包装成 AppError 再向上抛，
/// ViewModel 只面对友好文案，Widget 不感知底层异常类型。
class AppError implements Exception {
  const AppError(this.kind, this.message, {this.cause});

  final AppErrorKind kind;
  final String message;
  final Object? cause;

  /// 把任意异常映射为中文友好文案。
  factory AppError.wrap(Object error, {String? context}) {
    if (error is AppError) return error;
    final p = (context == null || context.isEmpty) ? '' : '$context失败：';
    if (error is TimeoutException) {
      return AppError(AppErrorKind.timeout, '${p}连接超时，请检查网络后重试', cause: error);
    }
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          AppError(AppErrorKind.timeout, '${p}连接超时，请检查网络后重试', cause: error),
        DioExceptionType.connectionError =>
          AppError(AppErrorKind.network, '${p}网络连接失败，请检查网络或代理', cause: error),
        DioExceptionType.badResponse => AppError(
          AppErrorKind.network,
          '${p}服务器返回错误（HTTP ${error.response?.statusCode ?? '?'}）',
          cause: error,
        ),
        _ => AppError(AppErrorKind.network, '${p}网络请求未完成，请重试', cause: error),
      };
    }
    if (error is HandshakeException) {
      return AppError(AppErrorKind.network, '${p}证书验证失败，请检查站点 HTTPS 配置', cause: error);
    }
    if (error is SocketException) {
      return AppError(AppErrorKind.network, '${p}无法连接服务器，请检查网络', cause: error);
    }
    if (error is DatabaseException) {
      return AppError(AppErrorKind.database, '${p}本地数据读写失败，请重启应用重试', cause: error);
    }
    if (error is FileSystemException) {
      final noSpace = error.osError?.errorCode == 28;
      return AppError(
        AppErrorKind.file,
        noSpace ? '${p}存储空间不足，请清理后重试' : '${p}文件读写失败，请检查存储权限与空间',
        cause: error,
      );
    }
    if (error is FormatException) {
      final m = error.message;
      return AppError(AppErrorKind.parse, p + (m.isEmpty ? '文件格式不受支持' : m), cause: error);
    }
    if (error is RangeError) {
      return AppError(AppErrorKind.parse, '${p}文件内容不完整或已损坏', cause: error);
    }
    return AppError(AppErrorKind.unknown, '${p}发生未知错误，请重试', cause: error);
  }

  @override
  String toString() => message;
}
