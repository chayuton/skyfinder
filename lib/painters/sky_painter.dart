import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../engine/sky.dart';
import '../data/stars.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';

/// Shared helpers -----------------------------------------------------------

List<double> vec3(double alt, double az) => [
      math.cos(alt * d2r) * math.cos(az * d2r),
      math.cos(alt * d2r) * math.sin(az * d2r),
      math.sin(alt * d2r),
    ];

double dot3(List<double> a, List<double> b) =>
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

/// With the map locked to the compass, the direction the observer faces sits at
/// the bottom of the dome, so the top of the dome is that heading plus 180.
double mapRotation(AppState s) =>
    (s.faceLock && s.heading != null) ? s.heading! - 180 : 0;

/// The dome is drawn looking UP: the zenith is the centre, the horizon the rim,
/// and east falls on the LEFT, the way an all-sky chart held overhead reads.
Offset domeProject(
    double alt, double az, double radius, Offset c, double rot) {
  final r = radius * (90 - alt) / 90;
  final a = (az - rot) * d2r;
  return Offset(c.dx - r * math.sin(a), c.dy - r * math.cos(a));
}

({double alt, double az}) domeUnproject(
    Offset p, double radius, Offset c, double rot) {
  final dx = c.dx - p.dx, dy = c.dy - p.dy;
  final r = math.sqrt(dx * dx + dy * dy);
  return (
    alt: 90 - (r / radius) * 90,
    az: norm360(math.atan2(dx, dy) * r2d + rot)
  );
}

void drawPhase(Canvas canvas, Offset c, double r, double k, double limbAngle,
    Color lit, Color dark) {
  k = clampD(k, 0, 1);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(limbAngle - math.pi / 2);
  final rect = Rect.fromCircle(center: Offset.zero, radius: r);
  canvas.drawCircle(Offset.zero, r, Paint()..color = dark);
  canvas.drawArc(rect, -math.pi / 2, math.pi, true, Paint()..color = lit);
  final a = r * (1 - 2 * k).abs();
  canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 2 * math.max(a, 0.01),
          height: 2 * r),
      Paint()..color = k < 0.5 ? dark : lit);
  canvas.restore();
}

TextPainter _label(String text, Color color, double size,
    {FontWeight weight = FontWeight.w600, String family = fBody}) {
  final tp = TextPainter(
    text: TextSpan(
        text: text,
        style: TextStyle(
            color: color, fontSize: size, fontWeight: weight, fontFamily: family)),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp;
}

/// All-sky dome ------------------------------------------------------------

class SkyDomePainter extends CustomPainter {
  final Scene sc;
  final AppState s;
  final Sky c;

  /// AppState is mutated in place, so the old painter and the new one hold the
  /// same object and comparing their fields always says "unchanged". The state
  /// that matters is flattened into a string at construction time instead;
  /// without it, tapping a layer toggle does nothing until the clock ticks.
  final String sig;

  SkyDomePainter(this.sc, this.s, this.c)
      : sig = '${sc.jd}|${s.lat}|${s.lon}|${s.height}|${s.magLim}|${s.lines}'
            '|${s.names}|${s.milky}|${s.ecliptic}|${s.faceLock}|${s.heading}'
            '|${s.selected?.kind}${s.selected?.id}|${s.nightMode}';

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final centre = Offset(w / 2, w / 2);
    final radius = w / 2 - 22;
    final rot = mapRotation(s);
    final dk = darkness(sc.sunAlt);

    // Ground colour tracks how far the Sun has sunk.
    final List<Color> grad = s.nightMode
        ? [const Color(0xFF240708), const Color(0xFF140304)]
        : dk > 0.75
            ? [const Color(0xFF0B1226), const Color(0xFF060A16)]
            : dk > 0.35
                ? [const Color(0xFF152340), const Color(0xFF0C1430)]
                : dk > 0.08
                    ? [const Color(0xFF2A2F55), const Color(0xFF1A1E3E)]
                    : [const Color(0xFF2E4F82), const Color(0xFF1D355C)];
    canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(centre, radius, grad, [0.0, 1.0]));

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: radius)));

    if (s.milky && dk > 0.3) {
      final p = Paint()..blendMode = BlendMode.plus;
      for (final m in milkyWay) {
        final aa = eqToAltAz(m.ra, m.dec, s.lat, s.lon, sc.jd);
        if (aa.alt < 0) continue;
        final o = domeProject(aa.alt, aa.az, radius, centre, rot);
        final a = m.w * 0.058 * dk * clampD(aa.alt / 20, 0.25, 1);
        p.color = c.milky.withOpacity(a.clamp(0.0, 1.0));
        canvas.drawCircle(o, radius * 0.115, p);
      }
    }

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = s.nightMode ? const Color(0xFF4A1414) : const Color(0xFF22304E);
    for (final a in [30.0, 60.0]) {
      canvas.drawCircle(centre, radius * (90 - a) / 90, grid);
    }
    for (var az = 0.0; az < 360; az += 45) {
      final o = domeProject(0, az, radius, centre, rot);
      _dashLine(canvas, centre, o, grid, 2, 5);
    }

    if (s.ecliptic) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = s.nightMode
            ? const Color(0xFF7A2A22)
            : const Color(0x88C9A24B);
      Offset? prev;
      for (var l = 0.0; l <= 360; l += 2) {
        final e = eclToEq(l, 0, obliquity(sc.jd));
        final aa = eqToAltAz(e.ra, e.dec, s.lat, s.lon, sc.jd);
        if (aa.alt < 0) {
          prev = null;
          continue;
        }
        final o = domeProject(aa.alt, aa.az, radius, centre, rot);
        if (prev != null) _dashLine(canvas, prev, o, p, 5, 4);
        prev = o;
      }
    }

    final pos = {for (final sv in sc.stars) sv.ref.id: sv};

    if (s.lines && dk > 0.12) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = s.nightMode ? const Color(0xFF5E1A16) : const Color(0xFF3C5186);
      for (final con in constellationData) {
        for (final seg in con.lines) {
          final a = pos[seg[0]], b = pos[seg[1]];
          if (a == null || b == null || a.alt < 0 || b.alt < 0) continue;
          final pa = domeProject(a.alt, a.az, radius, centre, rot);
          final pb = domeProject(b.alt, b.az, radius, centre, rot);
          if ((pa - pb).distance > radius * 1.15) continue;
          canvas.drawLine(pa, pb, p);
        }
      }
    }

    final labels = <({Offset at, String text, bool body, double r})>[];

    for (final sv in sc.stars) {
      if (sv.alt < 0 || sv.ref.mag > s.magLim) continue;
      final vis = clampD((dk - 0.05) * 1.6, 0, 1) *
          clampD(0.35 + sv.alt / 22, 0, 1);
      if (vis <= 0.02) continue;
      final o = domeProject(sv.alt, sv.az, radius, centre, rot);
      final rad =
          clampD((s.magLim + 0.9 - sv.ref.mag) * 0.30 * (radius / 160), 0.55, 5.2);
      final col = s.nightMode ? c.star : Color(sv.ref.tint);
      if (sv.ref.mag < 1.6) {
        canvas.drawCircle(
            o,
            rad * 3.6,
            Paint()
              ..shader = ui.Gradient.radial(o, rad * 3.6, [
                col.withOpacity(vis),
                col.withOpacity(vis * 0.4),
                col.withOpacity(0),
              ], [
                0.0, 0.3, 1.0
              ]));
      }
      canvas.drawCircle(o, rad, Paint()..color = col.withOpacity(vis));
      if (s.names && sv.ref.mag < 1.75 && sv.alt > 7) {
        labels.add((at: o, text: sv.ref.shortTh, body: false, r: rad));
      }
    }

    if (dk > 0.4) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = (s.nightMode ? const Color(0xFF9A3A30) : const Color(0xFF8FD4C8))
            .withOpacity(0.65);
      for (final d in sc.dsos) {
        if (d.alt < 2 || d.ref.mag > s.magLim + 1.2) continue;
        final o = domeProject(d.alt, d.az, radius, centre, rot);
        canvas.drawOval(
            Rect.fromCenter(center: o, width: 8.4, height: 6.4), p);
      }
    }

    for (var i = 0; i < sc.bodies.length; i++) {
      final b = sc.bodies[i];
      if (b.alt < -1.5) continue;
      final meta = bodies[i];
      final o = domeProject(b.alt, b.az, radius, centre, rot);
      if (b.id == 'sun') {
        final glow = s.nightMode ? const Color(0xFFFF6A4A) : const Color(0xFFFFE9A8);
        canvas.drawCircle(
            o,
            22,
            Paint()
              ..shader = ui.Gradient.radial(o, 22, [
                glow,
                c.amber.withOpacity(0.53),
                glow.withOpacity(0),
              ], [
                0.0, 0.25, 1.0
              ]));
        canvas.drawCircle(o, 6.5,
            Paint()..color = s.nightMode ? const Color(0xFFFF7A58) : const Color(0xFFFFE07A));
      } else if (b.id == 'moon') {
        final ps = domeProject(sc.sun.alt, sc.sun.az, radius, centre, rot);
        final limb = math.atan2(ps.dx - o.dx, -(ps.dy - o.dy));
        drawPhase(canvas, o, 7, b.illum ?? 0.5, limb,
            s.nightMode ? const Color(0xFFFFB4A0) : const Color(0xFFF2F6FF),
            s.nightMode ? const Color(0xFF3A1210) : const Color(0xFF1A2238));
      } else {
        final rad = 2.1 + (meta.size - 0.9) * 1.9 + clampD((1.5 - b.mag) * 0.35, 0, 1.6);
        final col = s.nightMode ? const Color(0xFFFF8A6B) : Color(meta.color);
        if (b.mag < 1.5) {
          canvas.drawCircle(
              o,
              rad * 4,
              Paint()
                ..shader = ui.Gradient.radial(o, rad * 4, [
                  col, col.withOpacity(0.33), col.withOpacity(0),
                ], [
                  0.0, 0.3, 1.0
                ]));
        }
        canvas.drawCircle(o, rad, Paint()..color = col);
      }
      if (s.names && b.alt > 1) {
        labels.add((at: o, text: meta.th, body: true, r: 8));
      }
    }

    final sel = s.selected;
    if (sel != null) {
      final f = findInScene(sel, sc, s);
      if (f != null && f.alt > -1) {
        final o = domeProject(f.alt, f.az, radius, centre, rot);
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = c.amber;
        canvas.drawCircle(o, 13, p);
        canvas.drawLine(o + const Offset(-18, 0), o + const Offset(-13, 0), p);
        canvas.drawLine(o + const Offset(13, 0), o + const Offset(18, 0), p);
        canvas.drawLine(o + const Offset(0, -18), o + const Offset(0, -13), p);
        canvas.drawLine(o + const Offset(0, 13), o + const Offset(0, 18), p);
      }
    }

    // Labels last, dropping any that would collide with one already placed.
    final taken = <Rect>[];
    for (final l in labels) {
      final tp = _label(l.text,
          l.body ? c.amber : (s.nightMode ? const Color(0xFFC85B4A) : const Color(0xFFA9B7D6)),
          10.5);
      final at = Offset(l.at.dx - tp.width / 2, l.at.dy + l.r + 2);
      final box = Rect.fromLTWH(at.dx - 2, at.dy - 2, tp.width + 4, tp.height + 4);
      if (taken.any((t) => t.overlaps(box))) continue;
      taken.add(box);
      tp.paint(canvas, at);
    }
    canvas.restore();

    canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = s.nightMode ? const Color(0xFF6A1E1A) : const Color(0xFF2E3F66));

    for (final entry in const [('N', 0.0), ('E', 90.0), ('S', 180.0), ('W', 270.0)]) {
      final a = (entry.$2 - rot) * d2r;
      final rr = radius + 12;
      final at = Offset(centre.dx - rr * math.sin(a), centre.dy - rr * math.cos(a));
      final tp = _label(
          entry.$1,
          entry.$1 == 'N'
              ? c.amber
              : (s.nightMode ? const Color(0xFFA8392E) : const Color(0xFF7F8EB0)),
          12,
          weight: FontWeight.w700,
          family: fDisplay);
      tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
    }
  }

  void _dashLine(Canvas canvas, Offset a, Offset b, Paint p, double on, double off) {
    final total = (b - a).distance;
    if (total < 0.5) return;
    final dir = (b - a) / total;
    var t = 0.0;
    while (t < total) {
      final e = math.min(t + on, total);
      canvas.drawLine(a + dir * t, a + dir * e, p);
      t = e + off;
    }
  }

  @override
  bool shouldRepaint(SkyDomePainter old) => old.sig != sig;
}

/// Resolve a selection against the current scene.
({double alt, double az, Star? star, Dso? dso, BodyPosition? body})?
    findInScene(Selection sel, Scene sc, AppState s) {
  if (sel.kind == 'body') {
    for (final b in sc.bodies) {
      if (b.id == sel.id) {
        return (alt: b.alt, az: b.az, star: null, dso: null, body: b);
      }
    }
    return null;
  }
  if (sel.kind == 'star') {
    for (final sv in sc.stars) {
      if (sv.ref.id == sel.id) {
        return (alt: sv.alt, az: sv.az, star: sv.ref, dso: null, body: null);
      }
    }
    final r = starById[sel.id];
    if (r == null) return null;
    final aa = eqToAltAz(r.ra, r.dec, s.lat, s.lon, sc.jd);
    return (alt: aa.alt, az: aa.az, star: r, dso: null, body: null);
  }
  for (final d in sc.dsos) {
    if (d.ref.id == sel.id) {
      return (alt: d.alt, az: d.az, star: null, dso: d.ref, body: null);
    }
  }
  return null;
}
