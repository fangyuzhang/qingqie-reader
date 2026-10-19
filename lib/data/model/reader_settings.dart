import 'package:flutter/material.dart';

/// 阅读背景纸色（含夜读与墨水屏）。
/// 【原项目保留】枚举 + background()/foreground() 颜色映射移植自
/// wenku8-src reader_preferences.dart（ReaderPaper）。
enum ReaderPaper {
  system('跟随外观'),
  milk('奶白'),
  wheat('米黄'),
  matcha('抹茶'),
  ink('墨水屏'),
  night('夜读');

  const ReaderPaper(this.label);
  final String label;
}

/// 阅读模式：上下滚动 / 横排翻页。
enum ReaderMode { scroll('上下滚动'), paged('横排翻页');

  const ReaderMode(this.label);
  final String label;
}

/// 字体族 key（自定义字体：MVP 提供四套系统字体族；TTF 导入为二期）。
enum ReaderFont { system('默认'), serif('宋体'), kai('楷体'), hei('黑体');

  const ReaderFont(this.label);
  final String label;

  /// 映射到 Flutter 字体族名；system 返回 null（用主题默认字体）。
  String? get family => switch (this) {
    ReaderFont.system => null,
    ReaderFont.serif => 'serif',
    ReaderFont.kai => 'cursive',
    ReaderFont.hei => 'sans',
  };
}

/// 阅读设置（不可变值对象）。
/// 【原项目保留】copyWith + toJson/fromJson + 数值范围校验的结构移植自
/// wenku8-src reader_preferences.dart。
class ReaderSettings {
  const ReaderSettings({
    this.paper = ReaderPaper.system,
    this.mode = ReaderMode.scroll,
    this.font = ReaderFont.system,
    this.fontSize = 19,
    this.lineHeight = 1.72,
    this.paragraphGap = 12,
    this.margin = 26,
    this.indent = false,
    this.justify = true,
    this.keepScreenOn = false,
    this.autoScrollSpeed = 24,
  });

  final ReaderPaper paper;
  final ReaderMode mode;
  final ReaderFont font;
  final double fontSize;
  final double lineHeight;
  final double paragraphGap;
  final double margin;
  final bool indent;
  final bool justify;
  final bool keepScreenOn;
  final double autoScrollSpeed;

  bool get isNight => paper == ReaderPaper.night;

  /// 阅读区背景色（dark = 应用处于暗色主题）。
  Color background(bool dark) => switch (paper) {
    ReaderPaper.system => dark ? const Color(0xFF1A1815) : const Color(0xFFF7F7F2),
    ReaderPaper.milk => const Color(0xFFF6F5EF),
    ReaderPaper.wheat => const Color(0xFFF3E9D2),
    ReaderPaper.matcha => const Color(0xFFE4EBDD),
    ReaderPaper.ink => const Color(0xFFFFFFFF),
    ReaderPaper.night => const Color(0xFF1A1815),
  };

  Color foreground(bool dark) => switch (paper) {
    ReaderPaper.ink => const Color(0xFF111111),
    ReaderPaper.night => const Color(0xFFBDB2A0),
    ReaderPaper.system => dark ? const Color(0xFFBDB2A0) : const Color(0xFF30352F),
    _ => const Color(0xFF30352F),
  };

  Map<String, Object?> toJson() => {
    'paper': paper.name,
    'mode': mode.name,
    'font': font.name,
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'paragraphGap': paragraphGap,
    'margin': margin,
    'indent': indent,
    'justify': justify,
    'keepScreenOn': keepScreenOn,
    'autoScrollSpeed': autoScrollSpeed,
  };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    double number(String key, double min, double max, double fallback) {
      final v = json[key];
      if (v is! num || !v.isFinite || v < min || v > max) return fallback;
      return v.toDouble();
    }

    return ReaderSettings(
      paper: ReaderPaper.values.firstWhere(
        (p) => p.name == json['paper'],
        orElse: () => ReaderPaper.system,
      ),
      mode: ReaderMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => ReaderMode.scroll,
      ),
      font: ReaderFont.values.firstWhere(
        (f) => f.name == json['font'],
        orElse: () => ReaderFont.system,
      ),
      fontSize: number('fontSize', 12, 32, 19),
      lineHeight: number('lineHeight', 1.2, 2.6, 1.72),
      paragraphGap: number('paragraphGap', 0, 32, 12),
      margin: number('margin', 0, 80, 26),
      indent: json['indent'] == true,
      justify: json['justify'] != false,
      keepScreenOn: json['keepScreenOn'] == true,
      autoScrollSpeed: number('autoScrollSpeed', 8, 80, 24),
    );
  }

  ReaderSettings copyWith({
    ReaderPaper? paper,
    ReaderMode? mode,
    ReaderFont? font,
    double? fontSize,
    double? lineHeight,
    double? paragraphGap,
    double? margin,
    bool? indent,
    bool? justify,
    bool? keepScreenOn,
    double? autoScrollSpeed,
  }) => ReaderSettings(
    paper: paper ?? this.paper,
    mode: mode ?? this.mode,
    font: font ?? this.font,
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    paragraphGap: paragraphGap ?? this.paragraphGap,
    margin: margin ?? this.margin,
    indent: indent ?? this.indent,
    justify: justify ?? this.justify,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    autoScrollSpeed: autoScrollSpeed ?? this.autoScrollSpeed,
  );
}
