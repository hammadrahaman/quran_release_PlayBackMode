import 'package:flutter/material.dart';
import '../../../core/storage/local_storage.dart';

class TranslationWidget extends StatelessWidget {
  final String translation;
  final bool isDark;

  const TranslationWidget({
    super.key,
    required this.translation,
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
            'Translation',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            translation,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: LocalStorage.getTranslationFontSize(),
              height: 1.8,
              color: isDark ? Colors.grey[200] : Colors.grey[800],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}