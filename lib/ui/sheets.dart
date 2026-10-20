import 'package:flutter/material.dart';

import '../data/places.dart';
import '../engine/engine.dart';
import '../engine/sky.dart';
import '../painters/constellation_painter.dart';
import '../painters/sky_painter.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showSkySheet(BuildContext context, Sky colors, Widget child) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.panel,
    barrierColor: const Color(0xCC02050B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SkyColors(
      colors: colors,
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.94,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: colors.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(
                    16, 0, 16, 20 + MediaQuery.of(ctx).padding.bottom),
                children: [child],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------ location

class LocationSheet extends StatefulWidget {
  final AppState s;
  const LocationSheet(this.s, {super.key});
  @override
  State<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<LocationSheet> {
  String? _selKey;
  String _gpsNote = '';
  String _manualNote = '';
  bool _busy = false;
  late final TextEditingController _lat =
      TextEditingController(text: widget.s.lat.toStringAsFixed(4));
  late final TextEditingController _lon =
      TextEditingController(text: widget.s.lon.toStringAsFixed(4));
  late final TextEditingController _h =
      TextEditingController(text: widget.s.height.round().toString());

  @override
  void initState() {
    super.initState();
    for (final p in placeIndex) {
      if (p.name == widget.s.place) {
        _selKey = p.key;
        break;
      }
    }
  }

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    _h.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final c = SkyColors.of(context);
    final info = _selKey != null ? placeByKey[_selKey!] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('ตำแหน่งผู้สังเกต'),
        const SizedBox(height: 3),
        Text('คุณดูดาวจากที่ไหน',
            style: TextStyle(
                fontFamily: fDisplay,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.fg)),
        Text('ตำแหน่งเปลี่ยนไป 1 องศา ทำให้ดาวขึ้นเร็วขึ้นหรือช้าลงราว 4 นาที',
            style: TextStyle(fontSize: 12.5, color: c.muted)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() {
                      _busy = true;
                      _gpsNote = 'กำลังอ่านพิกัดจากเครื่อง…';
                    });
                    final note = await s.requestLocation();
                    if (!mounted) return;
                    setState(() {
                      _busy = false;
                      _gpsNote = note;
                      _selKey = null;
                      _lat.text = s.lat.toStringAsFixed(4);
                      _lon.text = s.lon.toStringAsFixed(4);
                      _h.text = s.height.round().toString();
                    });
                  },
            child: Text(_busy ? 'กำลังอ่าน…' : 'ใช้พิกัด GPS ของเครื่อง'),
          ),
        ),
        if (_gpsNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_gpsNote,
                style: TextStyle(fontSize: 12, height: 1.5, color: c.muted)),
          ),
        _sep(c),
        const Eyebrow('จังหวัดและจุดดูดาว'),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.panel2,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(11),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selKey,
              hint: Text('— เลือกสถานที่ —',
                  style: TextStyle(fontSize: 15, color: c.muted)),
              dropdownColor: c.panel,
              style: TextStyle(fontSize: 15, color: c.fg, fontFamily: fBody),
              items: _items(c),
              onChanged: (k) {
                if (k == null) return;
                final pl = placeByKey[k];
                if (pl == null) return;
                setState(() {
                  _selKey = k;
                  _lat.text = pl.lat.toStringAsFixed(4);
                  _lon.text = pl.lon.toStringAsFixed(4);
                  _h.text = pl.h.toString();
                  _gpsNote = '';
                });
                s.setPlace(pl.name, pl.lat, pl.lon, pl.h.toDouble());
              },
            ),
          ),
        ),
        if (info != null && info.kind == 'spot')
          Hint(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.blurb ?? ''),
                const SizedBox(height: 6),
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '${info.lat.toStringAsFixed(4)}°, '
                          '${info.lon.toStringAsFixed(4)}° · สูง ${info.h} ม.',
                      style: TextStyle(fontFamily: fMono, color: c.muted)),
                  if (info.approximate)
                    TextSpan(
                        text: ' · พิกัดเป็นค่าประมาณระดับพื้นที่',
                        style: TextStyle(color: c.warn)),
                ])),
              ],
            ),
          ),
        _sep(c),
        const Eyebrow('กรอกพิกัดเอง'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _field(c, _lat, 'ละติจูด')),
            const SizedBox(width: 8),
            Expanded(child: _field(c, _lon, 'ลองจิจูด')),
            const SizedBox(width: 8),
            SizedBox(width: 86, child: _field(c, _h, 'สูง (ม.)')),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            final la = double.tryParse(_lat.text.trim());
            final lo = double.tryParse(_lon.text.trim());
            final hv = double.tryParse(_h.text.trim());
            if (la == null || lo == null || la.abs() > 90 || lo.abs() > 180) {
              setState(() => _manualNote =
                  'พิกัดไม่ถูกต้อง: ละติจูดอยู่ระหว่าง −90 ถึง 90 และลองจิจูด −180 ถึง 180');
              return;
            }
            s.setPlace('${la.toStringAsFixed(3)}°, ${lo.toStringAsFixed(3)}°',
                la, lo, (hv ?? 0).clamp(-500.0, 9000.0));
            setState(() {
              _manualNote = 'ใช้พิกัดที่กรอกแล้ว';
              _selKey = null;
            });
          },
          child: const Text('ใช้พิกัดนี้'),
        ),
        if (_manualNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_manualNote,
                style: TextStyle(fontSize: 12, color: c.muted)),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('เสร็จแล้ว'),
          ),
        ),
      ],
    );
  }

  /// Flutter's DropdownButton has no option groups, so each region gets a
  /// non-selectable header row instead.
  List<DropdownMenuItem<String>> _items(Sky c) {
    final out = <DropdownMenuItem<String>>[];
    void header(String label) {
      out.add(DropdownMenuItem<String>(
        enabled: false,
        value: '#$label',
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: c.muted)),
      ));
    }

    for (final g in spotGroups) {
      header('★ ${g.label}');
      for (final sp in g.spots) {
        out.add(DropdownMenuItem(
            value: 's:${sp.name}',
            child: Text('${sp.name} · ${sp.province}',
                maxLines: 1, overflow: TextOverflow.ellipsis)));
      }
    }
    for (final r in regions) {
      header('${r.label} (${r.places.length} จังหวัด)');
      for (final p in r.places) {
        out.add(DropdownMenuItem(value: 'p:${p.name}', child: Text(p.name)));
      }
    }
    return out;
  }

  Widget _field(Sky c, TextEditingController ctl, String hint) => TextField(
        controller: ctl,
        keyboardType: const TextInputType.numberWithOptions(
            decimal: true, signed: true),
        style: TextStyle(fontFamily: fMono, fontSize: 13, color: c.fg),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.muted, fontSize: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          filled: true,
          fillColor: c.panel2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: c.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: c.line),
          ),
        ),
      );

  Widget _sep(Sky c) => Container(
      height: 1, color: c.line, margin: const EdgeInsets.symmetric(vertical: 14));
}

// ------------------------------------------------------------ object detail

class ObjectSheet extends StatelessWidget {
  final AppState s;
  final Scene sc;
  final Selection sel;
  const ObjectSheet(
      {super.key, required this.s, required this.sc, required this.sel});

  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    final o = findInScene(sel, sc, s);
    if (o == null) return const SizedBox.shrink();
    final a = s.alm;

    String name, sub;
    double mag;
    RiseSet? rs;
    final extra = <(String, String)>[];

    if (sel.kind == 'body') {
      final b = o.body!;
      final meta = bodies.firstWhere((x) => x.id == b.id);
      name = meta.th;
      sub = meta.en + (meta.kind == 'planet' ? ' · ดาวเคราะห์' : '');
      mag = b.mag;
      rs = b.id == 'moon'
          ? a.moonT
          : b.id == 'sun'
              ? RiseSet(rise: a.ev.rise, set: a.ev.set, transit: a.ev.transit,
                  maxAlt: a.ev.maxAlt)
              : a.planets[b.id];
      if (b.id == 'moon') {
        extra.addAll([
          ('ข้างขึ้นข้างแรม', moonPhaseName(b)),
          ('ส่วนสว่าง', '${((b.illum ?? 0) * 100).round()}%'),
          ('อายุดวงจันทร์', '${(b.age ?? 0).toStringAsFixed(1)} วัน'),
          ('ระยะทาง', '${(b.distKm ?? 0).round()} กม.'),
          ('ขนาดปรากฏ', '${(b.angSize ?? 0).toStringAsFixed(1)}′'),
        ]);
      } else if (meta.kind == 'planet') {
        extra.addAll([
          ('ระยะจากโลก', '${(b.distAu ?? 0).toStringAsFixed(3)} AU'),
          ('แสงเดินทางถึงโลก', '${((b.distAu ?? 0) * 8.317).toStringAsFixed(1)} นาที'),
          ('ระยะจากดวงอาทิตย์', '${(b.sunDistAu ?? 0).toStringAsFixed(3)} AU'),
          ('มุมห่างดวงอาทิตย์',
              '${(b.elong ?? 0).toStringAsFixed(1)}° ${(b.eastOfSun ?? true) ? 'ตะวันออก' : 'ตะวันตก'}'),
          ('ส่วนสว่าง', '${((b.phase ?? 0) * 100).round()}%'),
        ]);
      } else if (b.id == 'sun') {
        extra.addAll([
          ('ระยะจากโลก', '${(b.distAu ?? 0).toStringAsFixed(4)} AU'),
          ('แสงเดินทางถึงโลก', '${((b.distAu ?? 0) * 8.317).toStringAsFixed(1)} นาที'),
        ]);
      }
    } else if (sel.kind == 'star') {
      final st = o.star!;
      final con = conById[st.con];
      name = st.th;
      sub = '${st.en} · ${st.bayer} · กลุ่มดาว${con?.th ?? '—'}';
      mag = st.mag;
      rs = starRiseSet(st.ra, st.dec, a.jd0, s.lat, s.lon, s.height);
    } else {
      final d = o.dso!;
      name = d.th;
      sub = '${d.en} · ${d.type}';
      mag = d.mag;
      rs = starRiseSet(d.ra, d.dec, a.jd0, s.lat, s.lon, s.height);
    }

    final vis = visibility(mag, o.alt, sc.sunAlt);
    final altA = refract(o.alt);
    final transitAlt = (rs?.transit != null && sel.kind != 'body')
        ? eqToAltAz(
                sel.kind == 'star' ? o.star!.ra : o.dso!.ra,
                sel.kind == 'star' ? o.star!.dec : o.dso!.dec,
                s.lat, s.lon, rs!.transit!)
            .alt
        : rs?.maxAlt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(sel.kind == 'body'
                      ? 'ระบบสุริยะ'
                      : sel.kind == 'star'
                          ? 'ดาวฤกษ์'
                          : 'วัตถุห้วงลึก'),
                  Text(name,
                      style: TextStyle(
                          fontFamily: fDisplay,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: c.fg)),
                  Text(sub, style: TextStyle(fontSize: 12.5, color: c.muted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Pill(vis.text, vis.kind)),
          ],
        ),
        AimDial(az: o.az, alt: altA, up: o.alt > 0),
        Hint(
          child: Text(o.alt > 0
              ? 'หันหน้าไปทาง${compassTh(o.az)} (${o.az.round()}°) '
                  'แล้วเงยหน้าขึ้น ${altA.round()}°'
                  '${altA > 75 ? ' — เกือบตรงศีรษะ' : altA < 15 ? ' — อยู่เตี้ยติดขอบฟ้า ต้องมองข้ามสิ่งกีดขวาง' : ''}'
              : 'ตอนนี้อยู่ใต้ขอบฟ้า มองไม่เห็นจากที่นี่'),
        ),
        Kv([
          ('มุมเงย', '${altA.toStringAsFixed(1)}°'),
          ('อะซิมุท', '${o.az.toStringAsFixed(1)}° ${compassShort(o.az)}'),
          ('โชติมาตร', mag.toStringAsFixed(2)),
          ...extra,
          ('ขึ้น',
              rs == null
                  ? '—'
                  : rs.circumpolar
                      ? 'ไม่ตกลับขอบฟ้า'
                      : rs.neverUp
                          ? 'ไม่ขึ้นที่ละติจูดนี้'
                          : fmtTime(rs.rise)),
          ('ผ่านเมริเดียน',
              '${fmtTime(rs?.transit)}'
              '${transitAlt != null && transitAlt > -90 ? ' · ${transitAlt.round()}°' : ''}'),
          ('ตก', rs != null && rs.circumpolar ? '—' : fmtTime(rs?.set)),
        ]),
        const SizedBox(height: 14),
        Row(
          children: [
            FilledButton(
              onPressed: () {
                s.setTarget(sel);
                s.setTab(SkyTab.aim);
                Navigator.of(context).pop();
              },
              child: const Text('นำทางไปหาดวงนี้'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ปิด'),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------ constellation detail

class ConstellationSheet extends StatelessWidget {
  final AppState s;
  final Scene sc;
  final String conId;
  final void Function(Selection) onPick;
  const ConstellationSheet(
      {super.key,
      required this.s,
      required this.sc,
      required this.conId,
      required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    final con = conById[conId];
    if (con == null) return const SizedBox.shrink();
    final geo = conGeometry(con, sc, s.lat, s.lon);
    if (geo == null) return const SizedBox.shrink();
    final a = s.alm;
    final rd = altAzToEq(geo.altC, geo.azC, s.lat, s.lon, sc.jd);
    final t = starRiseSet(rd.ra, rd.dec, a.jd0, s.lat, s.lon, s.height);
    final bright = darkness(sc.sunAlt) < 0.25;
    final members = geo.members.toList()
      ..sort((x, y) => x.star.mag.compareTo(y.star.mag));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('กลุ่มดาว'),
        Text('กลุ่มดาว${con.th}',
            style: TextStyle(
                fontFamily: fDisplay,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: c.fg)),
        Text('${con.en} · ${geo.members.length} ดวงในผัง · '
            'สว่างสุดโชติมาตร ${geo.bright.star.mag.toStringAsFixed(1)}',
            style: TextStyle(fontSize: 12.5, color: c.muted)),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (_, box) => Container(
            width: box.maxWidth,
            height: box.maxWidth * 3 / 4,
            decoration: BoxDecoration(
              color: c.panel2,
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: CustomPaint(
                painter: ConstellationPainter(con, geo, c, s.nightMode, big: true)),
          ),
        ),
        Hint(child: Text(con.note)),
        Hint(
          child: Text(geo.altC > 0
              ? 'หันหน้าไปทาง${compassTh(geo.azC)} แล้วเงยหน้าขึ้น '
                  '${geo.altC.round()}° รูปที่เห็นจะเอียงตามภาพนี้พอดี'
                  '${bright ? ' — แต่ตอนนี้ฟ้ายังสว่างเกินกว่าจะมองเห็น' : ''}'
              : 'ตอนนี้อยู่ใต้ขอบฟ้า รอถึง ${fmtTime(t.rise)} จึงจะโผล่ขึ้นมาทางขอบฟ้า'),
        ),
        Kv([
          ('ดาวสว่างที่สุด',
              '${geo.bright.star.shortTh} (${geo.bright.star.mag.toStringAsFixed(2)})'),
          ('กึ่งกลางกลุ่ม',
              geo.altC > 0
                  ? '${geo.altC.round()}° ${compassShort(geo.azC)}'
                  : 'ใต้ขอบฟ้า'),
          ('ขึ้น',
              t.circumpolar
                  ? 'ไม่ตกลับขอบฟ้า'
                  : t.neverUp
                      ? 'ไม่ขึ้นที่นี่'
                      : fmtTime(t.rise)),
          ('สูงสุด', fmtTime(t.transit)),
          ('ตก', t.circumpolar ? '—' : fmtTime(t.set)),
        ]),
        Container(
            height: 1,
            color: c.line,
            margin: const EdgeInsets.symmetric(vertical: 14)),
        const Eyebrow('ดาวในกลุ่ม'),
        for (final m in members.take(12))
          ObjectRow(
            name: m.star.shortTh,
            sub: '${m.star.bayer} · ${m.star.en}',
            badge: '✦',
            right: m.alt > -1 ? '${refract(m.alt).round()}°' : 'ใต้ฟ้า',
            sub2: m.alt > -1
                ? '${compassShort(m.az)} · ${m.star.mag.toStringAsFixed(1)}'
                : 'โชติมาตร ${m.star.mag.toStringAsFixed(1)}',
            colour: s.nightMode ? c.star : Color(m.star.tint),
            belowHorizon: m.alt <= -1,
            onTap: () {
              Navigator.of(context).pop();
              onPick(Selection('star', m.star.id));
            },
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            FilledButton(
              onPressed: () {
                s.setTarget(Selection('star', geo.bright.star.id));
                s.setTab(SkyTab.aim);
                Navigator.of(context).pop();
              },
              child: const Text('นำทางไปหากลุ่มนี้'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ปิด'),
            ),
          ],
        ),
      ],
    );
  }
}
