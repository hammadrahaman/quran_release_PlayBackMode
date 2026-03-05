import 'package:flutter/material.dart';

class AyahTextWidget extends StatelessWidget {
  final String text;
  final int ayahNumber;
  final double fontSize;
  final bool isDark;
  final int surahNumber;
  final int ayahIndex;
  final bool showContainer;
  final String? bismillahText;

  const AyahTextWidget({
    super.key,
    required this.text,
    required this.ayahNumber,
    required this.fontSize,
    required this.isDark,
    required this.surahNumber,
    required this.ayahIndex,
    this.showContainer = true,
    this.bismillahText,
  });

  @override
  Widget build(BuildContext context) {
    final arabicColor =
        isDark ? const Color(0xFFF6EDE5) : const Color(0xFF2B1B12);

    final textWidget = RichText(
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      text: TextSpan(
        children: [
          if (bismillahText != null) ...[
            TextSpan(
              text: bismillahText!,
              style: TextStyle(
                fontFamily: 'IndoPak',
                fontSize: fontSize + 8,
                height: 2.4,
                fontWeight: FontWeight.bold,
                color: arabicColor,
              ),
            ),
            const TextSpan(text: '\n\n'),
          ],
          TextSpan(
            text: text,
            style: TextStyle(
              fontFamily: 'IndoPak',
              fontSize: fontSize + 8,
              height: 2.4,
              letterSpacing: 0.0,
              wordSpacing: 3.0,
              color: arabicColor,
            ),
          ),
        ],
      ),
    );

    if (!showContainer) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: textWidget,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: textWidget,
    );
  }
}