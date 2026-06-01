import 'package:flutter/material.dart';

class AyahNavigationBar extends StatelessWidget {
  final bool canGoPrevious;
  final bool canGoNext;
  final bool isFavorited;
  final bool isBookmarked;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFavorite;
  final VoidCallback onBookmark;
  final bool isDark;

  const AyahNavigationBar({
    super.key,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.isFavorited,
    required this.isBookmarked,
    required this.onPrevious,
    required this.onNext,
    required this.onFavorite,
    required this.onBookmark,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2D7A4F);
    final textSecondary = isDark ? Colors.white38 : Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1B12) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              // Previous
              TextButton.icon(
                onPressed: canGoPrevious ? onPrevious : null,
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: canGoPrevious ? green : textSecondary,
                ),
                label: Text(
                  'Previous',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: canGoPrevious ? green : textSecondary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              const Spacer(),

              // Favorite
              _BarButton(
                icon: isFavorited
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: 'Favorite',
                color: isFavorited ? Colors.red : textSecondary,
                onTap: onFavorite,
              ),

              const SizedBox(width: 16),

              // Bookmark
              _BarButton(
                icon: isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                label: 'Bookmark',
                color: isBookmarked ? green : textSecondary,
                onTap: onBookmark,
              ),

              const Spacer(),

              // Next
              TextButton.icon(
                onPressed: canGoNext ? onNext : null,
                icon: Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: canGoNext ? green : textSecondary,
                  ),
                ),
                label: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: canGoNext ? green : textSecondary,
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
