import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class QuranAPI {
  static const String baseUrl = 'https://api.alquran.cloud/v1';

  static Map<String, dynamic>? _cachedArabicData;
  static Map<String, dynamic>? _cachedEnglishData;

  static Future<void> _loadLocalData() async {
    if (_cachedArabicData == null) {
      final arabicString = await rootBundle.loadString(
        'assets/data/quran/quran_arabic.json',
      );
      _cachedArabicData = json.decode(arabicString);
    }
    if (_cachedEnglishData == null) {
      final englishString = await rootBundle.loadString(
        'assets/data/quran/quran_english.json',
      );
      _cachedEnglishData = json.decode(englishString);
    }
  }

  /// Fetches transliteration for a surah from API. Returns null on failure.
  static Future<List<String>?> _fetchTransliterationForSurah(int number) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/surah/$number/en.transliteration'),
      );
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>?;
      final dataData = data?['data'];
      if (dataData == null) return null;
      List<dynamic>? ayahList;
      if (dataData['ayahs'] is List) {
        ayahList = dataData['ayahs'] as List<dynamic>;
      } else if (dataData['surahs'] is List) {
        final surahs = dataData['surahs'] as List<dynamic>;
        if (surahs.isNotEmpty) {
          ayahList = (surahs.first as Map<String, dynamic>)['ayahs'] as List<dynamic>?;
        }
      }
      if (ayahList == null || ayahList.isEmpty) return null;
      return ayahList
          .map<String>((a) => (a as Map<String, dynamic>)['text'] as String? ?? '')
          .toList();
    } catch (_) {
      return null;
    }
  }

  static bool _looksLikeBismillah(String s) {
    final t = s.replaceAll('\uFEFF', '').trim(); // remove BOM if present
    // Works for both "simple" and "uthmani" text
    return t.contains('بسم') &&
        t.contains('الله') &&
        t.contains('الرحمن') &&
        t.contains('الرحيم');
  }

  static List<Ayah> _stripBismillahIfNeeded(int surahNumber, List<Ayah> ayahs) {
    // Keep Surah 1 as-is (Bismillah is commonly treated as ayah 1 there)
    // Surah 9 has no Bismillah
    if (surahNumber == 1 || surahNumber == 9) return ayahs;
    if (ayahs.isEmpty) return ayahs;

    // If dataset prepends Bismillah, remove it
    if (_looksLikeBismillah(ayahs.first.text)) {
      final trimmed = ayahs.sublist(1);

      // IMPORTANT: renumber display ayah numbers (keep GLOBAL number for audio)
      return List<Ayah>.generate(trimmed.length, (i) {
        final a = trimmed[i];
        return Ayah(
          number: a.number, // keep global ayah number for audio
          text: a.text,
          numberInSurah: i + 1, // renumber so Alif Lam Meem becomes Ayah 1
          translation: a.translation,
          transliteration: a.transliteration,
        );
      });
    }

    return ayahs;
  }

  static Future<List<Surah>> getAllSurahs() async {
    try {
      await _loadLocalData();
      final surahs = (_cachedArabicData?['data']?['surahs'] as List? ?? [])
          .map((s) => Surah.fromJson(s as Map<String, dynamic>))
          .toList();
      if (surahs.isNotEmpty) return surahs;
    } catch (_) {}

    try {
      final response = await http.get(Uri.parse('$baseUrl/surah'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data'] as List).map((s) => Surah.fromJson(s)).toList();
      }
    } catch (_) {}

    return [];
  }

  static Future<SurahDetail?> getSurahWithTranslation(int number) async {
    // 1) Offline-first
    try {
      await _loadLocalData();

      final arabicSurahs = _cachedArabicData?['data']?['surahs'] as List?;
      final englishSurahs = _cachedEnglishData?['data']?['surahs'] as List?;

      if (arabicSurahs != null &&
          englishSurahs != null &&
          number > 0 &&
          number <= arabicSurahs.length &&
          number <= englishSurahs.length) {
        final arabicSurah = arabicSurahs[number - 1] as Map<String, dynamic>;
        final englishSurah = englishSurahs[number - 1] as Map<String, dynamic>;

        final arabicAyahs = (arabicSurah['ayahs'] as List? ?? []);
        final englishAyahs = (englishSurah['ayahs'] as List? ?? []);

        final built = <Ayah>[];
        for (int i = 0; i < arabicAyahs.length; i++) {
          final a = arabicAyahs[i] as Map<String, dynamic>;
          final tr = (i < englishAyahs.length)
              ? (englishAyahs[i] as Map<String, dynamic>)
              : null;

          built.add(
            Ayah(
              number: a['number'] ?? 0, // GLOBAL ayah number (needed for audio)
              text: a['text'] ?? '',
              numberInSurah: a['numberInSurah'] ?? (i + 1),
              translation: tr?['text'] as String?,
              transliteration: null, // filled below if API provides it
            ),
          );
        }

        var ayahs = _stripBismillahIfNeeded(number, built);
        final transliterations = await _fetchTransliterationForSurah(number);
        if (transliterations != null && transliterations.isNotEmpty) {
          List<String> toUse = transliterations;
          if (transliterations.length == ayahs.length + 1) {
            toUse = transliterations.sublist(1);
          } else if (transliterations.length != ayahs.length) {
            toUse = transliterations.length >= ayahs.length
                ? transliterations.sublist(0, ayahs.length)
                : [...transliterations, ...List.filled(ayahs.length - transliterations.length, '')];
          }
          if (toUse.length == ayahs.length) {
            ayahs = List.generate(ayahs.length, (i) {
              final a = ayahs[i];
              final tr = toUse[i];
              return Ayah(
                number: a.number,
                text: a.text,
                numberInSurah: a.numberInSurah,
                translation: a.translation,
                transliteration: tr.isEmpty ? null : tr,
              );
            });
          }
        }

        return SurahDetail(
          number: arabicSurah['number'] ?? number,
          name: arabicSurah['name'] ?? '',
          englishName: arabicSurah['englishName'] ?? '',
          englishNameTranslation: arabicSurah['englishNameTranslation'] ?? '',
          numberOfAyahs: ayahs.length, // after stripping
          ayahs: ayahs,
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading local surah: $e');
    }

    // 2) Online fallback (Uthmani)
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/surah/$number/editions/quran-uthmani,en.asad'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final detail = SurahDetail.fromJsonWithTranslation(data['data']);
        final ayahs = _stripBismillahIfNeeded(number, detail.ayahs);
        return SurahDetail(
          number: detail.number,
          name: detail.name,
          englishName: detail.englishName,
          englishNameTranslation: detail.englishNameTranslation,
          numberOfAyahs: ayahs.length,
          ayahs: ayahs,
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching online surah: $e');
    }

    return null;
  }

  /// Fetches transliteration for a surah from API (Latin script).
  /// Returns list of transliteration strings in ayah order, or empty list on failure.
  static Future<List<String>> getTransliterationForSurah(int number) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/surah/$number/en.transliteration'),
      );
      if (response.statusCode != 200) return [];
      final data = json.decode(response.body);
      final ayahs = data['data']?['ayahs'] as List?;
      if (ayahs == null) return [];
      return ayahs
          .map<String>((a) => (a as Map<String, dynamic>)['text'] as String? ?? '')
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<JuzStart>> getAllJuzStarts() async {
    try {
      await _loadLocalData();
      final surahs = (_cachedArabicData?['data']?['surahs'] as List? ?? []);
      final Map<int, JuzStart> starts = {};

      for (final rawSurah in surahs) {
        final surah = rawSurah as Map<String, dynamic>;
        final int surahNumber = (surah['number'] ?? 0) as int;
        final String englishName = (surah['englishName'] ?? '') as String;
        final ayahs = (surah['ayahs'] as List? ?? []);

        for (final rawAyah in ayahs) {
          final ayah = rawAyah as Map<String, dynamic>;
          final int juz = (ayah['juz'] ?? 0) as int;
          if (juz <= 0 || starts.containsKey(juz)) continue;

          starts[juz] = JuzStart(
            juzNumber: juz,
            surahNumber: surahNumber,
            surahEnglishName: englishName,
            ayahNumberInSurah: (ayah['numberInSurah'] ?? 1) as int,
          );
        }
      }

      return List<JuzStart>.generate(30, (i) {
        final juz = i + 1;
        return starts[juz] ??
            JuzStart(
              juzNumber: juz,
              surahNumber: 1,
              surahEnglishName: 'Al-Faatiha',
              ayahNumberInSurah: 1,
            );
      });
    } catch (_) {
      return [];
    }
  }

  /// Indo-Pak Juz boundaries (start surah+ayah for each of the 30 Juz).
  static const List<({int surah, int ayah})> juzStarts = [
    (surah: 1,  ayah: 1),   (surah: 2,  ayah: 142), (surah: 2,  ayah: 253),
    (surah: 3,  ayah: 92),  (surah: 4,  ayah: 24),  (surah: 4,  ayah: 148),
    (surah: 5,  ayah: 83),  (surah: 6,  ayah: 111), (surah: 7,  ayah: 88),
    (surah: 8,  ayah: 41),  (surah: 9,  ayah: 94),  (surah: 11, ayah: 6),
    (surah: 12, ayah: 53),  (surah: 15, ayah: 2),   (surah: 17, ayah: 1),
    (surah: 18, ayah: 75),  (surah: 21, ayah: 1),   (surah: 23, ayah: 1),
    (surah: 25, ayah: 21),  (surah: 27, ayah: 60),  (surah: 29, ayah: 45),
    (surah: 33, ayah: 31),  (surah: 36, ayah: 22),  (surah: 39, ayah: 32),
    (surah: 41, ayah: 47),  (surah: 46, ayah: 1),   (surah: 51, ayah: 31),
    (surah: 58, ayah: 1),   (surah: 67, ayah: 1),   (surah: 78, ayah: 1),
  ];

  /// End (surah, ayah) for each of the 30 Juz.
  static const List<({int surah, int ayah})> _juzEnds = [
    (surah: 2,  ayah: 141), (surah: 2,  ayah: 252), (surah: 3,  ayah: 91),
    (surah: 4,  ayah: 23),  (surah: 4,  ayah: 147), (surah: 5,  ayah: 82),
    (surah: 6,  ayah: 110), (surah: 7,  ayah: 87),  (surah: 8,  ayah: 40),
    (surah: 9,  ayah: 93),  (surah: 11, ayah: 5),   (surah: 12, ayah: 52),
    (surah: 15, ayah: 1),   (surah: 16, ayah: 128), (surah: 18, ayah: 74),
    (surah: 20, ayah: 135), (surah: 22, ayah: 78),  (surah: 25, ayah: 20),
    (surah: 27, ayah: 59),  (surah: 29, ayah: 44),  (surah: 33, ayah: 30),
    (surah: 36, ayah: 21),  (surah: 39, ayah: 31),  (surah: 41, ayah: 46),
    (surah: 45, ayah: 37),  (surah: 51, ayah: 30),  (surah: 57, ayah: 29),
    (surah: 66, ayah: 12),  (surah: 77, ayah: 50),  (surah: 114, ayah: 6),
  ];

  static const List<String> _surahEnglishNames = [
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

  /// Returns a flat list of [JuzItem]s (surah dividers + ayahs) for the given
  /// Juz number (1–30). Returns null on load failure.
  static Future<List<JuzItem>?> getJuzAyahs(int juzNumber) async {
    if (juzNumber < 1 || juzNumber > 30) return null;
    final idx = juzNumber - 1;
    final start = juzStarts[idx];
    final end = _juzEnds[idx];

    // Collect which surahs are needed
    final surahsNeeded = <int>[];
    for (int s = start.surah; s <= end.surah; s++) {
      surahsNeeded.add(s);
    }

    // Fetch all needed surahs concurrently
    final futures = surahsNeeded.map((s) => getSurahWithTranslation(s));
    final results = await Future.wait(futures);

    final items = <JuzItem>[];
    for (int i = 0; i < surahsNeeded.length; i++) {
      final surahNum = surahsNeeded[i];
      final detail = results[i];
      if (detail == null) continue;

      final surahName = surahNum <= _surahEnglishNames.length
          ? _surahEnglishNames[surahNum - 1]
          : detail.englishName;

      final startAyah = (surahNum == start.surah) ? start.ayah : 1;
      final endAyah = (surahNum == end.surah) ? end.ayah : detail.ayahs.length;

      // Surah divider banner
      items.add(JuzSurahDivider(surahNumber: surahNum, surahName: surahName));

      for (final ayah in detail.ayahs) {
        if (ayah.numberInSurah >= startAyah && ayah.numberInSurah <= endAyah) {
          items.add(JuzAyahItem(ayah: ayah, surahNumber: surahNum, surahName: surahName));
        }
      }
    }
    return items.isEmpty ? null : items;
  }
}

// Models
class Surah {
  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final int numberOfAyahs;
  final String revelationType;

  Surah({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.numberOfAyahs,
    required this.revelationType,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    final ayahs = (json['ayahs'] as List?) ?? const [];
    return Surah(
      number: json['number'] ?? 0,
      name: json['name'] ?? '',
      englishName: json['englishName'] ?? '',
      englishNameTranslation: json['englishNameTranslation'] ?? '',
      numberOfAyahs: (json['numberOfAyahs'] as int?) ?? ayahs.length,
      revelationType: json['revelationType'] ?? 'Meccan',
    );
  }
}

class JuzStart {
  final int juzNumber;
  final int surahNumber;
  final String surahEnglishName;
  final int ayahNumberInSurah;

  JuzStart({
    required this.juzNumber,
    required this.surahNumber,
    required this.surahEnglishName,
    required this.ayahNumberInSurah,
  });
}

class SurahDetail {
  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final int numberOfAyahs;
  final List<Ayah> ayahs;

  SurahDetail({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.numberOfAyahs,
    required this.ayahs,
  });

  factory SurahDetail.fromJsonWithTranslation(List<dynamic> data) {
    final arabic = data[0];
    final translation = data[1];

    final built = <Ayah>[];
    for (int i = 0; i < (arabic['ayahs'] as List).length; i++) {
      built.add(
        Ayah(
          number: arabic['ayahs'][i]['number'] ?? 0,
          text: arabic['ayahs'][i]['text'] ?? '',
          numberInSurah: arabic['ayahs'][i]['numberInSurah'] ?? (i + 1),
          translation: translation['ayahs'][i]['text'],
          transliteration: null,
        ),
      );
    }

    return SurahDetail(
      number: arabic['number'] ?? 0,
      name: arabic['name'] ?? '',
      englishName: arabic['englishName'] ?? '',
      englishNameTranslation: arabic['englishNameTranslation'] ?? '',
      numberOfAyahs: arabic['numberOfAyahs'] ?? built.length,
      ayahs: built,
    );
  }
}

class Ayah {
  final int number; // GLOBAL ayah number (audio uses this)
  final String text;
  final int numberInSurah;
  final String? translation;
  final String? transliteration;

  Ayah({
    required this.number,
    required this.text,
    required this.numberInSurah,
    this.translation,
    this.transliteration,
  });
}

// ─── Juz flat-list model ─────────────────────────────────────────────────────

/// An item in the flat Juz ayah list — either a surah divider or an ayah.
sealed class JuzItem {}

class JuzSurahDivider extends JuzItem {
  final int surahNumber;
  final String surahName;
  JuzSurahDivider({required this.surahNumber, required this.surahName});
}

class JuzAyahItem extends JuzItem {
  final Ayah ayah;
  final int surahNumber;
  final String surahName;
  JuzAyahItem({required this.ayah, required this.surahNumber, required this.surahName});
}
