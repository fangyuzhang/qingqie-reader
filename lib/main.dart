import 'package:flutter/material.dart';

import 'app.dart';
import 'data/repository/bookshelf_repository.dart';

/// 入口：初始化数据库默认数据后启动应用。
/// 依赖装配在 QingqieApp 内完成（provider），此处只做启动前置。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 确保默认分类存在（幂等）
  await BookshelfRepository().ensureReady();
  runApp(const QingqieApp());
}
