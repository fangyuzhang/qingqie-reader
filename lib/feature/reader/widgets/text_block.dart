import 'package:flutter/material.dart';

/// 一段富文本片段：文本 + 可选下划线色（划线）/ 背景（选中高亮）。
class TextPiece {
  const TextPiece(
    this.text, {
    this.underlineColor,
    this.background,
  });

  final String text;
  final Color? underlineColor;
  final Color? background;
}

/// 自绘富文本块：用 TextPainter 精确布局，支持长按取词（返回文本偏移）。
/// 不依赖 Text  widget，因此可以把点击坐标换算成字符偏移，实现「选句」。
class TextBlock extends StatefulWidget {
  const TextBlock({
    super.key,
    required this.pieces,
    required this.style,
    this.onLongPressAt,
    this.selectedRange,
    this.maxHeight,
  });

  final List<TextPiece> pieces;
  final TextStyle style;

  /// 长按时回调，参数为该块内拼接文本的字符偏移。
  final void Function(int offset)? onLongPressAt;

  /// 选中范围（闭开区间），在块内拼接文本的坐标。
  final (int, int)? selectedRange;

  /// 分页模式下锁定高度（滚动模式传 null 自适应）。
  final double? maxHeight;

  @override
  State<TextBlock> createState() => _TextBlockState();
}

class _TextBlockState extends State<TextBlock> {
  late TextPainter _painter;
  String _plain = '';

  TextPainter _buildPainter() {
    final plain = StringBuffer();
    final spans = <TextSpan>[];
    for (final piece in widget.pieces) {
      if (piece.text.isEmpty) continue;
      plain.write(piece.text);
      spans.add(TextSpan(
        text: piece.text,
        style: widget.style.copyWith(
          backgroundColor: piece.background,
          decoration: piece.underlineColor == null ? null : TextDecoration.underline,
          decorationColor: piece.underlineColor,
          decorationThickness: 2,
        ),
      ));
    }
    _plain = plain.toString();
    return TextPainter(
      text: TextSpan(style: widget.style, children: spans),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
  }

  /// 在原文上按选中范围切分，叠加底纹后重建 painter。
  void _applySelection() {
    final range = widget.selectedRange;
    if (range == null) return;
    final start = range.$1.clamp(0, _plain.length);
    final end = range.$2.clamp(0, _plain.length);
    if (end <= start) return;
    final rebuilt = <TextPiece>[];
    var cursor = 0;
    for (final piece in widget.pieces) {
      final len = piece.text.length;
      final pieceStart = cursor;
      final pieceEnd = cursor + len;
      cursor = pieceEnd;
      if (len == 0) continue;
      final s = start > pieceStart ? start - pieceStart : 0;
      final e = end < pieceEnd ? end - pieceStart : len;
      if (s >= e) {
        rebuilt.add(piece);
        continue;
      }
      if (s > 0) {
        rebuilt.add(TextPiece(piece.text.substring(0, s), underlineColor: piece.underlineColor));
      }
      rebuilt.add(TextPiece(
        piece.text.substring(s, e),
        underlineColor: piece.underlineColor,
        background: const Color(0x33000000),
      ));
      if (e < len) {
        rebuilt.add(TextPiece(piece.text.substring(e), underlineColor: piece.underlineColor));
      }
    }
    final spans = <TextSpan>[];
    for (final piece in rebuilt) {
      spans.add(TextSpan(
        text: piece.text,
        style: widget.style.copyWith(
          backgroundColor: piece.background,
          decoration: piece.underlineColor == null ? null : TextDecoration.underline,
          decorationColor: piece.underlineColor,
          decorationThickness: 2,
        ),
      ));
    }
    _painter.text = TextSpan(style: widget.style, children: spans);
  }

  @override
  Widget build(BuildContext context) {
    _painter = _buildPainter();
    _applySelection();
    return LayoutBuilder(
      builder: (context, constraints) {
        _painter.layout(maxWidth: constraints.maxWidth);
        final size = Size(constraints.maxWidth, _painter.height);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: widget.onLongPressAt == null
              ? null
              : (details) {
                  final offset = _painter.getPositionForOffset(details.localPosition).offset;
                  widget.onLongPressAt!(offset.clamp(0, _plain.length));
                },
          child: CustomPaint(
            size: size,
            painter: _TextBlockPainter(_painter),
          ),
        );
      },
    );
  }
}

class _TextBlockPainter extends CustomPainter {
  const _TextBlockPainter(this.painter);

  final TextPainter painter;

  @override
  void paint(Canvas canvas, Size size) {
    painter.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _TextBlockPainter old) => old.painter != painter;
}
