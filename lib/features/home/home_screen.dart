import 'package:flutter/material.dart';
import '../../core/storage/local_storage.dart';
import '../../core/services/quran_api.dart';
import '../quran/surah_list_screen.dart';
import '../quran/ayah_screen.dart';

enum _Range { today, week, all }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _Range _range = _Range.today;

  Future<void> _continueReading() async {
    final lastRead = LocalStorage.getLastRead();
    final surahNumber = lastRead['surah']!;
    final ayahNumber = lastRead['ayah']!;

    final surahData = await QuranAPI.getSurahWithTranslation(surahNumber);

    if (surahData != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AyahScreen(
            surahNumber: surahNumber,
            surahName: surahData.englishName,
            initialAyahIndex: ayahNumber - 1,
          ),
        ),
      ).then((_) => setState(() {}));
    }
  }

  String _formatSeconds(int seconds) {
    if (seconds <= 0) return '0s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m <= 0) return '${s}s';
    return '${m}m ${s}s';
  }

  String _formatCompactNumber(int value) {
    final abs = value.abs();
    String format(double n, String suffix) {
      final fixed = n >= 10 ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
      final clean = fixed.endsWith('.0')
          ? fixed.substring(0, fixed.length - 2)
          : fixed;
      return '$clean$suffix';
    }

    if (abs >= 1000000000) return format(value / 1000000000, 'B');
    if (abs >= 1000000) return format(value / 1000000, 'M');
    if (abs >= 1000) return format(value / 1000, 'K');
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2563EB); // blue
    const accent2 = Color(0xFF7C3AED); // violet
    const warm = Color(0xFFF59E0B); // amber
    const mint = Color(0xFF10B981); // green

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F1117) : const Color(0xFFF2F7F6);
    final todayKey = LocalStorage.dateKey();

    final goal = LocalStorage.getDailyGoal();
    final completed = LocalStorage.isCompleted(todayKey);
    final streak = LocalStorage.getCurrentStreak();
    final lastRead = LocalStorage.getLastRead();

    int hasanat;
    int verses;
    int seconds;

    switch (_range) {
      case _Range.today:
        hasanat = LocalStorage.getDailyHasanat(todayKey);
        verses = LocalStorage.getDailyAyahsRead(todayKey);
        seconds = LocalStorage.getDailySeconds(todayKey);
        break;
      case _Range.week:
        hasanat = LocalStorage.getWeeklyHasanat();
        verses = LocalStorage.getWeeklyAyahsRead();
        seconds = LocalStorage.getWeeklySeconds();
        break;
      case _Range.all:
        hasanat = LocalStorage.getAllTimeHasanat();
        verses = LocalStorage.getAllTimeAyahsRead();
        seconds = LocalStorage.getAllTimeSeconds();
        break;
    }

    final todayRead = LocalStorage.getDailyAyahsRead(todayKey);
    final progressValue = goal <= 0 ? 0.0 : (todayRead / goal).clamp(0.0, 1.0);

    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final gridColumns = (isLandscape || size.width >= 700) ? 3 : 2;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: const Text("Today's Reading"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: surface,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, isLandscape ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Continue Reading (always visible)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF0B0F1A), Color(0xFF141B33)]
                        : const [Color(0xFFFFFFFF), Color(0xFFF3F6FF)],
                  ),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(isDark ? 0.22 : 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: _continueReading,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [accent, accent2]),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lastRead['surah'] == 1 && lastRead['ayah'] == 1
                                    ? 'Start reading'
                                    : 'Continue reading',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Surah ${lastRead['surah']}, Ayah ${lastRead['ayah']}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 28,
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            Color(0xFF0A1230),
                            Color(0xFF0D1E2A),
                            Color(0xFF1F1030),
                          ]
                        : const [
                            Color(0xFFEAF7FF),
                            Color(0xFFE9FFF2),
                            Color(0xFFF3ECFF),
                          ],
                  ),
                ),
                child: Column(
                  children: [
                    // Range selector
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black26
                            : Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: Row(
                        children: [
                          _RangePill(
                            label: 'Today',
                            selected: _range == _Range.today,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFA3E55E), Color(0xFF24C3A4)],
                            ),
                            onTap: () => setState(() => _range = _Range.today),
                          ),
                          _RangePill(
                            label: 'Week',
                            selected: _range == _Range.week,
                            gradient: const LinearGradient(
                              colors: [mint, accent],
                            ),
                            onTap: () => setState(() => _range = _Range.week),
                          ),
                          _RangePill(
                            label: 'All',
                            selected: _range == _Range.all,
                            gradient: const LinearGradient(
                              colors: [warm, accent2],
                            ),
                            onTap: () => setState(() => _range = _Range.all),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Stats grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final gap = 10.0;
                        final itemWidth =
                            (constraints.maxWidth - gap * (gridColumns - 1)) /
                            gridColumns;

                        final cards = <Widget>[
                          _StatCard(
                            title: 'Hasanat',
                            value: _formatCompactNumber(hasanat),
                            icon: Icons.favorite_rounded,
                            gradient: const LinearGradient(
                              colors: [accent2, accent],
                            ),
                            valueColor: const Color(0xFF6B43C6),
                          ),
                          _StatCard(
                            title: 'Verses',
                            value: '$verses',
                            icon: Icons.article_rounded,
                            gradient: const LinearGradient(
                              colors: [mint, Color(0xFF06B6D4)],
                            ),
                            valueColor: const Color(0xFF137E6D),
                          ),
                          _StatCard(
                            title: 'Time',
                            value: _formatSeconds(seconds),
                            icon: Icons.timer_rounded,
                            gradient: const LinearGradient(
                              colors: [warm, Color(0xFFEF4444)],
                            ),
                            valueColor: const Color(0xFFE85A0C),
                          ),
                        ];

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: cards
                              .map((c) => SizedBox(width: itemWidth, child: c))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Note (required)
              Text(
                'Note: These calculations are based on authentic hadith describing the reward for reciting the Qur’an and represent an estimated minimum. Actual reward is granted by Allah alone and depends on sincerity, intention, presence of heart, and may be multiplied by His mercy or diminished due to heedlessness or pride.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),

              const SizedBox(height: 14),

              // Streak + goal card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF0B0F1A), Color(0xFF111827)]
                        : const [Colors.white, Color(0xFFF8FAFF)],
                  ),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: warm,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Streak',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$streak day${streak == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: warm,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // last 7 days completion bars
                    Row(
                      children: List.generate(7, (i) {
                        final day = DateTime.now().subtract(
                          Duration(days: 6 - i),
                        );
                        final dk = LocalStorage.dateKey(day);
                        final done = LocalStorage.isCompleted(dk);

                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 9,
                            margin: EdgeInsets.only(right: i == 6 ? 0 : 6),
                            decoration: BoxDecoration(
                              color: done
                                  ? warm
                                  : (isDark ? Colors.white10 : Colors.black12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'Daily goal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$todayRead / $goal ayahs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progressValue,
                        minHeight: 10,
                        backgroundColor: isDark
                            ? Colors.white10
                            : Colors.black12,
                        valueColor: const AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      completed
                          ? '✓ Goal completed for today'
                          : 'Complete your goal to add +1 to your streak (once per day).',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Browse All Surahs
              SizedBox(
                width: double.infinity,
                height: isLandscape ? 48 : 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [accent, accent2]),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(isDark ? 0.25 : 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SurahListScreen(),
                        ),
                      ).then((_) => setState(() {}));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Browse All Surahs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  final String label;
  final bool selected;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _RangePill({
    required this.label,
    required this.selected,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedText = isDark ? Colors.white70 : const Color(0xFF334155);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? gradient : null,
            color: selected
                ? null
                : (isDark ? Colors.transparent : Colors.transparent),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : unselectedText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  final Color valueColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 128,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF111827) : Colors.white,
        border: Border.all(color: isDark ? Colors.white12 : Colors.black26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: gradient,
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : valueColor,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
