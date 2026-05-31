import 'package:flutter/material.dart';

class AyahNavigationBar extends StatelessWidget {
  final int currentIndex;
  final int totalAyahs;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onDone;
  final bool isDark;

  const AyahNavigationBar({
    super.key,
    required this.currentIndex,
    required this.totalAyahs,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    required this.onDone,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2D7A4F); // green

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final vPad = isLandscape ? 10.0 : 14.0;
    final hPad = isLandscape ? 12.0 : 18.0;
    final buttonHeight = isLandscape ? 42.0 : 48.0;

    Color iconBg(bool enabled) => enabled
        ? (isDark ? Colors.white10 : Colors.black.withOpacity(0.06))
        : (isDark ? Colors.white12 : Colors.black.withOpacity(0.04));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1B12) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Previous
            Container(
              decoration: BoxDecoration(
                color: iconBg(canGoPrevious),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: canGoPrevious ? onPrevious : null,
                iconSize: 28,
                color: canGoPrevious
                    ? (isDark ? Colors.white : Colors.black87)
                    : Colors.grey,
              ),
            ),

            const SizedBox(width: 12),

            // Done button (adaptive)
            Expanded(
              child: SizedBox(
                height: buttonHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(isDark ? 0.35 : 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: onDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Save & Bookmark",
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: isLandscape ? 14 : 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Next
            Container(
              decoration: BoxDecoration(
                color: iconBg(canGoNext),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: canGoNext ? onNext : null,
                iconSize: 28,
                color: canGoNext
                    ? (isDark ? Colors.white : Colors.black87)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}