// Moon phase instants and the forward-looking night calendar: the part of the
// almanac that answers "which night should I drive out on", rather than
// "what is in the sky right now". Free of Flutter imports like the rest of the
// engine, so `dart test` can check it on its own.

import 'dart:math' as math;
import 'engine.dart';

/// Mean length of a lunation. The real interval between consecutive New Moons
/// swings between roughly 29.27 and 29.83 days, so this is only ever used to
/// bound a search, never to predict a date.
const double synodicMonth = 29.530588853;

/// Difference between Terrestrial Time, which the Meeus series are written in,
/// and the Universal Time a clock shows.
///
/// The rest of the engine ignores this, and rightly so: seventy seconds moves
/// a star less than its own twinkle. It matters here only because a phase is
/// reported as an instant on a civil clock, and a New Moon falling a minute
/// either side of local midnight lands on a different calendar day.
///
/// A constant, not the usual Espenak and Meeus polynomial. That polynomial was
/// fitted when the Earth was still slowing and projects 75.4 seconds for 2026,
/// but the spin stopped slowing around 2017 and the real figure has sat within
/// half a second of 69 ever since: TT runs 32.184 s ahead of TAI by definition,
/// TAI has run 37 s ahead of UTC since the last leap second at the end of 2016,
/// and UT1 is steered to within 0.9 s of UTC. Extrapolating the old curve is
/// six seconds of invented drift.
///
/// This needs revisiting if a leap second is ever inserted again, which would
/// move it by a whole second in one step.
double deltaTSeconds(double jd) => 69.2;

/// Nutation in longitude, to the same single-term accuracy the Sun's apparent
/// longitude already uses.
double nutationLon(double jd) =>
    -0.00478 * math.sin((125.04 - 1934.136 * jcent(jd)) * d2r);

/// Moon minus Sun in apparent geocentric ecliptic longitude, folded to
/// -180..180 degrees.
///
/// Two corrections sit between a geometric longitude and an apparent one, and
/// they behave very differently inside a difference like this.
///
/// Nutation is common-mode: it swings both bodies together, so it cancels, and
/// all that is required is consistency. `sunEcliptic` already carries it while
/// `moonEcliptic` does not, which is why it is added back to the Moon here —
/// whereupon it duly cancels and the two are in the same frame.
///
/// Aberration does not cancel. It shifts the Sun by about -20.8 arcseconds and
/// the Moon by essentially nothing, so dropping it biases every phase in the
/// same direction. The elongation closes at roughly 1890 arcseconds an hour,
/// which turns those 21 arcseconds into some 40 seconds of time. `sunEcliptic`
/// includes it, so this comes out right; a library that leaves it off reports
/// every New Moon about 40 seconds early, comfortably inside its positional
/// accuracy and comfortably outside its timing.
double moonSunElong(double jd) =>
    norm180(moonEcliptic(jd).lon + nutationLon(jd) - sunEcliptic(jd).lon);

/// The four quarters, as the angle by which the Moon leads the Sun.
///
/// Named for what the sky does, not for the ค่ำ of the Thai lunar calendar.
/// The two only loosely coincide: the Thai months run on an arithmetic
/// scheme, so a quarter Moon does not reliably land on ขึ้น ๘ ค่ำ, and even
/// the New Moon falls sometimes on แรม ๑๔ ค่ำ, sometimes on แรม ๑๕ ค่ำ and
/// sometimes on ขึ้น ๑ ค่ำ. Printing a ค่ำ next to a computed instant would be
/// wrong about one day in several.
enum Phase {
  newMoon(0.0, 'จันทร์ดับ', 'ฟ้ามืดที่สุด'),
  firstQuarter(90.0, 'กึ่งดวง ข้างขึ้น', 'ตกราวเที่ยงคืน ครึ่งหลังของคืนมืด'),
  fullMoon(180.0, 'จันทร์เพ็ญ', 'สว่างทั้งคืน'),
  lastQuarter(270.0, 'กึ่งดวง ข้างแรม', 'ขึ้นราวเที่ยงคืน ครึ่งแรกของคืนมืด');

  final double angle;
  final String th, note;
  const Phase(this.angle, this.th, this.note);
}

class PhaseEvent {
  final Phase phase;

  /// Julian Day of the instant, on the UT scale the rest of the app uses.
  final double jd;
  const PhaseEvent(this.phase, this.jd);

  DateTime get local => DateTime.fromMillisecondsSinceEpoch(msFromJd(jd));
}

/// The instant the Moon next leads the Sun by [target] degrees, searching
/// forward from [from].
///
/// Solved by bisection on the elongation rather than by Meeus' chapter 49
/// series, because this app already carries a lunar theory that reproduces his
/// example 47.a to six decimals, and a second set of coefficients would be one
/// more thing to keep true. The elongation climbs about 12.19 degrees a day, so
/// an hourly scan cannot step over a crossing.
double? phaseAfter(double from, double target) {
  double f(double jd) => norm180(moonSunElong(jd) - target);

  const step = 1 / 24.0;
  var a = from, fa = f(a);
  final limit = from + synodicMonth + 2;
  for (var b = from + step; b < limit; b += step) {
    final fb = f(b);
    if (fa < 0 && fb >= 0) {
      var lo = a, hi = b;
      // 40 halvings of an hour is far below the accuracy of the theory itself;
      // it costs nothing and removes the iteration count as a thing to think
      // about.
      for (var i = 0; i < 40; i++) {
        final mid = (lo + hi) / 2;
        if (f(mid) < 0) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      final jde = (lo + hi) / 2;
      return jde - deltaTSeconds(jde) / 86400.0;
    }
    a = b;
    fa = fb;
  }
  return null;
}

double? nextNewMoon(double from) => phaseAfter(from, 0);

/// The New Moon before [jd], which is what the Moon's age counts from.
///
/// The search window has to be wider than a lunation to be sure of catching
/// one, which means it can just as easily catch two: on the night after a New
/// Moon the window reaches back past the one before it as well. Taking the
/// first hit would report an age of twenty-nine days on a night when the Moon
/// is a day old, so the second is checked for.
double? lastNewMoon(double jd) {
  final first = phaseAfter(jd - synodicMonth - 2, 0);
  if (first == null) return null;
  final second = phaseAfter(first + 1, 0);
  return (second != null && second <= jd) ? second : first;
}

/// Every quarter falling in the next [days] days, in time order.
List<PhaseEvent> upcomingPhases(double from, int days) {
  final out = <PhaseEvent>[];
  final until = from + days;
  for (final p in Phase.values) {
    var t = from;
    while (true) {
      final jd = phaseAfter(t, p.angle);
      if (jd == null || jd > until) break;
      out.add(PhaseEvent(p, jd));
      t = jd + 1;
    }
  }
  out.sort((x, y) => x.jd.compareTo(y.jd));
  return out;
}

// --------------------------------------------------------------- the nights

/// How finely a night is sampled when measuring its dark hours. Five minutes
/// bounds the error on each edge of a window at five minutes, which is well
/// under the precision anyone reads off a planning calendar.
const double _nightStep = 5 / 1440.0;

/// How much of a Full Moon's glare is in play, 0 to 1, for a Moon [illum] lit
/// and [altDeg] above the horizon.
///
/// Moonlight does not scale with the illuminated fraction, and not by a tidy
/// power of it either. Half the disc lit is about a tenth of the light, not a
/// half: the lit area halves, and on top of that the Moon's albedo collapses
/// as the phase angle opens and the rough surface shadows itself. A linear
/// penalty would throw away every usable quarter-Moon evening.
///
/// Rather than invent a curve, this runs the brightness law `bodyPosition`
/// already uses for the Moon's magnitude backwards: recover the phase angle
/// from the illuminated fraction, ask that law how many magnitudes fainter
/// than Full the Moon is, and turn it back into a flux ratio. The two stay in
/// step by construction, and it lands on 9.1 per cent at half and 2.6 per cent
/// at a quarter, which is where the published sky-brightness models put it.
///
/// The altitude ramp is a plain approximation of a real airmass-and-scattering
/// term: a Moon sitting on the horizon lights the sky far less than one
/// overhead, and one below it lights nothing at all.
double moonGlare(double illum, double altDeg) {
  if (altDeg <= 0) return 0.0;
  final a = math.acos(clampD(2 * clampD(illum, 0, 1) - 1, -1, 1)) * r2d;
  final dm = 0.026 * a + 4e-9 * ipow(a, 4);
  return math.pow(10, -0.4 * dm).toDouble() * clampD((altDeg + 5) / 45, 0, 1);
}

/// One night's worth of the things that decide whether it is worth going out.
class NightQuality {
  /// Date the evening belongs to, at local midnight.
  final DateTime evening;

  /// Hours between the end of astronomical twilight and its return.
  final double darkHours;

  /// The part of those hours with the Moon below the horizon. This is the
  /// number that actually matters for faint objects, and it is why a thin
  /// waning crescent beats a thin waxing one: the waning Moon holds off until
  /// the small hours, the waxing one sits in the evening sky.
  final double moonFreeHours;

  /// Illuminated fraction at the middle of the dark window, 0 to 1.
  final double illum;

  /// Highest the Moon climbs while the sky is astronomically dark, in degrees.
  /// Negative means it never rose during the dark window.
  final double moonAltMax;

  /// Dark hours after discounting each one by how much the Moon was washing
  /// the sky out at the time. Equal to [darkHours] on a night with no Moon up
  /// at all, and close to it under a thin crescent, which costs less than the
  /// night-to-night wobble of the airglow.
  final double effectiveDarkHours;

  /// Nights since the last New Moon, which is what the Thai lunar calendar
  /// counts in ค่ำ.
  final double moonAge;

  /// Start and end of the longest unbroken moonless stretch of darkness.
  final double? bestFrom, bestTo;

  const NightQuality({
    required this.evening,
    required this.darkHours,
    required this.moonFreeHours,
    required this.illum,
    required this.moonAltMax,
    required this.effectiveDarkHours,
    required this.moonAge,
    this.bestFrom,
    this.bestTo,
  });

  /// 0 to 1, for ranking and for colouring a calendar cell: the share of the
  /// night's darkness that the Moon leaves alone.
  double get score =>
      darkHours <= 0 ? 0.0 : clampD(effectiveDarkHours / darkHours, 0, 1);

  /// Plain Thai for the headline on a calendar cell.
  String get verdict {
    final s = score;
    if (s >= 0.85) return 'ดีเยี่ยม';
    if (s >= 0.65) return 'ดี';
    if (s >= 0.4) return 'พอดูได้';
    if (moonFreeHours < 0.5) return 'จันทร์ส่องเกือบทั้งคืน';
    return 'ไม่เหมาะกับดาวจาง';
  }
}

/// Measures [nights] nights starting with the evening of [from].
///
/// Sun and Moon altitudes are sampled on a five-minute grid rather than solved
/// for, because the question asked of them here is how *much* of the night is
/// dark and moonless, not exactly when it starts. One pass over the grid
/// answers both and costs a few milliseconds for a two-month calendar.
List<NightQuality> nightCalendar(
    DateTime from, int nights, double lat, double lon, double h) {
  final jdStart = jdFromMs(DateTime(from.year, from.month, from.day)
      .millisecondsSinceEpoch);
  // Every New Moon the span could need, found once. Searching per night
  // instead would repeat the same month-long scan sixty times over.
  final newMoons = <double>[];
  var t = jdStart - synodicMonth - 2;
  while (t < jdStart + nights + 2) {
    final nm = phaseAfter(t, 0);
    if (nm == null) break;
    newMoons.add(nm);
    t = nm + 1;
  }

  final out = <NightQuality>[];
  for (var n = 0; n < nights; n++) {
    final evening = DateTime(from.year, from.month, from.day + n);
    out.add(nightQualityAt(evening, lat, lon, h, newMoons: newMoons));
  }
  return out;
}

/// Everything the planning view needs for one place and one starting date.
class Planner {
  final String key;
  final List<NightQuality> nights;
  final List<PhaseEvent> phases;
  const Planner(this.key, this.nights, this.phases);

  List<PhaseEvent> get newMoons =>
      phases.where((p) => p.phase == Phase.newMoon).toList();
}

Planner? _cache;

/// Sweeping sixty nights is far too slow to repeat on a clock tick, and the
/// almanac's shared memo is not a safe home for it: that map is keyed by the
/// minute elsewhere in the app and wipes itself wholesale once it fills, which
/// would drop this on the floor every few hours mid-session. One slot of its
/// own, in the manner of the almanac cache, keeps it until the date or the
/// place actually changes.
Planner planner(DateTime from, int nights, double lat, double lon, double h) {
  final key = '${from.toIso8601String().substring(0, 10)}|$nights'
      '|${lat.toStringAsFixed(3)}|${lon.toStringAsFixed(3)}|$h';
  final c = _cache;
  if (c != null && c.key == key) return c;
  final p = Planner(
    key,
    nightCalendar(from, nights, lat, lon, h),
    upcomingPhases(jdFromMs(DateTime(from.year, from.month, from.day)
        .millisecondsSinceEpoch), nights),
  );
  _cache = p;
  return p;
}

/// One night on its own, for callers that want a single date rather than a run
/// of them. [jdOverride] takes the place of local midnight on [evening], which
/// is what lets a test pin an exact instant instead of inheriting whatever
/// zone the machine running it happens to sit in.
NightQuality nightQualityAt(DateTime evening, double lat, double lon, double h,
    {List<double>? newMoons, double? jdOverride}) {
  final jd0 = jdOverride ?? jdFromMs(evening.millisecondsSinceEpoch);
  // Noon to noon, so the whole night sits inside the window whatever the
  // season does to sunset.
  final start = jd0 + 0.5, end = jd0 + 1.5;

  var dark = 0.0, free = 0.0, effective = 0.0;
  var moonAltMax = -90.0;
  double? runFrom, bestFrom, bestTo;
  var bestLen = 0.0;
  final mid = <double>[];

  for (var jd = start; jd <= end; jd += _nightStep) {
    final sunAlt = bodyPosition('sun', jd, lat, lon, h).alt;
    if (sunAlt >= -18) {
      if (runFrom != null) {
        if (jd - runFrom > bestLen) {
          bestLen = jd - runFrom;
          bestFrom = runFrom;
          bestTo = jd;
        }
        runFrom = null;
      }
      continue;
    }
    dark += _nightStep;
    mid.add(jd);
    final m = bodyPosition('moon', jd, lat, lon, h);
    final moonAlt = m.alt;
    if (moonAlt > moonAltMax) moonAltMax = moonAlt;
    effective += _nightStep * (1 - moonGlare(m.illum ?? 0, moonAlt));
    if (moonAlt <= 0) {
      free += _nightStep;
      runFrom ??= jd;
    } else if (runFrom != null) {
      if (jd - runFrom > bestLen) {
        bestLen = jd - runFrom;
        bestFrom = runFrom;
        bestTo = jd;
      }
      runFrom = null;
    }
  }
  if (runFrom != null && end - runFrom > bestLen) {
    bestLen = end - runFrom;
    bestFrom = runFrom;
    bestTo = end;
  }

  // Phase read at the middle of the dark window, not at midnight: on a night
  // whose darkness is lopsided the Moon that matters is the one overhead then.
  final sampleJd = mid.isEmpty ? jd0 + 1 : mid[mid.length ~/ 2];
  final m = bodyPosition('moon', sampleJd, lat, lon, h);
  double? prev;
  for (final nm in (newMoons ?? const <double>[])) {
    if (nm <= sampleJd) prev = nm;
  }
  prev ??= lastNewMoon(sampleJd);

  return NightQuality(
    evening: evening,
    darkHours: dark * 24,
    moonFreeHours: free * 24,
    illum: m.illum ?? 0,
    moonAltMax: moonAltMax,
    effectiveDarkHours: effective * 24,
    moonAge: prev == null ? (m.age ?? 0) : sampleJd - prev,
    bestFrom: bestFrom,
    bestTo: bestTo,
  );
}
