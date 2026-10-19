import 'dart:math';
import 'dart:ui';

/// 立体书架几何（2.5D 轴测投影）。
///
/// 【原项目保留】常量与公式逐行移植自 wenku8-src archive_shelf_geometry.dart
/// （GPL-3.0，Copyright (C) 2015 MewX / mikufoxxx）：
///   depthX=.66 / depthY=-.30 / 书脊=W*.043 / 书距=书脊+11 / 封面=W*.32
///   railY = d*2.5 + d²*.45（整排成弧）
///   weight = cos(d/1.48·π/2)²（连续选中量，驱动拉出与上浮）
/// 仅重写数据绑定（原作为自定义 RenderObject，此处改为标准 Widget 组合），
/// 视觉算法保持一致；遮挡路径级 fidelity 留待二期。
abstract final class ShelfGeometry {
  static const double depthX = .66;
  static const double depthY = -.30;
  static const double rowStep = 2.5;
  static const double radius = 1.48;

  /// 书脊宽度（14~18）。
  static double spineFor(double width) => (width * .043).clamp(14.0, 18.0);

  /// 书间距（书脊 + 11，紧贴成一排）。
  static double pitchFor(double width) => spineFor(width) + 11;

  /// 封面宽度（100~128）。
  static double coverFor(double width) => (width * .32).clamp(100.0, 128.0);

  /// 书身高度。
  static double bodyHeight(double cover) => (cover - 20) * 166 / 118 + 54;

  /// 一书占用的水平总宽（书脊 + 封面投影）。
  static double footprint(double spine, double cover) => spine + cover * depthX;

  /// 选中时的向左拉出距离。
  static double pullDistance(double cover) => cover * .84;

  /// 书身基准 Y（未选中时的垂直位置）。
  static double baseY(double cover, double height) => -cover * depthY + height * .60 + 12;

  /// 整排书的弧线高度（两边下沉）。
  static double railY(double distance) {
    final d = distance.clamp(-7.0, 7.0);
    return d * rowStep + d * d * .45;
  }

  /// 连续选中量：距焦点越近越接近 1（原作为 cos²）。
  static double weight(double distance) {
    if (distance >= radius) return 0;
    final v = cos(distance / radius * pi / 2);
    return v * v;
  }

  /// 书身原点：拉出（向左）+ 上浮（smoothstep）。
  static Offset origin(double cover, double height, double w) {
    final pull = pullDistance(cover) * w * (1.24 - .24 * w);
    final lift = w * w * (3 - 2 * w);
    return Offset(
      -pull * depthX,
      baseY(cover, height) - pull * depthY - height * .60 * lift,
    );
  }

  /// 由书名确定性取一组封面渐变（避免为封面色改数据库结构）。
  static (String, String) paletteFor(String seed) {
    const palettes = <(String, String)>[
      ('#8E2DE2', '#4A00E0'),
      ('#F7971E', '#F45C43'),
      ('#11998E', '#38EF7D'),
      ('#3A7BD5', '#00D2FF'),
      ('#C33764', '#1D2671'),
      ('#EB3349', '#F45C43'),
      ('#603813', '#B29F94'),
      ('#136A8A', '#267871'),
      ('#654ea3', '#eaafc8'),
      ('#005C97', '#363795'),
      ('#1F4037', '#99F2C8'),
      ('#DC2424', '#4A569D'),
    ];
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return palettes[hash % palettes.length];
  }
}
