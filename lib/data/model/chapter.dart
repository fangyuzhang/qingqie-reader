/// 章节。本地书正文随章节一起缓存；网络书 url 指向书源章节页。
class Chapter {
  const Chapter({
    required this.index,
    required this.title,
    this.url = '',
    this.body = '',
  });

  final int index;
  final String title;
  final String url;
  final String body;

  bool get hasBody => body.trim().isNotEmpty;

  Map<String, Object?> toJson() => {'title': title, 'url': url, 'body': body};

  factory Chapter.fromJson(int index, Map<String, Object?> j) => Chapter(
    index: index,
    title: j['title'] as String? ?? '',
    url: j['url'] as String? ?? '',
    body: j['body'] as String? ?? '',
  );
}
