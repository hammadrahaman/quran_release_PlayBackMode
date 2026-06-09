import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/services/audio_service.dart';
import '../../core/services/quran_api.dart';
import '../../core/storage/local_storage.dart';
import 'widgets/bismillah_header.dart';

class FullJuzScreen extends StatefulWidget {
  final int juzNumber;
  final String juzName;

  /// Global ayah number to scroll to on open (optional).
  final int? initialGlobalAyahNumber;

  const FullJuzScreen({
    super.key,
    required this.juzNumber,
    required this.juzName,
    this.initialGlobalAyahNumber,
  });

  @override
  State<FullJuzScreen> createState() => _FullJuzScreenState();
}

class _FullJuzScreenState extends State<FullJuzScreen> {
  List<JuzItem>? _items;
  bool _isLoading = true;

  // Flat list of ayahs only (for audio index tracking)
  final List<JuzAyahItem> _ayahItems = [];
  // Map global ayah number → index in _items
  final Map<int, int> _globalToListIndex = {};
  // Map index in _items → GlobalKey
  final Map<int, GlobalKey> _itemKeys = {};

  // Audio
  int _activeAyahGlobalNumber = -1;
  bool _isPlaying = false;
  bool _isHandlingCompletion = false;
  StreamSubscription<PlayerState>? _playerSub;

  // Session
  final Set<int> _sessionGlobalAyahs = {};
  final DateTime _sessionStart = DateTime.now();
  bool _timeSaved = false;

  // Scroll & visibility
  late final ScrollController _scrollController;
  final Map<int, DateTime> _visibleSince = {}; // key: list index
  Timer? _visibilityTimer;

  // Settings
  double _arabicFontSize = 32.0;
  bool _showTranslation = false;

  static const _green = Color(0xFF2D7A4F);
  static const _greenDark = Color(0xFF3CAF6E);

  @override
  void initState() {
    super.initState();
    _arabicFontSize = LocalStorage.getArabicFontSize();
    // Pre-position near the target so it's in the render tree when ensureVisible fires
    _scrollController = ScrollController();
    _loadJuz();
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

  Future<void> _loadJuz() async {
    setState(() => _isLoading = true);
    final items = await QuranAPI.getJuzAyahs(widget.juzNumber);
    if (!mounted) return;

    _ayahItems.clear();
    _globalToListIndex.clear();
    _itemKeys.clear();

    if (items != null) {
      for (int i = 0; i < items.length; i++) {
        _itemKeys[i] = GlobalKey();
        if (items[i] is JuzAyahItem) {
          final ai = items[i] as JuzAyahItem;
          _ayahItems.add(ai);
          _globalToListIndex[ai.ayah.number] = i;
        }
      }
    }

    setState(() {
      _items = items;
      _isLoading = false;
    });

    // Scroll to initial position after frame
    if (items != null && widget.initialGlobalAyahNumber != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final idx = _globalToListIndex[widget.initialGlobalAyahNumber!];
        if (idx != null) _scrollToListIndex(idx, animate: false);
      });
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
    if (_ayahItems.isEmpty) return;
    _awardHasanat(_activeAyahGlobalNumber);

    final currentIdx = _ayahItems.indexWhere((a) => a.ayah.number == _activeAyahGlobalNumber);
    if (currentIdx == -1) return;

    if (currentIdx < _ayahItems.length - 1) {
      final next = _ayahItems[currentIdx + 1];
      setState(() => _activeAyahGlobalNumber = next.ayah.number);
      LocalStorage.saveLastRead(next.surahNumber, next.ayah.numberInSurah);
      final listIdx = _globalToListIndex[next.ayah.number];
      if (listIdx != null) _scrollToListIndex(listIdx);
      // Prefetch the one after next so it's cached before we need it
      if (currentIdx + 2 < _ayahItems.length) {
        AudioService.prefetchAyah(_ayahItems[currentIdx + 2].ayah.number);
      }
      await AudioService.playAyah(next.ayah.number);
    } else {
      // End of Juz
      setState(() => _isPlaying = false);
      await _onJuzComplete();
    }
  }

  Future<void> _togglePlayPause() async {
    if (_ayahItems.isEmpty) return;
    HapticFeedback.lightImpact();
    try {
      if (_isPlaying) {
        await AudioService.pause();
      } else {
        final startAyah = _activeAyahGlobalNumber != -1
            ? _activeAyahGlobalNumber
            : _ayahItems.first.ayah.number;
        setState(() => _activeAyahGlobalNumber = startAyah);
        // Prefetch next while first starts loading
        final startIdx = _ayahItems.indexWhere((a) => a.ayah.number == startAyah);
        if (startIdx != -1 && startIdx + 1 < _ayahItems.length) {
          AudioService.prefetchAyah(_ayahItems[startIdx + 1].ayah.number);
        }
        await AudioService.playAyah(startAyah);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio failed to load. Check internet and try again.')),
      );
    }
  }

  Future<void> _startAudioFrom(JuzAyahItem item) async {
    setState(() => _activeAyahGlobalNumber = item.ayah.number);
    LocalStorage.saveLastRead(item.surahNumber, item.ayah.numberInSurah);
    final listIdx = _globalToListIndex[item.ayah.number];
    if (listIdx != null) _scrollToListIndex(listIdx);
    // Prefetch next ayah immediately
    final itemIdx = _ayahItems.indexOf(item);
    if (itemIdx != -1 && itemIdx + 1 < _ayahItems.length) {
      AudioService.prefetchAyah(_ayahItems[itemIdx + 1].ayah.number);
    }
    try {
      await AudioService.playAyah(item.ayah.number);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio failed to load. Check internet and try again.')),
      );
    }
  }

  Future<void> _onJuzComplete() async {
    if (!mounted) return;
    _timeSaved = true;
    final secs = DateTime.now().difference(_sessionStart).inSeconds;
    if (secs > 0) LocalStorage.addReadingSeconds(secs);

    if (widget.juzNumber >= 30) {
      // Last Juz — just show a completion message
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Juz Complete'),
          content: Text('You have completed Juz ${widget.juzNumber} — ${widget.juzName}.\nMay Allah accept your recitation.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      return;
    }

    // Offer next Juz
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Juz ${widget.juzNumber} Complete'),
        content: Text('May Allah accept your recitation.\n\nContinue to Juz ${widget.juzNumber + 1}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Done')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Juz ${widget.juzNumber + 1}')),
        ],
      ),
    );
    if (go == true && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FullJuzScreen(
            juzNumber: widget.juzNumber + 1,
            juzName: 'Juz ${widget.juzNumber + 1}',
          ),
        ),
      );
    }
  }

  // ─── Visibility / Hasanat ────────────────────────────────────────────────

  void _checkVisibility() {
    if (_items == null || !mounted) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final screenHeight = renderBox.size.height;

    for (final entry in _itemKeys.entries) {
      final listIdx = entry.key;
      final key = entry.value;
      if (_items![listIdx] is! JuzAyahItem) continue;

      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final pos = box.localToGlobal(Offset.zero);
      final top = pos.dy;
      final bottom = top + box.size.height;
      final isVisible = bottom > 0 && top < screenHeight;

      if (isVisible) {
        _visibleSince.putIfAbsent(listIdx, () => DateTime.now());
        final elapsed = DateTime.now().difference(_visibleSince[listIdx]!).inSeconds;
        if (elapsed >= 5) {
          final ai = _items![listIdx] as JuzAyahItem;
          _awardHasanat(ai.ayah.number);
        }
      } else {
        _visibleSince.remove(listIdx);
      }
    }
  }

  void _awardHasanat(int globalAyahNumber) {
    if (globalAyahNumber < 0) return;
    if (_sessionGlobalAyahs.contains(globalAyahNumber)) return;
    // Find the ayah text for hasanat estimate
    final item = _ayahItems.firstWhere(
      (a) => a.ayah.number == globalAyahNumber,
      orElse: () => _ayahItems.first,
    );
    final hasanat = RegExp(r'[ء-يٱ]').allMatches(item.ayah.text).length * 10;
    LocalStorage.recordAyahRead(globalAyahNumber: globalAyahNumber, hasanatEarned: hasanat);
    _sessionGlobalAyahs.add(globalAyahNumber);
  }

  // ─── Scroll ──────────────────────────────────────────────────────────────

  void _scrollToListIndex(int listIdx, {bool animate = true}) {
    final key = _itemKeys[listIdx];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;
    if (animate) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.15);
    } else {
      Scrollable.ensureVisible(ctx, duration: Duration.zero);
    }
  }

  // ─── Bottom sheet ────────────────────────────────────────────────────────

  void _showAyahActions(JuzAyahItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _JuzAyahActionSheet(
        surahNumber: item.surahNumber,
        ayahNumber: item.ayah.numberInSurah,
        surahName: item.surahName,
        isDark: isDark,
        isLastReadPosition: () {
          final lr = LocalStorage.getLastRead();
          return lr['surah'] == item.surahNumber && lr['ayah'] == item.ayah.numberInSurah;
        },
        onDone: () {
          LocalStorage.saveLastRead(item.surahNumber, item.ayah.numberInSurah);
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D1B12) : Colors.white,
        elevation: 0,
        leading: BackButton(color: green),
        title: Column(
          children: [
            Text(
              'Juz ${widget.juzNumber}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
            ),
            Text(
              widget.juzName,
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
            tooltip: _isPlaying ? 'Pause' : 'Play Juz',
            onPressed: _togglePlayPause,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: green))
          : _items == null
              ? Center(child: Text('Failed to load Juz.', style: TextStyle(color: textSecondary)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
                  itemCount: _items!.length,
                  itemBuilder: (context, i) {
                    final item = _items![i];
                    if (item is JuzSurahDivider) {
                      return _buildSurahDivider(i, item, isDark, green, textPrimary, textSecondary);
                    } else {
                      return _buildAyahCard(i, item as JuzAyahItem, isDark, green, textSecondary);
                    }
                  },
                ),
      bottomNavigationBar: _buildAudioBar(isDark, green, textSecondary),
    );
  }

  Widget _buildSurahDivider(int listIdx, JuzSurahDivider div, bool isDark, Color green, Color textPrimary, Color textSecondary) {
    final showBismillah = div.surahNumber != 1 && div.surahNumber != 9;
    return Container(
      key: _itemKeys[listIdx],
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, color: green, size: 16),
                const SizedBox(width: 8),
                Text(
                  div.surahName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: green),
                ),
                const Spacer(),
                Text(
                  'Surah ${div.surahNumber}',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ),
          if (showBismillah) ...[
            const SizedBox(height: 4),
            BismillahHeader(isDark: isDark, fontSize: _arabicFontSize),
          ],
        ],
      ),
    );
  }

  Widget _buildAyahCard(int listIdx, JuzAyahItem item, bool isDark, Color green, Color textSecondary) {
    final isActive = item.ayah.number == _activeAyahGlobalNumber;
    final arabicColor = isDark ? const Color(0xFFF6EDE5) : const Color(0xFF2B1B12);

    return GestureDetector(
      onTap: () => _showAyahActions(item),
      onLongPress: () => _startAudioFrom(item),
      child: Container(
        key: _itemKeys[listIdx],
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
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
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
                        '${item.ayah.numberInSurah}',
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
            // Arabic
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Text(
                item.ayah.text,
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
            if (_showTranslation && item.ayah.translation != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  item.ayah.translation!,
                  style: TextStyle(
                    fontSize: LocalStorage.getTranslationFontSize(),
                    color: textSecondary,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
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
                _isPlaying ? 'Playing' : 'Long-press ayah to play',
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ayah action bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _JuzAyahActionSheet extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;
  final String surahName;
  final bool isDark;
  final bool Function() isLastReadPosition;
  final VoidCallback onDone;

  const _JuzAyahActionSheet({
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    required this.isDark,
    required this.isLastReadPosition,
    required this.onDone,
  });

  @override
  State<_JuzAyahActionSheet> createState() => _JuzAyahActionSheetState();
}

class _JuzAyahActionSheetState extends State<_JuzAyahActionSheet> {
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
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Text(
            '${widget.surahName} — Ayah ${widget.ayahNumber}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _JuzActionButton(
                icon: _isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: _isFavorited ? 'Unfavourite' : 'Favourite',
                color: _isFavorited ? Colors.red : textSecondary,
                onTap: _toggleFavorite,
              ),
              _JuzActionButton(
                icon: _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                label: _isBookmarked ? 'Bookmarked' : 'Bookmark',
                color: _isBookmarked ? _green : textSecondary,
                onTap: _toggleBookmark,
              ),
              _JuzActionButton(
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

class _JuzActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _JuzActionButton({
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
              color: color.withValues(alpha: 0.1),
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
