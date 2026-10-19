import 'package:flutter/material.dart';

import 'text_block.dart';

/// 分页器：把章节段落切分为「一屏一页」。
/// 算法：以 TextPiece 为原子单位贪心装页；单块超页时按字符二分切分。
/// 【原项目保留】思路移植自 wenku8-src reader_pagination.dart（TextPainter 测量），
/// 此处做了简化：不做跨段落的行级重排，精度损失在原型期可接受。
class Paginator {
  const Paginator._();

  /// paragraphs: 章节段落文本
  /// piecesForParagraph: 由上层提供（注入划线/批注样式）
  /// 返回每页的片段列表
  static List<List<TextPiece>> paginate({
    required List<String> paragraphs,
    required List<TextPiece> Function(int paragraphIndex) piecesForParagraph,
    required TextStyle style,
    required double width,
    required double height,
  }) {
    if (paragraphs.isEmpty || width <= 0 || height <= 0) return const [];
    final pages = <List<TextPiece>>[];
    var current = <TextPiece>[];
    var currentHeight = 0.0;

    void pushPage() {
      if (current.isNotEmpty) {
        // 去掉页尾的空段间隔
        while (current.isNotEmpty && current.last.text.trim().isEmpty) {
          current.removeLast();
        }
        if (current.isNotEmpty) pages.add(current);
      }
      current = <TextPiece>[];
      currentHeight = 0;
    }

    for (var p = 0; p < paragraphs.length; p++) {
      final pieces = piecesForParagraph(p);
      if (pieces.isEmpty) continue;
      for (final piece in pieces) {
        final h = _measure(piece, style, width);
        if (h <= height) {
          if (currentHeight + h > height && current.isNotEmpty) {
            pushPage();
          }
          current.add(piece);
          currentHeight += h;
          continue;
        }
        // 超长块：二分切分为可装进一页的小块，逐块装页
        var rest = piece;
        while (true) {
          if (current.isNotEmpty) pushPage();
          final chunks = _splitPiece(rest, style, width, height);
          current.add(chunks.first);
          currentHeight = _measure(chunks.first, style, width);
          if (chunks.length < 2) break;
          rest = chunks[1];
          final restHeight = _measure(rest, style, width);
          if (restHeight <= height) {
            current.add(rest);
            currentHeight += restHeight;
            break;
          }
          // 剩余仍超一页，继续切分
        }
      }
      // 段间距（以空行近似）
      const gap = TextPiece('\n\n');
      final gapHeight = _measure(gap, style, width);
      if (currentHeight + gapHeight > height) {
        pushPage();
      } else {
        current.add(gap);
        currentHeight += gapHeight;
      }
    }
    pushPage();
    return pages;
  }

  static double _measure(TextPiece piece, TextStyle style, double width) {
    final tp = TextPainter(
      text: TextSpan(
        text: piece.text,
        style: style.copyWith(
          decoration: piece.underlineColor == null ? null : TextDecoration.underline,
          decorationColor: piece.underlineColor,
          decorationThickness: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    tp.layout(maxWidth: width);
    final h = tp.height;
    tp.dispose();
    return h;
  }

  /// 把超长块二分切成可装进一页的若干块。
  static List<TextPiece> _splitPiece(TextPiece piece, TextStyle style, double width, double height) {
    final text = piece.text;
    var lo = 1;
    var hi = text.length;
    // 找到最大的可行长度
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      final h = _measure(TextPiece(text.substring(0, mid), underlineColor: piece.underlineColor), style, width);
      if (h <= height) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final first = text.substring(0, lo);
    final rest = text.substring(lo);
    return [
      TextPiece(first, underlineColor: piece.underlineColor),
      if (rest.isNotEmpty) TextPiece(rest, underlineColor: piece.underlineColor),
    ];
  }
}
