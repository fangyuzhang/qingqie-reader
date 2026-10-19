/// 搜索结果条目（在线搜索用）。
class SearchItem {
  const SearchItem({
    required this.title,
    this.author = '',
    this.intro = '',
    this.bookUrl = '',
    this.coverUrl = '',
    this.sourceId = 0,
    this.sourceName = '',
  });

  final String title;
  final String author;
  final String intro;
  final String bookUrl;
  final String coverUrl;
  final int sourceId;
  final String sourceName;
}
