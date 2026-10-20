// Scene assembly, the nightly almanac, and the plain-language judgements the
// interface needs. Still free of Flutter imports so it stays testable.

import 'dart:math' as math;
import 'engine.dart';
import '../data/stars.dart';
import '../data/places.dart';

/// Colours drawn from each star's spectral class, so the red supergiants and
/// blue-white giants on the chart match what the eye actually sees.
const Map<String, int> starTint = {
  'betelgeuse': 0xFFFFB08A, 'antares': 0xFFFFA585, 'aldebaran': 0xFFFFC79A,
  'arcturus': 0xFFFFD9A8, 'mirach': 0xFFFFC59B, 'gacrux': 0xFFFFB89A,
  'eltanin': 0xFFFFD3A8, 'menkar': 0xFFFFC79A, 'alphard': 0xFFFFCCA2,
  'zaurak': 0xFFFFB391, 'mira': 0xFFFF9F80, 'pollux': 0xFFFFD6A8,
  'rigel': 0xFFCFE0FF, 'spica': 0xFFC7D9FF, 'vega': 0xFFE3EBFF,
  'achernar': 0xFFCFE2FF, 'bellatrix': 0xFFD3E2FF, 'alnilam': 0xFFCDDEFF,
  'alnitak': 0xFFCFDFFF, 'mintaka': 0xFFD2E0FF, 'regulus': 0xFFDCE8FF,
  'sirius': 0xFFEAF1FF, 'hadar': 0xFFCFE0FF, 'shaula': 0xFFD2E2FF,
  'mimosa': 0xFFCBDCFF, 'acrux': 0xFFCEDEFF, 'elnath': 0xFFE6EDFF,
  'capella': 0xFFFFEFC9, 'procyon': 0xFFFBF4E8, 'canopus': 0xFFFFF6E6,
  'deneb': 0xFFEAF0FF, 'altair': 0xFFF2F6FF, 'fomalhaut': 0xFFE8EEFF,
  'rigil_kent': 0xFFFFF0D2, 'polaris': 0xFFF2F3FF,
};

class Star {
  final String id, en, th, bayer, con;
  final double ra0, dec0, mag;
  final int tint;
  double ra, dec;
  Star(this.id, this.en, this.th, this.bayer, this.con, this.ra0, this.dec0,
      this.mag, this.tint)
      : ra = ra0,
        dec = dec0;
  String get shortTh => th.split(' (').first;
}

class Dso {
  final String id, en, th, type;
  final double ra0, dec0, mag;
  double ra, dec;
  Dso(this.id, this.en, this.th, this.ra0, this.dec0, this.mag, this.type)
      : ra = ra0,
        dec = dec0;
}

class MilkyPoint {
  final double ra0, dec0, w;
  double ra, dec;
  MilkyPoint(this.ra0, this.dec0, this.w)
      : ra = ra0,
        dec = dec0;
}

class Place {
  final String key, name, group, kind;
  final double lat, lon;
  final int h;
  final String? province, precision, blurb;
  const Place(this.key, this.name, this.lat, this.lon, this.h, this.group,
      this.kind,
      {this.province, this.precision, this.blurb});
  bool get approximate => precision == 'approx';
}

final List<Star> stars = starData
    .map((s) => Star(s.id, s.en, s.th, s.bayer, s.con, hmsToDeg(s.raStr),
        dmsToDeg(s.decStr), s.mag, starTint[s.id] ?? 0xFFF2F6FF))
    .toList();

final Map<String, Star> starById = {for (final s in stars) s.id: s};

final List<Dso> dsos = dsoData
    .map((d) => Dso(d.id, d.en, d.th, hmsToDeg(d.raStr), dmsToDeg(d.decStr),
        d.mag, d.type))
    .toList();

final Map<String, ConstellationData> conById = {
  for (final c in constellationData) c.id: c
};

/// The Milky Way as weighted points astride the galactic equator, thinned
/// where the Great Rift's dust blocks the light.
final List<MilkyPoint> milkyWay = () {
  final pts = <MilkyPoint>[];
  for (var l = 0.0; l < 360; l += 4) {
    for (final b in [-11.0, -7.5, -4.5, -2.0, 0.0, 2.0, 4.5, 7.5, 11.0]) {
      final e = galToEq(l, b);
      final toCentre = math.min(norm180(l).abs(), 180.0);
      var w = math.exp(-(b * b) / 48) *
          (0.45 + 0.75 * math.exp(-(toCentre * toCentre) / 4200));
      if (toCentre < 55 && b > -3 && b < 6) w *= 0.72;
      if (toCentre > 120 && toCentre < 200) w *= 0.78;
      pts.add(MilkyPoint(e.ra, e.dec, w));
    }
  }
  return pts;
}();

final List<Place> placeIndex = () {
  final out = <Place>[];
  for (final r in regions) {
    for (final p in r.places) {
      out.add(Place('p:${p.name}', p.name, p.lat, p.lon, p.h, r.label, 'province'));
    }
  }
  for (final g in spotGroups) {
    for (final s in g.spots) {
      out.add(Place('s:${s.name}', s.name, s.lat, s.lon, s.h, g.label, 'spot',
          province: s.province, precision: s.precision, blurb: s.blurb));
    }
  }
  return out;
}();

final Map<String, Place> placeByKey = {for (final p in placeIndex) p.key: p};

/// The equinox of date drifts about 50 arcseconds a year, so recomputing
/// monthly is far more precision than naked-eye observing needs.
double _precessedAt = 0;
void precessCatalogue(double jd) {
  if ((jd - _precessedAt).abs() < 30) return;
  _precessedAt = jd;
  for (final s in stars) {
    final p = precess(s.ra0, s.dec0, jd);
    s.ra = p.ra;
    s.dec = p.dec;
  }
  for (final d in dsos) {
    final p = precess(d.ra0, d.dec0, jd);
    d.ra = p.ra;
    d.dec = p.dec;
  }
  for (final m in milkyWay) {
    final p = precess(m.ra0, m.dec0, jd);
    m.ra = p.ra;
    m.dec = p.dec;
  }
}

class StarView {
  final Star ref;
  final double alt, az;
  const StarView(this.ref, this.alt, this.az);
}

class DsoView {
  final Dso ref;
  final double alt, az;
  const DsoView(this.ref, this.alt, this.az);
}

class Scene {
  final double jd;
  final List<BodyPosition> bodies;
  final List<StarView> stars;
  final List<DsoView> dsos;
  const Scene(this.jd, this.bodies, this.stars, this.dsos);
  double get sunAlt => bodies[0].alt;
  BodyPosition get sun => bodies[0];
  BodyPosition get moon => bodies[1];
}

Scene buildScene(double jd, double lat, double lon, double h) {
  precessCatalogue(jd);
  final b = bodies.map((x) => bodyPosition(x.id, jd, lat, lon, h)).toList();
  final sv = <StarView>[];
  for (final s in stars) {
    final aa = eqToAltAz(s.ra, s.dec, lat, lon, jd);
    if (aa.alt > -2) sv.add(StarView(s, aa.alt, aa.az));
  }
  final dv = dsos.map((d) {
    final aa = eqToAltAz(d.ra, d.dec, lat, lon, jd);
    return DsoView(d, aa.alt, aa.az);
  }).toList();
  return Scene(jd, b, sv, dv);
}

/// 0 in daylight, 1 once the Sun is 18 degrees below the horizon.
double darkness(double sunAlt) => clampD((-sunAlt - 2) / 16, 0, 1);

String darknessLabel(double sunAlt) {
  if (sunAlt > 0) return 'กลางวัน';
  if (sunAlt > -6) return 'สนธยาพลเรือน ฟ้ายังสว่าง';
  if (sunAlt > -12) return 'สนธยานาวี เริ่มเห็นดาวสว่าง';
  if (sunAlt > -18) return 'สนธยาดาราศาสตร์ ใกล้มืดสนิท';
  return 'ฟ้ามืดสนิท เหมาะแก่การดูดาว';
}

class Visibility {
  final String text, kind; // kind: up | dn | am
  const Visibility(this.text, this.kind);
}

Visibility visibility(double mag, double alt, double sunAlt) {
  if (alt < -0.5) return const Visibility('อยู่ใต้ขอบฟ้า', 'dn');
  if (darkness(sunAlt) < 0.25 && mag > -3) {
    return const Visibility('ฟ้ายังสว่างเกินไป', 'dn');
  }
  if (mag <= 6.0) {
    return Visibility(
        alt < 10 ? 'เห็นได้ แต่อยู่ต่ำมาก' : 'เห็นได้ด้วยตาเปล่า', 'up');
  }
  if (mag <= 8.5) return const Visibility('ต้องใช้กล้องสองตา', 'am');
  return const Visibility('ต้องใช้กล้องโทรทรรศน์', 'am');
}

String moonPhaseName(BodyPosition m) {
  final e = m.elong ?? 0;
  if (e < 12 || e > 348) return 'จันทร์ดับ';
  if (e < 80) return 'ข้างขึ้น เสี้ยวบาง';
  if (e < 100) return 'ขึ้น 8 ค่ำ (ครึ่งดวง)';
  if (e < 170) return 'ข้างขึ้น ค่อนดวง';
  if (e < 190) return 'จันทร์เพ็ญ';
  if (e < 260) return 'ข้างแรม ค่อนดวง';
  if (e < 280) return 'แรม 8 ค่ำ (ครึ่งดวง)';
  return 'ข้างแรม เสี้ยวบาง';
}

class NearPlace {
  final Place place;
  final double km;
  const NearPlace(this.place, this.km);
}

NearPlace nearestPlace(double lat, double lon) {
  Place? best;
  var bd = 1e9;
  for (final pl in placeIndex) {
    final dx = (pl.lon - lon) * math.cos((lat + pl.lat) / 2 * d2r);
    final dy = pl.lat - lat;
    final km = math.sqrt(dx * dx + dy * dy) * 111.32;
    if (km < bd) {
      bd = km;
      best = pl;
    }
  }
  return NearPlace(best!, bd);
}

// ---------------- time ----------------

const List<String> thaiMonths = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

String two(int n) => n.toString().padLeft(2, '0');

String fmtTime(double? jd) {
  if (jd == null) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(msFromJd(jd));
  return '${two(dt.hour)}:${two(dt.minute)}';
}

String fmtClock(DateTime dt) => '${two(dt.hour)}:${two(dt.minute)}';

/// Thai dates count years from the Buddhist era, 543 ahead of the Gregorian.
String fmtDate(DateTime d) =>
    '${d.day} ${thaiMonths[d.month - 1]} ${d.year + 543}';

double localMidnightJd(DateTime t) =>
    jdFromMs(DateTime(t.year, t.month, t.day).millisecondsSinceEpoch);

/// Before noon, "tonight" still means the night that began yesterday.
DateTime nightStart(DateTime now) {
  var d = now;
  if (d.hour < 12) d = d.subtract(const Duration(days: 1));
  return DateTime(d.year, d.month, d.day);
}

class Almanac {
  final String key;
  final double jd0;
  final SunEvents ev, evN;
  final RiseSet moonT, moonN, sunN;
  final Map<String, RiseSet> planets;
  const Almanac(this.key, this.jd0, this.ev, this.evN, this.moonT, this.moonN,
      this.sunN, this.planets);

  /// Moonrise for this night and the moonset that follows it, which usually
  /// lands after midnight and so belongs to the next day's table.
  ({double? rise, double? set}) get moonNight {
    final rise = moonT.rise ?? moonN.rise;
    double? set;
    for (final c in [moonT.set, moonN.set]) {
      if (c != null && (rise == null || c > rise)) {
        set = c;
        break;
      }
    }
    set ??= moonT.set ?? moonN.set;
    return (rise: rise, set: set);
  }
}

/// The clock ticks once a second and every tick rebuilds the tree, so anything
/// that sweeps the whole night has to be remembered between frames. Without
/// this, the tonight tab recomputes roughly ten thousand planet positions a
/// second and the app stutters on a phone.
final Map<String, Object?> _memo = {};

T memo<T>(String key, T Function() compute) {
  if (_memo.containsKey(key)) return _memo[key] as T;
  if (_memo.length > 240) _memo.clear();
  final v = compute();
  _memo[key] = v;
  return v;
}

/// A key that only changes once a minute: positions move far too slowly for
/// a faster recompute to show on screen.
String minuteKey(double jd) => (jd * 1440).floor().toString();

Almanac? _almCache;

Almanac almanac(DateTime now, double lat, double lon, double h) {
  final jd0 = localMidnightJd(nightStart(now));
  final key = '${jd0.toStringAsFixed(4)}|${lat.toStringAsFixed(3)}'
      '|${lon.toStringAsFixed(3)}|$h';
  final c = _almCache;
  if (c != null && c.key == key) return c;
  final ev = sunEvents(jd0, lat, lon, h);
  final evN = sunEvents(jd0 + 1, lat, lon, h);
  final moonT = riseSet('moon', jd0, lat, lon, h);
  final moonN = riseSet('moon', jd0 + 1, lat, lon, h);
  final sunN = riseSet('sun', jd0 + 1, lat, lon, h);
  final planets = <String, RiseSet>{};
  for (final b in bodies) {
    if (b.kind == 'planet') {
      planets[b.id] = riseSet(b.id, jd0, lat, lon, h);
    }
  }
  final a = Almanac(key, jd0, ev, evN, moonT, moonN, sunN, planets);
  _almCache = a;
  return a;
}

/// Stretches of the night with the Moon below the horizon: the only hours when
/// faint objects are really within reach.
List<List<double>> moonDownWindows(
    Almanac a, double lat, double lon, double h) {
  return memo('moondown|${a.key}', () => _moonDownWindows(a, lat, lon, h));
}

List<List<double>> _moonDownWindows(
    Almanac a, double lat, double lon, double h) {
  final win = <List<double>>[];
  final evts = <({double j, bool rise})>[];
  if (a.moonT.rise != null) evts.add((j: a.moonT.rise!, rise: true));
  if (a.moonT.set != null) evts.add((j: a.moonT.set!, rise: false));
  if (a.moonN.rise != null) evts.add((j: a.moonN.rise!, rise: true));
  if (a.moonN.set != null) evts.add((j: a.moonN.set!, rise: false));
  evts.sort((x, y) => x.j.compareTo(y.j));

  var up = bodyPosition('moon', a.jd0, lat, lon, h).alt > 0;
  var t0 = a.jd0;
  for (final e in evts) {
    if (!up) win.add([t0, e.j]);
    up = e.rise;
    t0 = e.j;
  }
  if (!up) win.add([t0, a.jd0 + 2]);
  return win;
}

({double jd, double alt, double az})? bestDuring(
    String id, double? dusk, double? dawn, double lat, double lon, double h) {
  if (dusk == null || dawn == null) return null;
  final key = 'best|$id|${dusk.toStringAsFixed(5)}|${dawn.toStringAsFixed(5)}'
      '|${lat.toStringAsFixed(3)}|${lon.toStringAsFixed(3)}|$h';
  return memo(key, () {
    ({double jd, double alt, double az})? best;
    for (var jd = dusk; jd <= dawn; jd += 1 / 48) {
      final p = bodyPosition(id, jd, lat, lon, h);
      if (best == null || p.alt > best.alt) {
        best = (jd: jd, alt: p.alt, az: p.az);
      }
    }
    return (best != null && best.alt > 5) ? best : null;
  });
}

class ShowerView {
  final ShowerData s;
  final double diff, bestAlt;
  final double? bestJd;
  const ShowerView(this.s, this.diff, this.bestAlt, this.bestJd);
}

List<ShowerView> activeShowers(DateTime date, double? dusk, double? dawn,
    double lat, double lon, double jdNow) {
  final key = 'showers|${date.toIso8601String().substring(0, 10)}'
      '|${dusk?.toStringAsFixed(5)}|${dawn?.toStringAsFixed(5)}'
      '|${lat.toStringAsFixed(3)}|${lon.toStringAsFixed(3)}';
  return memo(key, () => _activeShowers(date, dusk, dawn, lat, lon, jdNow));
}

List<ShowerView> _activeShowers(DateTime date, double? dusk, double? dawn,
    double lat, double lon, double jdNow) {
  final out = <ShowerView>[];
  for (final s in showerData) {
    final peak = DateTime(date.year, s.month, s.day);
    var diff = peak.difference(date).inMinutes / 1440.0;
    if (diff < -200) diff += 365;
    if (diff > 200) diff -= 365;
    if (diff.abs() > 12) continue;
    final p2 = precess(hmsToDeg(s.raStr), dmsToDeg(s.decStr), jdNow);
    var bestAlt = -90.0;
    double? bestJd;
    if (dusk != null && dawn != null) {
      for (var jd = dusk; jd <= dawn; jd += 1 / 48) {
        final aa = eqToAltAz(p2.ra, p2.dec, lat, lon, jd);
        if (aa.alt > bestAlt) {
          bestAlt = aa.alt;
          bestJd = jd;
        }
      }
    }
    out.add(ShowerView(s, diff, bestAlt, bestJd));
  }
  out.sort((a, b) => a.diff.abs().compareTo(b.diff.abs()));
  return out;
}
