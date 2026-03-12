import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/services/audio_service.dart';
import '../../core/services/quran_api.dart';
import '../../core/storage/local_storage.dart';

import 'widgets/ayah_navigation_bar.dart';
import 'widgets/ayah_text_widget.dart';
import 'widgets/surah_completion_dialog.dart';
import 'widgets/translation_widget.dart';
import 'widgets/transliteration_widget.dart';

class AyahScreen extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final int initialAyahIndex;

  const AyahScreen({
    super.key,
    required this.surahNumber,
    required this.surahName,
    this.initialAyahIndex = 0,
  });

  @override
  State<AyahScreen> createState() => _AyahScreenState();
}

class _AyahScreenState extends State<AyahScreen> {
  SurahDetail? surahDetail;
  bool isLoading = true;
  int currentAyahIndex = 0;
  double arabicFontSize = 32.0;
  bool isPlaying = false;
  bool showTranslation = true;

  final DateTime _sessionStart = DateTime.now();
  final Set<int> _sessionGlobalAyahs = {};
  int _sessionHasanat = 0;

  StreamSubscription<PlayerState>? _playerSub;

  @override
  void initState() {
    super.initState();
    arabicFontSize = LocalStorage.getArabicFontSize();
    currentAyahIndex = widget.initialAyahIndex;

    _playerSub = AudioService.playerStateStream.listen((state) {
        if (!mounted) return;

        if (state.processingState == ProcessingState.completed) {
            setState(() => isPlaying = false);
            return;
        }

        setState(() => isPlaying = state.playing);
        });

    loadSurah();
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    AudioService.stop();
    super.dispose();
  }

  void _toggleTranslation() {
    setState(() => showTranslation = !showTranslation);
  }

  String _normalizeArabic(String text) {
    final withoutBom = text.replaceFirst('\uFEFF', '');
    final removedDiacritics = withoutBom.replaceAll(
      RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670]'),
      '',
    );
    return removedDiacritics
        .replaceAll('\u0640', '') // tatweel
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trimLeft();
  }

  String _stripLeadingBismillah(String text) {
    final normalized = _normalizeArabic(text);
    const normalizedBismillah = 'بسم الله الرحمن الرحيم';
    if (!normalized.startsWith(normalizedBismillah)) {
      return text;
    }
    final withNoBom = text.replaceFirst('\uFEFF', '').trimLeft();
    final parts = withNoBom.split(RegExp(r'\s+'));
    if (parts.length >= 4) {
      return parts.sublist(4).join(' ').trimLeft();
    }
    return withNoBom;
  }


  void _copyCurrentAyah() {
    if (surahDetail == null) return;
    final ayah = surahDetail!.ayahs[currentAyahIndex];

    final buffer = StringBuffer()
      ..write('${widget.surahName} ${widget.surahNumber}:${ayah.numberInSurah}\n')
      ..write(ayah.text);

    if ((ayah.transliteration ?? '').trim().isNotEmpty) {
      buffer.write('\n\n${ayah.transliteration}');
    }
    if ((ayah.translation ?? '').isNotEmpty) {
      buffer.write('\n\n${ayah.translation}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ayah copied')),
    );
  }

  Future<void> _handleSwipe(DragEndDetails details) async {
    final v = details.primaryVelocity ?? 0;
    if (v < -300) {
      HapticFeedback.selectionClick();
      nextAyah();
    } else if (v > 300) {
      HapticFeedback.selectionClick();
      previousAyah();
    }
  }

  Future<void> loadSurah() async {
    setState(() => isLoading = true);
    final data = await QuranAPI.getSurahWithTranslation(widget.surahNumber);
    setState(() {
      surahDetail = data;
      isLoading = false;
    });
    if (data != null) {
      LocalStorage.saveLastRead(widget.surahNumber, currentAyahIndex + 1);
      _markCurrentAyahAsRead();
    }
  }

 Future<void> _toggleAudio() async {
  if (surahDetail == null) return;
  final globalAyah = surahDetail!.ayahs[currentAyahIndex].number;

  try {
    if (AudioService.isPlaying) {
      await AudioService.pause();
    } else {
      await AudioService.playAyah(globalAyah);
    }
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audio failed to load. Check internet and try again.'),
      ),
    );
  }
}

  void _toggleBookmark() {
    if (surahDetail == null) return;

    final ayahInSurah = surahDetail!.ayahs[currentAyahIndex].numberInSurah;
    final bookmarked =
        LocalStorage.isBookmarked(widget.surahNumber, ayahInSurah);

    setState(() {
      if (bookmarked) {
        LocalStorage.removeBookmark(widget.surahNumber, ayahInSurah);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bookmark removed')),
        );
      } else {
        LocalStorage.addBookmark(
          surahNumber: widget.surahNumber,
          ayahNumber: ayahInSurah,
          surahName: widget.surahName,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bookmarked')),
        );
      }
    });
  }

  // Hasanah estimate (minimum): 10 per Arabic letter
  int _estimateHasanatFromArabic(String text) {
    // Count Arabic letters (includes ٱ too)
    final letters = RegExp(r'[ء-يٱ]').allMatches(text).length;
    return letters * 10;
  }

  void _markCurrentAyahAsRead() {
    if (surahDetail == null) return;

    final ayah = surahDetail!.ayahs[currentAyahIndex];
    final globalAyah = ayah.number;
    final hasanat = _estimateHasanatFromArabic(ayah.text);

    // Daily/all-time (unique per day)
    LocalStorage.recordAyahRead(
      globalAyahNumber: globalAyah,
      hasanatEarned: hasanat,
    );

    // Session total (unique per session)
    if (_sessionGlobalAyahs.add(globalAyah)) {
      _sessionHasanat += hasanat;
    }
  }

  Future<void> _playCompletionCelebration() async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'celebration',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
     pageBuilder: (context, _, __) => const _FireworkOverlay(),
    );
  }

  Future<void> nextAyah() async {
    await AudioService.stop();
    setState(() => isPlaying = false);

    if (surahDetail == null) return;

    if (currentAyahIndex < surahDetail!.ayahs.length - 1) {
      setState(() => currentAyahIndex++);
      LocalStorage.saveLastRead(widget.surahNumber, currentAyahIndex + 1);
      _markCurrentAyahAsRead();
      return;
    }

    await _playCompletionCelebration();

    final shouldContinue = await SurahCompletionDialog.show(
      context: context,
      surahName: widget.surahName,
      nextSurahNumber: widget.surahNumber + 1,
      hasNextSurah: widget.surahNumber < 114,
    );

    if (shouldContinue) {
      await goToNextSurah();
    }
  }

  Future<void> previousAyah() async {
    await AudioService.stop();
    setState(() => isPlaying = false);

    if (currentAyahIndex <= 0) return;
    setState(() => currentAyahIndex--);
    LocalStorage.saveLastRead(widget.surahNumber, currentAyahIndex + 1);
    _markCurrentAyahAsRead();
  }

  Future<void> goToNextSurah() async {
    if (widget.surahNumber >= 114) return;
    final next = await QuranAPI.getSurahWithTranslation(widget.surahNumber + 1);
    if (!mounted || next == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AyahScreen(
          surahNumber: widget.surahNumber + 1,
          surahName: next.englishName,
          initialAyahIndex: 0,
        ),
      ),
    );
  }

  Future<void> _onDone() async {
    if (surahDetail == null) return;

    HapticFeedback.mediumImpact();

    // Ensure current ayah counted
    _markCurrentAyahAsRead();

    final ayahInSurah = surahDetail!.ayahs[currentAyahIndex].numberInSurah;

    // Save bookmark (idempotent)
    if (!LocalStorage.isBookmarked(widget.surahNumber, ayahInSurah)) {
      LocalStorage.addBookmark(
        surahNumber: widget.surahNumber,
        ayahNumber: ayahInSurah,
        surahName: widget.surahName,
      );
    }

    // Save reading time
    final seconds = DateTime.now().difference(_sessionStart).inSeconds;
    LocalStorage.addReadingSeconds(seconds);

    if (!mounted) return;

    const accent = Color(0xFF2563EB); // blue
    const accent2 = Color(0xFF7C3AED); // violet

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF0B0F1A), Color(0xFF141B33)]
                      : const [Colors.white, Color(0xFFF3F6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white24 : Colors.black12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: 62,
                      height: 62,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [accent, accent2]),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Session completed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Estimated minimum hasanah earned',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: isDark ? Colors.white10 : Colors.white,
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$_sessionHasanat',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bookmarked: ${widget.surahNumber}:$ayahInSurah',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, 'keep'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark ? Colors.white24 : Colors.black12,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Keep reading',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, 'finish'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Finish',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (action == 'finish') {
      Navigator.pop(context); // back to previous screen
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2563EB);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ayahInSurah = (surahDetail == null)
        ? 1
        : surahDetail!.ayahs[currentAyahIndex].numberInSurah;
    final totalAyahs = surahDetail?.ayahs.length ?? 0;

    final bookmarked =
        LocalStorage.isBookmarked(widget.surahNumber, ayahInSurah);

    const bismillahText = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
    final originalAyahText = surahDetail?.ayahs[currentAyahIndex].text ?? '';
    final showInlineBismillah = widget.surahNumber != 1 &&
        widget.surahNumber != 9 &&
        currentAyahIndex == 0;
    final cleanedAyahText = showInlineBismillah
        ? _stripLeadingBismillah(originalAyahText)
        : originalAyahText;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF05070F) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF05070F) : Colors.white,
        elevation: 0,
        title: Column(
          children: [
            Text(
              '${widget.surahNumber}. ${widget.surahName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (surahDetail != null)
              Text(
                surahDetail!.englishNameTranslation,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
          ],
        ),
        centerTitle: true,
        leading: BackButton(color: isDark ? Colors.white : Colors.black),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
             colors: isDark
                ? const [Color(0xFF438FD2), Color(0xFF1C1B24)]
                : const [Color(0xFF4A2D6F), Color(0xFF1C1B24)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : surahDetail == null
                ? const Center(child: Text('Failed to load Surah'))
                : Column(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onHorizontalDragEnd: _handleSwipe,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(18),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF10131C)
                                    : const Color(0xFFF7F6FB),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 18, 18, 8),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white10
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.white12
                                                  : Colors.black12,
                                            ),
                                          ),
                                          child: Text(
                                            totalAyahs > 0
                                                ? '$ayahInSurah/$totalAyahs'
                                                : '$ayahInSurah',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: Icon(
                                            isPlaying
                                                ? Icons.pause_circle_filled
                                                : Icons.play_circle_fill,
                                            size: 30,
                                          ),
                                          color: accent,
                                          onPressed: _toggleAudio,
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            bookmarked
                                                ? Icons.bookmark_rounded
                                                : Icons.bookmark_outline_rounded,
                                            size: 28,
                                          ),
                                          color: bookmarked
                                              ? const Color(0xFF7C3AED)
                                              : (isDark
                                                  ? Colors.white70
                                                  : Colors.black54),
                                          onPressed: _toggleBookmark,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onTap: _toggleTranslation,
                                      onDoubleTap: _toggleBookmark,
                                      onLongPress: _copyCurrentAyah,
                                      child: AyahTextWidget(
                                        text: cleanedAyahText,
                                        ayahNumber: ayahInSurah,
                                        fontSize: arabicFontSize,
                                        isDark: isDark,
                                        surahNumber: widget.surahNumber,
                                        ayahIndex: currentAyahIndex,
                                        showContainer: false,
                                        bismillahText:
                                            showInlineBismillah ? bismillahText : null,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (showTranslation &&
                                        (surahDetail!.ayahs[currentAyahIndex].transliteration !=
                                                null ||
                                            surahDetail!
                                                    .ayahs[currentAyahIndex]
                                                    .translation !=
                                                null)) ...[
                                      if (surahDetail!
                                              .ayahs[currentAyahIndex]
                                              .transliteration !=
                                          null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: TransliterationWidget(
                                            transliteration: surahDetail!
                                                .ayahs[currentAyahIndex]
                                                .transliteration!,
                                            isDark: isDark,
                                          ),
                                        ),
                                      if (surahDetail!
                                              .ayahs[currentAyahIndex]
                                              .translation !=
                                          null)
                                        TranslationWidget(
                                          translation: surahDetail!
                                              .ayahs[currentAyahIndex]
                                              .translation!,
                                          isDark: isDark,
                                        ),
                                    ],
                                    const SizedBox(height: 14),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      AyahNavigationBar(
                        currentIndex: currentAyahIndex,
                        totalAyahs: surahDetail!.ayahs.length,
                        canGoPrevious: currentAyahIndex > 0,
                        canGoNext: true,
                        onPrevious: previousAyah,
                        onNext: nextAyah,
                        onDone: _onDone,
                        isDark: isDark,
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _FireworkOverlay extends StatefulWidget {
  const _FireworkOverlay();

  @override
  State<_FireworkOverlay> createState() => _FireworkOverlayState();
}

class _FireworkOverlayState extends State<_FireworkOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _burst(Color color, double maxSize, double t) {
    final size = maxSize * t;
    final opacity = (1 - t).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(opacity), width: 2),
        ),
      ),
    );
  }

  Widget _sparkle(Offset base, double size, Color color, double t) {
    final offset = Offset(base.dx * (0.3 + t), base.dy * (0.3 + t));
    final opacity = (1 - t).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: offset,
        child: Icon(Icons.auto_awesome, size: size, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t1 = Curves.easeOut.transform(_controller.value.clamp(0, 1));
            final t2 = Curves.easeOut.transform(
                (_controller.value - 0.15).clamp(0, 1));
            final t3 = Curves.easeOut.transform(
                (_controller.value - 0.3).clamp(0, 1));

            return Stack(
              alignment: Alignment.center,
              children: [
                _burst(Colors.amber, 160, t1),
                _burst(Colors.pinkAccent, 140, t2),
                _burst(Colors.lightBlueAccent, 130, t3),

                _sparkle(const Offset(-90, -60), 22, Colors.amber, t1),
                _sparkle(const Offset(90, -40), 20, Colors.pinkAccent, t1),
                _sparkle(const Offset(-70, 70), 18, Colors.lightBlueAccent, t2),
                _sparkle(const Offset(70, 80), 20, Colors.tealAccent, t3),
              ],
            );
          },
        ),
      ),
    );
  }
}