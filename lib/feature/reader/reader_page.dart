import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/model/book.dart';
import '../../data/model/note.dart';
import '../../data/repository/book_source_repository.dart';
import '../../data/repository/bookshelf_repository.dart';
import '../../data/repository/reader_repository.dart';
import 'reader_view_model.dart';
import 'widgets/paginator.dart';
import 'widgets/reader_menu.dart';
import 'widgets/selection_toolbar.dart';
import 'widgets/text_block.dart';

/// 阅读器页：滚动/翻页双模式 + 选句批注 + 目录/排版/查找/书签/自动滚。
class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.book,
    required this.readerRepository,
    required this.shelfRepository,
    required this.sourceRepository,
  });

  final Book book;
  final ReaderRepository readerRepository;
  final BookshelfRepository shelfRepository;
  final BookSourceRepository sourceRepository;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final ReaderViewModel _vm = ReaderViewModel(
    widget.readerRepository,
    widget.shelfRepository,
    widget.sourceRepository,
  );

  final ScrollController _scroll = ScrollController();
  final PageController _pageController = PageController();
  final Map<int, GlobalKey> _paraKeys = {};
  final TextEditingController _findController = TextEditingController();

  Timer? _autoScrollTimer;
  bool _markExpanded = false;
  bool _findOpen = false;
  int _lastFindIndex = -1;

  List<List<TextPiece>>? _pagesCache;
  String _pagesCacheKey = '';

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onVmChanged);
    _scroll.addListener(_onScroll);
    _vm.openBook(widget.book);
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _pageController.dispose();
    _findController.dispose();
    _autoScrollTimer?.cancel();
    _vm.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_vm.settings.mode == ReaderMode.scroll) {
      _vm.onPositionChanged(_scroll.offset);
    }
  }

  void _onVmChanged() {
    if (!mounted) return;
    // 进度恢复：章节加载完成后跳到记录的偏移
    if (!_vm.loading && _vm.pendingOffset > 0) {
      final offset = _vm.pendingOffset;
      _vm.pendingOffset = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_vm.settings.mode == ReaderMode.scroll && _scroll.hasClients) {
          _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
        } else if (_pageController.hasClients) {
          _pageController.jumpTo(offset.toInt().clamp(0, 9999));
        }
      });
    }
    // 查找跳转
    if (_vm.findHits.isNotEmpty && _vm.findIndex != _lastFindIndex) {
      _lastFindIndex = _vm.findIndex;
      _jumpToFind();
    }
    _syncAutoScroll();
  }

  void _jumpToFind() {
    final hit = _vm.findHits[_vm.findIndex];
    final key = _paraKeys[hit.paragraph];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.4,
      );
    }
  }

  void _syncAutoScroll() {
    if (_vm.autoScrolling && _autoScrollTimer == null) {
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!_scroll.hasClients) return;
        final next = _scroll.offset + _vm.settings.autoScrollSpeed * 0.15;
        if (next >= _scroll.position.maxScrollExtent) {
          _vm.toggleAutoScroll();
          return;
        }
        _scroll.jumpTo(next);
      });
    } else if (!_vm.autoScrolling && _autoScrollTimer != null) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = vm.settings.background(dark);
    final fg = vm.settings.foreground(dark);
    final style = TextStyle(
      fontSize: vm.settings.fontSize,
      height: vm.settings.lineHeight,
      color: fg,
      fontFamily: vm.settings.font.family,
    );

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // 正文区域
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) {
              final height = MediaQuery.sizeOf(context).height;
              final y = details.globalPosition.dy;
              // 点屏幕中央区域呼出/隐藏工具栏
              if (y > height * 0.25 && y < height * 0.78) {
                vm.toggleChrome();
              }
            },
            child: _buildBody(vm, style, bg),
          ),
          // 顶部工具栏
          if (vm.chromeVisible) _buildTopBar(vm),
          // 查找栏
          if (_findOpen) _buildFindBar(vm),
          // 底部工具栏
          if (vm.chromeVisible) _buildBottomBar(vm),
          // 选区工具条
          if (vm.selection != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: vm.chromeVisible ? 108 : 24,
              child: Center(
                child: SelectionToolbar(
                  selectedText: vm.selectedText,
                  expanded: _markExpanded,
                  onToggleExpand: () => setState(() => _markExpanded = !_markExpanded),
                  onMark: (color) async {
                    await vm.addMark(color);
                    setState(() => _markExpanded = false);
                  },
                  onAnnot: () => _showAnnotDialog(vm),
                  onExcerpt: () => vm.addExcerpt(),
                  onCancel: () {
                    vm.clearSelection();
                    setState(() => _markExpanded = false);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- 正文 ----

  Widget _buildBody(ReaderViewModel vm, TextStyle style, Color bg) {
    if (vm.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.paragraphs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            vm.errorMessage ?? '本章暂无内容',
            textAlign: TextAlign.center,
            style: TextStyle(color: style.color?.withValues(alpha: .7)),
          ),
        ),
      );
    }
    if (vm.settings.mode == ReaderMode.paged) {
      return _buildPaged(vm, style);
    }
    return _buildScroll(vm, style);
  }

  Widget _buildScroll(ReaderViewModel vm, TextStyle style) {
    final annotBlocks = vm.annotBlocksByParagraph;
    final sel = vm.selection;
    final findActive = _findOpen && vm.findHits.isNotEmpty;
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        vm.settings.margin,
        MediaQuery.paddingOf(context).top + 56,
        vm.settings.margin,
        120,
      ),
      itemCount: vm.paragraphs.length,
      itemBuilder: (context, i) {
        final key = _paraKeys.putIfAbsent(i, () => GlobalKey());
        // 选中范围：用户选句优先，否则查找命中
        (int, int)? range;
        if (sel != null && sel.paragraph == i) {
          range = (sel.start, sel.end);
        } else if (findActive && vm.findHits[vm.findIndex].paragraph == i) {
          final hit = vm.findHits[vm.findIndex];
          range = (hit.start, hit.end);
        }
        final blocks = annotBlocks[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              key: key,
              padding: EdgeInsets.only(bottom: vm.settings.paragraphGap),
              child: TextBlock(
                pieces: vm.piecesForParagraph(i),
                style: style,
                selectedRange: range,
                onLongPressAt: (offset) => vm.onLongPressParagraph(i, offset),
              ),
            ),
            if (blocks != null)
              for (final note in blocks)
                _NoteBlock(
                  note: note,
                  onDelete: () => vm.deleteNote(note.id ?? 0),
                ),
          ],
        );
      },
    );
  }

  Widget _buildPaged(ReaderViewModel vm, TextStyle style) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = vm.settings;
        final key = [
          vm.chapterIndex,
          s.fontSize,
          s.lineHeight,
          s.font.name,
          s.paper.name,
          s.margin.toInt(),
          constraints.maxWidth.toInt(),
          constraints.maxHeight.toInt(),
        ].join('|');
        if (_pagesCache == null || _pagesCacheKey != key) {
          final topPad = MediaQuery.paddingOf(context).top + 56;
          _pagesCache = Paginator.paginate(
            paragraphs: vm.paragraphs,
            piecesForParagraph: vm.piecesForParagraph,
            style: style,
            width: constraints.maxWidth - s.margin * 2,
            height: constraints.maxHeight - topPad - 100,
          );
          _pagesCacheKey = key;
        }
        return PageView.builder(
          controller: _pageController,
          itemCount: _pagesCache!.length,
          onPageChanged: (page) => vm.onPageChanged(page),
          itemBuilder: (context, page) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                s.margin,
                MediaQuery.paddingOf(context).top + 56,
                s.margin,
                100,
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: TextBlock(
                  pieces: _pagesCache![page],
                  style: style,
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---- 工具栏 ----

  Widget _buildTopBar(ReaderViewModel vm) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: vm.settings.background(Theme.of(context).brightness == Brightness.dark),
        elevation: 3,
        child: SafeArea(
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vm.book?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (vm.chapters.isNotEmpty)
                        Text(
                          '${vm.chapterIndex + 1}/${vm.chapters.length} ${vm.chapters[vm.chapterIndex].title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: vm.bookmarked ? '移除书签' : '加书签',
                  icon: Icon(vm.bookmarked ? Icons.bookmark : Icons.bookmark_border),
                  color: vm.bookmarked ? const Color(0xFFE85D26) : null,
                  onPressed: vm.toggleBookmark,
                ),
                PopupMenuButton<String>(
                  tooltip: '更多',
                  onSelected: (value) async {
                    switch (value) {
                      case 'toc':
                        await ReaderMenu.showToc(context, vm);
                      case 'typeset':
                        await ReaderMenu.showTypeset(context, vm);
                      case 'find':
                        setState(() => _findOpen = true);
                      case 'autoscroll':
                        vm.toggleAutoScroll();
                      case 'night':
                        vm.toggleNight();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'toc', child: Text('目录')),
                    PopupMenuItem(value: 'typeset', child: Text('排版')),
                    PopupMenuItem(value: 'find', child: Text('章内查找')),
                    PopupMenuItem(value: 'autoscroll', child: Text('自动滚动')),
                    PopupMenuItem(value: 'night', child: Text('夜间模式')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ReaderViewModel vm) {
    final s = vm.settings;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: vm.settings.background(Theme.of(context).brightness == Brightness.dark),
        elevation: 8,
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BarButton(
                  icon: Icons.skip_previous,
                  label: '上一章',
                  enabled: vm.chapterIndex > 0,
                  onTap: vm.prevChapter,
                ),
                _BarButton(
                  icon: Icons.list,
                  label: '目录',
                  onTap: () => ReaderMenu.showToc(context, vm),
                ),
                _BarButton(
                  icon: Icons.text_fields,
                  label: '排版',
                  onTap: () => ReaderMenu.showTypeset(context, vm),
                ),
                _BarButton(
                  icon: Icons.search,
                  label: '查找',
                  onTap: () => setState(() => _findOpen = true),
                ),
                _BarButton(
                  icon: s.paper == ReaderPaper.night ? Icons.light_mode : Icons.dark_mode,
                  label: s.paper == ReaderPaper.night ? '日间' : '夜间',
                  onTap: vm.toggleNight,
                ),
                _BarButton(
                  icon: vm.autoScrolling ? Icons.pause_circle : Icons.play_circle,
                  label: vm.autoScrolling ? '停止' : '自动滚',
                  onTap: vm.toggleAutoScroll,
                ),
                _BarButton(
                  icon: Icons.skip_next,
                  label: '下一章',
                  enabled: vm.chapterIndex < vm.chapters.length - 1,
                  onTap: vm.nextChapter,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFindBar(ReaderViewModel vm) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 52,
      left: 0,
      right: 0,
      child: Material(
        elevation: 4,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _findController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '本章内查找',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    suffixText: vm.findHits.isEmpty
                        ? (vm.findQuery.isEmpty ? '' : '0 处')
                        : '${vm.findIndex + 1}/${vm.findHits.length}',
                  ),
                  onChanged: vm.runFind,
                  onSubmitted: (_) => vm.findNext(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed: vm.findPrev,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: vm.findNext,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() => _findOpen = false);
                  _findController.clear();
                  vm.closeFind();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAnnotDialog(ReaderViewModel vm) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('写想法'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            decoration: const InputDecoration(hintText: '写下你的想法，保存后显示在原文下方'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (text != null && text.isNotEmpty) {
      await vm.addAnnot(text);
    }
  }
}

/// 底部工具栏按钮。
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 9.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 行内批注块（蜗牛读书式：米色底 + 「批」角标，可折叠/删除）。
class _NoteBlock extends StatefulWidget {
  const _NoteBlock({required this.note, required this.onDelete});

  final Note note;
  final VoidCallback onDelete;

  @override
  State<_NoteBlock> createState() => _NoteBlockState();
}

class _NoteBlockState extends State<_NoteBlock> {
  bool _folded = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEADFC8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFD64545),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text('批', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _folded = !_folded),
              child: Text(
                note.thought,
                maxLines: _folded ? 1 : null,
                overflow: _folded ? TextOverflow.ellipsis : TextOverflow.visible,
                style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF6B5B3E)),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFB0A08A)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}
