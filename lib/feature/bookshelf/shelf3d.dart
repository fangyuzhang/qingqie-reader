import 'package:flutter/material.dart';

import '../../data/model/book.dart';
import 'shelf_geometry.dart';

/// 立体书架（立式排布 · 斜视图 · 选中上浮）。
/// 几何算法移植自 Wenku8_Flutter（见 shelf_geometry.dart），
/// 交互（拖拽/吸附/点击）为本项目按同等手感重写。
class Shelf3D extends StatefulWidget {
  const Shelf3D({
    super.key,
    required this.books,
    required this.onOpen,
    this.onLongPress,
    this.initialIndex = 0,
  });

  final List<Book> books;
  final void Function(Book book) onOpen;
  final void Function(Book book)? onLongPress;
  final int initialIndex;

  @override
  State<Shelf3D> createState() => _Shelf3DState();
}

class _Shelf3DState extends State<Shelf3D> {
  final ScrollController _scroll = ScrollController();
  double _focus = 0;

  @override
  void initState() {
    super.initState();
    _focus = widget.initialIndex.toDouble();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(_focus));
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pitch = _pitchOf(context);
    if (pitch <= 0) return;
    final next = _scroll.offset / pitch;
    if ((next - _focus).abs() > 0.0005) {
      setState(() => _focus = next);
    }
  }

  double _pitchOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ShelfGeometry.pitchFor(width);
  }

  void _jumpTo(double focus) {
    if (!_scroll.hasClients) return;
    final pitch = _pitchOf(context);
    _scroll.jumpTo(focus * pitch);
  }

  void _animateTo(double focus) {
    if (!_scroll.hasClients) return;
    final pitch = _pitchOf(context);
    final target = (focus * pitch).clamp(
      _scroll.position.minScrollExtent,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  void _onScrollEnd(ScrollEndNotification notification) {
    _animateTo(_focus.roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.books;
    if (books.isEmpty) {
      return const Center(child: Text('这个分组还没有书', style: TextStyle(color: Colors.grey)));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final spine = ShelfGeometry.spineFor(width);
        final cover = ShelfGeometry.coverFor(width);
        final pitch = ShelfGeometry.pitchFor(width);
        final bookHeight = ShelfGeometry.bodyHeight(cover);
        final foot = ShelfGeometry.footprint(spine, cover);
        final padTop = cover * 0.30 + 8;
        final contentWidth = books.length * pitch + width;
        // 书身在舞台中的基准高度（选中书上浮后仍不越界）
        final stageHeight = height;

        return NotificationListener<ScrollEndNotification>(
          onNotification: (n) {
            _onScrollEnd(n);
            return false;
          },
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            // 自由滚动 + 滚动结束时按 pitch 整数位自定义吸附（不用 PageScrollPhysics，
            // 因为它会按视口宽度而不是书距吸附）
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: contentWidth,
              height: stageHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < books.length; i++)
                    _buildBook(
                      book: books[i],
                      index: i,
                      width: width,
                      spine: spine,
                      cover: cover,
                      pitch: pitch,
                      bookHeight: bookHeight,
                      foot: foot,
                      padTop: padTop,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBook({
    required Book book,
    required int index,
    required double width,
    required double spine,
    required double cover,
    required double pitch,
    required double bookHeight,
    required double foot,
    required double padTop,
  }) {
    final d = index - _focus;
    if (d.abs() > 2.8) return const SizedBox.shrink();
    final w = ShelfGeometry.weight(d.abs());
    final origin = ShelfGeometry.origin(cover, bookHeight, w);
    final rail = ShelfGeometry.railY(d);
    final left = width / 2 - foot / 2 + d * pitch + origin.dx;
    final top = padTop + rail + origin.dy;
    final selected = d.abs() < 0.5;

    final solidWidth = spine + cover * ShelfGeometry.depthX + 6;
    final solidHeight = padTop + bookHeight + 18;

    return Positioned(
      left: left,
      top: top,
      width: solidWidth,
      height: solidHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (selected) {
            widget.onOpen(book);
          } else {
            _animateTo(index.toDouble());
          }
        },
        onLongPress: widget.onLongPress == null ? null : () => widget.onLongPress!(book),
        child: Opacity(
          opacity: selected ? 1 : 0.82,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 书脊（竖直，左侧，竖排书名）
              Positioned(
                left: 0,
                top: padTop,
                width: spine,
                height: bookHeight,
                child: _Spine(
                  title: book.title,
                  height: bookHeight,
                  idLabel: 'WK-${(book.id % 100000).toString().padLeft(5, '0')}',
                ),
              ),
              // 封面（平行四边形，斜视图）
              Positioned(
                left: spine + cover * ShelfGeometry.depthX - 10,
                top: padTop + cover * ShelfGeometry.depthY,
                width: cover,
                height: bookHeight,
                child: Transform(
                  alignment: Alignment.topLeft,
                  transform: Matrix4(
                    ShelfGeometry.depthX, ShelfGeometry.depthY, 0, 0,
                    0, 1, 0, 0,
                    0, 0, 1, 0,
                    0, 0, 0, 1,
                  ),
                  child: _Cover(book: book, selected: selected),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 书脊：深色竖条 + 竖排书名 + 编号。
class _Spine extends StatelessWidget {
  const _Spine({required this.title, required this.height, required this.idLabel});

  final String title;
  final double height;
  final String idLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xCC241C14), Color(0x993D3226), Color(0xCC2E2519)],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Text(
            idLabel,
            style: const TextStyle(fontSize: 6, color: Color(0xCCFFFFFF), letterSpacing: .5),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RotatedBox(
              quarterTurns: 1,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 封面：渐变底 + 书名 + 作者 + 装饰圆。
class _Cover extends StatelessWidget {
  const _Cover({required this.book, required this.selected});

  final Book book;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final (c1, c2) = ShelfGeometry.paletteFor(book.title);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(_hex(c1)), Color(_hex(c2))],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: selected ? .38 : .22),
            blurRadius: selected ? 22 : 10,
            offset: const Offset(2, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.3,
              shadows: [Shadow(color: Colors.black26, blurRadius: 6)],
            ),
          ),
          const Spacer(),
          Text(
            book.author.isEmpty ? '佚名' : '${book.author} 著',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Color(0xE6FFFFFF)),
          ),
        ],
      ),
    );
  }

  static int _hex(String value) {
    var hex = value.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return int.parse(hex, radix: 16);
  }
}
