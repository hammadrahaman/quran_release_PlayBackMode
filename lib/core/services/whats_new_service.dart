import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../storage/local_storage.dart';

// ─── Release notes ───────────────────────────────────────────────────────────
// Add a new entry here for every release. Most recent version first.

class _ReleaseNote {
  final String version;
  final String date;
  final List<_NoteItem> items;
  const _ReleaseNote({required this.version, required this.date, required this.items});
}

class _NoteItem {
  final IconData icon;
  final String title;
  final String detail;
  const _NoteItem(this.icon, this.title, this.detail);
}

const List<_ReleaseNote> _releaseNotes = [
  _ReleaseNote(
    version: '2.3.0',
    date: 'June 2025',
    items: [
      _NoteItem(Icons.auto_stories_rounded, 'Full Surah & Juz Reading',
          'New scrollable reading mode — read an entire Surah or Juz on one continuous page. Switch between modes in Settings.'),
      _NoteItem(Icons.nightlight_round, 'Night Recitation',
          'A curated nightly reading list (7 PM – 1 AM) with Al-Mulk, Al-Baqarah last 2 ayahs, and the three Quls.'),
      _NoteItem(Icons.wb_sunny_rounded, 'Friday Recitation',
          'Al-Kahf and Al-Jumu\'ah highlighted every Friday (12 PM – 7 PM) with progress tracking.'),
      _NoteItem(Icons.check_circle_outline_rounded, 'Mark Done',
          'Tap the ✓ button in the ayah reader to save your reading position instantly.'),
      _NoteItem(Icons.speed_rounded, 'Faster Audio',
          'Next ayah audio pre-fetched in the background — near-gapless playback between ayahs.'),
      _NoteItem(Icons.refresh_rounded, 'Pull to Refresh',
          'Pull down on the Home screen to refresh your stats and recitation progress.'),
      _NoteItem(Icons.my_location_rounded, 'Accurate Resume Reading',
          'Continue Reading in Full Surah mode now scrolls to the exact saved ayah correctly.'),
      _NoteItem(Icons.swap_horiz_rounded, 'Consistent Mode Switching',
          'Night & Friday Recitation and Continue Reading all respect your chosen reading mode — switching between Ayah and Full Surah applies everywhere.'),
    ],
  ),
  // Add older versions below for reference (shown in Settings "What\'s New"):
  _ReleaseNote(
    version: '2.2.0',
    date: 'May 2025',
    items: [
      _NoteItem(Icons.mic_rounded, 'Recitation Audio', 'Added continuous recitation mode with auto-play.'),
      _NoteItem(Icons.calendar_today_rounded, 'Streak Calendar', 'View your 7-day reading streak on the home screen.'),
    ],
  ),
];

// ─── Service ─────────────────────────────────────────────────────────────────

class WhatsNewService {
  /// Show the dialog automatically if the user hasn't seen this version yet.
  static Future<void> maybeShow(BuildContext context) async {
    final pkg = await PackageInfo.fromPlatform();
    final current = pkg.version;
    final seen = LocalStorage.getLastSeenWhatsNewVersion();
    if (seen == current) return;
    if (!context.mounted) return;
    await show(context);
    LocalStorage.setLastSeenWhatsNewVersion(current);
  }

  /// Show the What's New dialog unconditionally (e.g. from Settings tap).
  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (_) => const _WhatsNewDialog(),
    );
  }
}

// ─── Dialog widget ────────────────────────────────────────────────────────────

class _WhatsNewDialog extends StatelessWidget {
  const _WhatsNewDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1B12) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF555555);
    final green = isDark ? const Color(0xFF3CAF6E) : const Color(0xFF2D7A4F);
    final divider = isDark ? Colors.white10 : Colors.black12;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: green.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(Icons.auto_awesome_rounded, color: green, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("What's New", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textPrimary)),
                    Text(_releaseNotes.first.version, style: TextStyle(fontSize: 12, color: green, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable notes
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
              child: Column(
                children: [
                  for (final release in _releaseNotes) ...[
                    if (release != _releaseNotes.first)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: divider)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'v${release.version} · ${release.date}',
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                            ),
                            Expanded(child: Divider(color: divider)),
                          ],
                        ),
                      ),
                    for (final item in release.items)
                      _NoteRow(item: item, green: green, textPrimary: textPrimary, textSecondary: textSecondary),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Dismiss button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final _NoteItem item;
  final Color green;
  final Color textPrimary;
  final Color textSecondary;

  const _NoteRow({
    required this.item,
    required this.green,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: green, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                const SizedBox(height: 2),
                Text(item.detail, style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
