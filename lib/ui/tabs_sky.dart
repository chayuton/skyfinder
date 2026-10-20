import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../engine/sky.dart';
import '../painters/constellation_painter.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

// ---------------------------------------------------------------- list tab

const _listFilters = [
  ('all', 'ทั้งหมด'),
  ('up', 'เหนือขอบฟ้า'),
  ('planet', 'ดาวเคราะห์'),
  ('star', 'ดาวฤกษ์'),
  ('dso', 'วัตถุห้วงลึก'),
];

class ListTabView extends StatelessWidget {
  final AppState s;
  final Scene sc;
  final void Function(Selection) onPick;
  const ListTabView(
      {super.key, required this.s, required this.sc, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    final compact = compactPhone(context);
    final items = <({
      Selection sel, String name, String sub, double alt, double az,
      Color colour, String badge, String grp
    })>[];

    for (var i = 0; i < sc.bodies.length; i++) {
      final b = sc.bodies[i], meta = bodies[i];
      items.add((
        sel: Selection('body', b.id),
        name: meta.th,
        sub: '${meta.en} · โชติมาตร ${b.mag.toStringAsFixed(1)}',
        alt: b.alt,
        az: b.az,
        colour: s.nightMode ? const Color(0xFFFF8A6B) : Color(meta.color),
        badge: b.id == 'moon' ? '☾' : '●',
        grp: 'planet',
      ));
    }
    for (final sv in sc.stars) {
      if (sv.ref.mag > s.magLim) continue;
      final con = conById[sv.ref.con];
      items.add((
        sel: Selection('star', sv.ref.id),
        name: sv.ref.shortTh,
        sub: '${sv.ref.bayer} · กลุ่มดาว${con?.th ?? '—'}'
            ' · ${sv.ref.mag.toStringAsFixed(1)}',
        alt: sv.alt,
        az: sv.az,
        colour: s.nightMode ? c.star : Color(sv.ref.tint),
        badge: '✦',
        grp: 'star',
      ));
    }
    for (final d in sc.dsos) {
      items.add((
        sel: Selection('dso', d.ref.id),
        name: d.ref.th,
        sub: '${d.ref.type} · โชติมาตร ${d.ref.mag.toStringAsFixed(1)}',
        alt: d.alt,
        az: d.az,
        colour: s.nightMode ? const Color(0xFF9A3A30) : const Color(0xFF8FD4C8),
        badge: '◎',
        grp: 'dso',
      ));
    }

    var shown = items;
    if (s.listFilter == 'up') {
      shown = items.where((i) => i.alt > 0).toList();
    } else if (s.listFilter != 'all') {
      shown = items.where((i) => i.grp == s.listFilter).toList();
    }
    shown.sort((a, b) => b.alt.compareTo(a.alt));
    shown = shown.take(120).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
          compact ? 12 : 16, 10, compact ? 12 : 16, 96 + MediaQuery.of(context).padding.bottom),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in _listFilters) ...[
              Tog(f.$2, s.listFilter == f.$1, () => s.setListFilter(f.$1)),
              const SizedBox(width: 6),
            ],
          ]),
        ),
        SkyCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (final i in shown)
                ObjectRow(
                  name: i.name,
                  sub: i.sub,
                  badge: i.badge,
                  right: i.alt > -1 ? '${refract(i.alt).round()}°' : 'ใต้ฟ้า',
                  sub2: i.alt > -1 ? '${compassShort(i.az)} ${i.az.round()}°' : '—',
                  colour: i.colour,
                  belowHorizon: i.alt <= -1,
                  onTap: () => onPick(i.sel),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          child: Text(
              'เรียงจากดาวที่อยู่สูงที่สุดลงมา · ค่าทั้งหมดคำนวณสำหรับตำแหน่งที่เลือก',
              style: TextStyle(
                  fontSize: compact ? 10.8 : 11.5,
                  height: 1.6,
                  color: c.dim)),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- night tab

class NightTabView extends StatelessWidget {
  final AppState s;
  final Scene sc;
  final void Function(Selection) onPick;
  const NightTabView(
      {super.key, required this.s, required this.sc, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    final compact = compactPhone(context);
    final a = s.alm;
    final d = nightStart(s.now);
    final moon = sc.moon;
    final mt = a.moonNight;
    final sunset = a.ev.set, dusk = a.ev.astro.dusk;
    final dawn = a.evN.astro.dawn, sunrise = a.sunN.rise;

    final t0 = sunset != null ? sunset - 0.02 : a.jd0 + 0.5;
    final t1 = sunrise != null ? sunrise + 0.02 : a.jd0 + 1.5;
    final span = t1 - t0;

    final windows = <List<double>>[];
    if (dusk != null && dawn != null) {
      for (final w in moonDownWindows(a, s.lat, s.lon, s.height)) {
        final f = math.max(w[0], dusk), t = math.min(w[1], dawn);
        if (t - f > 1 / 48) windows.add([f, t]);
      }
    }

    final tOr = moon.alt > 0 ? sc.jd : (a.moonT.transit ?? sc.jd);
    final mo = bodyPosition('moon', tOr, s.lat, s.lon, s.height);
    final so = bodyPosition('sun', tOr, s.lat, s.lon, s.height);
    final limb = math.atan2(
        norm180(so.az - mo.az) * math.cos(mo.alt * d2r), so.alt - mo.alt);

    final showers = activeShowers(d, dusk, dawn, s.lat, s.lon, sc.jd);

    return ListView(
      padding: EdgeInsets.fromLTRB(
          compact ? 12 : 16, 2, compact ? 12 : 16, 96 + MediaQuery.of(context).padding.bottom),
      children: [
        SkyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('คืนวันที่'),
              Text(fmtDate(d),
                  style: TextStyle(
                      fontFamily: fDisplay,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: c.fg)),
              Text('${s.place} · ${s.lat.toStringAsFixed(3)}°, '
                  '${s.lon.toStringAsFixed(3)}°',
                  style: TextStyle(fontSize: 12.5, color: c.muted)),
              const SizedBox(height: 10),
              _twilightBar(context, a, t0, span),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _tiny(c, '${fmtTime(sunset)} ตก'),
                  _tiny(c, '${fmtTime(dusk)} ฟ้ามืดสนิท'),
                  _tiny(c, fmtTime(dawn)),
                  _tiny(c, '${fmtTime(sunrise)} ขึ้น'),
                ],
              ),
              Kv([
                ('ดวงอาทิตย์ตก', fmtTime(sunset)),
                ('สิ้นแสงสนธยา (−18°)', fmtTime(dusk)),
                ('เริ่มแสงเช้า', fmtTime(dawn)),
                ('ดวงอาทิตย์ขึ้น', fmtTime(sunrise)),
              ]),
              Hint(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ช่วงฟ้ามืดสนิทไร้แสงจันทร์',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: c.fg, fontSize: 12.5)),
                    if (windows.isEmpty)
                      const Text('คืนนี้ดวงจันทร์ส่องตลอดช่วงฟ้ามืด — เหมาะกับการดูดวงจันทร์ ดาวเคราะห์ และดาวสว่างมากกว่า'),
                    else
                      for (final w in windows)
                        Text('${fmtTime(w[0])} – ${fmtTime(w[1])} '
                            '(${((w[1] - w[0]) * 24).toStringAsFixed(1)} ชม.)'),
                  ],
                ),
              ),
            ],
          ),
        ),
        SkyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ดวงจันทร์', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: compact ? 58 : 66,
                    height: compact ? 58 : 66,
                    child: CustomPaint(
                        painter: MoonPainter(moon.illum ?? 0.5, limb, s.nightMode)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${((moon.illum ?? 0) * 100).round()}%',
                            style: TextStyle(
                                fontFamily: fDisplay,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: c.fg)),
                        Text('${moonPhaseName(moon)} · '
                            'อายุ ${(moon.age ?? 0).toStringAsFixed(1)} วัน',
                            style: TextStyle(fontSize: 12.5, color: c.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              Kv([
                ('ขึ้น', fmtTime(mt.rise)),
                ('ตก', fmtTime(mt.set)),
                ('ระยะทาง', '${(moon.distKm ?? 0).round()} กม.'),
                ('ขนาดปรากฏ', '${(moon.angSize ?? 0).toStringAsFixed(1)}′'),
              ]),
            ],
          ),
        ),
        SkyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ดาวเคราะห์คืนนี้',
                  style: Theme.of(context).textTheme.titleMedium),
              ..._planets(context, dusk, dawn),
            ],
          ),
        ),
        SkyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ฝนดาวตก', style: Theme.of(context).textTheme.titleMedium),
              if (showers.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('ไม่มีฝนดาวตกสำคัญในช่วงสองสัปดาห์นี้',
                      style: TextStyle(fontSize: 12.5, color: c.muted)),
                )
              else ...[
                for (final o in showers) _shower(context, o),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                      'ดูฝนดาวตกให้นอนราบ มองกลางฟ้าเป็นวงกว้าง และให้ตาปรับความมืดอย่างน้อย 20 นาที',
                      style: TextStyle(fontSize: 12, height: 1.5, color: c.muted)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _tiny(Sky c, String t) => Text(t,
      style: TextStyle(fontFamily: fMono, fontSize: 10.5, color: c.muted));

  Widget _twilightBar(BuildContext context, Almanac a, double t0, double span) {
    final c = SkyColors.of(context);
    final segs = <({double from, double to, List<Color> colors})>[];
    void add(double? f, double? t, List<Color> cols) {
      if (f != null && t != null && t > f) segs.add((from: f, to: t, colors: cols));
    }

    add(t0, a.ev.set, [const Color(0xFF3C73B8), const Color(0xFF9C6A4E)]);
    add(a.ev.set, a.ev.civil.dusk, [const Color(0xFF8E5A52), const Color(0xFF3E3660)]);
    add(a.ev.civil.dusk, a.ev.nautical.dusk, [const Color(0xFF3E3660), const Color(0xFF232A52)]);
    add(a.ev.nautical.dusk, a.ev.astro.dusk, [const Color(0xFF232A52), const Color(0xFF10172F)]);
    add(a.ev.astro.dusk, a.evN.astro.dawn, [const Color(0xFF080C1A), const Color(0xFF080C1A)]);
    add(a.evN.astro.dawn, a.evN.nautical.dawn, [const Color(0xFF10172F), const Color(0xFF232A52)]);
    add(a.evN.nautical.dawn, a.evN.civil.dawn, [const Color(0xFF232A52), const Color(0xFF3E3660)]);
    add(a.evN.civil.dawn, a.sunN.rise, [const Color(0xFF3E3660), const Color(0xFF9C6A4E)]);

    return Container(
      height: 30,
      decoration: BoxDecoration(
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final seg in segs)
            Expanded(
              flex: math.max(1, (((seg.to - seg.from) / span) * 1000).round()),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: seg.colors),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _planets(BuildContext context, double? dusk, double? dawn) {
    final c = SkyColors.of(context);
    final out = <Widget>[];
    for (var i = 0; i < sc.bodies.length; i++) {
      final b = sc.bodies[i], meta = bodies[i];
      if (meta.kind != 'planet' || b.mag > 6.2) continue;
      final best = bestDuring(b.id, dusk, dawn, s.lat, s.lon, s.height);
      out.add(ObjectRow(
        name: meta.th,
        sub: best != null
            ? 'ดีที่สุดเวลา ${fmtTime(best.jd)} · สูง ${best.alt.round()}° '
                'ทาง${compassTh(best.az)}'
            : 'ไม่ขึ้นเหนือขอบฟ้าช่วงฟ้ามืด',
        badge: '●',
        right: b.mag.toStringAsFixed(1),
        sub2: 'โชติมาตร',
        colour: s.nightMode ? const Color(0xFFFF8A6B) : Color(meta.color),
        onTap: () => onPick(Selection('body', b.id)),
      ));
    }
    if (out.isEmpty) {
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('คืนนี้ไม่มีดาวเคราะห์สว่างอยู่เหนือขอบฟ้าช่วงฟ้ามืด',
            style: TextStyle(fontSize: 12.5, color: c.muted)),
      ));
    }
    return out;
  }

  Widget _shower(BuildContext context, ShowerView o) {
    final c = SkyColors.of(context);
    final near = o.diff.abs() < 1.5;
    final when = o.diff.abs() < 0.5
        ? 'คืนนี้คือคืนสูงสุด'
        : o.diff > 0
            ? 'อีก ${o.diff.round()} วันถึงจุดสูงสุด'
            : 'ผ่านจุดสูงสุดมา ${(-o.diff).round()} วัน';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(o.s.th,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: c.fg)),
              ),
              const SizedBox(width: 10),
              Pill(when, near ? 'am' : 'dn'),
            ],
          ),
          const SizedBox(height: 3),
          Text('สูงสุดราว ${o.s.zhr} ดวง/ชม. · ช่วงที่เห็นได้ ${o.s.window}',
              style: TextStyle(fontSize: 12.5, color: c.muted)),
          Text(
              o.bestAlt > 0
                  ? 'จุดกระจายขึ้นสูงสุด ${o.bestAlt.round()}° '
                      'เวลา ${fmtTime(o.bestJd)}'
                  : 'จุดกระจายไม่ขึ้นเหนือขอบฟ้าช่วงฟ้ามืดจากที่นี่',
              style: TextStyle(fontSize: 12.5, fontFamily: fMono, color: c.muted)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ settings tab

class SettingsTabView extends StatelessWidget {
  final AppState s;
  final VoidCallback onOpenPlace;
  const SettingsTabView(
      {super.key, required this.s, required this.onOpenPlace});

  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    final compact = compactPhone(context);
    Place? pl;
    for (final p in placeIndex) {
      if (p.name == s.place) {
        pl = p;
        break;
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
          compact ? 12 : 16, 2, compact ? 12 : 16, 96 + MediaQuery.of(context).padding.bottom),
      children: [
        SkyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ตำแหน่งผู้สังเกต',
                  style: Theme.of(context).textTheme.titleMedium),
              Kv([
                ('สถานที่', s.place),
                if (pl != null && pl.kind == 'spot') ('จังหวัด', pl.province ?? ''),
                ('ละติจูด', '${s.lat.toStringAsFixed(4)}°'),
                ('ลองจิจูด', '${s.lon.toStringAsFixed(4)}°'),
                ('ความสูง', '${s.height.round()} ม.'),
                ('ขอบฟ้ากดลง', '${horizonDip(s.height).toStringAsFixed(2)}°'),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onOpenPlace,
                  child: const Text('เปลี่ยนสถานที่ · GPS, 77 จังหวัด, จุดดูดาว'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                    'ความสูงมีผลจริง: ที่ยอดดอยอินทนนท์ ขอบฟ้ากดต่ำกว่าที่ราบราว 1.1°',
                    style: TextStyle(fontSize: 12, height: 1.5, color: c.muted)),
              ),
            ],
          ),
        ),
        SkyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('การแสดงผล', style: Theme.of(context).textTheme.titleMedium),
              _switchRow(context, 'โหมดไฟแดง',
                  'ถนอมสายตาที่ปรับเข้ากับความมืดแล้ว', s.nightMode,
                  () => s.toggle('night')),
              _switchRow(context, 'ไม่ให้จอดับ', 'ระหว่างที่ถือดูฟ้ากลางแจ้ง',
                  s.wakeOn, s.toggleWake),
              const SizedBox(height: 10),
              Text('ความสว่างดาวต่ำสุด',
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600, color: c.fg)),
              Text('แสดงถึงโชติมาตร ${s.magLim.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 11.5, color: c.muted)),
              Slider(
                value: s.magLim,
                min: 3,
                max: 6,
                divisions: 6,
                onChanged: s.setMagLimit,
              ),
            ],
          ),
        ),
        SkyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ความแม่นยำ', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                  'ดวงอาทิตย์และดวงจันทร์คำนวณด้วยชุดสมการ ELP2000/VSOP ที่รวดเร็ว',
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: c.muted)),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                    'เวลาทั้งหมดแสดงตามเขตเวลาของเครื่อง ถ้าเลือกตำแหน่งข้ามเขตเวลา ให้เทียบเวลาเองด้วย',
                    style: TextStyle(fontSize: 12, height: 1.5, color: c.muted)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _switchRow(BuildContext context, String title, String sub, bool value,
      VoidCallback onTap) {
    final c = SkyColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600, color: c.fg)),
                Text(sub, style: TextStyle(fontSize: 11.5, color: c.muted)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (_) => onTap(),
            activeColor: c.amber,
          ),
        ],
      ),
    );
  }
}
