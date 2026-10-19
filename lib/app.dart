import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/model/book.dart';
import 'data/repository/backup_repository.dart';
import 'data/repository/book_source_repository.dart';
import 'data/repository/bookshelf_repository.dart';
import 'data/repository/reader_repository.dart';
import 'data/parser/book_source_engine.dart';
import 'data/remote/http_client.dart';
import 'feature/bookshelf/bookshelf_page.dart';
import 'feature/bookshelf/bookshelf_view_model.dart';
import 'feature/reader/reader_page.dart';
import 'feature/search/search_page.dart';
import 'feature/search/search_view_model.dart';
import 'feature/settings/settings_page.dart';
import 'feature/settings/settings_view_model.dart';
import 'feature/source/source_page.dart';
import 'feature/source/source_view_model.dart';

/// 应用根组件：装配 Repository 与 ViewModel（MVVM 依赖方向单向向下）。
class QingqieApp extends StatelessWidget {
  const QingqieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ---- Repository 层（单例，跨页面共享）----
        Provider.value(value: BookshelfRepository()),
        Provider.value(value: ReaderRepository()),
        Provider.value(value: BookSourceRepository()),
        Provider.value(value: BackupRepository()),
        // ---- ViewModel 层 ----
        ChangeNotifierProvider(
          create: (_) => BookshelfViewModel(context.read<BookshelfRepository>())..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => SourceViewModel(context.read<BookSourceRepository>()),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsViewModel(
            bookshelf: context.read<BookshelfRepository>(),
            sources: context.read<BookSourceRepository>(),
            backup: context.read<BackupRepository>(),
          )..load(),
        ),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsViewModel, String>((vm) => vm.themeMode);
    return MaterialApp(
      title: '青茄阅读',
      debugShowCheckedModeBanner: false,
      themeMode: switch (themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const HomeShell(),
    );
  }

  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE85D26),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F1E7),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F1E7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      useMaterial3: true,
    );
  }
}

/// 主框架：书架 / 书源 / 我的。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  void _openBook(Book book) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReaderPage(
        book: book,
        readerRepository: context.read<ReaderRepository>(),
        shelfRepository: context.read<BookshelfRepository>(),
        sourceRepository: context.read<BookSourceRepository>(),
      ),
    ));
  }

  void _openSearch() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => SearchViewModel(
          context.read<BookSourceRepository>(),
          context.read<BookshelfRepository>(),
          BookSourceEngine(AppHttpClient.instance),
        ),
        child: SearchPage(onOpenBook: _openBook),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BookshelfPage(onOpenBook: _openBook),
      SourcePage(onOpenSearch: _openSearch),
      const SettingsPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: '书架'),
          NavigationDestination(icon: Icon(Icons.source_outlined), selectedIcon: Icon(Icons.source), label: '书源'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
