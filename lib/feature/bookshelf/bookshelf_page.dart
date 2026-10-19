import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/book.dart';
import '../../data/model/category.dart';
import 'bookshelf_view_model.dart';
import 'shelf3d.dart';
import 'shelf_geometry.dart';

/// 书架页：立体书架 / 列表视图 + 分类 + 本地搜索 + 导入入口。
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key, required this.onOpenBook});

  final void Function(Book book) onOpenBook;

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookshelfViewModel>();
    // 展示一次性操作消息
    if (vm.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toast(vm.message!);
        vm.consumeMessage();
      });
    }
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F1E7),
        surfaceTintColor: Colors.transparent,
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索书架（书名 / 作者）',
                  border: InputBorder.none,
                ),
                onChanged: vm.search,
              )
            : const Text('书架'),
        actions: [
          IconButton(
            tooltip: '搜索',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) {
                _searchCtrl.clear();
                vm.search('');
              }
            },
          ),
          IconButton(
            tooltip: vm.shelf3D ? '切换列表视图' : '切换立体书架',
            icon: Icon(vm.shelf3D ? Icons.view_list_outlined : Icons.auto_awesome_motion),
            onPressed: vm.toggleView,
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              if (value == 'category') _showCategoryManager(context, vm);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'category', child: Text('分类管理')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _CategoryBar(vm: vm),
          Expanded(
            child: vm.loading
                ? const Center(child: CircularProgressIndicator())
                : vm.books.isEmpty
                    ? _EmptyShelf(onImport: () => vm.importLocal())
                    : vm.shelf3D
                        ? Shelf3D(
                            books: vm.books,
                            onOpen: widget.onOpenBook,
                            onLongPress: (book) => _showBookActions(context, vm, book),
                          )
                        : _BookList(
                            vm: vm,
                            onOpen: widget.onOpenBook,
                            onLongPress: (book) => _showBookActions(context, vm, book),
                          ),
          ),
          if (vm.books.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 98),
              child: Text(
                vm.shelf3D ? '拖动旋转书架 · 点封面开始阅读' : '长按书籍可移动分组或移除',
                style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF9A8B72)),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE85D26),
        foregroundColor: Colors.white,
        onPressed: () async {
          final book = await vm.importLocal();
          if (book != null && mounted) {
            widget.onOpenBook(book);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('导入书籍'),
      ),
    );
  }

  void _showBookActions(BuildContext context, BookshelfViewModel vm, Book book) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book),
                title: Text(book.title),
                subtitle: Text('${book.author} · ${book.chapterCount} 章'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.drive_file_move),
                title: const Text('移动分组'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMoveDialog(context, vm, book);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFD64545)),
                title: const Text('移出书架', style: TextStyle(color: Color(0xFFD64545))),
                onTap: () {
                  Navigator.pop(ctx);
                  vm.removeBook(book);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showMoveDialog(BuildContext context, BookshelfViewModel vm, Book book) {
    showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('移动到分组'),
          children: [
            for (final c in vm.categories)
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(ctx);
                  vm.moveBook(book, c.id);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(c.name + (c.id == book.categoryId ? '（当前）' : '')),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showCategoryManager(BuildContext context, BookshelfViewModel vm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('分类管理'),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in vm.categories)
                  ListTile(
                    dense: true,
                    title: Text(c.name),
                    trailing: c.id <= 1
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () {
                              Navigator.pop(ctx);
                              vm.deleteCategory(c.id);
                            },
                          ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: '新分类名称',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) vm.createCategory(name);
                controller.clear();
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }
}

/// 分类筛选条。
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.vm});

  final BookshelfViewModel vm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('全部'),
              selected: vm.selectedCategory == 0,
              onSelected: (_) => vm.selectCategory(0),
            ),
          ),
          for (final BookCategory c in vm.categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c.name),
                selected: vm.selectedCategory == c.id,
                onSelected: (_) => vm.selectCategory(c.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// 空书架提示。
class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.onImport});

  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 64, color: Colors.brown.shade200),
          const SizedBox(height: 12),
          const Text('书架空空如也', style: TextStyle(color: Color(0xFF9A8B72))),
          const SizedBox(height: 4),
          const Text('导入 TXT / EPUB，或去书源页搜索', style: TextStyle(color: Color(0xFFB3A48C))),
          const SizedBox(height: 16),
          FilledButton(onPressed: onImport, child: const Text('导入本地书籍')),
        ],
      ),
    );
  }
}

/// 传统列表视图。
class _BookList extends StatelessWidget {
  const _BookList({required this.vm, required this.onOpen, required this.onLongPress});

  final BookshelfViewModel vm;
  final void Function(Book) onOpen;
  final void Function(Book) onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      itemCount: vm.books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final book = vm.books[i];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onOpen(book),
            onLongPress: () => onLongPress(book),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _MiniCover(book: book),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${book.author.isEmpty ? '佚名' : book.author} · ${book.chapterCount} 章',
                          style: const TextStyle(color: Color(0xFF9A8B72), fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        const ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            backgroundColor: Color(0xFFEDE4D3),
                            valueColor: AlwaysStoppedAnimation(Color(0xFFE85D26)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFFC9BBA6)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniCover extends StatelessWidget {
  const _MiniCover({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final (c1, c2) = ShelfGeometry.paletteFor(book.title);
    int hex(String v) {
      var s = v.replaceFirst('#', '');
      if (s.length == 6) s = 'FF$s';
      return int.parse(s, radix: 16);
    }

    return Container(
      width: 46,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(hex(c1)), Color(hex(c2))],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: Text(
        book.title.length > 4 ? book.title.substring(0, 4) : book.title,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
