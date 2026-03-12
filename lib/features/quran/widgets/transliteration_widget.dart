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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF252530)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transliteration',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            transliteration,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: isDark ? const Color(0xFFE8E6E3) : const Color(0xFF3D3D3D),
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
