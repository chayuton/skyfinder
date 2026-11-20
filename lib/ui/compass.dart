import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../state/app_state.dart';
import 'theme.dart';

/// The rose is a compass in the plain sense on every tab: the needle points
/// at north as seen from the phone, and the fixed mark at the top stands for
/// the top edge, so the figure underneath is the bearing that edge faces.
/// That makes it something to hold the rest of the app against: the bearings
/// in the lists and sheets, and the sky map.
///
/// It no longer turns with the map. The map is drawn looking UP, and locked
/// to the compass it keeps the way the user faces at its lower edge, the way
/// an all-sky chart held overhead is read; a rose turning with it pointed
/// north back at a user who was facing north. Without a sensor the aim view
/// is steered by hand, and the rose shows that bearing, greyed out.
({double rot, double? label, bool live}) compassReference(AppState s) {
  final h = s.deviceHeading;
  if (s.sensorOn && h != null) return (rot: -h, label: h, live: true);
  if (s.tab == SkyTab.aim) {
    return (rot: -s.aimAz, label: s.aimAz, live: false);
  }
  return (rot: 0.0, label: null, live: false);
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

    final String label;
    final String semantic;
    if (r.label != null) {
      final deg = norm360(r.label!).round() % 360;
      label = '$deg° ${compassShort(r.label!)}';
      semantic = r.live
          ? 'เข็มทิศ ขอบบนของมือถือหันไปทาง${compassTh(r.label!)} $deg องศา '
              'แตะเพื่อ${s.faceLock ? 'เลิกหมุนแผนที่ตามทิศ' : 'หมุนแผนที่ตามทิศที่หัน'}'
          : 'เข็มทิศ ยังไม่ได้เปิดเซ็นเซอร์ จุดเล็งอยู่ทาง${compassTh(r.label!)} '
              '$deg องศา แตะเพื่อเปิดเซ็นเซอร์';
    } else {
      label = s.sensorStarting
          ? '…'
          : s.compassNeedsTap
              ? 'แตะเปิด'
              : '—';
      semantic = s.sensorStarting
          ? 'เข็มทิศ กำลังรอค่าจากเซ็นเซอร์'
          : 'เข็มทิศ ยังไม่รู้ทิศ แตะเพื่อเปิดเซ็นเซอร์';
    }

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
              // The first tap turns the compass on; a browser will only ask
              // for motion access from inside a tap like this one. After
              // that a tap locks the map to it, or lets the map go.
              if (!s.sensorOn) {
                s.startSensors();
                return;
              }
              s.toggle('faceLock');
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

    // The lubber mark: fixed at the top, it stands for the phone's top edge,
    // and the bearing under the rose is the one it faces. Facing north, the
    // north tick sits right under it.
    final mark = Path()
      ..moveTo(20.4 * k, 0.4 * k)
      ..lineTo(25.6 * k, 0.4 * k)
      ..lineTo(23 * k, 4.6 * k)
      ..close();
    canvas.drawPath(
        mark, Paint()..color = (live ? c.fg : c.muted).withOpacity(0.9));

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
