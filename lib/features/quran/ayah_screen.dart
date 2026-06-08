import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/services/audio_service.dart';
import '../../core/services/quran_api.dart';
import '../../core/storage/local_storage.dart';

import 'widgets/ayah_navigation_bar.dart';
import 'widgets/ayah_text_widget.dart';
import 'widgets/bismillah_header.dart';
import 'widgets/surah_completion_dialog.dart';
import 'widgets/translation_widget.dart';
import 'widgets/transliteration_widget.dart';

class AyahScreen extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final int initialAyahIndex;
  final bool isFromRecitation;
  final VoidCallback? onSurahCompleted;

  const AyahScreen({
    super.key,
    required this.surahNumber,
    required this.surahName,
    this.initialAyahIndex = 0,
    this.isFromRecitation = false,
    this.onSurahCompleted,
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
  bool _showTranslation = false;
  bool _showTransliteration = false;
  final ScrollController _scrollController = ScrollController();
  final DateTime _sessionStart = DateTime.now();
  final Set<int> _sessionGlobalAyahs = {};
  int _sessionHasanat = 0;
  bool _isHandlingCompletion = false;
  bool _timeSaved = false;

  StreamSubscription<PlayerState>? _playerSub;

  @override
  void initState() {
    super.initState();
    arabicFontSize = LocalStorage.getArabicFontSize();
    currentAyahIndex = widget.initialAyahIndex;

    _playerSub = AudioService.playerStateStream.listen((state) async {
      if (!mounted) return;

      if (state.processingState == ProcessingState.completed) {
        if (_isHandlingCompletion) return;
        _isHandlingCompletion = true;

        try {
          final mode = LocalStorage.getPlayMode();

          if (mode == 'auto') {
            if (surahDetail == null) return;
            final moved = await _advanceToNextAyah(scrollImmediate: true);
            if (!moved) {
              await nextAyah();
              return;
            }
            if (!mounted || LocalStorage.getPlayMode() != 'auto') return;
            await Future.delayed(const Duration(milliseconds: 300));
            if (!mounted || surahDetail == null) return;
            final nextGlobalAyah = surahDetail!.ayahs[currentAyahIndex].number;
            await AudioService.playAyah(nextGlobalAyah);
          } else if (mode == 'repeat') {
            if (surahDetail == null) return;
            final currentGlobalAyah = surahDetail!.ayahs[currentAyahIndex].number;
            await AudioService.playAyah(currentGlobalAyah);
          } else {
            setState(() => isPlaying = false);
          }
        } finally {
          _isHandlingCompletion = false;
        }
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
    _scrollController.dispose();
    if (!_timeSaved) {
      final seconds = DateTime.now().difference(_sessionStart).inSeconds;
      if (seconds > 0) LocalStorage.addReadingSeconds(seconds);
    }
    super.dispose();
  }

  String _normalizeArabic(String text) {
    // Remove BOM, then strip all Arabic diacritical marks broadly
    final withoutBom = text.replaceFirst('﻿', '');
    // Remove every Arabic combining/diacritic character (broad approach for all Quran editions)
    final removedDiacritics = withoutBom.replaceAll(RegExp(
      r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06dc\u06df-\u06e4\u06e7\u06e8\u06ea-\u06ed]'),
      '');
    return removedDiacritics
        .replaceAll('\u0640', '') // tatweel
        .replaceAll('\u0623', '\u0627') // أ → ا
        .replaceAll('\u0625', '\u0627') // إ → ا
        .replaceAll('\u0622', '\u0627') // آ → ا
        .replaceAll('\u0671', '\u0627') // ٱ → ا
        .replaceAll(RegExp(r'\s+'), ' ')
        .trimLeft();
  }

  String _stripLeadingBismillah(String text) {
    final normalized = _normalizeArabic(text);
    const normalizedBismillah = '\u0628\u0633\u0645 \u0627\u0644\u0644\u0647 \u0627\u0644\u0631\u062d\u0645\u0646 \u0627\u0644\u0631\u062d\u064a\u0645';
    if (!normalized.startsWith(normalizedBismillah)) return text;
    final withNoBom = text.replaceFirst('\ufeff', '').trimLeft();
    final parts = withNoBom.split(RegExp(r'\s+'));
    if (parts.length >= 4) return parts.sublist(4).join(' ').trimLeft();
    return withNoBom;
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
        const SnackBar(content: Text('Audio failed to load. Check internet and try again.')),
      );
    }
  }

  void _markDone() {
    if (surahDetail == null) return;
    final ayahInSurah = surahDetail!.ayahs[currentAyahIndex].numberInSurah;
    LocalStorage.saveLastRead(widget.surahNumber, ayahInSurah);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Progress saved — ${widget.surahName} : Ayah $ayahInSurah'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleBookmark() {
    if (surahDetail == null) return;
    final ayahInSurah = surahDetail!.ayahs[currentAyahIndex].numberInSurah;
    final bookmarked = LocalStorage.isBookmarked(widget.surahNumber, ayahInSurah);
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

  void _toggleFavorite() {
    if (surahDetail == null) return;
    final ayahInSurah = surahDetail!.ayahs[currentAyahIndex].numberInSurah;
    setState(() {
      if (LocalStorage.isFavorited(widget.surahNumber, ayahInSurah)) {
        LocalStorage.removeFavorite(widget.surahNumber, ayahInSurah);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favorites')),
        );
      } else {
        LocalStorage.addFavorite(
          surahNumber: widget.surahNumber,
          ayahNumber: ayahInSurah,
          surahName: widget.surahName,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to favorites')),
        );
      }
    });
  }

  int _estimateHasanatFromArabic(String text) {
    final letters = RegExp(r'[ء-يٱ]').allMatches(text).length;
    return letters * 10;
  }

  void _markCurrentAyahAsRead() {
    if (surahDetail == null) return;
    final ayah = surahDetail!.ayahs[currentAyahIndex];
    final globalAyah = ayah.number;
    final hasanat = _estimateHasanatFromArabic(ayah.text);
    LocalStorage.recordAyahRead(
      globalAyahNumber: globalAyah,
      hasanatEarned: hasanat,
    );
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

  Future<void> _scrollToTop({bool immediate = false}) async {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.minScrollExtent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (immediate) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(target,
            duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      }
    });
    if (immediate) {
      await Future.delayed(const Duration(milliseconds: 90));
      if (!mounted || !_scrollController.hasClients) return;
      if ((_scrollController.offset - target).abs() > 1) {
        _scrollController.jumpTo(target);
      }
      return;
    }
    await _scrollController.animateTo(target,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  Future<bool> _advanceToNextAyah({bool scrollImmediate = false}) async {
    if (surahDetail == null) return false;
    if (currentAyahIndex >= surahDetail!.ayahs.length - 1) return false;
    setState(() => currentAyahIndex++);
    LocalStorage.saveLastRead(widget.surahNumber, currentAyahIndex + 1);
    _markCurrentAyahAsRead();
    await _scrollToTop(immediate: scrollImmediate);
    return true;
  }

  Future<void> nextAyah() async {
    if (AudioService.isPlaying) await AudioService.stop();
    setState(() => isPlaying = false);
    final moved = await _advanceToNextAyah();
    if (moved) return;
    await _playCompletionCelebration();
    widget.onSurahCompleted?.call();
    final shouldContinue = await SurahCompletionDialog.show(
      context: context,
      surahName: widget.surahName,
      nextSurahNumber: widget.surahNumber + 1,
      hasNextSurah: widget.isFromRecitation || widget.surahNumber < 114,
      primaryButtonLabel: widget.isFromRecitation ? 'Back to Recitations' : null,
    );
    if (shouldContinue) {
      if (widget.isFromRecitation && mounted) {
        Navigator.pop(context);
      } else {
        await goToNextSurah();
      }
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
    _markCurrentAyahAsRead();

    final ayahInSurah = surahDetail!.ayahs[currentAyahIndex].numberInSurah;
    if (!LocalStorage.isBookmarked(widget.surahNumber, ayahInSurah)) {
      LocalStorage.addBookmark(
        surahNumber: widget.surahNumber,
        ayahNumber: ayahInSurah,
        surahName: widget.surahName,
      );
    }

    _timeSaved = true;
    final seconds = DateTime.now().difference(_sessionStart).inSeconds;
    LocalStorage.addReadingSeconds(seconds);

    if (!mounted) return;

    const accent = Color(0xFF2D7A4F);

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
                      ? const [Color(0xFF0D1B12), Color(0xFF1A2E20)]
                      : const [Colors.white, Color(0xFFF0FAF4)],
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
                      width: 44, height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: 62, height: 62,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            child: const Text('Keep reading',
                                style: TextStyle(fontWeight: FontWeight.w800)),
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
                            child: const Text('Finish',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, color: Colors.white)),
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
    if (action == 'finish') Navigator.pop(context);
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const green = Color(0xFF2D7A4F);

    final ayahInSurah = surahDetail == null
        ? 1
        : surahDetail!.ayahs[currentAyahIndex].numberInSurah;
    final totalAyahs = surahDetail?.ayahs.length ?? 0;
    final bookmarked = LocalStorage.isBookmarked(widget.surahNumber, ayahInSurah);
    final favorited = LocalStorage.isFavorited(widget.surahNumber, ayahInSurah);
    final lastRead = LocalStorage.getLastRead();
    final isDone = lastRead['surah'] == widget.surahNumber &&
        lastRead['ayah'] == ayahInSurah;

    final originalAyahText = surahDetail?.ayahs[currentAyahIndex].text ?? '';
    final showInlineBismillah = widget.surahNumber != 1 &&
        widget.surahNumber != 9 &&
        currentAyahIndex == 0;
    final displayAyahText = showInlineBismillah
        ? _stripLeadingBismillah(originalAyahText)
        : originalAyahText;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1B12) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D1B12) : Colors.white,
        elevation: 0,
        leading: BackButton(color: green),
        title: Column(
          children: [
            Text(
              '${widget.surahName}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              totalAyahs > 0
                  ? 'Ayah $ayahInSurah of $totalAyahs'
                  : widget.surahName,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : surahDetail == null
              ? const Center(child: Text('Failed to load Surah'))
              : Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onHorizontalDragEnd: (details) {
                          final v = details.primaryVelocity ?? 0;
                          if (v < -300) {
                            HapticFeedback.selectionClick();
                            nextAyah();
                          } else if (v > 300) {
                            HapticFeedback.selectionClick();
                            previousAyah();
                          }
                        },
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            children: [
                              // Bismillah card at start of each surah
                              if (showInlineBismillah) ...[
                                BismillahHeader(
                                  isDark: isDark,
                                  fontSize: arabicFontSize,
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Arabic text card
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1A2E20)
                                      : const Color(0xFFF7F6FB),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Top row: counter + bookmark
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? green.withOpacity(0.2)
                                                  : green.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              totalAyahs > 0
                                                  ? '$ayahInSurah / $totalAyahs'
                                                  : '$ayahInSurah',
                                              style: const TextStyle(
                                                color: green,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          // Play/pause button
                                          IconButton(
                                            icon: Icon(
                                              isPlaying
                                                  ? Icons.pause_circle_filled_rounded
                                                  : Icons.play_circle_fill_rounded,
                                              size: 30,
                                              color: green,
                                            ),
                                            onPressed: _toggleAudio,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 8),
                                          // Bookmark button
                                          IconButton(
                                            icon: Icon(
                                              bookmarked
                                                  ? Icons.bookmark_rounded
                                                  : Icons.bookmark_outline_rounded,
                                              size: 26,
                                              color: bookmarked
                                                  ? green
                                                  : (isDark
                                                      ? Colors.white54
                                                      : Colors.black45),
                                            ),
                                            onPressed: _toggleBookmark,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Arabic text (UNTOUCHED — font/rendering not modified)
                                      AyahTextWidget(
                                          text: displayAyahText,
                                          ayahNumber: ayahInSurah,
                                          fontSize: arabicFontSize,
                                          isDark: isDark,
                                          surahNumber: widget.surahNumber,
                                          ayahIndex: currentAyahIndex,
                                          showContainer: false,
                                          bismillahText: null,
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Audio player bar
                              _AudioPlayerBar(
                                isDark: isDark,
                                isPlaying: isPlaying,
                                onPlayPause: _toggleAudio,
                              ),

                              const SizedBox(height: 10),

                              // Translation collapsible
                              if (surahDetail!.ayahs[currentAyahIndex].translation != null)
                                _CollapseRow(
                                  icon: Icons.language_rounded,
                                  label: 'Translation',
                                  isExpanded: _showTranslation,
                                  isDark: isDark,
                                  onToggle: () => setState(
                                      () => _showTranslation = !_showTranslation),
                                  child: TranslationWidget(
                                    translation: surahDetail!
                                        .ayahs[currentAyahIndex].translation!,
                                    isDark: isDark,
                                  ),
                                ),

                              const SizedBox(height: 8),

                              // Transliteration collapsible
                              if (surahDetail!.ayahs[currentAyahIndex]
                                      .transliteration !=
                                  null)
                                _CollapseRow(
                                  icon: Icons.abc_rounded,
                                  label: 'Transliteration',
                                  isExpanded: _showTransliteration,
                                  isDark: isDark,
                                  onToggle: () => setState(() =>
                                      _showTransliteration =
                                          !_showTransliteration),
                                  child: TransliterationWidget(
                                    transliteration: surahDetail!
                                        .ayahs[currentAyahIndex]
                                        .transliteration!,
                                    isDark: isDark,
                                  ),
                                ),

                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom navigation bar
                    AyahNavigationBar(
                      canGoPrevious: currentAyahIndex > 0,
                      canGoNext: true,
                      isFavorited: favorited,
                      isBookmarked: bookmarked,
                      isCompleted: isDone,
                      onPrevious: previousAyah,
                      onNext: nextAyah,
                      onFavorite: _toggleFavorite,
                      onBookmark: _toggleBookmark,
                      onComplete: _markDone,
                      isDark: isDark,
                    ),
                  ],
                ),
    );
  }
}

// ─────────────────────────────────────────────
// Audio Player Bar
// ─────────────────────────────────────────────

class _AudioPlayerBar extends StatelessWidget {
  final bool isDark;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  const _AudioPlayerBar({
    required this.isDark,
    required this.isPlaying,
    required this.onPlayPause,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2D7A4F);
    final cardBg = isDark ? const Color(0xFF1A2E20) : Colors.white;
    final textSecondary = isDark ? Colors.white54 : Colors.black45;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Play/pause
          GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: green,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Progress slider
          Expanded(
            child: StreamBuilder<Duration>(
              stream: AudioService.positionStream,
              builder: (context, posSnap) {
                return StreamBuilder<Duration?>(
                  stream: AudioService.durationStream,
                  builder: (context, durSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    final dur = durSnap.data ?? Duration.zero;
                    final maxVal = dur.inSeconds > 0
                        ? dur.inSeconds.toDouble()
                        : 1.0;
                    final curVal =
                        pos.inSeconds.clamp(0, maxVal.toInt()).toDouble();

                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: green,
                            inactiveTrackColor: green.withOpacity(0.2),
                            thumbColor: green,
                            overlayColor: green.withOpacity(0.15),
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14),
                          ),
                          child: Slider(
                            value: curVal,
                            min: 0,
                            max: maxVal,
                            onChanged: (v) => AudioService.seek(
                                Duration(seconds: v.toInt())),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fmt(pos),
                                  style: TextStyle(
                                      fontSize: 11, color: textSecondary)),
                              Text(_fmt(dur),
                                  style: TextStyle(
                                      fontSize: 11, color: textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Collapsible accordion row
// ─────────────────────────────────────────────

class _CollapseRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onToggle;
  final Widget child;

  const _CollapseRow({
    required this.icon,
    required this.label,
    required this.isExpanded,
    required this.isDark,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2D7A4F);
    final cardBg = isDark ? const Color(0xFF1A2E20) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: green),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isExpanded ? green : textPrimary,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: green, size: 20),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: child,
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Action sheet row
// ─────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Firework overlay (unchanged)
// ─────────────────────────────────────────────

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
            final t2 = Curves.easeOut
                .transform((_controller.value - 0.15).clamp(0, 1));
            final t3 = Curves.easeOut
                .transform((_controller.value - 0.3).clamp(0, 1));
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
