import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../engine/sky.dart';
import '../data/stars.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import 'sky_painter.dart';

class NearHit {
  final String name, sub;
  final double mag, sep;
  final Selection sel;
  const NearHit(this.name, this.sub, this.mag, this.sep, this.sel);
}

/// The aim view looks OUT rather than up, so azimuth increases to the right —
/// the opposite of the dome. Everything downstream (the compass especially)
/// depends on keeping those two straight.
class AimPainter extends CustomPainter {
  final Scene sc;
  final AppState s;
  final Sky c;
  final void Function(NearHit?) onHit;
  AimPainter(this.sc, this.s, this.c, this.onHit);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final centre = Offset(w / 2, h / 2);
    const fovY = 58.0;
    final f = (h / 2) / math.tan(fovY / 2 * d2r);
    final a0 = s.aimAlt, z0 = s.aimAz;

    final fwd = vec3(a0, z0);
    var right = [-fwd[1], fwd[0], 0.0];
    final rn = math.sqrt(right[0] * right[0] + right[1] * right[1]);
    right = rn < 1e-9 ? [1.0, 0.0, 0.0] : [right[0] / rn, right[1] / rn, 0.0];
    final up = [
      fwd[1] * right[2] - fwd[2] * right[1],
      fwd[2] * right[0] - fwd[0] * right[2],
      fwd[0] * right[1] - fwd[1] * right[0],
    ];

    Offset? put(double alt, double az) {
      final v = vec3(alt, az);
      final z = dot3(v, fwd);
      if (z < 0.15) return null;
      return Offset(centre.dx + f * dot3(v, right) / z,
          centre.dy - f * dot3(v, up) / z);
    }

    final dk = darkness(sc.sunAlt);
    final grad = s.nightMode
        ? [const Color(0xFF1B0506), const Color(0xFF2A0809)]
        : dk > 0.6
            ? [const Color(0xFF070C1A), const Color(0xFF101936)]
            : [const Color(0xFF1C2A4D), const Color(0xFF2E4068)];
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.linear(
              const Offset(0, 0), Offset(0, h), grad, const [0.0, 1.0]));

    // Ground below the horizon, then the horizon itself.
    final hp = <Offset>[];
    for (var az = z0 - 95; az <= z0 + 95; az += 3) {
      final p = put(0, norm360(az));
      if (p != null) hp.add(p);
    }
    if (hp.length > 1) {
      final path = Path()..moveTo(hp.first.dx, h);
      for (final p in hp) {
        path.lineTo(p.dx, p.dy);
      }
      path.lineTo(hp.last.dx, h);
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..color = s.nightMode ? const Color(0xFF120304) : const Color(0xFF050811));
      final line = Path()..moveTo(hp.first.dx, hp.first.dy);
      for (final p in hp) {
        line.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
          line,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = s.nightMode ? const Color(0xFF6A1E1A) : const Color(0xFF3A5080));
    }

    if (s.lines) {
      final pos = {for (final sv in sc.stars) sv.ref.id: sv};
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = s.nightMode ? const Color(0xFF5E1A16) : const Color(0xFF3C5186);
      for (final con in constellationData) {
        for (final seg in con.lines) {
          final a = pos[seg[0]], b = pos[seg[1]];
          if (a == null || b == null) continue;
          final pa = put(a.alt, a.az), pb = put(b.alt, b.az);
          if (pa == null || pb == null) continue;
          canvas.drawLine(pa, pb, p);
        }
      }
    }

    final near = <NearHit>[];

    for (final sv in sc.stars) {
      if (sv.ref.mag > s.magLim) continue;
      final o = put(sv.alt, sv.az);
      if (o == null) continue;
      final rad = clampD((s.magLim + 1.2 - sv.ref.mag) * 0.95, 0.9, 7);
      canvas.drawCircle(o, rad,
          Paint()..color = s.nightMode ? c.star : Color(sv.ref.tint));
      near.add(NearHit(sv.ref.th, '${sv.ref.en} · ${sv.ref.bayer}',
          sv.ref.mag, angSep(a0, z0, sv.alt, sv.az),
          Selection('star', sv.ref.id)));
      if (sv.ref.mag < 2.2 &&
          o.dx > 44 && o.dx < w - 44 && o.dy < h - 86) {
        final tp = TextPainter(
          text: TextSpan(
              text: sv.ref.shortTh,
              style: TextStyle(
                  fontSize: 11,
                  fontFamily: fBody,
                  color: s.nightMode
                      ? const Color(0xFFC05A49)
                      : const Color(0xFF9FB0D4))),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(o.dx - tp.width / 2, o.dy + rad + 6));
      }
    }

    for (var i = 0; i < sc.bodies.length; i++) {
      final b = sc.bodies[i];
      final meta = bodies[i];
      final o = put(b.alt, b.az);
      if (o == null) continue;
      if (b.id == 'moon') {
        final ps = put(sc.sun.alt, sc.sun.az);
        final ang = ps != null
            ? math.atan2(ps.dx - o.dx, -(ps.dy - o.dy))
            : 0.0;
        drawPhase(canvas, o, 14, b.illum ?? 0.5, ang,
            s.nightMode ? const Color(0xFFFFB4A0) : const Color(0xFFF2F6FF),
            s.nightMode ? const Color(0xFF3A1210) : const Color(0xFF1A2238));
      } else {
        final rad = b.id == 'sun' ? 14.0 : clampD(5 - b.mag * 0.8, 3, 9);
        final col = s.nightMode ? const Color(0xFFFF8A6B) : Color(meta.color);
        canvas.drawCircle(
            o,
            rad * 3,
            Paint()
              ..shader = ui.Gradient.radial(o, rad * 3, [
                col, col.withOpacity(0.33), col.withOpacity(0),
              ], [
                0.0, 0.3, 1.0
              ]));
        canvas.drawCircle(o, rad, Paint()..color = col);
      }
      if (o.dx > 44 && o.dx < w - 44 && o.dy < h - 90) {
        final tp = TextPainter(
          text: TextSpan(
              text: meta.th,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  fontFamily: fBody, color: c.amber)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(o.dx - tp.width / 2, o.dy + 18));
      }
      near.add(NearHit(meta.th, meta.en, b.mag,
          angSep(a0, z0, b.alt, b.az), Selection('body', b.id)));
    }

    for (final d in sc.dsos) {
      final o = put(d.alt, d.az);
      if (o == null) continue;
      canvas.drawOval(
          Rect.fromCenter(center: o, width: 16, height: 12),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = s.nightMode ? const Color(0xFF9A3A30) : const Color(0xFF8FD4C8));
      near.add(NearHit(d.ref.th, d.ref.type, d.ref.mag,
          angSep(a0, z0, d.alt, d.az), Selection('dso', d.ref.id)));
    }

    // Reticle.
    final ret = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = c.amber.withOpacity(0.9);
    canvas.drawCircle(centre, 26, ret);
    for (final d in const [
      Offset(-38, 0), Offset(38, 0), Offset(0, -38), Offset(0, 38)
    ]) {
      final inner = d / d.distance * 26;
      canvas.drawLine(centre + inner, centre + d, ret);
    }

    // Arrow toward the chosen target when it is off screen.
    final tgt = s.target;
    if (tgt != null) {
      final o = findInScene(tgt, sc, s);
      if (o != null) {
        final sep = angSep(a0, z0, o.alt, o.az);
        final p = put(o.alt, o.az);
        final offScreen = p == null ||
            p.dx < 20 || p.dx > w - 20 || p.dy < 20 || p.dy > h - 20;
        if (sep > 4 && offScreen) {
          final dRight = norm180(o.az - z0) * math.cos(a0 * d2r);
          final dUp = o.alt - a0;
          canvas.save();
          canvas.translate(centre.dx, centre.dy);
          canvas.rotate(math.atan2(dRight, dUp));
          final path = Path()
            ..moveTo(0, -78)
            ..lineTo(13, -52)
            ..lineTo(0, -60)
            ..lineTo(-13, -52)
            ..close();
          canvas.drawPath(path, Paint()..color = c.amber);
          canvas.restore();
        } else if (p != null) {
          canvas.drawCircle(
              p,
              20,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = c.amber);
        }
      }
    }

    near.sort((a, b) => a.sep.compareTo(b.sep));
    NearHit? hit;
    for (final n in near) {
      if (n.sep < 9) {
        hit = n;
        break;
      }
    }
    hit ??= near.isNotEmpty ? near.first : null;
    onHit(hit != null && hit.sep < 14 ? hit : null);
  }

  @override
  bool shouldRepaint(AimPainter old) =>
      old.sc.jd != sc.jd ||
      old.s.aimAlt != s.aimAlt ||
      old.s.aimAz != s.aimAz ||
      old.s.magLim != s.magLim ||
      old.s.lines != s.lines ||
      old.s.target != s.target ||
      old.s.nightMode != s.nightMode;
}
