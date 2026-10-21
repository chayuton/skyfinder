// The planning half of the tonight tab: when the next New Moon falls, and
// which of the coming nights actually have dark, moonless hours in them.

import 'package:flutter/material.dart';

import '../engine/calendar.dart';
import '../engine/sky.dart';
import '../state/app_state.dart';
import 'theme.dart';

/// How far ahead to plan. Two lunations is enough to cover the next two dark
/// windows, which is as far as anyone sensibly books a trip.
const int _horizon = 60;

const List<String> _dowTh = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

/// Sunday-first column for a Thai calendar grid. DateTime counts Monday as 1
/// and Sunday as 7.
int _col(DateTime d) => d.weekday % 7;

class MoonCalendarSection extends StatefulWidget {
  final AppState s;
  const MoonCalendarSection({super.key, required this.s});

  @override
  State<MoonCalendarSection> createState() => _MoonCalendarSectionState();
}

class _MoonCalendarSectionState extends State<MoonCalendarSection> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final c = SkyColors.of(context);
    final start = nightStart(s.now);

    final p = planner(start, _horizon, s.lat, s.lon, s.height);
    final nights = p.nights;
    final phases = p.phases;

    final selIdx = _sel < 0
        ? 0
        : (_sel >= nights.length ? nights.length - 1 : _sel);
    final sel = nights[selIdx];
    final newMoons = p.newMoons;

    return Column(
      children: [
        if (newMoons.isNotEmpty) _nextNewMoon(context, newMoons.first, start),
        _grid(context, nights, c),
        _detail(context, sel, c),
        _best(context, nights, c),
        _phaseList(context, phases, c),
        _season(context, start, c),
      ],
    );
  }

  /// What the score deliberately leaves out. The calendar knows where the Moon
  /// and the Sun will be months ahead; it knows nothing about cloud, and in
  /// Thailand cloud is what actually cancels the trip. Worse, the two pull
  /// against each other: the months with the galactic centre high are the
  /// monsoon months, and the clearest months have no core in the sky at all.
  Widget _season(BuildContext context, DateTime start, Sky c) {
    final (String head, String body) = switch (start.month) {
      11 || 12 || 1 => (
          'ช่วงนี้ฟ้าใสที่สุดของปี',
          'พฤศจิกายนถึงมกราคมเป็นหน้าหนาว ฝนน้อยและความชื้นต่ำที่สุด '
              'นครราชสีมามีฝนราวเดือนละ 1–2 วัน เทียบกับ 17 วันในเดือนกันยายน '
              'แต่ใจกลางทางช้างเผือกไม่ขึ้นในช่วงนี้'
        ),
      2 || 3 || 4 => (
          'ฟ้าใสแต่เริ่มมีฝุ่นควัน',
          'อีสานเผาตอซังเร็วกว่าภาคเหนือ ฝุ่นเริ่มราวเดือนกุมภาพันธ์ '
              'และหนักสุดเดือนมีนาคม ฟ้าอาจไร้เมฆแต่ทัศนวิสัยขุ่น '
              'ดาวจางจะหายไปก่อนดาวสว่าง'
        ),
      5 || 6 || 7 || 8 => (
          'ใจกลางทางช้างเผือกสูงสุด แต่เป็นหน้าฝน',
          'ใจกลางทางช้างเผือกขึ้นสูงถึง 46° จากละติจูดนี้ สูงกว่าที่ยุโรป'
              'หรืออเมริกาเหนือมาก แต่ตรงกับมรสุมพอดี ต้องอาศัยจังหวะฟ้าเปิด '
              'ดูพยากรณ์เมฆประกอบทุกครั้ง'
        ),
      _ => (
          'ปลายฝนต้นหนาว ฟ้าเริ่มเปิด',
          'ตุลาคมเป็นรอยต่อ ฝนเริ่มซา และยังเห็นใจกลางทางช้างเผือก'
              'ได้ช่วงหัวค่ำก่อนตกลับขอบฟ้า'
        ),
    };

    return SkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(head,
              style: TextStyle(
                  fontFamily: fDisplay,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.fg)),
          const SizedBox(height: 4),
          Text(body,
              style: TextStyle(fontSize: 12.5, height: 1.6, color: c.muted)),
          const SizedBox(height: 10),
          Text(
              'ปฏิทินนี้คิดจากดวงจันทร์กับแสงสนธยาเท่านั้น ไม่ได้รวมเมฆ ฝน '
              'หรือฝุ่น',
              style: TextStyle(fontSize: 11.5, height: 1.5, color: c.dim)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- headline

  Widget _nextNewMoon(BuildContext context, PhaseEvent nm, DateTime start) {
    final c = SkyColors.of(context);
    final days = nm.local.difference(start).inHours / 24.0;
    return SkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('จันทร์ดับครั้งถัดไป'),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(fmtDate(nm.local),
                    style: TextStyle(
                        fontFamily: fDisplay,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: c.fg)),
              ),
              Text(days < 1 ? 'วันนี้' : 'อีก ${days.round()} วัน',
                  style: TextStyle(
                      fontFamily: fMono, fontSize: 13, color: c.amber)),
            ],
          ),
          Text('เวลา ${fmtTime(nm.jd)} น. — คืนรอบ ๆ วันนี้คือช่วงที่ฟ้ามืดที่สุด'
              ' และเห็นดาวจางกับทางช้างเผือกได้ดีที่สุดของเดือน',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: c.muted)),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- grid

  Widget _grid(BuildContext context, List<NightQuality> nights, Sky c) {
    // Split the run of nights into the calendar months it touches, so the grid
    // reads like a wall calendar rather than a sixty-cell ribbon.
    final months = <(int, int), List<NightQuality>>{};
    for (final n in nights) {
      months.putIfAbsent((n.evening.year, n.evening.month), () => []).add(n);
    }

    return SkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ปฏิทินคืนฟ้ามืด',
              style: Theme.of(context).textTheme.titleMedium),
          Text('ยิ่งเข้ม ยิ่งมีชั่วโมงฟ้ามืดสนิทที่ไร้แสงจันทร์มาก',
              style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 12),
          for (final e in months.entries) ...[
            Text('${thaiMonths[e.key.$2 - 1]} ${e.key.$1 + 543}',
                style: TextStyle(
                    fontFamily: fDisplay,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.fg)),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final d in _dowTh)
                  Expanded(
                    child: Center(
                      child: Text(d,
                          style: TextStyle(fontSize: 10, color: c.dim)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ..._weeks(context, e.value, nights, c),
            const SizedBox(height: 14),
          ],
          _legend(c),
        ],
      ),
    );
  }

  List<Widget> _weeks(BuildContext context, List<NightQuality> month,
      List<NightQuality> all, Sky c) {
    final rows = <Widget>[];
    var cells = <Widget>[];

    // Blank cells so the first night lands under the right weekday.
    for (var i = 0; i < _col(month.first.evening); i++) {
      cells.add(const Expanded(child: SizedBox(height: 40)));
    }

    for (final n in month) {
      final idx = all.indexOf(n);
      cells.add(Expanded(child: _cell(context, n, idx, c)));
      if (cells.length == 7) {
        rows.add(Row(children: cells));
        cells = <Widget>[];
      }
    }
    if (cells.isNotEmpty) {
      while (cells.length < 7) {
        cells.add(const Expanded(child: SizedBox(height: 40)));
      }
      rows.add(Row(children: cells));
    }
    return rows;
  }

  Widget _cell(BuildContext context, NightQuality n, int idx, Sky c) {
    final sel = idx == _sel;
    final t = n.score;
    // The scale runs from the dim colour to the "visible" green, so a glance
    // down a column shows the dark window opening and closing.
    final bg = Color.lerp(c.down.withOpacity(0.10), c.up.withOpacity(0.55), t)!;
    final isNew = n.illum < 0.02;
    final isFull = n.illum > 0.98;

    return GestureDetector(
      onTap: () => setState(() => _sel = idx),
      child: Container(
        height: 40,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: sel ? c.amber : (isNew ? c.cool.withOpacity(0.6) : c.line),
              width: sel ? 1.6 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${n.evening.day}',
                style: TextStyle(
                    fontFamily: fMono,
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    color: t > 0.55 ? c.ink : c.fg)),
            Text(
                isNew
                    ? '●'
                    : isFull
                        ? '○'
                        : '${n.moonFreeHours.round()}',
                style: TextStyle(
                    fontFamily: fMono,
                    fontSize: 8.5,
                    color: t > 0.55 ? c.ink.withOpacity(0.75) : c.dim)),
          ],
        ),
      ),
    );
  }

  Widget _legend(Sky c) => Row(
        children: [
          Text('● จันทร์ดับ   ○ จันทร์เพ็ญ   ตัวเลข = ชั่วโมงไร้จันทร์',
              style: TextStyle(fontSize: 10.5, color: c.dim)),
        ],
      );

  // --------------------------------------------------------------- detail

  Widget _detail(BuildContext context, NightQuality n, Sky c) {
    final good = n.score >= 0.65;
    return SkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('คืนวันที่ ${fmtDate(n.evening)}',
                    style: TextStyle(
                        fontFamily: fDisplay,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.fg)),
              ),
              Pill(n.verdict, good ? 'up' : (n.score >= 0.4 ? 'am' : 'dn')),
            ],
          ),
          Kv([
            ('ฟ้ามืดสนิททั้งหมด', '${n.darkHours.toStringAsFixed(1)} ชม.'),
            ('ในนั้น ไร้แสงจันทร์', '${n.moonFreeHours.toStringAsFixed(1)} ชม.'),
            ('ส่วนสว่างของดวงจันทร์', '${(n.illum * 100).round()}%'),
            ('อายุดวงจันทร์', '${n.moonAge.toStringAsFixed(1)} วัน'),
            if (n.bestFrom != null)
              ('ช่วงดีที่สุด',
                  '${fmtTime(n.bestFrom)} – ${fmtTime(n.bestTo)}'),
          ]),
        ],
      ),
    );
  }

  // --------------------------------------------------------- dark windows

  /// A night counts as part of a dark window when the Moon stays below the
  /// horizon for at least this much of the astronomical night. Four fifths is
  /// strict enough to exclude the evenings where a half Moon hangs about until
  /// midnight, and loose enough to keep the thin-crescent nights at both ends,
  /// which is what makes the window about nine nights long rather than three.
  static const double _windowCut = 0.8;

  Widget _best(BuildContext context, List<NightQuality> nights, Sky c) {
    // Contiguous runs, because the useful answer to "when should I go" is a
    // stretch of dates, not the single best night in it. Over sixty nights
    // there are normally two such stretches, one per lunation.
    final windows = <List<NightQuality>>[];
    List<NightQuality>? run;
    for (final n in nights) {
      final ok = n.darkHours > 0 && n.moonFreeHours / n.darkHours >= _windowCut;
      if (ok) {
        (run ??= <NightQuality>[]).add(n);
      } else if (run != null) {
        windows.add(run);
        run = null;
      }
    }
    if (run != null) windows.add(run);

    return SkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ช่วงฟ้ามืดใน $_horizon วันข้างหน้า',
              style: Theme.of(context).textTheme.titleMedium),
          Text('ช่วงที่ดวงจันทร์ลับขอบฟ้าเกือบตลอดคืน เห็นดาวจาง '
              'ทางช้างเผือก และฝนดาวตกได้ดีที่สุด',
              style: TextStyle(fontSize: 12, height: 1.5, color: c.muted)),
          const SizedBox(height: 10),
          if (windows.isEmpty)
            Text('ไม่มีช่วงที่ฟ้ามืดยาวพอในกรอบนี้',
                style: TextStyle(fontSize: 12.5, color: c.muted))
          else
            for (final w in windows) _window(context, w, c),
        ],
      ),
    );
  }

  Widget _window(BuildContext context, List<NightQuality> w, Sky c) {
    final a = w.first.evening, b = w.last.evening;
    final peak = w.reduce((x, y) => y.moonFreeHours > x.moonFreeHours ? y : x);
    final span = a.month == b.month
        ? '${a.day}–${b.day} ${thaiMonths[b.month - 1]} ${b.year + 543}'
        : '${a.day} ${thaiMonths[a.month - 1]} – '
            '${b.day} ${thaiMonths[b.month - 1]} ${b.year + 543}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: c.panel2,
        border: Border.all(color: c.up.withOpacity(0.28)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(span,
                    style: TextStyle(
                        fontFamily: fDisplay,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: c.fg)),
              ),
              Pill('${w.length} คืน', 'up'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              'มืดสนิทไร้จันทร์สูงสุด '
              '${peak.moonFreeHours.toStringAsFixed(1)} ชม. '
              'คืนวันที่ ${peak.evening.day} '
              '${thaiMonths[peak.evening.month - 1]}',
              style: TextStyle(fontFamily: fMono, fontSize: 11.5, color: c.muted)),
          if (peak.bestFrom != null)
            Text('ช่วงเวลา ${fmtTime(peak.bestFrom)} – ${fmtTime(peak.bestTo)}',
                style: TextStyle(
                    fontFamily: fMono, fontSize: 11.5, color: c.muted)),
        ],
      ),
    );
  }

  // --------------------------------------------------------- phase table

  Widget _phaseList(BuildContext context, List<PhaseEvent> phases, Sky c) {
    return SkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ข้างขึ้นข้างแรมที่จะถึง',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final p in phases)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(_glyph(p.phase),
                        style: TextStyle(
                            fontSize: 13,
                            color: p.phase == Phase.newMoon ? c.cool : c.muted)),
                  ),
                  SizedBox(
                    width: 74,
                    child: Text(p.phase.th,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: p.phase == Phase.newMoon
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: c.fg)),
                  ),
                  Expanded(
                    child: Text(
                        '${fmtDate(p.local)}  ${fmtTime(p.jd)}',
                        style: TextStyle(
                            fontFamily: fMono, fontSize: 11.5, color: c.muted)),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
                'เวลาเป็นเวลาประเทศไทย คำนวณจากตำแหน่งจริงของดวงจันทร์'
                'กับดวงอาทิตย์ ไม่ได้อ่านจากปฏิทินจันทรคติ วันจันทร์ดับจริง'
                'จึงตรงกับแรม 14 ค่ำ แรม 15 ค่ำ หรือขึ้น 1 ค่ำ ก็ได้ '
                'แล้วแต่เดือน',
                style: TextStyle(fontSize: 11.5, height: 1.5, color: c.dim)),
          ),
        ],
      ),
    );
  }

  String _glyph(Phase p) => switch (p) {
        Phase.newMoon => '●',
        Phase.firstQuarter => '◑',
        Phase.fullMoon => '○',
        Phase.lastQuarter => '◐',
      };
}
