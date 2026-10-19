import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/book.dart';
import '../../data/model/book_source.dart';
import '../../data/model/search_item.dart';
import 'search_view_model.dart';

/// 在线搜索页：书源选择 → 关键词 → 结果 → 目录预览 → 加入书架。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.onOpenBook});

  final void Function(Book book) onOpenBook;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchViewModel>().loadSources();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    if (vm.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toast(vm.message!);
        vm.consumeMessage();
      });
    }
    // 目录预览面板
    if (vm.previewItem != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showTocSheet(context, vm));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F1E7),
        surfaceTintColor: Colors.transparent,
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索书名或作者',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: vm.search,
          ),
        ),
      ),
      body: Column(
        children: [
          // 书源选择
          if (vm.available.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  const Text('书源：', style: TextStyle(fontSize: 12, color: Color(0xFF9A8B72))),
                  const SizedBox(width: 4),
                  Expanded(
                    child: DropdownButton<BookSource>(
                      isExpanded: true,
                      value: vm.selected,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final s in vm.available)
                          DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: vm.selectSource,
                    ),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('没有可用的书源，请先到「书源」页添加', style: TextStyle(color: Color(0xFF9A8B72))),
            ),
          Expanded(
            child: vm.searching
                ? const Center(child: CircularProgressIndicator())
                : vm.results.isEmpty
                    ? Center(
                        child: Text(
                          vm.keyword.isEmpty ? '输入关键词开始搜索' : '没有找到相关书籍',
                          style: const TextStyle(color: Color(0xFFB3A48C)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: vm.results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _ResultCard(
                          item: vm.results[i],
                          onTap: () => vm.openToc(vm.results[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showTocSheet(BuildContext context, SearchViewModel vm) {
    final item = vm.previewItem;
    if (item == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            Text('${item.author} · ${item.sourceName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(ctx);
                          vm.closePreview();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: vm.loadingToc
                      ? const Center(child: CircularProgressIndicator())
                      : vm.previewToc == null
                          ? const Center(child: Text('目录抓取失败'))
                          : ListView.builder(
                              controller: controller,
                              itemCount: vm.previewToc!.length,
                              itemBuilder: (context, i) {
                                final ch = vm.previewToc![i];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    '${ch.index + 1}. ${ch.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              },
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: vm.previewToc == null
                          ? null
                          : () async {
                              final book = await vm.addToShelf();
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              vm.closePreview();
                              if (book != null && mounted) {
                                widget.onOpenBook(book);
                              }
                            },
                      child: const Text('加入书架'),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item, required this.onTap});

  final SearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFE6D4),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.title.length > 4 ? item.title.substring(0, 4) : item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A7B62)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(item.author, style: const TextStyle(fontSize: 12, color: Color(0xFF9A8B72))),
                    if (item.intro.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.intro,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB3A48C)),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFC9BBA6)),
            ],
          ),
        ),
      ),
    );
  }
}
