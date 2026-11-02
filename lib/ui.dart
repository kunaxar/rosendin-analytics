import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const slate = Color(0xFF3C5F82);
const slateDark = Color(0xFF2C4A68);
const orange = Color(0xFFFD6A3E);
const g50 = Color(0xFFF9FAFB);
const g100 = Color(0xFFF2F4F7);
const g200 = Color(0xFFEAECF0);
const g300 = Color(0xFFD0D5DD);
const g500 = Color(0xFF667085);
const g600 = Color(0xFF475467);
const g900 = Color(0xFF101828);
const green = Color(0xFF027A48);
const greenBg = Color(0xFFECFDF3);
const amber = Color(0xFFB54708);
const amberBg = Color(0xFFFFFAEB);
const red = Color(0xFFB42318);
const redBg = Color(0xFFFEF3F2);
const blueBg = Color(0xFFEFF4FB);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: slate).copyWith(primary: slate, secondary: orange, surface: Colors.white),
    scaffoldBackgroundColor: g50,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: g900, displayColor: g900),
    dividerColor: g200,
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: Colors.white, isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: g300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: g300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: slate, width: 1.5)),
    ),
  );
}

class Tag extends StatelessWidget {
  final String text; final Color fg, bg; final IconData? icon;
  const Tag(this.text, this.fg, this.bg, {super.key, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

Widget demoBanner() => Container(
      width: double.infinity, color: amberBg, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.science_outlined, size: 14, color: amber), SizedBox(width: 6),
        Flexible(child: Text('Prototype - fictional demo data. Nudges and verification requests are simulated; nothing is sent.', style: TextStyle(color: amber, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );

class CardBox extends StatelessWidget {
  final Widget child; final EdgeInsets? padding;
  const CardBox({super.key, required this.child, this.padding});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: g200), borderRadius: BorderRadius.circular(14)),
        child: child,
      );
}

class KpiCard extends StatelessWidget {
  final String label; final String value; final String? sub; final IconData icon; final Color? accent;
  const KpiCard({super.key, required this.label, required this.value, this.sub, required this.icon, this.accent});
  @override
  Widget build(BuildContext context) => CardBox(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: accent ?? slate), const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: g600, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub!, style: const TextStyle(fontSize: 12, color: g500))),
        ]),
      );
}

Widget chartTitle(String t, {String? sub}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: const TextStyle(fontSize: 12.5, color: g500))),
      ]),
    );

Widget pct(int part, int total) => Text(total == 0 ? '0%' : '${(100 * part / total).round()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700));
