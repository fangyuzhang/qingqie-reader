import 'package:flutter/foundation.dart';

import '../../data/model/book.dart';
import '../../data/model/category.dart';
import '../../data/repository/bookshelf_repository.dart';

/// 书架 ViewModel：分类/书籍数据 + 导入/删除/移动。
/// 只依赖 Repository，不感知 DAO/文件/网络细节。
class BookshelfViewModel extends ChangeNotifier {
  BookshelfViewModel(this._repo);

  final BookshelfRepository _repo;

  List<BookCategory> categories = const [];
  List<Book> books = const [];
  int selectedCategory = 0; // 0 = 全部
  String query = '';
  bool loading = false;
  bool shelf3D = true;
  String? message; // 最近一次操作结果（供页面弹 toast）

  Future<void> load() async {
    loading = true;
    notifyListeners();
    await _repo.ensureReady();
    await _refresh();
    loading = false;
    notifyListeners();
  }

  Future<void> _refresh() async {
    final c = await _repo.categories();
    categories = c.valueOrNull ?? const [];
    final b = await _repo.books(
      categoryId: selectedCategory == 0 ? null : selectedCategory,
      query: query.trim().isEmpty ? null : query,
    );
    books = b.valueOrNull ?? const [];
  }

  Future<void> refresh() async {
    await _refresh();
    notifyListeners();
  }

  void selectCategory(int id) {
    if (selectedCategory == id) return;
    selectedCategory = id;
    refresh();
  }

  void search(String q) {
    query = q;
    refresh();
  }

  void toggleView() {
    shelf3D = !shelf3D;
    notifyListeners();
  }

  void consumeMessage() {
    message = null;
  }

  /// 导入本地 TXT/EPUB。
  Future<Book?> importLocal() async {
    final res = await _repo.importLocalBook(
      categoryId: selectedCategory == 0 ? 1 : selectedCategory,
    );
    res.when(
      ok: (book) async {
        await _refresh();
        message = '已导入《${book.title}》';
        notifyListeners();
        return book;
      },
      err: (e) {
        message = e.message;
        notifyListeners();
        return null;
      },
    );
    return res.valueOrNull;
  }

  Future<void> removeBook(Book book) async {
    final res = await _repo.removeBook(book.id);
    res.when(
      ok: (_) async {
        await _refresh();
        message = '已移除《${book.title}》';
      },
      err: (e) => message = e.message,
    );
    notifyListeners();
  }

  Future<void> moveBook(Book book, int categoryId) async {
    final res = await _repo.moveBook(book.id, categoryId);
    res.when(
      ok: (_) async {
        await _refresh();
        message = '已移动分组';
      },
      err: (e) => message = e.message,
    );
    notifyListeners();
  }

  Future<void> createCategory(String name) async {
    final res = await _repo.createCategory(name);
    res.when(
      ok: (_) async {
        await _refresh();
        message = '已创建分类';
      },
      err: (e) => message = e.message,
    );
    notifyListeners();
  }

  Future<void> renameCategory(int id, String name) async {
    final res = await _repo.renameCategory(id, name);
    res.when(
      ok: (_) async {
        await _refresh();
        message = '已重命名';
      },
      err: (e) => message = e.message,
    );
    notifyListeners();
  }

  Future<void> deleteCategory(int id) async {
    final res = await _repo.deleteCategory(id);
    res.when(
      ok: (_) async {
        if (selectedCategory == id) selectedCategory = 0;
        await _refresh();
        message = '已删除分类，书籍回到默认分组';
      },
      err: (e) => message = e.message,
    );
    notifyListeners();
  }
}
