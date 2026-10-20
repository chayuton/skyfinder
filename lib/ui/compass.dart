import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../state/app_state.dart';
import '../painters/sky_painter.dart';
import 'theme.dart';

/// Two pictures, two signs. The all-sky dome is drawn looking UP, so east
/// falls on the left and the rose turns WITH the map; the aim view and a plain
/// device compass look OUT, so the rose turns AGAINST the heading. Getting
/// this backwards mirrors the needle, which is worse than showing no compass.
({double rot, double? label, bool live}) compassReference(AppState s) {
  switch (s.tab) {
    case SkyTab.aim:
      return (rot: -s.aimAz, label: s.aimAz, live: s.sensorOn);
    case SkyTab.sky:
      final facing = s.faceLock && s.heading != null;
      return (
        rot: mapRotation(s),
        label: facing ? s.heading! : 0.0,
        live: facing
      );
    default:
      final dh = s.deviceHeading;
      if (dh != null) return (rot: -dh, label: dh, live: true);
      return (rot: 0.0, label: null, live: false);
  }
}

/// A 42px rose pinned above the tab bar. It fades while a list scrolls under
/// it so the figures it covers stay readable.
class SkyCompass extends StatefulWidget {
  final AppState state;
  final bool scrolling;
  const SkyCompass({super.key, required this.state, required this.scrolling});

  @override
  State<SkyCompass> createState() => _SkyCompassState();
}

class _SkyCompassState extends State<SkyCompass> {
  double _shown = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final c = SkyColors.of(context);
    final r = compassReference(s);
    // Unwrap so the needle never spins the long way round 360.
    _shown += norm180(r.rot - _shown);

    final label = r.label == null
        ? '—'
        : '${norm360(r.label!).round()}° ${compassShort(r.label!)}';
    final semantic = r.label == null
        ? 'เข็มทิศ ยังไม่รู้ทิศ แตะเพื่อเปิดเซ็นเซอร์'
        : 'เข็มทิศ หันไปทาง${compassTh(r.label!)} '
            '${norm360(r.label!).round()} องศา '
            'แตะเพื่อ${s.faceLock ? 'เลิกหมุนแผนที่ตามทิศ' : 'หมุนแผนที่ตามทิศที่หัน'}';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: widget.scrolling ? 0.22 : 1,
      child: IgnorePointer(
        ignoring: widget.scrolling,
        child: Semantics(
          button: true,
          label: semantic,
          child: GestureDetector(
            onTap: () {
              s.toggle('faceLock');
              if (s.faceLock && s.heading == null) s.startSensors();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: CustomPaint(
                    painter: _RosePainter(_shown, c, s.faceLock, r.live),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: c.panel.withOpacity(0.85),
                    border: Border.all(
                        color: s.faceLock
                            ? c.amber.withOpacity(0.4)
                            : c.line),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontFamily: fMono,
                          fontSize: 8.5,
                          color: s.faceLock ? c.amber : c.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RosePainter extends CustomPainter {
  final double angle;
  final Sky c;
  final bool pressed, live;
  _RosePainter(this.angle, this.c, this.pressed, this.live);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 46;
    final centre = Offset(23 * k, 23 * k);
    canvas.drawCircle(centre, 21 * k, Paint()..color = c.panel.withOpacity(0.9));
    canvas.drawCircle(
        centre,
        21 * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = pressed ? c.amber : c.line);

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(angle * d2r);
    canvas.translate(-centre.dx, -centre.dy);

    final tick = Paint()
      ..strokeWidth = 1
      ..color = c.muted.withOpacity(0.55);
    final tickN = Paint()
      ..strokeWidth = 1.4
      ..color = c.amber.withOpacity(0.9);
    canvas.drawLine(Offset(23 * k, 3.5 * k), Offset(23 * k, 8.5 * k), tickN);
    canvas.drawLine(Offset(42.5 * k, 23 * k), Offset(38.5 * k, 23 * k), tick);
    canvas.drawLine(Offset(23 * k, 42.5 * k), Offset(23 * k, 38.5 * k), tick);
    canvas.drawLine(Offset(3.5 * k, 23 * k), Offset(7.5 * k, 23 * k), tick);

    final north = Path()
      ..moveTo(23 * k, 8.5 * k)
      ..lineTo(26.6 * k, 24 * k)
      ..lineTo(23 * k, 21.6 * k)
      ..lineTo(19.4 * k, 24 * k)
      ..close();
    canvas.drawPath(north, Paint()..color = live ? c.amber : c.down);
    final south = Path()
      ..moveTo(23 * k, 37.5 * k)
      ..lineTo(19.4 * k, 22 * k)
      ..lineTo(23 * k, 24.4 * k)
      ..lineTo(26.6 * k, 22 * k)
      ..close();
    canvas.drawPath(south, Paint()..color = c.down);
    canvas.restore();

    canvas.drawCircle(centre, 2.4 * k, Paint()..color = c.panel2);
    canvas.drawCircle(
        centre,
        2.4 * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = c.line);
  }

  @override
  bool shouldRepaint(_RosePainter old) =>
      old.angle != angle || old.pressed != pressed || old.live != live ||
      old.c != c;
}
