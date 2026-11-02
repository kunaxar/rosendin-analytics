import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ui.dart';
import 'data.dart';

// ---------- single series vertical bars ----------
class Bars extends StatelessWidget {
  final List<MonthCount> data;
  final Color color;
  final int height;
  const Bars({super.key, required this.data, this.color = slate, this.height = 180});

  @override
  Widget build(BuildContext context) {
    final maxV = data.fold<int>(0, (a, b) => math.max(a, b.value));
    return SizedBox(
      height: height.toDouble(),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final d in data)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('${d.value}', style: const TextStyle(fontSize: 10, color: g500)),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                height: maxV == 0 ? 0 : (d.value / maxV) * (height - 46),
                decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
              ),
              const SizedBox(height: 6),
              Text(d.label, style: const TextStyle(fontSize: 11, color: g500)),
            ]),
          ),
      ]),
    );
  }
}

// ---------- horizontal bar list ----------
class HBars extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final Color color;
  const HBars({super.key, required this.entries, this.color = slate});

  @override
  Widget build(BuildContext context) {
    final maxV = entries.fold<int>(0, (a, b) => math.max(a, b.value));
    return Column(children: [
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(width: 170, child: Text(e.key, style: const TextStyle(fontSize: 13, color: g900), overflow: TextOverflow.ellipsis)),
            Expanded(
              child: Container(
                height: 20,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: maxV == 0 ? 0 : e.value / maxV,
                  child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 28, child: Text('${e.value}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
        ),
    ]);
  }
}

// ---------- donut ----------
class Donut extends StatelessWidget {
  final List<(String, int, Color)> slices;
  final String centerLabel;
  const Donut({super.key, required this.slices, required this.centerLabel});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (a, s) => a + s.$2);
    return Row(children: [
      SizedBox(
        width: 150, height: 150,
        child: CustomPaint(
          painter: _DonutPainter(slices),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$total', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            Text(centerLabel, style: const TextStyle(fontSize: 11, color: g500)),
          ])),
        ),
      ),
      const SizedBox(width: 20),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: s.$3, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Expanded(child: Text(s.$1, style: const TextStyle(fontSize: 13))),
              Text('${s.$2}${total == 0 ? '' : '  ·  ${(100 * s.$2 / total).round()}%'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
      ])),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final List<(String, int, Color)> slices;
  _DonutPainter(this.slices);
  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (a, s) => a + s.$2);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(6);
    var start = -math.pi / 2;
    if (total == 0) {
      canvas.drawArc(rect, 0, 2 * math.pi, false, Paint()..color = g200..style = PaintingStyle.stroke..strokeWidth = 22);
      return;
    }
    for (final s in slices) {
      final sweep = 2 * math.pi * s.$2 / total;
      canvas.drawArc(rect, start + 0.02, sweep - 0.04, false, Paint()..color = s.$3..style = PaintingStyle.stroke..strokeWidth = 22..strokeCap = StrokeCap.butt);
      start += sweep;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
