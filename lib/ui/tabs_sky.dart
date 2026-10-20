import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../engine/sky.dart';
import '../painters/sky_painter.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

class SkyTabView extends StatelessWidget {
  final AppState s;
  final Scene sc;
  final void Function(Selection) onPick;
  const SkyTabView(
      {super.key, required this.s, required this.sc, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 2, 16, 96 + MediaQuery.of(context).padding.bottom),
      children: [
        LayoutBuilder(
          builder: (_, box) {
            final w = box.maxWidth;
            return GestureDetector(
              onTapUp: (d) => _tap(d.localPosition, w),
              child: SizedBox(
                width: w,
                height: w,
                child: CustomPaint(painter: SkyDomePainter(sc, s, c)),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Tog('เส้นกลุ่มดาว', s.lines, () => s.toggle('lines')),
            Tog('ชื่อดาว', s.names, () => s.toggle('names')),
            Tog('ทางช้างเผือก', s.milky, () => s.toggle('milky')),
            Tog('เส้นสุริยวิถี', s.ecliptic, () => s.toggle('ecliptic')),
            Tog('หมุนตามเข็มทิศ', s.faceLock, () => s.toggle('faceLock'), hot: true),
          ],
        ),
        SkyCard(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(fmtDate(s.now)),
                        Text(fmtClock(s.now),
                            style: TextStyle(
                                fontFamily: fMono, fontSize: 17, color: c.fg)),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 5,
                    children: [
                      _step(context, '−1ชม', () => s.nudgeOffset(-60)),
                      _step(context, '−10น', () => s.nudgeOffset(-10)),
                      _step(context, 'ตอนนี้', () => s.setOffset(0)),
                      _step(context, '+10น', () => s.nudgeOffset(10)),
                      _step(context, '+1ชม', () => s.nudgeOffset(60)),
                    ],
                  ),
                ],
              ),
              Slider(
                value: s.offsetMinutes.toDouble(),
                min: -720,
                max: 720,
                divisions: 288,
                onChanged: (v) => s.setOffset(v.round()),
              ),
            ],
          ),
        ),
        SkyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('เด่นบนฟ้าตอนนี้',
                  style: Theme.of(context).textTheme.titleMedium),
              ..._highlights(context),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          child: Text(
            'ดวงอาทิตย์อยู่ที่ ${sc.sunAlt.toStringAsFixed(1)}° '
            '${sc.sunAlt > 0 ? 'เหนือ' : 'ใต้'}ขอบฟ้า · '
            '${darknessLabel(sc.sunAlt)} · แตะที่ดาวบนแผนที่เพื่อดูรายละเอียด',
            style: TextStyle(fontSize: 11.5, height: 1.6, color: c.dim),
          ),
        ),
      ],
    );
  }

  Widget _step(BuildContext context, String label, VoidCallback onTap) {
    final c = SkyColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11.5, fontFamily: fMono, color: c.muted)),
      ),
    );
  }

  void _tap(Offset p, double w) {
    final radius = w / 2 - 22;
    final u = domeUnproject(p, radius, Offset(w / 2, w / 2), mapRotation(s));
    if (u.alt < -3) return;
    Selection? best;
    var bd = 7.0;
    for (final b in sc.bodies) {
      if (b.alt < -1) continue;
      final d = angSep(u.alt, u.az, b.alt, b.az);
      if (d < bd) {
        bd = d;
        best = Selection('body', b.id);
      }
    }
    for (final sv in sc.stars) {
      if (sv.alt < 0 || sv.ref.mag > s.magLim) continue;
      final d = angSep(u.alt, u.az, sv.alt, sv.az) + sv.ref.mag * 0.25;
      if (d < bd) {
        bd = d;
        best = Selection('star', sv.ref.id);
      }
    }
    for (final o in sc.dsos) {
      if (o.alt < 0) continue;
      final d = angSep(u.alt, u.az, o.alt, o.az);
      if (d < bd) {
        bd = d;
        best = Selection('dso', o.ref.id);
      }
    }
    if (best != null) onPick(best);
  }

  List<Widget> _highlights(BuildContext context) {
    final c = SkyColors.of(context);
    final rows = <Widget>[];
    final ranked = <({BodyPosition b, Body meta, double score})>[];
    for (var i = 0; i < sc.bodies.length; i++) {
      final b = sc.bodies[i];
      final meta = bodies[i];
      if (b.id == 'sun') {
        if (b.alt > -1) ranked.add((b: b, meta: meta, score: 100));
        continue;
      }
      if (b.alt < 0) continue;
      if (b.id == 'moon') {
        ranked.add((b: b, meta: meta, score: 99));
        continue;
      }
      if (b.mag > 6) continue;
      ranked.add((b: b, meta: meta, score: 50 - b.mag));
    }
    ranked.sort((a, b) => b.score.compareTo(a.score));
    for (final r in ranked) {
      final extra = r.b.id == 'moon'
          ? 'สว่าง ${((r.b.illum ?? 0) * 100).round()}% · ${moonPhaseName(r.b)}'
          : r.b.id == 'sun'
              ? 'กลางวัน'
              : 'โชติมาตร ${r.b.mag.toStringAsFixed(1)}';
      rows.add(ObjectRow(
        name: r.meta.th,
        sub: extra,
        badge: r.b.id == 'moon' ? '☾' : '●',
        right: '${r.b.altApp.round()}°',
        sub2: '${compassShort(r.b.az)} ${r.b.az.round()}°',
        colour: s.nightMode ? const Color(0xFFFF8A6B) : Color(r.meta.color),
        onTap: () => onPick(Selection('body', r.b.id)),
      ));
    }
    final bright = sc.stars.where((x) => x.alt > 8 && x.ref.mag < 1.6).toList()
      ..sort((a, b) => a.ref.mag.compareTo(b.ref.mag));
    for (final sv in bright.take(5)) {
      final con = conById[sv.ref.con];
      rows.add(ObjectRow(
        name: sv.ref.shortTh,
        sub: '${con != null ? 'กลุ่มดาว${con.th} · ' : ''}'
            'โชติมาตร ${sv.ref.mag.toStringAsFixed(1)}',
        badge: '✦',
        right: '${refract(sv.alt).round()}°',
        sub2: '${compassShort(sv.az)} ${sv.az.round()}°',
        colour: s.nightMode ? c.star : Color(sv.ref.tint),
        onTap: () => onPick(Selection('star', sv.ref.id)),
      ));
    }
    if (rows.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text('ยังไม่มีวัตถุสว่างเหนือขอบฟ้าในเวลานี้',
              style: TextStyle(fontSize: 12.5, color: c.muted)),
        )
      ];
    }
    return rows;
  }
}
