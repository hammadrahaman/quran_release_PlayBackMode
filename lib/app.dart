import 'package:flutter/material.dart';
import 'features/home/home_screen.dart';
import 'features/quran/surah_list_screen.dart';
import 'features/bookmarks/bookmarks_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/settings/settings_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/local_storage.dart';

class QuranCompanionApp extends StatefulWidget {
  const QuranCompanionApp({super.key});

  static QuranCompanionAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<QuranCompanionAppState>();

  @override
  State<QuranCompanionApp> createState() => QuranCompanionAppState();
}

class QuranCompanionAppState extends State<QuranCompanionApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  void _loadThemeMode() {
    final isDark = LocalStorage.isDarkMode();
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
      LocalStorage.setDarkMode(_themeMode == ThemeMode.dark);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Iqra Quran Daily',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static MainNavigationScreenState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainNavigationScreenState>();

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void switchTab(int index) => setState(() => _currentIndex = index);

  final List<Widget> _screens = const [
    HomeScreen(),
    SurahListScreen(),
    BookmarksScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF0D1B12) : Colors.white,
        selectedItemColor: isDark ? const Color(0xFF3CAF6E) : const Color(0xFF2D7A4F),
        unselectedItemColor: isDark ? Colors.white38 : Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Surah',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline),
            activeIcon: Icon(Icons.bookmark),
            label: 'Bookmarks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_list_outlined),
            activeIcon: Icon(Icons.view_list),
            label: 'Juz',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
