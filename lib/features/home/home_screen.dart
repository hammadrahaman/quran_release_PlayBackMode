import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/storage/local_storage.dart';
import '../../core/services/play_store_update_service.dart';
import '../../core/services/quran_api.dart';
import '../../core/services/review_service.dart';
import '../../core/services/update_check_service.dart';
import '../../core/services/whats_new_service.dart';
import '../quran/ayah_screen.dart';
import '../quran/full_surah_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _recitationTimer;

  @override
  void initState() {
    super.initState();
    ReviewService.recordAppOpen();
    _recitationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowUpdateDialog();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await WhatsNewService.maybeShow(context);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await _maybeShowReview();
    });
  }

  @override
  void dispose() {
    _recitationTimer?.cancel();
    super.dispose();
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

  _RecitationMode _recitationMode() {
    final now = DateTime.now();
    final hour = now.hour;
    final isFriday = now.weekday == DateTime.friday;
    if (isFriday && hour >= 12 && hour < 19) return _RecitationMode.friday;
    if (hour >= 19 || hour == 0) return _RecitationMode.night;
    return _RecitationMode.none;
  }

  Future<void> _continueReading() async {
    final lastRead = LocalStorage.getLastRead();
    final surahNumber = lastRead['surah']!;
    final ayahNumber = lastRead['ayah']!;

    final surahData = await QuranAPI.getSurahWithTranslation(surahNumber);

    if (surahData != null && mounted) {
      final mode = LocalStorage.getReadingMode();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => mode == 'surah'
              ? FullSurahScreen(
                  surahNumber: surahNumber,
                  surahName: surahData.englishName,
                  initialAyahIndex: ayahNumber - 1,
                )
              : AyahScreen(
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
        child: RefreshIndicator(
          color: green,
          onRefresh: () async => setState(() {}),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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

              // Recitation section (time-gated)
              Builder(builder: (_) {
                final mode = _recitationMode();
                if (mode == _RecitationMode.none) return const SizedBox.shrink();
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    _RecitationSection(mode: mode, isDark: isDark),
                  ],
                );
              }),

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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Recitation section
// ─────────────────────────────────────────────────────────────

enum _RecitationMode { none, night, friday }

class _RecItem {
  final String id;
  final String displayName;
  final String arabic;
  final String? subtitle;
  final int surahNumber;
  final String surahName;
  final int initialAyahIndex;
  const _RecItem({
    required this.id,
    required this.displayName,
    required this.arabic,
    this.subtitle,
    required this.surahNumber,
    required this.surahName,
    required this.initialAyahIndex,
  });
}

const _nightItems = <_RecItem>[
  _RecItem(id: 'mulk', displayName: 'Surah Al-Mulk', arabic: 'الملك', surahNumber: 67, surahName: 'Al-Mulk', initialAyahIndex: 0),
  _RecItem(id: 'baqarah', displayName: 'Surah Al-Baqarah', arabic: 'البقرة', subtitle: 'Last 2 Ayahs (285–286)', surahNumber: 2, surahName: 'Al-Baqarah', initialAyahIndex: 284),
  _RecItem(id: 'ikhlas', displayName: 'Surah Al-Ikhlas', arabic: 'الإخلاص', surahNumber: 112, surahName: 'Al-Ikhlas', initialAyahIndex: 0),
  _RecItem(id: 'falaq', displayName: 'Surah Al-Falaq', arabic: 'الفلق', surahNumber: 113, surahName: 'Al-Falaq', initialAyahIndex: 0),
  _RecItem(id: 'nas', displayName: 'Surah An-Nas', arabic: 'الناس', surahNumber: 114, surahName: 'An-Nas', initialAyahIndex: 0),
];

const _fridayItems = <_RecItem>[
  _RecItem(id: 'kahf', displayName: 'Surah Al-Kahf', arabic: 'الكهف', surahNumber: 18, surahName: 'Al-Kahf', initialAyahIndex: 0),
  _RecItem(id: 'jumuah', displayName: "Surah Al-Jumu'ah", arabic: 'الجمعة', surahNumber: 62, surahName: "Al-Jumu'ah", initialAyahIndex: 0),
];

class _RecitationSection extends StatefulWidget {
  final _RecitationMode mode;
  final bool isDark;

  const _RecitationSection({required this.mode, required this.isDark});

  @override
  State<_RecitationSection> createState() => _RecitationSectionState();
}

class _RecitationSectionState extends State<_RecitationSection> {
  late List<String> _completedList;

  bool get _isFriday => widget.mode == _RecitationMode.friday;
  String get _storageType => _isFriday ? 'friday' : 'night';
  String get _dateKey => LocalStorage.dateKey();
  List<_RecItem> get _items => _isFriday ? _fridayItems : _nightItems;

  // Design tokens
  static const _greenAccent = Color(0xFF22C55E);
  static const _goldAccent = Color(0xFFD4AF37);
  static const _titleLight = Color(0xFF111827);
  static const _subtitleLight = Color(0xFF6B7280);
  static const _trackLight = Color(0xFFE5E7EB);
  static const _incompleteLight = Color(0xFFD1D5DB);
  static const _cardDark = Color(0xFF101B2A);
  static const _borderDark = Color(0xFF1E293B);
  static const _subtitleDark = Color(0xFF94A3B8);
  static const _incompleteDark = Color(0xFF475569);

  Color get _accent => _isFriday ? _goldAccent : _greenAccent;

  @override
  void initState() {
    super.initState();
    _completedList = LocalStorage.getCompletedRecitations(_storageType, _dateKey);
  }

  @override
  void didUpdateWidget(_RecitationSection old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) {
      _completedList = LocalStorage.getCompletedRecitations(_storageType, _dateKey);
    }
  }

  void _toggle(String id) {
    LocalStorage.toggleRecitation(_storageType, _dateKey, id);
    setState(() {
      _completedList = LocalStorage.getCompletedRecitations(_storageType, _dateKey);
    });
  }

  void _markDone(String id) {
    if (_completedList.contains(id)) return;
    LocalStorage.toggleRecitation(_storageType, _dateKey, id);
    setState(() {
      _completedList = LocalStorage.getCompletedRecitations(_storageType, _dateKey);
    });
  }

  void _openItem(_RecItem item) {
    final mode = LocalStorage.getReadingMode();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => mode == 'surah'
            ? FullSurahScreen(
                surahNumber: item.surahNumber,
                surahName: item.surahName,
                initialAyahIndex: item.initialAyahIndex,
              )
            : AyahScreen(
                surahNumber: item.surahNumber,
                surahName: item.surahName,
                initialAyahIndex: item.initialAyahIndex,
                isFromRecitation: true,
                onSurahCompleted: () => _markDone(item.id),
              ),
      ),
    );
  }

  void _openNextIncomplete() {
    final next = _items.firstWhere(
      (it) => !_completedList.contains(it.id),
      orElse: () => _items.first,
    );
    _openItem(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final total = _items.length;
    final done = _completedList.length;
    final progress = total == 0 ? 0.0 : done / total;
    final isAllDone = done >= total;
    final accent = _accent;

    final cardBg = isDark ? _cardDark : Colors.white;
    final titleColor = isDark ? Colors.white : _titleLight;
    final subtitleColor = isDark ? _subtitleDark : _subtitleLight;
    final trackColor = isDark ? _borderDark : _trackLight;
    final incompleteColor = isDark ? _incompleteDark : _incompleteLight;

    final title = _isFriday ? 'Friday Recitations' : 'Night Recitations';
    final icon = _isFriday ? '🕌' : '🌙';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: _borderDark) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.0 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAllDone
                          ? '✨ Completed'
                          : '$done of $total completed',
                      style: TextStyle(
                        fontSize: 14,
                        color: isAllDone ? accent : subtitleColor,
                        fontWeight: isAllDone ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Progress bar + % ──
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: trackColor,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Items ──
          ...List.generate(_items.length, (i) {
            final item = _items[i];
            final isDone = _completedList.contains(item.id);
            return Column(
              children: [
                if (i > 0)
                  Divider(height: 1, color: isDark ? _borderDark : _trackLight),
                InkWell(
                  onTap: () => _openItem(item),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        // Toggle circle
                        GestureDetector(
                          onTap: () => _toggle(item.id),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDone ? accent : Colors.transparent,
                              border: isDone
                                  ? null
                                  : Border.all(color: incompleteColor, width: 1.5),
                            ),
                            child: isDone
                                ? Icon(Icons.check_rounded,
                                    color: Colors.white, size: 13)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: titleColor,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                  decorationColor: subtitleColor,
                                ),
                              ),
                              if (item.subtitle != null)
                                Text(
                                  item.subtitle!,
                                  style: TextStyle(fontSize: 12, color: subtitleColor),
                                ),
                            ],
                          ),
                        ),
                        // Arabic
                        Text(
                          item.arabic,
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'IndoPak',
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),

          const SizedBox(height: 16),

          // ── Footer ──
          if (isAllDone)
            Center(
              child: Text(
                'May Allah accept your recitation.',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: subtitleColor,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _openNextIncomplete,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Continue Reading',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, color: accent, size: 18),
                ],
              ),
            ),
        ],
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
