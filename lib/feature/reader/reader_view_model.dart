import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/model/book.dart';
import '../../data/model/bookmark.dart';
import '../../data/model/chapter.dart';
import '../../data/model/note.dart';
import '../../data/model/reader_settings.dart';
import '../../data/model/reading_progress.dart';
import '../../data/model/book_source.dart';
import '../../data/repository/book_source_repository.dart';
import '../../data/repository/bookshelf_repository.dart';
import '../../data/repository/reader_repository.dart';
import '../../core/app_error.dart';
import 'widgets/text_block.dart';

/// 文本范围（段落内坐标，包头不包尾）。
typedef TextRangeSel = ({int paragraph, int start, int end});

/// 划线色值（蜗牛读书式纯下划线）。
const Map<String, Color> kNoteLineColors = {
  'yellow': Color(0xFFF0B429),
  'mint': Color(0xFF3DA88A),
  'pink': Color(0xFFE25C73),
  'violet': Color(0xFF8A63C9),
};

const Color kAnnotLineColor = Color(0xFFD64545);

/// 阅读器 ViewModel：章节/进度/书签/笔记/设置/查找/自动滚动。
class ReaderViewModel extends ChangeNotifier {
  ReaderViewModel(this._reader, this._shelf, this._sources);

  final ReaderRepository _reader;
  final BookshelfRepository _shelf;
  final BookSourceRepository _sources;

  /// 已加载的书源缓存（网络书抓取时同步反查规则）。
  List<BookSource> _sourcesCache = const [];

  Book? book;
  List<Chapter> chapters = const [];
  int chapterIndex = 0;
  String? chapterBody;
  List<String> paragraphs = const [];
  ReaderSettings settings = const ReaderSettings();
  List<Note> notes = const [];
  List<Bookmark> bookmarks = const [];
  bool loading = false;
  String? errorMessage;

  /// 选中范围（长按选句）。
  TextRangeSel? selection;

  /// 沉浸模式：点屏幕中央切换工具栏显隐。
  bool chromeVisible = true;

  /// 查找。
  String findQuery = '';
  List<TextRangeSel> findHits = const [];
  int findIndex = 0;

  /// 自动滚动开关（速度来自 settings.autoScrollSpeed，由页面驱动定时器）。
  bool autoScrolling = false;

  /// 打开章节后待消费的滚动偏移（进度恢复用）。
  double pendingOffset = 0;

  Timer? _saveTimer;
  bool _disposed = false;

  bool get hasBook => book != null;

  bool get bookmarked =>
      bookmarks.any((b) => b.chapterIndex == chapterIndex);

  // ---- 生命周期 ----

  Future<void> openBook(Book target) async {
    loading = true;
    errorMessage = null;
    book = target;
    notifyListeners();
    settings = (await _reader.loadSettings()).valueOrNull ?? const ReaderSettings();
    // 网络书：预载书源缓存并设置同步解析器
    if (!target.isLocal) {
      _sourcesCache = (await _sources.all()).valueOrNull ?? const [];
      _reader.setSourceResolver((id) {
        for (final s in _sourcesCache) {
          if (s.id == id) return s;
        }
        throw const AppError(AppErrorKind.unknown, '书籍所属书源已被删除，请重新添加');
      });
    }
    var list = (await _reader.chapters(target)).valueOrNull ?? const <Chapter>[];
    if (list.isEmpty && !target.isLocal) {
      list = (await _reader.fetchToc(target)).valueOrNull ?? const <Chapter>[];
    }
    chapters = list;
    bookmarks = (await _reader.bookmarks(target.id)).valueOrNull ?? const [];
    final progress = (await _reader.progress(target.id)).valueOrNull;
    var index = progress?.chapterIndex ?? 0;
    if (index < 0 || index >= chapters.length) index = 0;
    chapterIndex = index;
    pendingOffset = progress?.offsetValue ?? 0;
    await _loadChapter(index);
    loading = false;
    notifyListeners();
  }

  Future<void> _loadChapter(int index) async {
    final target = book;
    if (target == null) return;
    chapterIndex = index;
    selection = null;
    chapterBody = null;
    paragraphs = const [];
    notes = const [];
    notifyListeners();
    // 本地书：openBook 时已把正文读进内存，直接命中，不再读文件
    if (index >= 0 && index < chapters.length && chapters[index].hasBody) {
      _setBody(chapters[index].body);
      await _reloadNotes(notify: false);
      notifyListeners();
      return;
    }
    final bodyRes = await _reader.chapterBody(target, index);
    final body = bodyRes.valueOrNull;
    if (body == null) {
      errorMessage = bodyRes.errorOrNull?.message ?? '章节加载失败';
    } else {
      _setBody(body);
      // 网络书抓到的正文回填进内存列表，翻回来时免二次请求
      if (index >= 0 && index < chapters.length && !chapters[index].hasBody) {
        chapters[index] = Chapter(
          index: index,
          title: chapters[index].title,
          url: chapters[index].url,
          body: body,
        );
      }
    }
    notifyListeners();
  }

  void _setBody(String body) {
    chapterBody = body;
    paragraphs = body.split(RegExp(r'\n+')).where((p) => p.trim().isNotEmpty).toList();
  }

  Future<void> _reloadNotes({bool notify = true}) async {
    final target = book;
    if (target == null) return;
    notes = (await _reader.notes(target.id, chapterIndex)).valueOrNull ?? const [];
    selection = null;
    if (notify) notifyListeners();
  }

  Future<void> gotoChapter(int index) async {
    if (index < 0 || index >= chapters.length) return;
    await _loadChapter(index);
    await _persistProgress(0);
  }

  Future<void> nextChapter() => gotoChapter(chapterIndex + 1);

  Future<void> prevChapter() => gotoChapter(chapterIndex - 1);

  // ---- 进度 ----

  /// 滚动/翻页位置变化（防抖 500ms 后落库）。
  void onPositionChanged(double offset) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _persistProgress(offset);
    });
  }

  /// 翻页模式：翻页即存。
  void onPageChanged(int page) => _persistProgress(page.toDouble());

  Future<void> _persistProgress(double offset) async {
    final target = book;
    if (target == null || chapters.isEmpty) return;
    final title = chapterIndex < chapters.length ? chapters[chapterIndex].title : '';
    final percent = (chapterIndex + 1) / chapters.length;
    await _reader.saveProgress(ReadingProgress(
      bookId: target.id,
      chapterIndex: chapterIndex,
      chapterTitle: title,
      offsetValue: offset,
      percent: percent,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _shelf.touchLastRead(target.id);
  }

  // ---- 设置 ----

  Future<void> updateSettings(ReaderSettings next) async {
    settings = next;
    notifyListeners();
    await _reader.saveSettings(next);
  }

  void toggleNight() {
    final next = settings.paper == ReaderPaper.night
        ? settings.copyWith(paper: ReaderPaper.milk)
        : settings.copyWith(paper: ReaderPaper.night);
    updateSettings(next);
  }

  void toggleChrome() {
    chromeVisible = !chromeVisible;
    notifyListeners();
  }

  // ---- 书签 ----

  Future<void> toggleBookmark() async {
    final target = book;
    if (target == null) return;
    final existing = bookmarks.where((b) => b.chapterIndex == chapterIndex).toList();
    if (existing.isNotEmpty) {
      for (final b in existing) {
        await _reader.removeBookmark(b.id ?? 0);
      }
    } else {
      final excerpt = paragraphs.isNotEmpty ? paragraphs.first.substring(0, paragraphs.first.length.clamp(0, 80)) : '';
      await _reader.addBookmark(Bookmark(
        bookId: target.id,
        chapterIndex: chapterIndex,
        chapterTitle: chapterIndex < chapters.length ? chapters[chapterIndex].title : '',
        excerpt: excerpt,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    bookmarks = (await _reader.bookmarks(target.id)).valueOrNull ?? const [];
    notifyListeners();
  }

  // ---- 选句与笔记 ----

  /// 长按段落：自动选中当前句（含句尾标点）。
  void onLongPressParagraph(int paragraph, int offset) {
    if (paragraph < 0 || paragraph >= paragraphs.length) return;
    final text = paragraphs[paragraph];
    final (start, end) = sentenceRange(text, offset);
    selection = (paragraph: paragraph, start: start, end: end);
    notifyListeners();
  }

  static (int, int) sentenceRange(String text, int offset) {
    const breaks = '。！？；…';
    var s = offset.clamp(0, text.length);
    while (s > 0 && !breaks.contains(text[s - 1])) {
      s--;
    }
    var e = offset.clamp(0, text.length);
    while (e < text.length && !breaks.contains(text[e])) {
      e++;
    }
    if (e < text.length) e++; // 包含句尾标点
    if (e <= s) e = (s + 1).clamp(0, text.length);
    return (s, e);
  }

  void clearSelection() {
    if (selection == null) return;
    selection = null;
    notifyListeners();
  }

  String get selectedText {
    final sel = selection;
    if (sel == null) return '';
    return paragraphs[sel.paragraph].substring(sel.start, sel.end);
  }

  Future<void> addMark(String colorKey) async {
    final sel = selection;
    final target = book;
    if (sel == null || target == null) return;
    await _reader.addNote(Note(
      bookId: target.id,
      chapterIndex: chapterIndex,
      type: NoteType.mark,
      color: colorKey,
      text: selectedText,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _reloadNotes();
  }

  Future<void> addAnnot(String thought) async {
    final sel = selection;
    final target = book;
    if (sel == null || target == null) return;
    await _reader.addNote(Note(
      bookId: target.id,
      chapterIndex: chapterIndex,
      type: NoteType.annot,
      color: 'red',
      text: selectedText,
      thought: thought,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _reloadNotes();
  }

  Future<void> addExcerpt() async {
    final sel = selection;
    final target = book;
    if (sel == null || target == null) return;
    await _reader.addNote(Note(
      bookId: target.id,
      chapterIndex: chapterIndex,
      type: NoteType.excerpt,
      text: selectedText,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _reloadNotes();
  }

  Future<void> deleteNote(int id) async {
    await _reader.removeNote(id);
    await _reloadNotes();
  }

  /// 为段落构造带下划线的文本片段。
  List<TextPiece> piecesForParagraph(int p) {
    if (p < 0 || p >= paragraphs.length) return const [];
    final text = paragraphs[p];
    final ranges = <({int start, int end, Color color})>[];
    for (final n in notes) {
      if (n.type == NoteType.excerpt) continue;
      final idx = text.indexOf(n.text);
      if (idx < 0 || n.text.isEmpty) continue;
      final color = n.type == NoteType.annot
          ? kAnnotLineColor
          : (kNoteLineColors[n.color] ?? kNoteLineColors['yellow']!);
      ranges.add((start: idx, end: idx + n.text.length, color: color));
    }
    if (ranges.isEmpty) return [TextPiece(text)];
    ranges.sort((a, b) => a.start.compareTo(b.start));
    final pieces = <TextPiece>[];
    var cursor = 0;
    for (final r in ranges) {
      if (r.start < cursor) continue; // 跳过重叠
      if (r.start > cursor) {
        pieces.add(TextPiece(text.substring(cursor, r.start)));
      }
      pieces.add(TextPiece(text.substring(r.start, r.end), underlineColor: r.color));
      cursor = r.end;
    }
    if (cursor < text.length) {
      pieces.add(TextPiece(text.substring(cursor)));
    }
    return pieces;
  }

  /// 被批注的段落 → 批注块数据（段落下标 → 想法列表）。
  Map<int, List<Note>> get annotBlocksByParagraph {
    final map = <int, List<Note>>{};
    for (final n in notes) {
      if (n.type != NoteType.annot) continue;
      for (var p = 0; p < paragraphs.length; p++) {
        if (paragraphs[p].contains(n.text)) {
          map.putIfAbsent(p, () => []).add(n);
          break;
        }
      }
    }
    return map;
  }

  // ---- 查找 ----

  void runFind(String query) {
    findQuery = query;
    findHits = const [];
    findIndex = 0;
    if (query.trim().isNotEmpty) {
      final hits = <TextRangeSel>[];
      for (var p = 0; p < paragraphs.length; p++) {
        var idx = paragraphs[p].indexOf(query);
        while (idx >= 0) {
          hits.add((paragraph: p, start: idx, end: idx + query.length));
          idx = paragraphs[p].indexOf(query, idx + query.length);
        }
      }
      findHits = hits;
    }
    notifyListeners();
  }

  void findNext() {
    if (findHits.isEmpty) return;
    findIndex = (findIndex + 1) % findHits.length;
    notifyListeners();
  }

  void findPrev() {
    if (findHits.isEmpty) return;
    findIndex = (findIndex - 1 + findHits.length) % findHits.length;
    notifyListeners();
  }

  void closeFind() {
    findQuery = '';
    findHits = const [];
    findIndex = 0;
    notifyListeners();
  }

  // ---- 自动滚动 ----

  void toggleAutoScroll() {
    autoScrolling = !autoScrolling;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
