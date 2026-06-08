import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/storage/local_storage.dart';
import '../../core/services/play_store_update_service.dart';
import '../../core/services/quran_api.dart';
import '../../core/services/review_service.dart';
import '../../core/services/update_check_service.dart';
import '../quran/ayah_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    ReviewService.recordAppOpen();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowUpdateDialog();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await _maybeShowReview();
    });
  }

  Future<void> _maybeShowReview() async {
    final shouldShow = await ReviewService.shouldShowReviewDialog();
    if (!mounted || !shouldShow) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enjoying Iqra Quran Daily?'),
        content: const Text(
          'Your rating helps others discover the app. Would you take a moment to rate us on the Play Store?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              ReviewService.recordReviewLater();
              Navigator.of(ctx).pop();
            },
            child: const Text('Maybe Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await ReviewService.requestReview();
              if (!mounted || ok) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unable to open review right now.')),
              );
            },
            child: const Text('Rate'),
          ),
        ],
      ),
    );
  }

  Future<void> _maybeShowUpdateDialog() async {
    final playInfo = await PlayStoreUpdateService.checkForUpdate();
    if (playInfo != null &&
        PlayStoreUpdateService.isUpdateAvailable(playInfo) &&
        mounted) {
      await PlayStoreUpdateService.performImmediateUpdate();
      return;
    }

    if (!mounted) return;
    final info = await UpdateCheckService.fetchVersionInfo();
    if (info == null || !mounted) return;
    final latest = info['latest_version'] ?? '';
    final storeUrl = info['store_url'] ?? '';
    final forceFlag = (info['force_update'] ?? '').toLowerCase() == 'true';
    final minSupportedVersion = info['min_supported_version'];
    if (latest.isEmpty) return;

    final pkg = await PackageInfo.fromPlatform();
    final hasUpdate = UpdateCheckService.isVersionNewer(latest, pkg.version);
    final isForced = UpdateCheckService.isForceUpdate(
      currentVersion: pkg.version,
      latestVersion: latest,
      minSupportedVersion: minSupportedVersion,
      forceFlag: forceFlag,
    );
    if (!hasUpdate && !isForced) return;
    if (!isForced && LocalStorage.getLastDismissedUpdateVersion() == latest) return;

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: !isForced,
      builder: (ctx) => PopScope(
        canPop: !isForced,
        child: AlertDialog(
          title: const Text('Update available'),
          content: Text(
            isForced
                ? 'Version $latest is required to continue using the app. Please update now.'
                : 'A new version ($latest) is available. Update now for the latest features and improvements.',
          ),
          actions: [
            if (!isForced)
              TextButton(
                onPressed: () {
                  UpdateCheckService.markUpdateDialogDismissed(latest);
                  Navigator.of(ctx).pop();
                },
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                UpdateCheckService.openStore(storeUrl.isNotEmpty ? storeUrl : null);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

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

  String _formatCompactNumber(int value) {
    final abs = value.abs();
    String fmt(double n, String suffix) {
      final s = n >= 10 ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
      return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}$suffix';
    }
    if (abs >= 1000000000) return fmt(value / 1000000000, 'B');
    if (abs >= 1000000) return fmt(value / 1000000, 'M');
    if (abs >= 1000) return fmt(value / 1000, 'K');
    return '$value';
  }

  String _formatSeconds(int seconds) {
    if (seconds <= 0) return '0m';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m <= 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }

  void _showHasanatInfoSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? const Color(0xFF3CAF6E) : const Color(0xFF2D7A4F);
    final bg = isDark ? const Color(0xFF1A2E20) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF666666);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'How Hasanat Are Estimated',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.black12,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, size: 18, color: textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _HasanatBullet(
                  iconData: Icons.menu_book_rounded,
                  iconColor: const Color(0xFF2D7A4F),
                  iconBg: const Color(0xFFD4EDDA),
                  text:
                      "The hasanat shown in this app are based on authentic hadith describing the reward for reciting the Qur'an and are intended as an estimated minimum only.",
                  textColor: textSecondary,
                ),
                const SizedBox(height: 14),
                _HasanatBullet(
                  iconData: Icons.favorite_rounded,
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFDBEAFE),
                  text:
                      'Actual reward is granted by Allah alone and depends on sincerity, intention, presence of heart, understanding, and acceptance by Him.',
                  textColor: textSecondary,
                ),
                const SizedBox(height: 14),
                _HasanatBullet(
                  iconData: Icons.trending_up_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  iconBg: const Color(0xFFEDE9FE),
                  text:
                      'Allah may multiply rewards through His mercy beyond what is shown here, or reduce them due to heedlessness, showing off, or lack of sincerity.',
                  textColor: textSecondary,
                ),
                const SizedBox(height: 14),
                _HasanatBullet(
                  iconData: Icons.auto_awesome_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  iconBg: const Color(0xFFFEF3C7),
                  text:
                      "This feature is designed to encourage consistent engagement with the Qur'an, not to determine one's true reward with Allah.",
                  textColor: textSecondary,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Last updated according to authentic hadith sources',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? const Color(0xFF3CAF6E) : const Color(0xFF2D7A4F);
    final bg = isDark ? const Color(0xFF0D1B12) : const Color(0xFFF5F5F5);
    final cardBg = isDark ? const Color(0xFF1A2E20) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF666666);
    final divider = isDark ? Colors.white12 : Colors.black12;

    final todayKey = LocalStorage.dateKey();
    final goal = LocalStorage.getDailyGoal();
    final completed = LocalStorage.isCompleted(todayKey);
    final streak = LocalStorage.getCurrentStreak();
    final lastRead = LocalStorage.getLastRead();

    final hasanat = LocalStorage.getDailyHasanat(todayKey);
    final seconds = LocalStorage.getDailySeconds(todayKey);
    final todayRead = LocalStorage.getDailyAyahsRead(todayKey);
    final progressValue = goal <= 0 ? 0.0 : (todayRead / goal).clamp(0.0, 1.0);

    final isFirstRead = lastRead['surah'] == 1 && lastRead['ayah'] == 1;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            18, 16, 18,
            MediaQuery.of(context).padding.bottom + 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assalamu Alaikum 👋',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Today's Reading",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 3,
                              decoration: BoxDecoration(
                                color: green,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 20,
                              height: 3,
                              decoration: BoxDecoration(
                                color: green,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Continue Reading card
              GestureDetector(
                onTap: _continueReading,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                  height: 180,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Full-card mosque background image
                      Image.asset(
                        isDark
                            ? 'assets/images/mosque_dark.png'
                            : 'assets/images/mosque_light.png',
                        fit: BoxFit.cover,
                      ),

                      // Gradient overlay for text readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: isDark
                                ? [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.55),
                                    Colors.black.withOpacity(0.75),
                                  ]
                                : [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.25),
                                    Colors.black.withOpacity(0.50),
                                  ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),

                      // Content overlay
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue Reading',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF3CAF6E)
                                    : const Color(0xFF90EFB8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isFirstRead
                                  ? 'Al-Faatiha, Ayah 1'
                                  : 'Surah ${lastRead['surah']}, Ayah ${lastRead['ayah']}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: const [
                                Icon(
                                  Icons.bookmark_border_rounded,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Last read',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: green,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Resume Reading',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Stats row: Hasanat | Circular Daily Goal | Time
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Hasanat
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            color: green,
                            size: 26,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatCompactNumber(hasanat),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hasanat',
                            style: TextStyle(
                              fontSize: 12,
                              color: green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Vertical divider
                    Container(width: 1, height: 60, color: divider),

                    // Circular goal
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: CircularProgressIndicator(
                                    value: progressValue,
                                    strokeWidth: 7,
                                    backgroundColor: isDark
                                        ? Colors.white12
                                        : Colors.black12,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(green),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.menu_book_rounded,
                                      size: 16,
                                      color: green,
                                    ),
                                    Text(
                                      'Daily Goal',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: green,
                                      ),
                                    ),
                                    Text(
                                      '$todayRead / $goal',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Ayahs',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Vertical divider
                    Container(width: 1, height: 60, color: divider),

                    // Time
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            color: const Color(0xFFF59E0B),
                            size: 26,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatSeconds(seconds),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Time',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFFF59E0B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Reward Estimate card
              GestureDetector(
                onTap: _showHasanatInfoSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: green.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: green,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reward Estimate',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Based on authentic hadith',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: textSecondary,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Streak card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Text(
                          '$streak Day Streak',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      completed
                          ? 'Great job! Goal completed today.'
                          : streak == 0
                              ? 'Keep going! You can do it.'
                              : 'You\'re on a roll! Keep it up.',
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Day labels — derived from actual dates so they always match the dots
                    Row(
                      children: List.generate(7, (i) {
                        final day = DateTime.now().subtract(Duration(days: 6 - i));
                        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        final label = names[day.weekday - 1];
                        return Expanded(
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                color: textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),

                    // Dots with dashed connectors
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final slotWidth = constraints.maxWidth / 7;
                        return SizedBox(
                          height: 28,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // dashed line behind dots
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _DashedLinePainter(
                                    color: isDark
                                        ? Colors.white12
                                        : Colors.black12,
                                    slotWidth: slotWidth,
                                  ),
                                ),
                              ),
                              // dots
                              Row(
                                children: List.generate(7, (i) {
                                  final day = DateTime.now()
                                      .subtract(Duration(days: 6 - i));
                                  final dk = LocalStorage.dateKey(day);
                                  final done = LocalStorage.isCompleted(dk);
                                  return Expanded(
                                    child: Center(
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: done
                                              ? green
                                              : (isDark
                                                  ? const Color(0xFF1A2E20)
                                                  : Colors.white),
                                          border: done
                                              ? null
                                              : Border.all(
                                                  color: isDark
                                                      ? Colors.white24
                                                      : Colors.black12,
                                                  width: 1.5,
                                                ),
                                        ),
                                        child: done
                                            ? const Icon(
                                                Icons.star_rounded,
                                                color: Colors.white,
                                                size: 13,
                                              )
                                            : null,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

class _HasanatBullet extends StatelessWidget {
  final IconData iconData;
  final Color iconColor;
  final Color iconBg;
  final String text;
  final Color textColor;

  const _HasanatBullet({
    required this.iconData,
    required this.iconColor,
    required this.iconBg,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: TextStyle(fontSize: 13.5, color: textColor, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double slotWidth;

  const _DashedLinePainter({required this.color, required this.slotWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    final dotRadius = 12.0;
    const dashLen = 4.0;
    const dashGap = 3.0;

    for (int i = 0; i < 6; i++) {
      final x1 = slotWidth * i + slotWidth / 2 + dotRadius;
      final x2 = slotWidth * (i + 1) + slotWidth / 2 - dotRadius;
      double x = x1;
      while (x < x2) {
        final end = (x + dashLen).clamp(x, x2);
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
        x += dashLen + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) =>
      old.color != color || old.slotWidth != slotWidth;
}
