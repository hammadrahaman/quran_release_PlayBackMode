import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/quran_api.dart';
import '../../core/storage/local_storage.dart';
import 'ayah_screen.dart';
import 'full_surah_screen.dart';

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  List<Surah> surahs = [];
  List<Surah> filteredSurahs = [];
  bool isLoading = true;
  String? errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadSurahs();
    _searchController.addListener(_filterSurahs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadSurahs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await QuranAPI.getAllSurahs();
      setState(() {
        surahs = data;
        filteredSurahs = data;
        isLoading = false;
        if (data.isEmpty) {
          errorMessage =
              'No surahs found. Please check your internet connection.';
        }
      });
    } catch (_) {
      setState(() {
        isLoading = false;
        errorMessage =
            'Failed to load Quran data. Please check your internet connection and try again.';
      });
    }
  }

  void _filterSurahs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredSurahs = surahs;
      } else {
        filteredSurahs = surahs.where((surah) {
          return surah.englishName.toLowerCase().contains(query) ||
              surah.englishNameTranslation.toLowerCase().contains(query) ||
              surah.number.toString().contains(query) ||
              surah.name.contains(query);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
  }

  Future<int?> _showAyahStartDialog(Surah surah) async {
    final maxAyah = surah.numberOfAyahs > 0 ? surah.numberOfAyahs : 1;
    final lastRead = LocalStorage.getLastRead();
    final suggestedAyah = (lastRead['surah'] == surah.number)
        ? (lastRead['ayah'] ?? 1)
        : 1;
    final initialAyah = suggestedAyah.clamp(1, maxAyah);
    final controller = TextEditingController(text: '$initialAyah');
    String? error;

    return showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Start ${surah.englishName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose ayah (1 - $maxAyah)'),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Ayah number',
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 1),
                  child: Text('Ayah 1'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final value = int.tryParse(controller.text.trim());
                    if (value == null || value < 1 || value > maxAyah) {
                      setStateDialog(() {
                        error = 'Enter a number between 1 and $maxAyah';
                      });
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: Text('Start'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF121417) : const Color(0xFFF2F7F6);
    final card = isDark ? const Color(0xFF1B1E23) : Colors.white;
    final chip = isDark ? const Color(0xFF1F3A28) : const Color(0xFFD4EDDA);
    const green = Color(0xFF2D7A4F);
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
          'Quran Reading',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: surface,
        iconTheme: IconThemeData(color: textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: loadSurahs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Search Surah by name or number...',
                prefixIcon: Icon(Icons.search, color: green),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: textSecondary),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E2228) : Colors.white,
                hintStyle: TextStyle(color: textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: green, width: 1.4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          if (filteredSurahs.isNotEmpty && _searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Found ${filteredSurahs.length} Surah(s)',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: loadSurahs,
                            icon: Icon(Icons.refresh),
                            label: Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : filteredSurahs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: TextStyle(fontSize: 16, color: textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different search term',
                          style: TextStyle(fontSize: 14, color: textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredSurahs.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final surah = filteredSurahs[index];
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
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: chip,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '${surah.number}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  surah.englishName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                surah.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${surah.englishNameTranslation} • ${surah.numberOfAyahs} Ayahs',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                          onTap: () {
                            _showAyahStartDialog(surah).then((ayah) {
                              if (ayah == null || !context.mounted) return;
                              final mode = LocalStorage.getReadingMode();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => mode == 'surah'
                                      ? FullSurahScreen(
                                          surahNumber: surah.number,
                                          surahName: surah.englishName,
                                          initialAyahIndex: ayah - 1,
                                        )
                                      : AyahScreen(
                                          surahNumber: surah.number,
                                          surahName: surah.englishName,
                                          initialAyahIndex: ayah - 1,
                                        ),
                                ),
                              );
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
