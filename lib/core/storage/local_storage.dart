import 'package:hive/hive.dart';

class LocalStorage {
  static final Box _settings = Hive.box('settings');
  static final Box _progress = Hive.box('progress');
  static final Box _bookmarks = Hive.box('bookmarks');

  // ----------------------------
  // Existing (keep unchanged APIs)
  // ----------------------------

  // Daily goal
  static int getDailyGoal() => _settings.get('dailyGoal', defaultValue: 5);
  static void setDailyGoal(int goal) => _settings.put('dailyGoal', goal);

  // Theme
  static bool isDarkMode() => _settings.get('isDarkMode', defaultValue: false);
  static void setDarkMode(bool isDark) => _settings.put('isDarkMode', isDark);

  // Font Size (for Arabic text)
  static double getArabicFontSize() =>
      _settings.get('arabicFontSize', defaultValue: 32.0);
  static void setArabicFontSize(double size) =>
      _settings.put('arabicFontSize', size);

  // Progress tracking (completed day)
  static bool isCompleted(String dateKey) =>
      _progress.get(dateKey, defaultValue: false);
  static void markCompleted(String dateKey) => _progress.put(dateKey, true);
  static void resetToday(String dateKey) => _progress.delete(dateKey);

  static Map<String, bool> getAllProgress() {
    final Map<String, bool> progress = {};
    for (var key in _progress.keys) {
      progress[key.toString()] = _progress.get(key);
    }
    return progress;
  }

  static int getTotalDaysRead() => _progress.keys.length;

  // Last read position
  static void saveLastRead(int surahNumber, int ayahNumber) {
    _settings.put('lastSurah', surahNumber);
    _settings.put('lastAyah', ayahNumber);
  }

  static Map<String, int> getLastRead() {
    return {
      'surah': _settings.get('lastSurah', defaultValue: 1),
      'ayah': _settings.get('lastAyah', defaultValue: 1),
    };
  }

  // Bookmarks
  static String _getBookmarkKey(int surahNumber, int ayahNumber) {
    return '$surahNumber:$ayahNumber';
  }

  static void addBookmark({
    required int surahNumber,
    required int ayahNumber,
    required String surahName,
    String? note,
  }) {
    final key = _getBookmarkKey(surahNumber, ayahNumber);
    _bookmarks.put(key, {
      'surahNumber': surahNumber,
      'ayahNumber': ayahNumber,
      'surahName': surahName,
      'note': note ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void removeBookmark(int surahNumber, int ayahNumber) {
    final key = _getBookmarkKey(surahNumber, ayahNumber);
    _bookmarks.delete(key);
  }

  static bool isBookmarked(int surahNumber, int ayahNumber) {
    final key = _getBookmarkKey(surahNumber, ayahNumber);
    return _bookmarks.containsKey(key);
  }

  static List<Map<String, dynamic>> getAllBookmarks() {
    final List<Map<String, dynamic>> bookmarks = [];
    for (var key in _bookmarks.keys) {
      final bookmark = _bookmarks.get(key);
      if (bookmark != null) {
        bookmarks.add(Map<String, dynamic>.from(bookmark));
      }
    }
    bookmarks.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    return bookmarks;
  }

  static int getBookmarksCount() => _bookmarks.length;

  // ----------------------------
  // Date helpers
  // ----------------------------

  static String dateKey([DateTime? at]) =>
      (at ?? DateTime.now()).toIso8601String().substring(0, 10);

  static DateTime _parseDateKey(String k) {
    final parts = k.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  // ----------------------------
  // Ayah-read tracking (unique per day)
  // ----------------------------

  static String _readAyahsKey(String dateKey) => 'readAyahs:$dateKey';
  static String _dailyHasanatKey(String dateKey) => 'hasanat:$dateKey';
  static String _dailySecondsKey(String dateKey) => 'seconds:$dateKey';

  static List<int> _getReadAyahsList(String dateKey) {
    final v = _settings.get(_readAyahsKey(dateKey), defaultValue: <int>[]);
    return List<int>.from(v as List);
  }

  static int getDailyAyahsRead(String dateKey) =>
      _getReadAyahsList(dateKey).length;

  static int getDailyHasanat(String dateKey) =>
      _settings.get(_dailyHasanatKey(dateKey), defaultValue: 0) as int;

  static int getDailySeconds(String dateKey) =>
      _settings.get(_dailySecondsKey(dateKey), defaultValue: 0) as int;

  static int getAllTimeHasanat() =>
      _settings.get('allTimeHasanat', defaultValue: 0) as int;

  static int getAllTimeAyahsRead() =>
      _settings.get('allTimeAyahsRead', defaultValue: 0) as int;

  static int getAllTimeSeconds() =>
      _settings.get('allTimeSeconds', defaultValue: 0) as int;

  static void addReadingSeconds(int seconds, {DateTime? at}) {
    if (seconds <= 0) return;
    final dk = dateKey(at);
    _settings.put(_dailySecondsKey(dk), getDailySeconds(dk) + seconds);
    _settings.put('allTimeSeconds', getAllTimeSeconds() + seconds);
  }

  static bool recordAyahRead({
    required int globalAyahNumber,
    required int hasanatEarned,
    DateTime? at,
  }) {
    final dk = dateKey(at);
    final list = _getReadAyahsList(dk);

    if (list.contains(globalAyahNumber)) return false;

    list.add(globalAyahNumber);
    _settings.put(_readAyahsKey(dk), list);

    _settings.put(_dailyHasanatKey(dk), getDailyHasanat(dk) + hasanatEarned);

    _settings.put('allTimeHasanat', getAllTimeHasanat() + hasanatEarned);
    _settings.put('allTimeAyahsRead', getAllTimeAyahsRead() + 1);

    final goal = getDailyGoal();
    if (list.length >= goal && !isCompleted(dk)) {
      markCompleted(dk);
      _updateStreakOnCompletion(dk);
    }

    return true;
  }

  static void resetTodayStats(String dateKey) {
    resetToday(dateKey);
    _settings.delete(_readAyahsKey(dateKey));
    _settings.delete(_dailyHasanatKey(dateKey));
    _settings.delete(_dailySecondsKey(dateKey));
  }

  // ----------------------------
  // NEW: Reset ALL reading stats (daily + derived weekly + all-time)
  // ----------------------------

  static void resetAllReadingStats() {
    // 1) Clear completed days (streak/progress base)
    for (final k in _progress.keys.toList()) {
      _progress.delete(k);
    }

    // 2) Clear daily keys in settings
    for (final k in _settings.keys.toList()) {
      if (k is String) {
        if (k.startsWith('readAyahs:') ||
            k.startsWith('hasanat:') ||
            k.startsWith('seconds:')) {
          _settings.delete(k);
        }
      }
    }

    // 3) Clear all-time + streak
    _settings.delete('allTimeHasanat');
    _settings.delete('allTimeAyahsRead');
    _settings.delete('allTimeSeconds');
    _settings.delete('streakCount');
    _settings.delete('streakLastCompleted');
  }

  // ----------------------------
  // Streak
  // ----------------------------

  static int getCurrentStreak() =>
      _settings.get('streakCount', defaultValue: 0) as int;

  static String? getLastStreakCompletedDateKey() =>
      _settings.get('streakLastCompleted', defaultValue: null) as String?;

  static void _updateStreakOnCompletion(String todayKey) {
    final lastKey = getLastStreakCompletedDateKey();
    final current = getCurrentStreak();

    if (lastKey == null) {
      _settings.put('streakCount', 1);
      _settings.put('streakLastCompleted', todayKey);
      return;
    }

    final lastDate = _parseDateKey(lastKey);
    final today = _parseDateKey(todayKey);
    final yesterday = today.subtract(const Duration(days: 1));

    if (lastDate.year == yesterday.year &&
        lastDate.month == yesterday.month &&
        lastDate.day == yesterday.day) {
      _settings.put('streakCount', current + 1);
    } else if (lastKey == todayKey) {
      _settings.put('streakCount', current == 0 ? 1 : current);
    } else {
      _settings.put('streakCount', 1);
    }

    _settings.put('streakLastCompleted', todayKey);
  }

  // ----------------------------
  // Range helpers (Today / Week / All)
  // ----------------------------

  static int getWeeklyHasanat({DateTime? now}) {
    final anchor = _parseDateKey(dateKey(now));
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      sum += getDailyHasanat(dateKey(anchor.subtract(Duration(days: i))));
    }
    return sum;
  }

  static int getWeeklyAyahsRead({DateTime? now}) {
    final anchor = _parseDateKey(dateKey(now));
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      sum += getDailyAyahsRead(dateKey(anchor.subtract(Duration(days: i))));
    }
    return sum;
  }

  static int getWeeklySeconds({DateTime? now}) {
    final anchor = _parseDateKey(dateKey(now));
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      sum += getDailySeconds(dateKey(anchor.subtract(Duration(days: i))));
    }
    return sum;
  }

  // ----------------------------
  // In-app review
  // ----------------------------

  static int getAppOpenCount() =>
      _settings.get('appOpenCount', defaultValue: 0) as int;
  static void incrementAppOpenCount() =>
      _settings.put('appOpenCount', getAppOpenCount() + 1);
  static String? getLastReviewRequestDate() =>
      _settings.get('lastReviewRequestDate', defaultValue: null) as String?;
  static void setLastReviewRequestDate(String isoDate) =>
      _settings.put('lastReviewRequestDate', isoDate);

  // ----------------------------
  // Update prompt (dismissed version)
  // ----------------------------

  static String? getLastDismissedUpdateVersion() =>
      _settings.get('lastDismissedUpdateVersion', defaultValue: null) as String?;
  static void setLastDismissedUpdateVersion(String version) =>
      _settings.put('lastDismissedUpdateVersion', version);
}
