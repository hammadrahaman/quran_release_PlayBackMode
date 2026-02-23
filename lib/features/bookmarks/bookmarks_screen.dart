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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    loadBookmarks();
  }

  // This will be called whenever the widget is rebuilt
  @override
  void didUpdateWidget(BookmarksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    loadBookmarks();
  }

  void loadBookmarks() {
    setState(() {
      bookmarks = LocalStorage.getAllBookmarks();
    });
  }

  void deleteBookmark(int surahNumber, int ayahNumber) {
    LocalStorage.removeBookmark(surahNumber, ayahNumber);
    loadBookmarks();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bookmark removed'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Reload bookmarks on every build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentBookmarks = LocalStorage.getAllBookmarks();
      if (currentBookmarks.length != bookmarks.length) {
        loadBookmarks();
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF121417) : const Color(0xFFF2F7F6);
    final card = isDark ? const Color(0xFF1B1E23) : Colors.white;
    final chip = isDark ? const Color(0xFF2A2D33) : const Color(0xFFD7ECEC);
    final textPrimary = isDark
        ? const Color(0xFFF1F3F6)
        : const Color(0xFF1F2937);
    final textSecondary = isDark
        ? const Color(0xFFB1B6C2)
        : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          'Bookmarks',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: surface,
        iconTheme: IconThemeData(color: textPrimary),
        actions: [
          if (bookmarks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: chip,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${bookmarks.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: loadBookmarks,
            tooltip: 'Refresh bookmarks',
          ),
        ],
      ),
      body: bookmarks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No bookmarks yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bookmark ayahs while reading',
                    style: TextStyle(fontSize: 14, color: textSecondary),
                  ),
                  const SizedBox(height: 24),
                  // Manual refresh button
                  OutlinedButton.icon(
                    onPressed: loadBookmarks,
                    icon: Icon(Icons.refresh),
                    label: Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.teal),
                      foregroundColor: Colors.teal,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                final bookmark = bookmarks[index];
                final surahNumber = bookmark['surahNumber'];
                final ayahNumber = bookmark['ayahNumber'];
                final surahName = bookmark['surahName'];
                final note = bookmark['note'] ?? '';
                final timestamp = DateTime.parse(bookmark['timestamp']);
                final formattedDate =
                    '${timestamp.day}/${timestamp.month}/${timestamp.year}';

                return Card(
                  color: card,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AyahScreen(
                            surahNumber: surahNumber,
                            surahName: surahName,
                            initialAyahIndex: ayahNumber - 1,
                          ),
                        ),
                      ).then((_) => loadBookmarks());
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Bookmark icon
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: chip,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.bookmark,
                              color: textPrimary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  surahName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Surah $surahNumber, Ayah $ayahNumber',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textSecondary,
                                  ),
                                ),
                                if (note.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    note,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Delete button
                          IconButton(
                            icon: Icon(Icons.delete_outline),
                            color: Colors.red,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Remove Bookmark'),
                                  content: Text(
                                    'Are you sure you want to remove this bookmark?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        deleteBookmark(surahNumber, ayahNumber);
                                      },
                                      child: Text(
                                        'Remove',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
