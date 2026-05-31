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

/// Result from the Juz start dialog: which (surah, ayah) to open.
class _JuzDialogResult {
  final int surahNumber;
  final int ayahInSurah;
  final String surahName;
  _JuzDialogResult(this.surahNumber, this.ayahInSurah, this.surahName);
}

/// One segment of a Juz: a surah and the ayah range within it for this Juz.
class _JuzSegment {
  final int surahNumber;
  final String surahName;
  final int startAyah;
  final int endAyah;
  _JuzSegment(this.surahNumber, this.surahName, this.startAyah, this.endAyah);
}

/// Indo-Pak start (surah, ayah) for each Juz (1–30). Used for display and segment ranges.
const List<({int surah, int ayah})> _indoPakJuzStarts = [
  (surah: 1, ayah: 1), (surah: 2, ayah: 142), (surah: 2, ayah: 253), (surah: 3, ayah: 92), (surah: 4, ayah: 24),
  (surah: 4, ayah: 148), (surah: 5, ayah: 83), (surah: 6, ayah: 111), (surah: 7, ayah: 88), (surah: 8, ayah: 41),
  (surah: 9, ayah: 94), (surah: 11, ayah: 6), (surah: 12, ayah: 53), (surah: 15, ayah: 2),
  (surah: 17, ayah: 1), (surah: 18, ayah: 75), (surah: 21, ayah: 1), (surah: 23, ayah: 1), (surah: 25, ayah: 21),
  (surah: 27, ayah: 60), (surah: 29, ayah: 45), (surah: 33, ayah: 31), (surah: 36, ayah: 22), (surah: 39, ayah: 32),
  (surah: 41, ayah: 47), (surah: 46, ayah: 1), (surah: 51, ayah: 31), (surah: 58, ayah: 1), (surah: 67, ayah: 1),
  (surah: 78, ayah: 1),
];

/// Number of ayahs per surah (1–114). Matches app data.
const List<int> _surahAyahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128,
  111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54,
  45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62,
  55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28,
  20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15,
  21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
];

/// English names for surahs 1–114. Matches app data.
const List<String> _surahEnglishNames = [
  'Al-Faatiha', 'Al-Baqara', 'Aal-i-Imraan', 'An-Nisaa', 'Al-Maaida',
  'Al-An\'aam', 'Al-A\'raaf', 'Al-Anfaal', 'At-Tawba', 'Yunus', 'Hud',
  'Yusuf', 'Ar-Ra\'d', 'Ibrahim', 'Al-Hijr', 'An-Nahl', 'Al-Israa',
  'Al-Kahf', 'Maryam', 'Taa-Haa', 'Al-Anbiyaa', 'Al-Hajj', 'Al-Muminoon',
  'An-Noor', 'Al-Furqaan', 'Ash-Shu\'araa', 'An-Naml', 'Al-Qasas',
  'Al-Ankaboot', 'Ar-Room', 'Luqman', 'As-Sajda', 'Al-Ahzaab', 'Saba',
  'Faatir', 'Yaseen', 'As-Saaffaat', 'Saad', 'Az-Zumar', 'Ghafir',
  'Fussilat', 'Ash-Shura', 'Az-Zukhruf', 'Ad-Dukhaan', 'Al-Jaathiya',
  'Al-Ahqaf', 'Muhammad', 'Al-Fath', 'Al-Hujuraat', 'Qaaf',
  'Adh-Dhaariyat', 'At-Tur', 'An-Najm', 'Al-Qamar', 'Ar-Rahmaan',
  'Al-Waaqia', 'Al-Hadid', 'Al-Mujaadila', 'Al-Hashr', 'Al-Mumtahana',
  'As-Saff', 'Al-Jumu\'a', 'Al-Munaafiqoon', 'At-Taghaabun', 'At-Talaaq',
  'At-Tahrim', 'Al-Mulk', 'Al-Qalam', 'Al-Haaqqa', 'Al-Ma\'aarij',
  'Nooh', 'Al-Jinn', 'Al-Muzzammil', 'Al-Muddaththir', 'Al-Qiyaama',
  'Al-Insaan', 'Al-Mursalaat', 'An-Naba', 'An-Naazi\'aat', 'Abasa',
  'At-Takwir', 'Al-Infitaar', 'Al-Mutaffifin', 'Al-Inshiqaaq', 'Al-Burooj',
  'At-Taariq', 'Al-A\'laa', 'Al-Ghaashiya', 'Al-Fajr', 'Al-Balad',
  'Ash-Shams', 'Al-Lail', 'Ad-Dhuhaa', 'Ash-Sharh', 'At-Tin', 'Al-Alaq',
  'Al-Qadr', 'Al-Bayyina', 'Az-Zalzala', 'Al-Aadiyaat', 'Al-Qaari\'a',
  'At-Takaathur', 'Al-Asr', 'Al-Humaza', 'Al-Fil', 'Quraish', 'Al-Maa\'un',
  'Al-Kawthar', 'Al-Kaafiroon', 'An-Nasr', 'Al-Masad', 'Al-Ikhlaas',
  'Al-Falaq', 'An-Naas',
];

const List<_JuzInfo> _juzNamesAndEnd = [
  _JuzInfo('Alif Lam Meem', 2, 141),
  _JuzInfo('Sayaqool', 2, 252),
  _JuzInfo('Tilka Ar-Rusul', 3, 91),
  _JuzInfo('Lan Tana Loo', 4, 23),
  _JuzInfo('Wal-Muhsanat', 4, 147),
  _JuzInfo('La Yuhibbullah', 5, 82),
  _JuzInfo('Wa Iza Sami\'u', 6, 110),
  _JuzInfo('Wa Lau Annana', 7, 87),
  _JuzInfo('Qalal Malao', 8, 40),
  _JuzInfo('Wa A\'lamu', 9, 93),
  _JuzInfo('Ya\'taziroon', 11, 5),
  _JuzInfo('Wa Mamin Da\'abba', 12, 52),
  _JuzInfo('Wa Ma Ubarri\'u', 15, 1),
  _JuzInfo('Rubama', 16, 128),
  _JuzInfo('Subhanallazi', 18, 74),
  _JuzInfo('Qal Alam', 20, 135),
  _JuzInfo('Iqtaraba', 22, 78),
  _JuzInfo('Qad Aflaha', 25, 20),
  _JuzInfo('Wa Qalallazina', 27, 59),
  _JuzInfo('Aman Khalaq', 29, 44),
  _JuzInfo('Utlu Ma Oohiya', 33, 30),
  _JuzInfo('Wa Man Yaqnut', 36, 21),
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

    // Use Indo-Pak start boundaries for all 30 Juz (no API dependency for Juz tab).
    final list = <JuzStart>[];
    for (int i = 0; i < _indoPakJuzStarts.length && i < 30; i++) {
      final start = _indoPakJuzStarts[i];
      final name = (start.surah >= 1 && start.surah <= _surahEnglishNames.length)
          ? _surahEnglishNames[start.surah - 1]
          : 'Surah ${start.surah}';
      list.add(JuzStart(
        juzNumber: i + 1,
        surahNumber: start.surah,
        surahEnglishName: name,
        ayahNumberInSurah: start.ayah,
      ));
    }

    setState(() {
      _juzStarts = list;
      _filtered = list;
      _isLoading = false;
      if (list.isEmpty) {
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

  /// Builds the list of (surah, ayah range) segments for this Juz.
  List<_JuzSegment> _buildJuzSegments(JuzStart juz) {
    final juzIndex = juz.juzNumber - 1;
    if (juzIndex < 0 || juzIndex >= _juzNamesAndEnd.length) return [];
    final info = _juzNamesAndEnd[juzIndex];
    final segments = <_JuzSegment>[];
    int s = juz.surahNumber;
    int a = juz.ayahNumberInSurah;
    final endS = info.endSurah;
    final endA = info.endAyah;
    if (s < 1 || s > 114) return [];
    while (true) {
      final len = (s <= _surahAyahCounts.length)
          ? _surahAyahCounts[s - 1]
          : 0;
      if (len <= 0) break;
      final endInSurah = (s == endS) ? endA : len;
      final name = (s <= _surahEnglishNames.length)
          ? _surahEnglishNames[s - 1]
          : 'Surah $s';
      segments.add(_JuzSegment(s, name, a, endInSurah));
      if (s == endS) break;
      s++;
      a = 1;
      if (s > 114) break;
    }
    return segments;
  }

  Future<_JuzDialogResult?> _showAyahStartDialog(
      BuildContext context, JuzStart juz) async {
    final segments = _buildJuzSegments(juz);
    if (segments.isEmpty || !context.mounted) return null;

    final juzIndex = juz.juzNumber - 1;
    final juzName = juzIndex >= 0 && juzIndex < _juzNamesAndEnd.length
        ? _juzNamesAndEnd[juzIndex].name
        : null;

    final selectedIndexNotifier = ValueNotifier<int>(0);
    final controller = TextEditingController(
      text: '${segments[0].startAyah}',
    );
    String? error;

    return showDialog<_JuzDialogResult>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            final selectedSegmentIndex = selectedIndexNotifier.value;
            final seg = segments[selectedSegmentIndex];
            final minA = seg.startAyah;
            final maxA = seg.endAyah;

            return AlertDialog(
              title: Text(
                juzName != null
                    ? 'Start Juz ${juz.juzNumber} ($juzName)'
                    : 'Start ${juz.surahEnglishName}',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (segments.length > 1) ...[
                      Text(
                        'Surah in this Juz',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(ctx).hintColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: selectedSegmentIndex,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: List.generate(segments.length, (i) {
                          final s = segments[i];
                          return DropdownMenuItem<int>(
                            value: i,
                            child: Text(
                              '${s.surahName} (${s.startAyah}–${s.endAyah})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                        onChanged: (v) {
                          if (v != null) {
                            selectedIndexNotifier.value = v;
                            controller.text =
                                '${segments[v].startAyah}';
                            setStateDialog(() => error = null);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      '${seg.surahName} · Choose ayah ($minA – $maxA)',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: segments.length <= 1,
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        hintText: 'Ayah number',
                        errorText: error,
                      ),
                      onChanged: (_) => setStateDialog(() => error = null),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      ctx,
                      _JuzDialogResult(
                        seg.surahNumber,
                        seg.startAyah,
                        seg.surahName,
                      ),
                    );
                  },
                  child: Text('Ayah ${seg.startAyah}'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final value = int.tryParse(controller.text.trim());
                    if (value == null || value < minA || value > maxA) {
                      setStateDialog(() {
                        error = 'Enter a number between $minA and $maxA';
                      });
                      return;
                    }
                    Navigator.pop(
                      ctx,
                      _JuzDialogResult(
                        seg.surahNumber,
                        value,
                        seg.surahName,
                      ),
                    );
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
                            _showAyahStartDialog(context, juz).then((result) {
                              if (result == null || !context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AyahScreen(
                                    surahNumber: result.surahNumber,
                                    surahName: result.surahName,
                                    initialAyahIndex: result.ayahInSurah - 1,
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
