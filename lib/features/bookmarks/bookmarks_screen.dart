import 'package:flutter/material.dart';
import '../../core/storage/local_storage.dart';
import '../quran/ayah_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> bookmarks = [];
  List<Map<String, dynamic>> favorites = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      bookmarks = LocalStorage.getAllBookmarks();
      favorites = LocalStorage.getAllFavorites();
    });
  }

  void _deleteBookmark(int surahNumber, int ayahNumber) {
    LocalStorage.removeBookmark(surahNumber, ayahNumber);
    _load();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Bookmark removed')));
  }

  void _deleteFavorite(int surahNumber, int ayahNumber) {
    LocalStorage.removeFavorite(surahNumber, ayahNumber);
    _load();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Removed from favorites')));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final b = LocalStorage.getAllBookmarks();
      final f = LocalStorage.getAllFavorites();
      if (b.length != bookmarks.length || f.length != favorites.length) {
        _load();
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? const Color(0xFF3CAF6E) : const Color(0xFF2D7A4F);
    final surface = isDark ? const Color(0xFF0D1B12) : const Color(0xFFF5F5F5);
    final card = isDark ? const Color(0xFF1A2E20) : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFF1F3F6) : const Color(0xFF1F2937);
    final textSecondary =
        isDark ? const Color(0xFFB1B6C2) : const Color(0xFF6B7280);
    final chipBg = isDark ? const Color(0xFF1F3A28) : const Color(0xFFD4EDDA);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          title: Text(
            'Saved',
            style:
                TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: surface,
          iconTheme: IconThemeData(color: textPrimary),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
              tooltip: 'Refresh',
            ),
          ],
          bottom: TabBar(
            indicatorColor: green,
            labelColor: green,
            unselectedLabelColor: textSecondary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_outline_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('Bookmarks (${bookmarks.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('Favorites (${favorites.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ItemList(
              items: bookmarks,
              emptyIcon: Icons.bookmark_border,
              emptyTitle: 'No bookmarks yet',
              emptySubtitle: 'Bookmark ayahs while reading',
              accentIcon: Icons.bookmark_rounded,
              isDark: isDark,
              card: card,
              chipBg: chipBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              green: green,
              onTap: (item) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AyahScreen(
                    surahNumber: item['surahNumber'],
                    surahName: item['surahName'],
                    initialAyahIndex: item['ayahNumber'] - 1,
                  ),
                ),
              ).then((_) => _load()),
              onDelete: (item) => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Remove Bookmark'),
                  content: const Text(
                      'Are you sure you want to remove this bookmark?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteBookmark(
                            item['surahNumber'], item['ayahNumber']);
                      },
                      child: const Text('Remove',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
              onRefresh: _load,
            ),
            _ItemList(
              items: favorites,
              emptyIcon: Icons.favorite_border,
              emptyTitle: 'No favorites yet',
              emptySubtitle: 'Tap the heart icon while reading an ayah',
              accentIcon: Icons.favorite_rounded,
              accentColor: Colors.red,
              isDark: isDark,
              card: card,
              chipBg: chipBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              green: green,
              onTap: (item) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AyahScreen(
                    surahNumber: item['surahNumber'],
                    surahName: item['surahName'],
                    initialAyahIndex: item['ayahNumber'] - 1,
                  ),
                ),
              ).then((_) => _load()),
              onDelete: (item) => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Remove Favorite'),
                  content: const Text(
                      'Are you sure you want to remove this favorite?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteFavorite(
                            item['surahNumber'], item['ayahNumber']);
                      },
                      child: const Text('Remove',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
              onRefresh: _load,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData accentIcon;
  final Color? accentColor;
  final bool isDark;
  final Color card;
  final Color chipBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color green;
  final void Function(Map<String, dynamic>) onTap;
  final void Function(Map<String, dynamic>) onDelete;
  final VoidCallback onRefresh;

  const _ItemList({
    required this.items,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.accentIcon,
    this.accentColor,
    required this.isDark,
    required this.card,
    required this.chipBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.green,
    required this.onTap,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(emptyTitle,
                style: TextStyle(
                    fontSize: 18,
                    color: textSecondary,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(emptySubtitle,
                style: TextStyle(fontSize: 14, color: textSecondary)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: green),
                foregroundColor: green,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final surahNumber = item['surahNumber'];
        final ayahNumber = item['ayahNumber'];
        final surahName = item['surahName'];
        final note = item['note'] ?? '';
        final timestamp = DateTime.parse(item['timestamp']);
        final formattedDate =
            '${timestamp.day}/${timestamp.month}/${timestamp.year}';

        return Card(
          color: card,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: InkWell(
            onTap: () => onTap(item),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(accentIcon,
                        color: accentColor ?? green, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(surahName,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textPrimary)),
                        const SizedBox(height: 4),
                        Text('Surah $surahNumber, Ayah $ayahNumber',
                            style: TextStyle(
                                fontSize: 14, color: textSecondary)),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(note,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                  fontStyle: FontStyle.italic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 4),
                        Text(formattedDate,
                            style: TextStyle(
                                fontSize: 12, color: textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: () => onDelete(item),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
