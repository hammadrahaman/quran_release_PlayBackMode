import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/services/audio_service.dart';
import '../../core/services/quran_api.dart';
import '../../core/storage/local_storage.dart';
import 'widgets/bismillah_header.dart';
import 'widgets/surah_completion_dialog.dart';

class FullSurahScreen extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final int initialAyahIndex;

  const FullSurahScreen({
    super.key,
    required this.surahNumber,
    required this.surahName,
    this.initialAyahIndex = 0,
  });

  @override
  State<FullSurahScreen> createState() => _FullSurahScreenState();
}

class _FullSurahScreenState extends State<FullSurahScreen> {
  SurahDetail? _surah;
  bool _isLoading = true;

  // Audio
  int _activeIndex = 0;
  bool _isPlaying = false;
  bool _isHandlingCompletion = false;
  StreamSubscription<PlayerState>? _playerSub;

  // Session tracking
  final Set<int> _sessionGlobalAyahs = {};
  final DateTime _sessionStart = DateTime.now();
  bool _timeSaved = false;

  // Scroll & visibility
  late final ScrollController _scrollController;
  final List<GlobalKey> _ayahKeys = [];
  final Map<int, DateTime> _visibleSince = {};
  Timer? _visibilityTimer;

  // Settings
  double _arabicFontSize = 32.0;
  bool _showTranslation = false;
  bool _showTransliteration = false;

  static const _green = Color(0xFF2D7A4F);
  static const _greenDark = Color(0xFF3CAF6E);

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.initialAyahIndex;
    _arabicFontSize = LocalStorage.getArabicFontSize();
    _scrollController = ScrollController();
    _loadSurah();
    _subscribeAudio();
    _visibilityTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkVisibility());
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _visibilityTimer?.cancel();
    _scrollController.dispose();
    if (!_timeSaved) {
      final secs = DateTime.now().difference(_sessionStart).inSeconds;
      if (secs > 0) LocalStorage.addReadingSeconds(secs);
    }
    AudioService.stop();
    super.dispose();
  }

  // ─── Data ────────────────────────────────────────────────────────────────

  Future<void> _loadSurah() async {
    setState(() => _isLoading = true);
    final data = await QuranAPI.getSurahWithTranslation(widget.surahNumber);
    if (!mounted) return;
    setState(() {
      _surah = data;
      _isLoading = false;
      if (data != null) {
        _ayahKeys.clear();
        for (int i = 0; i < data.ayahs.length; i++) {
          _ayahKeys.add(GlobalKey());
        }
      }
    });
    if (data != null) {
      LocalStorage.saveLastRead(widget.surahNumber, _activeIndex + 1);
      // Scroll to initial position after frame renders
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToIndex(_activeIndex, animate: false));
    }
  }

  // ─── Audio ───────────────────────────────────────────────────────────────

  void _subscribeAudio() {
    _playerSub = AudioService.playerStateStream.listen((state) async {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);

      if (state.processingState == ProcessingState.completed) {
        if (_isHandlingCompletion) return;
        _isHandlingCompletion = true;
        await _onAyahAudioCompleted();
        _isHandlingCompletion = false;
      }
    });
  }

  Future<void> _onAyahAudioCompleted() async {
    if (_surah == null) return;
    // Award hasanat for completed ayah
    _awardHasanat(_activeIndex);

    if (_activeIndex < _surah!.ayahs.length - 1) {
      setState(() => _activeIndex++);
      LocalStorage.saveLastRead(widget.surahNumber, _activeIndex + 1);
      _scrollToIndex(_activeIndex);
      // Prefetch the one after so it's ready before we need it
      if (_activeIndex + 1 < _surah!.ayahs.length) {
        AudioService.prefetchAyah(_surah!.ayahs[_activeIndex + 1].number);
      }
      await AudioService.playAyah(_surah!.ayahs[_activeIndex].number);
    } else {
      // Last ayah completed
      setState(() => _isPlaying = false);
      await _onSurahComplete();
    }
  }

  Future<void> _togglePlayPause() async {
    if (_surah == null) return;
    HapticFeedback.lightImpact();
    try {
      if (_isPlaying) {
        await AudioService.pause();
      } else {
        await AudioService.playAyah(_surah!.ayahs[_activeIndex].number);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio failed to load. Check internet and try again.')),
      );
    }
  }

  Future<void> _startAudioFrom(int index) async {
    if (_surah == null) return;
    setState(() => _activeIndex = index);
    LocalStorage.saveLastRead(widget.surahNumber, index + 1);
    _scrollToIndex(index);
    // Prefetch next ayah while this one loads
    if (index + 1 < _surah!.ayahs.length) {
      AudioService.prefetchAyah(_surah!.ayahs[index + 1].number);
    }
    try {
      await AudioService.playAyah(_surah!.ayahs[index].number);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio failed to load. Check internet and try again.')),
      );
    }
  }

  Future<void> _onSurahComplete() async {
    if (!mounted) return;
    _timeSaved = true;
    final secs = DateTime.now().difference(_sessionStart).inSeconds;
    if (secs > 0) LocalStorage.addReadingSeconds(secs);

    final shouldContinue = await SurahCompletionDialog.show(
      context: context,
      surahName: widget.surahName,
      nextSurahNumber: widget.surahNumber + 1,
      hasNextSurah: widget.surahNumber < 114,
    );
    if (shouldContinue && mounted && widget.surahNumber < 114) {
      final next = await QuranAPI.getSurahWithTranslation(widget.surahNumber + 1);
      if (!mounted || next == null) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FullSurahScreen(
            surahNumber: widget.surahNumber + 1,
            surahName: next.englishName,
          ),
        ),
      );
    }
  }

  // ─── Visibility / Hasanat ────────────────────────────────────────────────

  void _checkVisibility() {
    if (_surah == null || !mounted) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final screenHeight = renderBox.size.height;

    for (int i = 0; i < _ayahKeys.length; i++) {
      final key = _ayahKeys[i];
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final pos = box.localToGlobal(Offset.zero);
      final ayahTop = pos.dy;
      final ayahBottom = ayahTop + box.size.height;

      final isVisible = ayahBottom > 0 && ayahTop < screenHeight;

      if (isVisible) {
        _visibleSince.putIfAbsent(i, () => DateTime.now());
        final elapsed = DateTime.now().difference(_visibleSince[i]!).inSeconds;
        if (elapsed >= 5) {
          _awardHasanat(i);
        }
      } else {
        _visibleSince.remove(i);
      }
    }
  }

  void _awardHasanat(int index) {
    if (_surah == null) return;
    final ayah = _surah!.ayahs[index];
    if (_sessionGlobalAyahs.contains(ayah.number)) return;
    final hasanat = _estimateHasanat(ayah.text);
    LocalStorage.recordAyahRead(
      globalAyahNumber: ayah.number,
      hasanatEarned: hasanat,
    );
    _sessionGlobalAyahs.add(ayah.number);
  }

  int _estimateHasanat(String text) {
    return RegExp(r'[ء-يٱ]').allMatches(text).length * 10;
  }

  // ─── Scroll ──────────────────────────────────────────────────────────────

  void _scrollToIndex(int index, {bool animate = true}) {
    if (index < 0 || index >= _ayahKeys.length) return;
    if (index == 0) return; // already at top

    final ctx = _ayahKeys[index].currentContext;
    if (ctx == null) return;

    if (animate) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.15);
    } else {
      Scrollable.ensureVisible(ctx, duration: Duration.zero, alignment: 0.15);
    }
  }

  // ─── Bottom sheet ────────────────────────────────────────────────────────

  void _showAyahActions(int index) {
    if (_surah == null) return;
    final ayah = _surah!.ayahs[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AyahActionSheet(
        surahNumber: widget.surahNumber,
        ayahNumber: ayah.numberInSurah,
        surahName: widget.surahName,
        isDark: isDark,
        isLastReadPosition: () {
          final lr = LocalStorage.getLastRead();
          return lr['surah'] == widget.surahNumber && lr['ayah'] == ayah.numberInSurah;
        },
        onDone: () {
          LocalStorage.saveLastRead(widget.surahNumber, ayah.numberInSurah);
          setState(() {});
        },
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? _greenDark : _green;
    final bg = isDark ? const Color(0xFF0D1B12) : const Color(0xFFF5F5F5);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF666666);

    final totalAyahs = _surah?.ayahs.length ?? 0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D1B12) : Colors.white,
        elevation: 0,
        leading: BackButton(color: green),
        title: Column(
          children: [
            Text(
              widget.surahName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            if (totalAyahs > 0)
              Text(
                'Ayah ${_activeIndex + 1} of $totalAyahs',
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Translation toggle
          IconButton(
            icon: Icon(
              _showTranslation ? Icons.translate : Icons.translate_outlined,
              color: _showTranslation ? green : textSecondary,
              size: 20,
            ),
            tooltip: 'Translation',
            onPressed: () => setState(() => _showTranslation = !_showTranslation),
          ),
          // Play / Pause
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
              color: green,
              size: 28,
            ),
            tooltip: _isPlaying ? 'Pause' : 'Play Surah',
            onPressed: _togglePlayPause,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: green))
          : _surah == null
              ? Center(child: Text('Failed to load surah.', style: TextStyle(color: textSecondary)))
              : ListView.builder(
                  controller: _scrollController,
                  cacheExtent: 99999,
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
                  itemCount: _surah!.ayahs.length + (_showBismillah ? 1 : 0),
                  itemBuilder: (context, listIndex) {
                    // Bismillah header as first item for eligible surahs
                    if (_showBismillah && listIndex == 0) {
                      return BismillahHeader(isDark: isDark, fontSize: _arabicFontSize);
                    }
                    final ayahIndex = _showBismillah ? listIndex - 1 : listIndex;
                    return _buildAyahCard(ayahIndex, isDark, green, textSecondary);
                  },
                ),
      // Audio progress bar at bottom
      bottomNavigationBar: _surah == null
          ? null
          : _buildAudioBar(isDark, green, textSecondary),
    );
  }

  bool get _showBismillah =>
      widget.surahNumber != 1 && widget.surahNumber != 9;

  Widget _buildAyahCard(int index, bool isDark, Color green, Color textSecondary) {
    final ayah = _surah!.ayahs[index];
    final isActive = index == _activeIndex;
    final arabicColor = isDark ? const Color(0xFFF6EDE5) : const Color(0xFF2B1B12);

    return GestureDetector(
      onTap: () => _showAyahActions(index),
      onLongPress: () => _startAudioFrom(index),
      child: Container(
        key: _ayahKeys[index],
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF1A3A22) : const Color(0xFFEAF7EE))
              : (isDark ? const Color(0xFF0A1A10) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: green, width: 1.5)
              : Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ayah number badge
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? green : (isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Center(
                      child: Text(
                        '${ayah.numberInSurah}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isActive && _isPlaying)
                    Icon(Icons.volume_up_rounded, color: green, size: 16),
                ],
              ),
            ),
            // Arabic text
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Text(
                ayah.text,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'IndoPak',
                  fontSize: _arabicFontSize + 8,
                  height: 2.4,
                  color: arabicColor,
                ),
              ),
            ),
            // Translation
            if (_showTranslation && ayah.translation != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  ayah.translation!,
                  style: TextStyle(
                    fontSize: LocalStorage.getTranslationFontSize(),
                    color: textSecondary,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            // Transliteration
            if (_showTransliteration && ayah.transliteration != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  ayah.transliteration!,
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioBar(bool isDark, Color green, Color textSecondary) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1B12) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.music_note_rounded, color: textSecondary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: AudioService.positionStream,
                  builder: (_, posSnap) {
                    return StreamBuilder<Duration?>(
                      stream: AudioService.durationStream,
                      builder: (_, durSnap) {
                        final pos = posSnap.data ?? Duration.zero;
                        final dur = durSnap.data ?? Duration.zero;
                        final progress = dur.inMilliseconds > 0
                            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                            : 0.0;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _isPlaying ? progress : 0.0,
                            minHeight: 4,
                            backgroundColor: isDark ? Colors.white12 : Colors.black12,
                            valueColor: AlwaysStoppedAnimation<Color>(green),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isPlaying
                    ? 'Playing ayah ${_activeIndex + 1}'
                    : 'Long-press ayah to play',
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Ayah action bottom sheet
// ─────────────────────────────────────────────────────────────

class _AyahActionSheet extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;
  final String surahName;
  final bool isDark;
  final bool Function() isLastReadPosition;
  final VoidCallback onDone;

  const _AyahActionSheet({
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    required this.isDark,
    required this.isLastReadPosition,
    required this.onDone,
  });

  @override
  State<_AyahActionSheet> createState() => _AyahActionSheetState();
}

class _AyahActionSheetState extends State<_AyahActionSheet> {
  static const _green = Color(0xFF2D7A4F);

  bool get _isBookmarked =>
      LocalStorage.isBookmarked(widget.surahNumber, widget.ayahNumber);
  bool get _isFavorited =>
      LocalStorage.isFavorited(widget.surahNumber, widget.ayahNumber);

  void _toggleBookmark() {
    setState(() {
      if (_isBookmarked) {
        LocalStorage.removeBookmark(widget.surahNumber, widget.ayahNumber);
      } else {
        LocalStorage.addBookmark(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
          surahName: widget.surahName,
        );
      }
    });
  }

  void _toggleFavorite() {
    setState(() {
      if (_isFavorited) {
        LocalStorage.removeFavorite(widget.surahNumber, widget.ayahNumber);
      } else {
        LocalStorage.addFavorite(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
          surahName: widget.surahName,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF1A2E20) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF666666);
    final isDone = widget.isLastReadPosition();

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          // Title
          Text(
            '${widget.surahName} — Ayah ${widget.ayahNumber}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
          ),
          const SizedBox(height: 24),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: _isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: _isFavorited ? 'Unfavourite' : 'Favourite',
                color: _isFavorited ? Colors.red : textSecondary,
                onTap: _toggleFavorite,
              ),
              _ActionButton(
                icon: _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                label: _isBookmarked ? 'Bookmarked' : 'Bookmark',
                color: _isBookmarked ? _green : textSecondary,
                onTap: _toggleBookmark,
              ),
              _ActionButton(
                icon: isDone ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                label: isDone ? 'Saved' : 'Mark Done',
                color: isDone ? _green : textSecondary,
                onTap: () {
                  widget.onDone();
                  setState(() {});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Progress saved — ${widget.surahName} : Ayah ${widget.ayahNumber}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
