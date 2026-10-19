import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'settings_view_model.dart';

/// 设置页（我的）：备份/恢复、外观、统计、关于。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsViewModel>().load();
    });
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 4)));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    if (vm.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toast(vm.message!);
        vm.consumeMessage();
      });
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F1E7),
        surfaceTintColor: Colors.transparent,
        title: const Text('我的'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Section(
            title: '书架数据',
            children: [
              _Tile(
                icon: Icons.upload_file,
                title: '导出备份',
                subtitle: '书架 / 进度 / 书签 / 笔记 / 书源 → JSON 文件',
                onTap: () => vm.exportBackup(),
              ),
              _Tile(
                icon: Icons.download,
                title: '恢复备份',
                subtitle: '从备份 JSON 恢复（按 ID 覆盖）',
                onTap: () => vm.importBackup(),
              ),
              const _Hint(text: '备份不含本地 TXT/EPUB 原文件，恢复后请重新链接原书文件。'),
            ],
          ),
          _Section(
            title: '外观',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'system', label: Text('跟随系统')),
                    ButtonSegment(value: 'light', label: Text('日间')),
                    ButtonSegment(value: 'dark', label: Text('夜间')),
                  ],
                  selected: {vm.themeMode},
                  onSelectionChanged: (v) => vm.setThemeMode(v.first),
                ),
              ),
            ],
          ),
          _Section(
            title: '统计',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(value: '${vm.bookCount}', label: '书架藏书'),
                    _Stat(value: '${vm.sourceCount}', label: '书源'),
                    _Stat(value: '${vm.noteCount}', label: '笔记'),
                  ],
                ),
              ),
            ],
          ),
          _Section(
            title: '关于',
            children: [
              const _Tile(
                icon: Icons.info_outline,
                title: '青茄阅读',
                subtitle: 'v0.1.0 · 基于 Wenku8_Flutter（GPL-3.0）重构',
              ),
              const _Tile(
                icon: Icons.shield_outlined,
                title: '免责声明',
                subtitle: '本项目仅用于个人学习研究；书源规则仅为网页解析规则，禁止用于小说盗版抓取与传播',
              ),
              const _Tile(
                icon: Icons.description_outlined,
                title: '开源协议',
                subtitle: 'GPL-3.0 · 保留原项目版权声明（见 LICENSE 与 NOTICE）',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF9A8B72), fontWeight: FontWeight.w700)),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFE85D26)),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(fontSize: 11)),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right, size: 18),
      onTap: onTap == null ? null : () => onTap!(),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFFB3A48C))),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFE85D26))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9A8B72))),
      ],
    );
  }
}
