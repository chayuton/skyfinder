import 'package:flutter/material.dart';

import '../data/stars.dart';
import '../engine/engine.dart';
import '../engine/sky.dart';
import '../painters/constellation_painter.dart';
import '../state/app_state.dart';
import 'theme.dart';

const _filters = [
  ('now', 'เหนือขอบฟ้าตอนนี้'),
  ('night', 'คืนนี้'),
  ('all', 'ทั้งหมด 40 กลุ่ม'),
];

class ConRow {
  final ConstellationData con;
  final ConGeometry geo;
  final RiseSet times;
  final bool upTonight;
  const ConRow(this.con, this.geo, this.times, this.upTonight);
}

class ConTabView extends StatelessWidget {
  final AppState s;
  final Scene sc;
  final void Function(String conId) onOpen;
  const ConTabView(
      {super.key, required this.s, required this.sc, required this.onOpen});

  List<ConRow> _rows() {
    return memo(
        'conrows|${minuteKey(sc.jd)}|${s.lat.toStringAsFixed(3)}'
        '|${s.lon.toStringAsFixed(3)}|${s.height}',
        _computeRows);
  }

  List<ConRow> _computeRows() {
    final a = s.alm;
    final out = <ConRow>[];
    for (final con in constellationData) {
      final geo = conGeometry(con, sc, s.lat, s.lon);
      if (geo == null) continue;
      final rd = altAzToEq(geo.altC, geo.azC, s.lat, s.lon, sc.jd);
      final t = starRiseSet(rd.ra, rd.dec, a.jd0, s.lat, s.lon, s.height);
      var up = geo.maxAlt > 10;
      final dusk = a.ev.astro.dusk, dawn = a.evN.astro.dawn;
      if (!up && dusk != null && dawn != null) {
        for (var jd = dusk; jd <= dawn; jd += 1 / 24) {
          if (eqToAltAz(rd.ra, rd.dec, s.lat, s.lon, jd).alt > 15) {
            up = true;
            break;
          }
        }
      }
      out.add(ConRow(con, geo, t, up));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    final compact = compactPhone(context);
    final rows = _rows();
    var list = rows;
    if (s.conFilter == 'now') {
      list = rows.where((r) => r.geo.maxAlt > 8).toList();
    } else if (s.conFilter == 'night') {
      list = rows.where((r) => r.upTonight).toList();
    }
    list.sort((x, y) => y.geo.altC.compareTo(x.geo.altC));
    final dk = darkness(sc.sunAlt);

    return ListView(
      padding: EdgeInsets.fromLTRB(
          compact ? 12 : 16, 2, compact ? 12 : 16, 96 + MediaQuery.of(context).padding.bottom),
      children: [
        SkyCard(
          padding: EdgeInsets.fromLTRB(compact ? 11 : 14, compact ? 10 : 13, compact ? 11 : 14, compact ? 10 : 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ผังกลุ่มดาว', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(
                  'แต่ละผังวาดตามมุมที่กลุ่มดาวนั้นเอียงอยู่จริงบนฟ้าขณะนี้ '
                  'ไม่ใช่รูปตั้งตรงแบบในตำรา หันหน้าไปตามทิศที่บอกแล้วเทียบกับตัวเลข',
                  style: TextStyle(
                      fontSize: compact ? 12 : 12.5,
                      height: 1.5,
                      color: c.muted)),
            ],
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _filters) ...[
                Tog(f.$2, s.conFilter == f.$1, () => s.setConFilter(f.$1)),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
            child: Text(
                'ไม่มีกลุ่มดาวในเงื่อนไขนี้ ลองเปลี่ยนเป็น “คืนนี้” หรือ “ทั้งหมด”',
                style: TextStyle(fontSize: 12.5, color: c.muted)),
          ),
        for (final r in list) _card(context, r, dk),
        Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          child: Text('แตะที่การ์ดเพื่อดูผังขนาดใหญ่ ชื่อดาวแต่ละดวง และวิธีสังเกต',
              style: TextStyle(
                  fontSize: compact ? 10.8 : 11.5,
                  height: 1.6,
                  color: c.dim)),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, ConRow r, double dk) {
    final c = SkyColors.of(context);
    final compact = compactPhone(context);
    final narrow = MediaQuery.of(context).size.width < 360;
    final fig = narrow ? 68.0 : 82.0;

    final Widget pill = r.geo.altC > 8
        ? (dk > 0.25
            ? const Pill('เห็นได้ตอนนี้', 'up')
            : const Pill('ฟ้ายังสว่าง', 'am'))
        : r.geo.maxAlt > 0
            ? const Pill('โผล่ขอบฟ้า', 'am')
            : r.upTonight
                ? Pill('ขึ้น ${fmtTime(r.times.rise)}', 'am')
                : const Pill('คืนนี้ไม่ขึ้น', 'dn');

    final where = r.geo.altC > 0
        ? 'ทาง${compassTh(r.geo.azC)} · สูง ${r.geo.altC.round()}°'
        : 'ดีที่สุดเวลา ${fmtTime(r.times.transit)}';

    return GestureDetector(
      onTap: () => onOpen(r.con.id),
      child: Container(
        margin: EdgeInsets.only(top: compact ? 8 : 9),
        padding: EdgeInsets.fromLTRB(compact ? 9 : 10, 10, compact ? 10 : 12, 10),
        decoration: BoxDecoration(
          color: c.panel,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: fig,
              height: fig,
              decoration: BoxDecoration(
                color: c.panel2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: CustomPaint(
                  painter: ConstellationPainter(r.con, r.geo, c, s.nightMode)),
            ),
            SizedBox(width: narrow ? 9 : 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text('กลุ่มดาว${r.con.th}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: compact ? 13.5 : 14.5,
                                fontWeight: FontWeight.w600,
                                color: c.fg)),
                      ),
                      const SizedBox(width: 8),
                      pill,
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text('${r.con.en} · สว่างสุด ${r.geo.bright.star.shortTh}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 10.7 : 11.5,
                          color: c.muted)),
                  const SizedBox(height: 4),
                  Text(where,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 10.7 : 11.5,
                          fontFamily: fMono,
                          color: c.amber)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
