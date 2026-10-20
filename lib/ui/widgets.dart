import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../engine/engine.dart';
import 'theme.dart';

/// One row of the object lists: badge, name, and the two figures that matter —
/// how high and which way.
class ObjectRow extends StatelessWidget {
  final String name, sub, badge;
  final String right, sub2;
  final Color colour;
  final bool belowHorizon;
  final VoidCallback? onTap;
  const ObjectRow({
    super.key,
    required this.name,
    required this.sub,
    required this.badge,
    required this.right,
    required this.sub2,
    required this.colour,
    this.belowHorizon = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colour.withOpacity(0.13),
                border: Border.all(color: colour.withOpacity(0.4)),
                shape: BoxShape.circle,
              ),
              child: Text(badge,
                  style: TextStyle(fontSize: 11, color: colour, fontFamily: fMono)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: c.fg)),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: c.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(right,
                    style: TextStyle(
                        fontFamily: fMono,
                        fontSize: 13,
                        color: belowHorizon ? c.down : c.fg,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                Text(sub2,
                    style: TextStyle(
                        fontFamily: fMono, fontSize: 10.5, color: c.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A compass dial and an altitude quadrant: the two numbers that actually get
/// someone pointed at the right patch of sky.
class AimDial extends StatelessWidget {
  final double az, alt;
  final bool up;
  const AimDial({super.key, required this.az, required this.alt, required this.up});

  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              height: 80,
              child: CustomPaint(painter: _DialPainter(az, up ? c.amber : c.down, c))),
          const SizedBox(width: 10),
          SizedBox(
              width: 60,
              height: 80,
              child: CustomPaint(
                  painter: _QuadrantPainter(alt, up ? c.amber : c.down, c))),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double az;
  final Color col;
  final Sky c;
  _DialPainter(this.az, this.col, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    const centre = Offset(40, 40);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = c.line;
    canvas.drawCircle(centre, 34, ring);
    for (final entry in const [('N', 0.0, 10.0), ('S', 180.0, 70.0)]) {
      _text(canvas, entry.$1, Offset(40, entry.$3), c.muted);
    }
    _text(canvas, 'E', const Offset(72, 40), c.muted);
    _text(canvas, 'W', const Offset(8, 40), c.muted);
    final a = (az - 90) * d2r;
    canvas.drawLine(
        centre,
        Offset(40 + 34 * math.cos(a), 40 + 34 * math.sin(a)),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = col);
    canvas.drawCircle(centre, 2.6, Paint()..color = col);
  }

  void _text(Canvas canvas, String t, Offset at, Color colour) {
    final tp = TextPainter(
      text: TextSpan(
          text: t,
          style: TextStyle(fontSize: 9, color: colour, fontFamily: fMono)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.az != az || old.col != col;
}

class _QuadrantPainter extends CustomPainter {
  final double alt;
  final Color col;
  final Sky c;
  _QuadrantPainter(this.alt, this.col, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..strokeWidth = 1
      ..color = c.line;
    canvas.drawLine(const Offset(10, 72), const Offset(46, 72), base);
    final a = clampD(alt, 0, 90);
    canvas.drawLine(
        const Offset(10, 72),
        Offset(10 + 40 * math.cos(a * d2r), 72 - 40 * math.sin(a * d2r)),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = col);
    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(
            text: '${a.round()}°\n',
            style: TextStyle(fontSize: 13, color: col, fontFamily: fMono)),
        TextSpan(
            text: 'มุมเงย',
            style: TextStyle(fontSize: 8.5, color: c.muted, fontFamily: fBody)),
      ]),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(28 - tp.width / 2, 8));
  }

  @override
  bool shouldRepaint(_QuadrantPainter old) => old.alt != alt || old.col != col;
}
