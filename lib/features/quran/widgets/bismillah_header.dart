import 'package:flutter/material.dart';

class BismillahHeader extends StatelessWidget {
  final bool isDark;
  final double fontSize;

  const BismillahHeader({
    super.key,
    required this.isDark,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1414) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2D7A4F).withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2D7A4F).withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Bismillah',
              style: TextStyle(
                color: const Color(0xFF2D7A4F),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
            fontFamily: 'IndoPak',
            fontSize: fontSize + 8,
            height: 2.3,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'In the Name of Allah—the Most Compassionate, Most Merciful',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: (isDark ? Colors.white70 : Colors.black54),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}