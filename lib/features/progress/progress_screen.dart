import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/quran_api.dart';
import '../quran/ayah_screen.dart';

/// Traditional names and end references for each Juz (from 1 to 30).
/// Start references come from [JuzStart]; end references are fixed.
class _JuzInfo {
  final String name;
  final int endSurah;
  final int endAyah;
  const _JuzInfo(this.name, this.endSurah, this.endAyah);
}

const List<_JuzInfo> _juzNamesAndEnd = [
  _JuzInfo('Alif Lam Meem', 2, 141),
  _JuzInfo('Sayaqool', 2, 252),
  _JuzInfo('Tilka Ar-Rusul', 3, 92),
  _JuzInfo('Lan Tana Loo', 4, 23),
  _JuzInfo('Wal-Muhsanat', 4, 147),
  _JuzInfo('La Yuhibbullah', 5, 81),
  _JuzInfo('Wa Iza Sami\'u', 6, 110),
  _JuzInfo('Wa Lau Annana', 7, 87),
  _JuzInfo('Qalal Malao', 8, 40),
  _JuzInfo('Wa A\'lamu', 9, 92),
  _JuzInfo('Ya\'taziroon', 11, 5),
  _JuzInfo('Wa Mamin Da\'abba', 12, 52),
  _JuzInfo('Wa Ma Ubarri\'u', 14, 52),
  _JuzInfo('Rubama', 16, 128),
  _JuzInfo('Subhanallazi', 18, 74),
  _JuzInfo('Qal Alam', 20, 135),
  _JuzInfo('Iqtaraba', 22, 78),
  _JuzInfo('Qad Aflaha', 25, 20),
  _JuzInfo('Wa Qalallazina', 27, 55),
  _JuzInfo('Aman Khalaq', 29, 45),
  _JuzInfo('Utlu Ma Oohiya', 33, 30),
  _JuzInfo('Wa Man Yaqnut', 36, 27),
  _JuzInfo('Wa Mali', 39, 31),
  _JuzInfo('Faman Azlam', 41, 46),
  _JuzInfo('Elahe Yuraddu', 45, 37),
  _JuzInfo('Ha\'a Meem', 51, 30),
  _JuzInfo('Qala Fama Khatbukum', 57, 29),
  _JuzInfo('Qad Sami Allah', 66, 12),
  _JuzInfo('Tabarakallazi', 77, 50),
  _JuzInfo('Amma Yatasa\'aloon', 114, 6),
];

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<JuzStart> _juzStarts = [];
  List<JuzStart> _filtered = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadJuz();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJuz() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final data = await QuranAPI.getAllJuzStarts();
    setState(() {
      _juzStarts = data;
      _filtered = data;
      _isLoading = false;
      if (data.isEmpty) {
        _error = 'Failed to load Juz list.';
      }
    });
  }

  void _filter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _juzStarts;
      } else {
        _filtered = _juzStarts.where((j) {
          final name = (j.juzNumber <= _juzNamesAndEnd.length)
              ? _juzNamesAndEnd[j.juzNumber - 1].name.toLowerCase()
              : '';
          return j.juzNumber.toString().contains(q) ||
              j.surahEnglishName.toLowerCase().contains(q) ||
              j.surahNumber.toString().contains(q) ||
              name.contains(q);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
  }

  Future<int?> _showAyahStartDialog(BuildContext context, JuzStart juz) async {
    final detail = await QuranAPI.getSurahWithTranslation(juz.surahNumber);
    if (detail == null || !context.mounted) return null;
    final maxAyah = detail.numberOfAyahs > 0 ? detail.numberOfAyahs : 1;
    final initialAyah = juz.ayahNumberInSurah.clamp(1, maxAyah);
    final controller = TextEditingController(text: '$initialAyah');
    String? error;

    final juzIndex = juz.juzNumber - 1;
    final juzName = juzIndex >= 0 && juzIndex < _juzNamesAndEnd.length
        ? _juzNamesAndEnd[juzIndex].name
        : null;

    return showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(
                juzName != null
                    ? 'Start Juz ${juz.juzNumber} ($juzName)'
                    : 'Start ${juz.surahEnglishName}',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${juz.surahEnglishName} · Choose ayah (1 - $maxAyah)',
                  ),
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
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 1),
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
                    Navigator.pop(ctx, value);
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
          'Juz Reading',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: surface,
        iconTheme: IconThemeData(color: textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadJuz,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
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
                hintText: 'Search Juz by number or Surah...',
                prefixIcon: Icon(Icons.search, color: Colors.teal),
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
                  borderSide: const BorderSide(color: Colors.teal, width: 1.4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
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
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _loadJuz,
                            icon: Icon(Icons.refresh),
                            label: Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final juz = _filtered[index];
                      final info = juz.juzNumber <= _juzNamesAndEnd.length
                          ? _juzNamesAndEnd[juz.juzNumber - 1]
                          : null;
                      final rangeStr = info != null
                          ? '${juz.surahNumber}:${juz.ayahNumberInSurah} – ${info.endSurah}:${info.endAyah}'
                          : 'Starts at ${juz.surahEnglishName} (${juz.surahNumber}:${juz.ayahNumberInSurah})';
                      final subtitleStr = info != null
                          ? '${info.name} · $rangeStr'
                          : 'Starts at ${juz.surahEnglishName} (${juz.surahNumber}:${juz.ayahNumberInSurah})';
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
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: chip,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '${juz.juzNumber}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            'Juz ${juz.juzNumber}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: textPrimary,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              subtitleStr,
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
                            _showAyahStartDialog(context, juz).then((ayah) {
                              if (ayah == null || !context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AyahScreen(
                                    surahNumber: juz.surahNumber,
                                    surahName: juz.surahEnglishName,
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
