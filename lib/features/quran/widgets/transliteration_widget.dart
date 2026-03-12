import 'package:flutter/material.dart';

class TransliterationWidget extends StatelessWidget {
  final String transliteration;
  final bool isDark;

  const TransliterationWidget({
    super.key,
    required this.transliteration,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A1A)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transliteration',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            transliteration,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
