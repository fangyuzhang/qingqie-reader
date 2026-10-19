import 'package:flutter/material.dart';

import '../../../data/model/reader_settings.dart';
import '../reader_view_model.dart';

/// 阅读器菜单：目录 / 排版 两个底部面板。
class ReaderMenu {
  const ReaderMenu._();

  /// 目录面板。
  static Future<void> showToc(BuildContext context, ReaderViewModel vm) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Text('目录（${vm.chapters.length} 章）',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: vm.chapters.length,
                    itemBuilder: (context, i) {
                      final current = i == vm.chapterIndex;
                      return ListTile(
                        dense: true,
                        selected: current,
                        selectedTileColor: const Color(0xFFFBE9DF),
                        title: Text(
                          vm.chapters[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: current ? const Color(0xFFE85D26) : null,
                            fontWeight: current ? FontWeight.w700 : null,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          vm.gotoChapter(i);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 排版面板：模式 / 字体 / 字号 / 行距 / 背景 / 沉浸开关。
  static Future<void> showTypeset(BuildContext context, ReaderViewModel vm) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void patch(ReaderSettings next) {
              vm.updateSettings(next);
              setSheetState(() {});
            }

            final s = vm.settings;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('排版', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('阅读模式', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  SegmentedButton<ReaderMode>(
                    segments: const [
                      ButtonSegment(value: ReaderMode.scroll, label: Text('上下滚动')),
                      ButtonSegment(value: ReaderMode.paged, label: Text('横排翻页')),
                    ],
                    selected: {s.mode},
                    onSelectionChanged: (v) => patch(s.copyWith(mode: v.first)),
                  ),
                  const SizedBox(height: 14),
                  const Text('字体', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final f in ReaderFont.values)
                        ChoiceChip(
                          label: Text(f.label),
                          selected: s.font == f,
                          onSelected: (_) => patch(s.copyWith(font: f)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('字号', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: s.fontSize > 12
                            ? () => patch(s.copyWith(fontSize: s.fontSize - 1))
                            : null,
                      ),
                      Text('${s.fontSize.toInt()}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: s.fontSize < 32
                            ? () => patch(s.copyWith(fontSize: s.fontSize + 1))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      const Text('行距', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: s.lineHeight > 1.2
                            ? () => patch(s.copyWith(lineHeight: s.lineHeight - 0.06))
                            : null,
                      ),
                      Text(s.lineHeight.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: s.lineHeight < 2.6
                            ? () => patch(s.copyWith(lineHeight: s.lineHeight + 0.06))
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('背景', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final paper in ReaderPaper.values)
                        _PaperSwatch(
                          paper: paper,
                          selected: s.paper == paper,
                          onTap: () => patch(s.copyWith(paper: paper)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('阅读时保持屏幕常亮'),
                    value: s.keepScreenOn,
                    onChanged: (v) => patch(s.copyWith(keepScreenOn: v)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PaperSwatch extends StatelessWidget {
  const _PaperSwatch({required this.paper, required this.selected, required this.onTap});

  final ReaderPaper paper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 34,
            decoration: BoxDecoration(
              color: _previewColor(paper),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? const Color(0xFFE85D26) : const Color(0xFFE3D9C8),
                width: selected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '字',
              style: TextStyle(
                fontSize: 12,
                color: paper == ReaderPaper.night ? const Color(0xFFBDB2A0) : const Color(0xFF30352F),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(paper.label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static Color _previewColor(ReaderPaper paper) => switch (paper) {
    ReaderPaper.system => const Color(0xFFF7F7F2),
    ReaderPaper.milk => const Color(0xFFF6F5EF),
    ReaderPaper.wheat => const Color(0xFFF3E9D2),
    ReaderPaper.matcha => const Color(0xFFE4EBDD),
    ReaderPaper.ink => const Color(0xFFFFFFFF),
    ReaderPaper.night => const Color(0xFF1A1815),
  };
}
