import 'package:flutter/foundation.dart';

import '../../data/model/book.dart';
import '../../data/model/book_source.dart';
import '../../data/model/chapter.dart';
import '../../data/model/search_item.dart';
import '../../data/repository/book_source_repository.dart';
import '../../data/repository/bookshelf_repository.dart';
import '../../data/parser/book_source_engine.dart';

/// 在线搜索 ViewModel：选书源 → 搜索 → 目录预览 → 加入书架。
class SearchViewModel extends ChangeNotifier {
  SearchViewModel(this._sources, this._shelf, this._engine);

  final BookSourceRepository _sources;
  final BookshelfRepository _shelf;
  final BookSourceEngine _engine;

  List<BookSource> available = const [];
  BookSource? selected;
  String keyword = '';
  List<SearchItem> results = const [];
  bool searching = false;

  /// 目录预览（点开某条搜索结果后抓取）。
  SearchItem? previewItem;
  List<Chapter>? previewToc;
  bool loadingToc = false;

  String? message;

  Future<void> loadSources() async {
    final res = await _sources.all();
    final all = res.valueOrNull ?? const [];
    available = all.where((s) => s.enabled).toList();
    if (available.isNotEmpty && selected == null) {
      selected = available.first;
    }
    notifyListeners();
  }

  void selectSource(BookSource? source) {
    selected = source;
    notifyListeners();
  }

  Future<void> search(String kw) async {
    keyword = kw;
    final source = selected;
    if (source == null || kw.trim().isEmpty) {
      results = const [];
      notifyListeners();
      return;
    }
    searching = true;
    notifyListeners();
    final res = await _engine.search(source, kw.trim());
    res.when(
      ok: (items) => results = items,
      err: (e) {
        results = const [];
        message = e.message;
      },
    );
    searching = false;
    notifyListeners();
  }

  /// 抓取目录并打开预览。
  Future<void> openToc(SearchItem item) async {
    final source = selected;
    if (source == null) return;
    previewItem = item;
    previewToc = null;
    loadingToc = true;
    notifyListeners();
    final res = await _engine.toc(source, item.bookUrl);
    res.when(
      ok: (chapters) => previewToc = chapters,
      err: (e) => message = e.message,
    );
    loadingToc = false;
    notifyListeners();
  }

  void closePreview() {
    previewItem = null;
    previewToc = null;
    notifyListeners();
  }

  /// 加入书架（携带已抓取的目录）。
  Future<Book?> addToShelf() async {
    final item = previewItem;
    final toc = previewToc;
    final source = selected;
    if (item == null || toc == null || source == null) return null;
    final res = await _shelf.addNetworkBook(
      sourceId: source.id ?? 0,
      sourceName: source.name,
      bookUrl: item.bookUrl,
      title: item.title,
      author: item.author,
      intro: item.intro,
      chapters: toc,
    );
    return res.when(
      ok: (book) {
        message = '已加入书架：${book.title}';
        notifyListeners();
        return book;
      },
      err: (e) {
        message = e.message;
        notifyListeners();
        return null;
      },
    );
  }

  void consumeMessage() => message = null;
}
