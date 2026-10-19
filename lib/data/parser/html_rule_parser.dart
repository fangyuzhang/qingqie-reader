import 'package:html/dom.dart' as dom;

/// 书源规则提取器：把 "css::attr(href)" / "css::text" / "a || b" 规则
/// 应用到 HTML 文档上。仅使用 CSS 选择器，不执行任何脚本。
class RuleParser {
  const RuleParser._();

  /// 解析单条规则 → (选择器, 模式, 属性名)。
  static ({String selector, String mode, String? attr}) parseRule(String rule) {
    final idx = rule.indexOf('::');
    if (idx < 0) return (selector: rule.trim(), mode: 'text', attr: null);
    final selector = rule.substring(0, idx).trim();
    final rest = rule.substring(idx + 2).trim();
    if (rest.startsWith('attr(') && rest.endsWith(')')) {
      return (selector: selector, mode: 'attr', attr: rest.substring(5, rest.length - 1).trim());
    }
    return (selector: selector, mode: 'text', attr: null);
  }

  /// 在容器元素上按规则取值；支持 || 回退（前者无命中时尝试后者）。
  static String? extract(dom.Element? container, String rule) {
    if (container == null || rule.trim().isEmpty) return null;
    for (final part in rule.split('||')) {
      if (part.trim().isEmpty) continue;
      final r = parseRule(part);
      final el = container.querySelector(r.selector);
      if (el == null) continue;
      final value = r.mode == 'attr' ? el.attributes[r.attr] : el.text.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// 按规则选择元素列表（list 规则）。
  static List<dom.Element> selectAll(dom.Document doc, String selector) {
    // list 规则也可能带 :: 后缀或 || 回退，这里只取选择器部分
    final parts = selector.split('||');
    for (final part in parts) {
      final r = parseRule(part);
      final found = doc.querySelectorAll(r.selector).toList();
      if (found.isNotEmpty) return found;
    }
    return const [];
  }

  /// 相对 URL 拼接为绝对 URL（基于书源根地址）。
  static String absoluteUrl(String base, String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) {
      final scheme = base.startsWith('https') ? 'https:' : 'http:';
      return scheme + url;
    }
    try {
      return Uri.parse(base).resolve(url).toString();
    } catch (_) {
      return url;
    }
  }
}
