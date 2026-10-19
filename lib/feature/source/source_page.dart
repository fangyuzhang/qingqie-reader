import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/book_source.dart';
import 'source_view_model.dart';

/// 书源管理页：导入/导出/启停/排序/校验/编辑。
class SourcePage extends StatefulWidget {
  const SourcePage({super.key, this.onOpenSearch});

  /// 点击「搜索」图标打开在线搜索页。
  final VoidCallback? onOpenSearch;

  @override
  State<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends State<SourcePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SourceViewModel>().load();
    });
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SourceViewModel>();
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
        title: const Text('书源'),
        actions: [
          if (widget.onOpenSearch != null)
            IconButton(
              tooltip: '在线搜索',
              icon: const Icon(Icons.search),
              onPressed: widget.onOpenSearch,
            ),
          IconButton(
            tooltip: '导入书源文件',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: vm.importFromFile,
          ),
          IconButton(
            tooltip: '导出书源',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: vm.exportToFile,
          ),
          IconButton(
            tooltip: '手动添加',
            icon: const Icon(Icons.add),
            onPressed: () => _showAddSheet(context, vm),
          ),
        ],
      ),
      body: vm.loading && vm.sources.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : vm.sources.isEmpty
              ? _EmptySources(onAdd: () => _showAddSheet(context, vm))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: vm.sources.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final source = vm.sources[i];
                    return _SourceCard(
                      source: source,
                      validating: vm.validatingId == source.id,
                      onToggle: () => vm.toggle(source),
                      onValidate: () => vm.validate(source),
                      onMoveUp: i > 0 ? () => vm.move(source, -1) : null,
                      onMoveDown: i < vm.sources.length - 1 ? () => vm.move(source, 1) : null,
                      onDelete: () => _confirmDelete(context, vm, source),
                    );
                  },
                ),
    );
  }

  void _confirmDelete(BuildContext context, SourceViewModel vm, BookSource source) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除书源'),
        content: Text('确定删除「${source.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.remove(source);
            },
            child: const Text('删除', style: TextStyle(color: Color(0xFFD64545))),
          ),
        ],
      ),
    );
  }

  /// 手动添加：粘贴 YAML。
  void _showAddSheet(BuildContext context, SourceViewModel vm) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('粘贴书源 YAML', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 12,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'bookSourceName: ...\nbookSourceUrl: ...\nsearch: ...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx);
                    vm.add(text);
                  },
                  child: const Text('添加书源'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.validating,
    required this.onToggle,
    required this.onValidate,
    this.onMoveUp,
    this.onMoveDown,
    required this.onDelete,
  });

  final BookSource source;
  final bool validating;
  final VoidCallback onToggle;
  final VoidCallback onValidate;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE4D3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Switch(value: source.enabled, onChanged: (_) => onToggle),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            source.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9A8B72)),
          ),
          if (source.group.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EDE0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(source.group, style: const TextStyle(fontSize: 10, color: Color(0xFF8A7B62))),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: onValidate,
                icon: validating
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.health_and_safety_outlined, size: 16),
                label: const Text('校验'),
              ),
              IconButton(
                tooltip: '上移',
                icon: const Icon(Icons.arrow_upward, size: 18),
                onPressed: onMoveUp,
              ),
              IconButton(
                tooltip: '下移',
                icon: const Icon(Icons.arrow_downward, size: 18),
                onPressed: onMoveDown,
              ),
              const Spacer(),
              IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFD64545)),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySources extends StatelessWidget {
  const _EmptySources({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.source_outlined, size: 60, color: Colors.brown.shade200),
          const SizedBox(height: 12),
          const Text('还没有书源', style: TextStyle(color: Color(0xFF9A8B72))),
          const SizedBox(height: 4),
          const Text('导入 YAML/JSON 书源后即可在线搜索', style: TextStyle(color: Color(0xFFB3A48C))),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAdd, child: const Text('添加书源')),
        ],
      ),
    );
  }
}
