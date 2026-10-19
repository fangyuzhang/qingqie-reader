import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 划线颜色（蜗牛读书式纯下划线）。
const List<({String key, String label, Color color})> kMarkColors = [
  (key: 'yellow', label: '明黄', color: Color(0xFFF0B429)),
  (key: 'mint', label: '薄荷', color: Color(0xFF3DA88A)),
  (key: 'pink', label: '蜜桃', color: Color(0xFFE25C73)),
  (key: 'violet', label: '紫藤', color: Color(0xFF8A63C9)),
];

/// 选区工具条：长按选句后弹出 —— 划线（4 色）/ 批注 / 书摘 / 复制 / 取消。
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    super.key,
    required this.selectedText,
    this.expanded = false,
    this.onToggleExpand,
    required this.onMark,
    required this.onAnnot,
    required this.onExcerpt,
    required this.onCancel,
  });

  final String selectedText;
  final bool expanded;
  final VoidCallback? onToggleExpand;
  final void Function(String colorKey) onMark;
  final VoidCallback onAnnot;
  final VoidCallback onExcerpt;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(14),
      color: const Color(0xFF3A332A),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (expanded) ...[
              for (final c in kMarkColors)
                _DotButton(
                  color: c.color,
                  tooltip: c.label,
                  onTap: () => onMark(c.key),
                ),
              const _Divider(),
            ] else
              _TextButton(
                icon: Icons.border_color,
                label: '划线',
                onTap: onToggleExpand ?? () {},
              ),
            _TextButton(
              icon: Icons.edit_note,
              label: '批注',
              onTap: onAnnot,
            ),
            _TextButton(
              icon: Icons.bookmark_border,
              label: '书摘',
              onTap: onExcerpt,
            ),
            _TextButton(
              icon: Icons.copy,
              label: '复制',
              onTap: () {
                if (selectedText.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: selectedText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
                  );
                }
              },
            ),
            const _Divider(),
            _TextButton(
              icon: Icons.close,
              label: '取消',
              onTap: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _DotButton extends StatelessWidget {
  const _DotButton({required this.color, required this.tooltip, required this.onTap});

  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white24,
    );
  }
}
