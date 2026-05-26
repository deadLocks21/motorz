import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/ui/theme/app_colors.dart';

/// Wordmark « Motor**z** » — Archivo 800 italic majuscules, le « z » en orange.
class MotorzWordmark extends StatelessWidget {
  const MotorzWordmark({super.key, this.fontSize = 40});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final style = GoogleFonts.archivo(
      textStyle: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: -0.5,
        height: 1,
      ),
    );
    return RichText(
      text: TextSpan(
        style: style.copyWith(color: colors.textPrimary),
        children: [
          const TextSpan(text: 'MOTOR'),
          TextSpan(text: 'Z', style: TextStyle(color: colors.accent)),
        ],
      ),
    );
  }
}
