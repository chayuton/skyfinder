import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../engine/sky.dart';
import '../data/stars.dart';
import '../ui/theme.dart';
import 'sky_painter.dart';

class ConMember {
  final Star star;
  final double alt, az;
  final List<double> v;
  double px = 0, py = 0;
  ConMember(this.star, this.alt, this.az, this.v);
}

class ConGeometry {
  final Map<String, ConMember> pos;
  final List<ConMember> members;
  final double altC, azC, maxAlt;
  final ConMember bright;
  const ConGeometry(
      this.pos, this.members, this.altC, this.azC, this.maxAlt, this.bright);
}

/// Project a constellation about its own centre with the zenith up, so the
/// drawing carries the tilt the figure actually has in the sky right now.
/// Stereographic rather than gnomonic: Hydra sprawls over a hundred degrees
/// and would tear a gnomonic projection apart.
ConGeometry? conGeometry(
    ConstellationData con, Scene sc, double lat, double lon) {
  final ids = <String>{};
  for (final seg in con.lines) {
    ids.add(seg[0]);
    ids.add(seg[1]);
  }
  final pos = <String, ConMember>{};
  for (final id in ids) {
    final s = starById[id];
    if (s == null) continue;
    final aa = eqToAltAz(s.ra, s.dec, lat, lon, sc.jd);
    pos[id] = ConMember(s, aa.alt, aa.az, vec3(aa.alt, aa.az));
  }
  final members = pos.values.toList();
  if (members.isEmpty) return null;

  var cx = 0.0, cy = 0.0, cz = 0.0;
  for (final m in members) {
    cx += m.v[0];
    cy += m.v[1];
    cz += m.v[2];
  }
  final n = math.sqrt(cx * cx + cy * cy + cz * cz);
  final fwd = n < 1e-9 ? [1.0, 0.0, 0.0] : [cx / n, cy / n, cz / n];
  final altC = math.asin(clampD(fwd[2], -1, 1)) * r2d;
  final azC = norm360(math.atan2(fwd[1], fwd[0]) * r2d);

  var right = [-fwd[1], fwd[0], 0.0];
  final rn = math.sqrt(right[0] * right[0] + right[1] * right[1]);
  right = rn < 1e-9 ? [1.0, 0.0, 0.0] : [right[0] / rn, right[1] / rn, 0.0];
  final up = [
    fwd[1] * right[2] - fwd[2] * right[1],
    fwd[2] * right[0] - fwd[0] * right[2],
    fwd[0] * right[1] - fwd[1] * right[0],
  ];

  for (final m in members) {
    final k = 2 / (1 + clampD(dot3(m.v, fwd), -0.999, 1));
    m.px = k * dot3(m.v, right);
    m.py = -k * dot3(m.v, up);
  }

  var bright = members.first;
  var maxAlt = members.first.alt;
  for (final m in members) {
    if (m.star.mag < bright.star.mag) bright = m;
    if (m.alt > maxAlt) maxAlt = m.alt;
  }
  return ConGeometry(pos, members, altC, azC, maxAlt, bright);
}

class ConstellationPainter extends CustomPainter {
  final ConstellationData con;
  final ConGeometry geo;
  final Sky c;
  final bool nightMode;
  final bool big;
  ConstellationPainter(this.con, this.geo, this.c, this.nightMode,
      {this.big = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final pad = big ? 30.0 : 16.0;
    var x0 = double.infinity, x1 = -double.infinity;
    var y0 = double.infinity, y1 = -double.infinity;
    for (final m in geo.members) {
      x0 = math.min(x0, m.px);
      x1 = math.max(x1, m.px);
      y0 = math.min(y0, m.py);
      y1 = math.max(y1, m.py);
    }
    final k = math.min((w - pad * 2) / math.max(x1 - x0, 1e-6),
        (h - pad * 2) / math.max(y1 - y0, 1e-6));
    final ox = w / 2 - ((x0 + x1) / 2) * k;
    final oy = h / 2 - ((y0 + y1) / 2) * k;
    Offset at(ConMember m) => Offset(ox + m.px * k, oy + m.py * k);

    // A dashed horizon when the figure straddles it.
    final above = geo.members.where((m) => m.alt > 0);
    final below = geo.members.where((m) => m.alt <= 0);
    if (above.isNotEmpty && below.isNotEmpty) {
      final yh = (above.map(at).map((o) => o.dy).reduce(math.min) +
              below.map(at).map((o) => o.dy).reduce(math.max)) /
          2;
      final p = Paint()
        ..strokeWidth = 1
        ..color = nightMode ? const Color(0xFF5A1A16) : const Color(0xFF2E3F66);
      for (var x = 0.0; x < w; x += 6) {
        canvas.drawLine(Offset(x, yh), Offset(math.min(x + 3, w), yh), p);
      }
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = big ? 1.4 : 1.0
      ..color = nightMode ? const Color(0xFF7A2420) : const Color(0xFF435C93);
    for (final seg in con.lines) {
      final a = geo.pos[seg[0]], b = geo.pos[seg[1]];
      if (a == null || b == null) continue;
      canvas.drawLine(at(a), at(b), linePaint);
    }

    for (final m in geo.members) {
      final o = at(m);
      final r = clampD((big ? 7.5 : 4.4) - m.star.mag * (big ? 1.15 : 0.62),
          big ? 1.8 : 1.1, big ? 7 : 4);
      final col = nightMode ? c.star : Color(m.star.tint);
      if (m.star.mag < 1.8) {
        canvas.drawCircle(
            o,
            r * 3.2,
            Paint()
              ..shader = ui.Gradient.radial(o, r * 3.2, [
                col, col.withOpacity(0.33), col.withOpacity(0),
              ], [
                0.0, 0.32, 1.0
              ]));
      }
      canvas.drawCircle(o, r, Paint()..color = col);
    }

    if (!big) return;

    // Name the brightest few, whatever their magnitude: some figures, like
    // Cancer, have nothing brighter than 3.5 and would end up unlabelled.
    final sorted = geo.members.toList()
      ..sort((a, b) => a.star.mag.compareTo(b.star.mag));
    final taken = <Rect>[];
    var placed = 0;
    for (final m in sorted) {
      if (placed >= 6 || (m.star.mag > 3.2 && placed >= 3)) break;
      final tp = TextPainter(
        text: TextSpan(
            text: m.star.shortTh,
            style: TextStyle(
                fontSize: 11,
                fontFamily: fBody,
                color: nightMode
                    ? const Color(0xFFC85B4A)
                    : const Color(0xFF9FB0D4))),
        textDirection: TextDirection.ltr,
      )..layout();
      final o = at(m);
      final p = Offset(o.dx - tp.width / 2, o.dy + 9);
      if (p.dx < 2 || p.dx + tp.width > w - 2 || p.dy + tp.height > h - 2) {
        continue;
      }
      final box = Rect.fromLTWH(p.dx - 2, p.dy - 2, tp.width + 4, tp.height + 4);
      if (taken.any((t) => t.overlaps(box))) continue;
      taken.add(box);
      placed++;
      tp.paint(canvas, p);
    }

    // Which way is up, so the reader can orient the page against the sky.
    final arrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = nightMode ? const Color(0xFF8A3A30) : const Color(0xFF4A5D85);
    canvas.drawLine(const Offset(16, 30), const Offset(16, 13), arrow);
    canvas.drawLine(const Offset(12, 18), const Offset(16, 13), arrow);
    canvas.drawLine(const Offset(20, 18), const Offset(16, 13), arrow);
    final tp = TextPainter(
      text: TextSpan(
          text: 'สู่กลางฟ้า',
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              fontFamily: fDisplay,
              color: nightMode ? const Color(0xFFB04A3E) : const Color(0xFF8291B0))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(25, 15));
  }

  @override
  bool shouldRepaint(ConstellationPainter old) =>
      old.geo != geo || old.nightMode != nightMode;
}

/// The moon phase on its own, for the tonight panel.
class MoonPainter extends CustomPainter {
  final double illum, limbAngle;
  final bool nightMode;
  MoonPainter(this.illum, this.limbAngle, this.nightMode);

  @override
  void paint(Canvas canvas, Size size) {
    drawPhase(
        canvas,
        Offset(size.width / 2, size.height / 2),
        size.width / 2 - 2,
        illum,
        limbAngle,
        nightMode ? const Color(0xFFFFB4A0) : const Color(0xFFEFF3FF),
        nightMode ? const Color(0xFF2A0C0B) : const Color(0xFF131A2C));
  }

  @override
  bool shouldRepaint(MoonPainter old) =>
      old.illum != illum || old.limbAngle != limbAngle ||
      old.nightMode != nightMode;
}
