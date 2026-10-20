// Positional astronomy for naked-eye observing.
//
// A direct port of a JavaScript implementation that was checked against the
// worked examples in Meeus, "Astronomical Algorithms": the Moon agrees with
// example 47.a to six decimal places and the Sun with 25.b to 1e-5 degrees.
// test/engine_test.dart pins those same numbers, so a mistake in this port
// shows up the first time the suite runs.
//
// No Flutter imports here on purpose: this file is plain Dart and runs under
// `dart test` on its own.

import 'dart:math' as math;

const double d2r = math.pi / 180.0;
const double r2d = 180.0 / math.pi;
const double eps2000 = 23.4392911;

double _sin(double x) => math.sin(x);
double _cos(double x) => math.cos(x);
double _tan(double x) => math.tan(x);

double norm360(double x) {
  x = x % 360.0;
  return x < 0 ? x + 360.0 : x;
}

double norm180(double x) {
  x = norm360(x);
  return x > 180.0 ? x - 360.0 : x;
}

double clampD(double v, double a, double b) => v < a ? a : (v > b ? b : v);

/// Integer power kept in double arithmetic. `math.pow` returns `num`, which
/// does not assign to `double` without a cast and would silently widen the
/// magnitude formulas below.
double ipow(double x, int n) {
  var r = 1.0;
  for (var k = 0; k < n; k++) {
    r *= x;
  }
  return r;
}

double jdFromMs(int ms) => ms / 86400000.0 + 2440587.5;
int msFromJd(double jd) => ((jd - 2440587.5) * 86400000.0).round();
double jcent(double jd) => (jd - 2451545.0) / 36525.0;

/// Greenwich mean sidereal time, degrees.
double gmst(double jd) {
  final t = jcent(jd);
  return norm360(280.46061837 +
      360.98564736629 * (jd - 2451545.0) +
      0.000387933 * t * t -
      t * t * t / 38710000.0);
}

/// Mean obliquity with the leading nutation term, degrees.
double obliquity(double jd) {
  final t = jcent(jd);
  final e0 = 23.439291111 -
      0.0130041667 * t -
      1.6389e-7 * t * t +
      5.0361e-7 * t * t * t;
  return e0 + 0.00256 * _cos((125.04452 - 1934.136261 * t) * d2r);
}

class Ecliptic {
  final double lon, lat, dist; // dist: AU for the Sun
  const Ecliptic(this.lon, this.lat, this.dist);
}

/// Sun, ecliptic of date (Meeus ch. 25).
Ecliptic sunEcliptic(double jd) {
  final t = jcent(jd);
  final l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
  final m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t;
  final e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t;
  final mr = m * d2r;
  final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * _sin(mr) +
      (0.019993 - 0.000101 * t) * _sin(2 * mr) +
      0.000289 * _sin(3 * mr);
  final trueLong = l0 + c;
  final v = m + c;
  final rad = (1.000001018 * (1 - e * e)) / (1 + e * _cos(v * d2r));
  final om = 125.04 - 1934.136 * t;
  return Ecliptic(
      norm360(trueLong - 0.00569 - 0.00478 * _sin(om * d2r)), 0.0, rad);
}

// ELP2000-82 abridged (Meeus ch. 47).
// Each row: D, M, M', F, sigma-l (1e-6 deg), sigma-r (1e-3 km).
const List<List<double>> _mLR = [
  [0, 0, 1, 0, 6288774, -20905355], [2, 0, -1, 0, 1274027, -3699111],
  [2, 0, 0, 0, 658314, -2955968], [0, 0, 2, 0, 213618, -569925],
  [0, 1, 0, 0, -185116, 48888], [0, 0, 0, 2, -114332, -3149],
  [2, 0, -2, 0, 58793, 246158], [2, -1, -1, 0, 57066, -152138],
  [2, 0, 1, 0, 53322, -170733], [2, -1, 0, 0, 45758, -204586],
  [0, 1, -1, 0, -40923, -129620], [1, 0, 0, 0, -34720, 108743],
  [0, 1, 1, 0, -30383, 104755], [2, 0, 0, -2, 15327, 10321],
  [0, 0, 1, 2, -12528, 0], [0, 0, 1, -2, 10980, 79661],
  [4, 0, -1, 0, 10675, -34782], [0, 0, 3, 0, 10034, -23210],
  [4, 0, -2, 0, 8548, -21636], [2, 1, -1, 0, -7888, 24208],
  [2, 1, 0, 0, -6766, 30824], [1, 0, -1, 0, -5163, -8379],
  [1, 1, 0, 0, 4987, -16675], [2, -1, 1, 0, 4036, -12831],
  [2, 0, 2, 0, 3994, -10445], [4, 0, 0, 0, 3861, -11650],
  [2, 0, -3, 0, 3665, 14403], [0, 1, -2, 0, -2689, -7003],
  [2, 0, -1, 2, -2602, 0], [2, -1, -2, 0, 2390, 10056],
  [1, 0, 1, 0, -2348, 6322], [2, -2, 0, 0, 2236, -9884],
  [0, 1, 2, 0, -2120, 5751], [0, 2, 0, 0, -2069, 0],
  [2, -2, -1, 0, 2048, -4950], [2, 0, 1, -2, -1773, 4130],
  [2, 0, 0, 2, -1595, 0], [4, -1, -1, 0, 1215, -3958],
  [0, 0, 2, 2, -1110, 0], [3, 0, -1, 0, -892, 3258],
  [2, 1, 1, 0, -810, 2616], [4, -1, -2, 0, 759, -1897],
  [0, 2, -1, 0, -713, -2117], [2, 2, -1, 0, -700, 2354],
  [2, 1, -2, 0, 691, 0], [2, -1, 0, -2, 596, 0],
  [4, 0, 1, 0, 549, -1423], [0, 0, 4, 0, 537, -1117],
  [4, -1, 0, 0, 520, -1571], [1, 0, -2, 0, -487, -1739],
  [2, 1, 0, -2, -399, 0], [0, 0, 2, -2, -381, -4421],
  [1, 1, 1, 0, 351, 0], [3, 0, -2, 0, -340, 0],
  [4, 0, -3, 0, 330, 0], [2, -1, 2, 0, 327, 0],
  [0, 2, 1, 0, -323, 1165], [1, 1, -1, 0, 299, 0],
  [2, 0, 3, 0, 294, 0], [2, 0, -1, -2, 0, 8752],
];

// Each row: D, M, M', F, sigma-b (1e-6 deg).
const List<List<double>> _mB = [
  [0, 0, 0, 1, 5128122], [0, 0, 1, 1, 280602], [0, 0, 1, -1, 277693],
  [2, 0, 0, -1, 173237], [2, 0, -1, 1, 55413], [2, 0, -1, -1, 46271],
  [2, 0, 0, 1, 32573], [0, 0, 2, 1, 17198], [2, 0, 1, -1, 9266],
  [0, 0, 2, -1, 8822], [2, -1, 0, -1, 8216], [2, 0, -2, -1, 4324],
  [2, 0, 1, 1, 4200], [2, 1, 0, -1, -3359], [2, -1, -1, 1, 2463],
  [2, -1, 0, 1, 2211], [2, -1, -1, -1, 2065], [0, 1, -1, -1, -1870],
  [4, 0, -1, -1, 1828], [0, 1, 0, 1, -1794], [0, 0, 0, 3, -1749],
  [0, 1, -1, 1, -1565], [1, 0, 0, 1, -1491], [0, 1, 1, 1, -1475],
  [0, 1, 1, -1, -1410], [0, 1, 0, -1, -1344], [1, 0, 0, -1, -1335],
  [0, 0, 3, 1, 1107], [4, 0, 0, -1, 1021], [4, 0, -1, 1, 833],
  [0, 0, 1, -3, 777], [4, 0, -2, 1, 671], [2, 0, 0, -3, 607],
  [2, 0, 2, -1, 596], [2, -1, 1, -1, 491], [2, 0, -2, 1, -451],
  [0, 0, 3, -1, 439], [2, 0, 2, 1, 422], [2, 0, -3, -1, 421],
  [2, 1, -1, 1, -366], [2, 1, 0, 1, -351], [4, 0, 0, 1, 331],
  [2, -1, 1, 1, 315], [2, -2, 0, -1, 302], [0, 0, 1, 3, -283],
  [2, 1, 1, -1, -229], [1, 1, 0, -1, 223], [1, 1, 0, 1, 223],
  [0, 1, -2, -1, -220], [2, 1, -1, -1, -220], [1, 0, 1, 1, -185],
  [2, -1, -2, -1, 181], [0, 1, 2, 1, -177], [4, 0, -2, -1, 176],
  [4, -1, -1, -1, 166], [1, 0, 1, -1, -164], [4, 0, 1, -1, 132],
  [1, 0, -1, -1, -119], [4, -1, 0, -1, 115], [2, -2, 0, 1, 107],
];

class MoonPos {
  final double lon, lat, distKm;
  const MoonPos(this.lon, this.lat, this.distKm);
  double get au => distKm / 149597870.7;
}

MoonPos moonEcliptic(double jd) {
  final t = jcent(jd);
  final lp = norm360(218.3164477 +
      481267.88123421 * t -
      0.0015786 * t * t +
      t * t * t / 538841.0 -
      t * t * t * t / 65194000.0);
  final dd = norm360(297.8501921 +
      445267.1114034 * t -
      0.0018819 * t * t +
      t * t * t / 545868.0 -
      t * t * t * t / 113065000.0);
  final m = norm360(357.5291092 +
      35999.0502909 * t -
      0.0001536 * t * t +
      t * t * t / 24490000.0);
  final mp = norm360(134.9633964 +
      477198.8675055 * t +
      0.0087414 * t * t +
      t * t * t / 69699.0 -
      t * t * t * t / 14712000.0);
  final f = norm360(93.2720950 +
      483202.0175233 * t -
      0.0036539 * t * t -
      t * t * t / 3526000.0 +
      t * t * t * t / 863310000.0);
  final a1 = norm360(119.75 + 131.849 * t);
  final a2 = norm360(53.09 + 479264.290 * t);
  final a3 = norm360(313.45 + 481266.484 * t);
  final e = 1 - 0.002516 * t - 0.0000074 * t * t;

  double sl = 0, sr = 0, sb = 0;
  for (final q in _mLR) {
    final arg = (q[0] * dd + q[1] * m + q[2] * mp + q[3] * f) * d2r;
    final mm = q[1];
    final fac = mm == 0 ? 1.0 : (mm.abs() == 1 ? e : e * e);
    sl += q[4] * fac * _sin(arg);
    sr += q[5] * fac * _cos(arg);
  }
  for (final q in _mB) {
    final arg = (q[0] * dd + q[1] * m + q[2] * mp + q[3] * f) * d2r;
    final mm = q[1];
    final fac = mm == 0 ? 1.0 : (mm.abs() == 1 ? e : e * e);
    sb += q[4] * fac * _sin(arg);
  }
  sl += 3958 * _sin(a1 * d2r) + 1962 * _sin((lp - f) * d2r) + 318 * _sin(a2 * d2r);
  sb += -2235 * _sin(lp * d2r) +
      382 * _sin(a3 * d2r) +
      175 * _sin((a1 - f) * d2r) +
      175 * _sin((a1 + f) * d2r) +
      127 * _sin((lp - mp) * d2r) -
      115 * _sin((lp + mp) * d2r);

  return MoonPos(norm360(lp + sl / 1e6), sb / 1e6, 385000.56 + sr / 1000.0);
}

// JPL approximate orbital elements, good to about an arcminute 1800-2050.
// a, e, I, L, long.peri, long.node then their per-century rates.
const Map<String, List<double>> _planetEl = {
  'mercury': [0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593,
    0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081],
  'venus': [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255,
    0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418],
  'earth': [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0,
    0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0],
  'mars': [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891,
    0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343],
  'jupiter': [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909,
    -0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106],
  'saturn': [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448,
    -0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794],
  'uranus': [19.18916464, 0.04725744, 0.77263783, 313.23810451, 170.95427630, 74.01692503,
    -0.00196176, -0.00004397, -0.00242939, 428.48202785, 0.40805281, 0.04240589],
  'neptune': [30.06992276, 0.00859048, 1.77004347, -55.12002969, 44.96476227, 131.78422574,
    0.00026291, 0.00005105, 0.00035372, 218.45945325, -0.32241464, -0.00508664],
};

class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);
  double get r => math.sqrt(x * x + y * y + z * z);
}

Vec3 helioXyz(String name, double jd) {
  final t = jcent(jd);
  final el = _planetEl[name]!;
  final a = el[0] + el[6] * t;
  final e = el[1] + el[7] * t;
  final inc = (el[2] + el[8] * t) * d2r;
  final l = el[3] + el[9] * t;
  final peri = el[4] + el[10] * t;
  final nodeDeg = el[5] + el[11] * t;
  final node = nodeDeg * d2r;
  final w = (peri - nodeDeg) * d2r;
  final m = norm180(l - peri) * d2r;

  var ecc = m + e * _sin(m);
  for (var i = 0; i < 15; i++) {
    final de = (ecc - e * _sin(ecc) - m) / (1 - e * _cos(ecc));
    ecc -= de;
    if (de.abs() < 1e-13) break;
  }
  final xv = a * (_cos(ecc) - e);
  final yv = a * math.sqrt(1 - e * e) * _sin(ecc);
  final cw = _cos(w), sw = _sin(w);
  final cn = _cos(node), sn = _sin(node);
  final ci = _cos(inc), si = _sin(inc);
  return Vec3(
    xv * (cw * cn - sw * sn * ci) + yv * (-sw * cn - cw * sn * ci),
    xv * (cw * sn + sw * cn * ci) + yv * (-sw * sn + cw * cn * ci),
    xv * (sw * si) + yv * (cw * si),
  );
}

class PlanetPos {
  final double lon, lat, dist, r, bigR;
  const PlanetPos(this.lon, this.lat, this.dist, this.r, this.bigR);
}

/// Geocentric J2000-ecliptic position, corrected for light time.
PlanetPos planetEcliptic(String name, double jd) {
  final e = helioXyz('earth', jd);
  var p = helioXyz(name, jd);
  double dx = 0, dy = 0, dz = 0, dist = 0;
  for (var i = 0; i < 3; i++) {
    dx = p.x - e.x;
    dy = p.y - e.y;
    dz = p.z - e.z;
    dist = math.sqrt(dx * dx + dy * dy + dz * dz);
    p = helioXyz(name, jd - dist * 0.0057755183);
  }
  dx = p.x - e.x;
  dy = p.y - e.y;
  dz = p.z - e.z;
  dist = math.sqrt(dx * dx + dy * dy + dz * dz);
  return PlanetPos(norm360(math.atan2(dy, dx) * r2d),
      math.asin(dz / dist) * r2d, dist, p.r, e.r);
}

class Equatorial {
  final double ra, dec;
  const Equatorial(this.ra, this.dec);
}

Equatorial eclToEq(double lon, double lat, double eps) {
  final l = lon * d2r, b = lat * d2r, e = eps * d2r;
  final ra = math.atan2(_sin(l) * _cos(e) - _tan(b) * _sin(e), _cos(l));
  final dec = math.asin(_sin(b) * _cos(e) + _cos(b) * _sin(e) * _sin(l));
  return Equatorial(norm360(ra * r2d), dec * r2d);
}

class AltAz {
  final double alt, az, ha, lst;
  const AltAz(this.alt, this.az, this.ha, this.lst);
}

AltAz eqToAltAz(double ra, double dec, double lat, double lon, double jd) {
  final lst = norm360(gmst(jd) + lon);
  final h = (lst - ra) * d2r, dd = dec * d2r, p = lat * d2r;
  final alt = math.asin(_sin(dd) * _sin(p) + _cos(dd) * _cos(p) * _cos(h));
  final az = math.atan2(
      -_cos(dd) * _sin(h), _sin(dd) * _cos(p) - _cos(dd) * _sin(p) * _cos(h));
  return AltAz(alt * r2d, norm360(az * r2d), norm180(h * r2d), lst);
}

/// True altitude to apparent altitude, degrees.
double refract(double alt) {
  if (alt < -2) return alt;
  return alt + 1.02 / _tan((alt + 10.3 / (alt + 5.11)) * d2r) / 60.0;
}

Equatorial precess(double ra0, double dec0, double jd) {
  final t = jcent(jd);
  final z0 = (2306.2181 * t + 0.30188 * t * t + 0.017998 * t * t * t) / 3600 * d2r;
  final z1 = (2306.2181 * t + 1.09468 * t * t + 0.018203 * t * t * t) / 3600 * d2r;
  final th = (2004.3109 * t - 0.42665 * t * t - 0.041833 * t * t * t) / 3600 * d2r;
  final a0 = ra0 * d2r, d0 = dec0 * d2r;
  final a = _cos(d0) * _sin(a0 + z0);
  final b = _cos(th) * _cos(d0) * _cos(a0 + z0) - _sin(th) * _sin(d0);
  final c = _sin(th) * _cos(d0) * _cos(a0 + z0) + _cos(th) * _sin(d0);
  return Equatorial(
      norm360(math.atan2(a, b) * r2d + z1 * r2d), math.asin(clampD(c, -1, 1)) * r2d);
}

/// Shift from the Earth's centre to the observer. For the Moon this reaches a
/// degree, which is two full Moon widths, so it is never optional.
Equatorial topocentric(double ra, double dec, double distAu, double lat,
    double lon, double jd, double heightM) {
  final sinPi = _sin((8.794 / 3600) * d2r) / distAu;
  final h = heightM / 6378140.0, p = lat * d2r;
  final u = math.atan(0.99664719 * _tan(p));
  final rhoSin = 0.99664719 * _sin(u) + h * _sin(p);
  final rhoCos = _cos(u) + h * _cos(p);
  final lst = norm360(gmst(jd) + lon);
  final hh = (lst - ra) * d2r, dd = dec * d2r;
  final dRa = math.atan2(
      -rhoCos * sinPi * _sin(hh), _cos(dd) - rhoCos * sinPi * _cos(hh));
  final dec2 = math.atan2((_sin(dd) - rhoSin * sinPi) * _cos(dRa),
      _cos(dd) - rhoCos * sinPi * _cos(hh));
  return Equatorial(norm360(ra + dRa * r2d), dec2 * r2d);
}

double phaseAngle(double r, double dist, double bigR) {
  final c = (r * r + dist * dist - bigR * bigR) / (2 * r * dist);
  return math.acos(clampD(c, -1, 1)) * r2d;
}

double planetMag(String name, double r, double dist, double bigR) {
  final i = phaseAngle(r, dist, bigR);
  final l = 5 * (math.log(r * dist) / math.ln10);
  switch (name) {
    case 'mercury':
      return -0.613 + l + 6.3280e-2 * i - 1.6336e-3 * i * i +
          3.3644e-5 * ipow(i, 3) - 3.4265e-7 * ipow(i, 4) +
          1.6893e-9 * ipow(i, 5) - 3.0334e-12 * ipow(i, 6);
    case 'venus':
      return i < 163.7
          ? -4.384 + l - 1.044e-3 * i + 3.687e-4 * i * i -
              2.814e-6 * ipow(i, 3) + 8.938e-9 * ipow(i, 4)
          : 236.05828 + l - 2.81914 * i + 8.39034e-3 * i * i;
    case 'mars':
      return -1.601 + l + 0.02267 * i - 0.0001302 * i * i;
    case 'jupiter':
      return -9.395 + l + 0.0005 * i;
    case 'saturn':
      return -8.914 + l + 0.026 * i; // rings ignored, worth up to 0.4 mag
    case 'uranus':
      return -7.110 + l;
    case 'neptune':
      return -7.00 + l;
  }
  return 0;
}

class Body {
  final String id, en, th;
  final int color;
  final String kind;
  final double size;
  const Body(this.id, this.en, this.th, this.color, this.kind, this.size);
}

const List<Body> bodies = [
  Body('sun', 'Sun', 'ดวงอาทิตย์', 0xFFFFD257, 'sun', 2.4),
  Body('moon', 'Moon', 'ดวงจันทร์', 0xFFE8ECF5, 'moon', 2.4),
  Body('mercury', 'Mercury', 'ดาวพุธ', 0xFFCBBBA2, 'planet', 1.0),
  Body('venus', 'Venus', 'ดาวศุกร์', 0xFFFFF3CE, 'planet', 1.5),
  Body('mars', 'Mars', 'ดาวอังคาร', 0xFFFF8A6B, 'planet', 1.2),
  Body('jupiter', 'Jupiter', 'ดาวพฤหัสบดี', 0xFFFFD9A0, 'planet', 1.5),
  Body('saturn', 'Saturn', 'ดาวเสาร์', 0xFFF2DFA8, 'planet', 1.3),
  Body('uranus', 'Uranus', 'ดาวยูเรนัส', 0xFFA8E8E0, 'planet', 0.9),
  Body('neptune', 'Neptune', 'ดาวเนปจูน', 0xFF9BB8FF, 'planet', 0.9),
];

double moonPhaseAngle(MoonPos m, Ecliptic s) {
  final psi = math.acos(
          clampD(_cos(m.lat * d2r) * _cos((m.lon - s.lon) * d2r), -1, 1)) *
      r2d;
  final bigR = s.dist * 149597870.7;
  return math.atan2(bigR * _sin(psi * d2r), m.distKm - bigR * _cos(psi * d2r)) *
      r2d;
}

/// Everything the app needs about one solar-system body at one instant.
class BodyPosition {
  final String id;
  final double ra, dec, alt, altApp, az, ha, mag;
  final double? distAu, distKm, angSize, illum, elong, age, phase, sunDistAu;
  final bool? waxing, eastOfSun;

  const BodyPosition({
    required this.id,
    required this.ra,
    required this.dec,
    required this.alt,
    required this.altApp,
    required this.az,
    required this.ha,
    required this.mag,
    this.distAu,
    this.distKm,
    this.angSize,
    this.illum,
    this.elong,
    this.age,
    this.phase,
    this.sunDistAu,
    this.waxing,
    this.eastOfSun,
  });
}

BodyPosition bodyPosition(
    String id, double jd, double lat, double lon, double height) {
  Equatorial eq;
  double mag = 0;
  double? distAu, distKm, angSize, illum, elong, age, phase, sunDistAu;
  bool? waxing, eastOfSun;

  if (id == 'sun') {
    final ecl = sunEcliptic(jd);
    eq = eclToEq(ecl.lon, ecl.lat, obliquity(jd));
    mag = -26.7;
    distAu = ecl.dist;
    angSize = 1919.3 / ecl.dist / 60.0;
  } else if (id == 'moon') {
    final ecl = moonEcliptic(jd);
    final s = sunEcliptic(jd);
    final i = moonPhaseAngle(ecl, s);
    elong = norm360(ecl.lon - s.lon);
    illum = (1 + _cos(i * d2r)) / 2;
    waxing = elong < 180;
    age = elong / 360.0 * 29.530588853;
    distKm = ecl.distKm;
    distAu = ecl.au;
    angSize = 2 * math.atan(1737.4 / ecl.distKm) * r2d * 60;
    mag = -12.73 + 0.026 * i.abs() + 4e-9 * ipow(i.abs(), 4);
    final g = eclToEq(ecl.lon, ecl.lat, obliquity(jd));
    eq = topocentric(g.ra, g.dec, ecl.au, lat, lon, jd, height);
  } else {
    final p = planetEcliptic(id, jd);
    final j2 = eclToEq(p.lon, p.lat, eps2000);
    eq = precess(j2.ra, j2.dec, jd);
    mag = planetMag(id, p.r, p.dist, p.bigR);
    distAu = p.dist;
    sunDistAu = p.r;
    phase = (1 + _cos(phaseAngle(p.r, p.dist, p.bigR) * d2r)) / 2;
    final s = sunEcliptic(jd);
    final lonDate = norm360(p.lon + 1.396971 * jcent(jd));
    elong = math.acos(
            clampD(_cos(p.lat * d2r) * _cos((lonDate - s.lon) * d2r), -1, 1)) *
        r2d;
    eastOfSun = norm360(lonDate - s.lon) < 180;
  }

  final aa = eqToAltAz(eq.ra, eq.dec, lat, lon, jd);
  return BodyPosition(
    id: id,
    ra: eq.ra,
    dec: eq.dec,
    alt: aa.alt,
    altApp: refract(aa.alt),
    az: aa.az,
    ha: aa.ha,
    mag: mag,
    distAu: distAu,
    distKm: distKm,
    angSize: angSize,
    illum: illum,
    elong: elong,
    age: age,
    phase: phase,
    sunDistAu: sunDistAu,
    waxing: waxing,
    eastOfSun: eastOfSun,
  );
}

/// Dip of the horizon seen from height h: 1.76' * sqrt(h in metres).
/// At the national observatory (2457 m) this is 1.45 degrees, which moves
/// sunset by several minutes.
double horizonDip(double h) => h > 0 ? 0.0293 * math.sqrt(h) : 0.0;

double standardAlt(String id, double h) {
  final base = id == 'sun' ? -0.8333 : (id == 'moon' ? 0.125 : -0.5667);
  return base - horizonDip(h);
}

double _altOf(String id, double jd, double lat, double lon, double h) =>
    bodyPosition(id, jd, lat, lon, h).alt;

class RiseSet {
  final double? rise, set, transit;
  final double maxAlt;
  final bool circumpolar, neverUp;
  const RiseSet(
      {this.rise,
      this.set,
      this.transit,
      this.maxAlt = -99,
      this.circumpolar = false,
      this.neverUp = false});
}

double _bisectAlt(String id, double a, double b, double h0, double lat,
    double lon, double height) {
  for (var i = 0; i < 24; i++) {
    final m = (a + b) / 2;
    final fa = _altOf(id, a, lat, lon, height) - h0;
    final fm = _altOf(id, m, lat, lon, height) - h0;
    if ((fa < 0) == (fm < 0)) {
      a = m;
    } else {
      b = m;
    }
  }
  return (a + b) / 2;
}

RiseSet riseSet(String id, double jd0, double lat, double lon, double height) {
  final h0 = standardAlt(id, height);
  const step = 1 / 144.0;
  var prev = _altOf(id, jd0, lat, lon, height) - h0;
  var prevJd = jd0;
  double? rise, set;
  var maxAlt = -99.0;
  double? maxJd;

  for (var jd = jd0 + step; jd <= jd0 + 1.0000001; jd += step) {
    final a = _altOf(id, jd, lat, lon, height);
    final cur = a - h0;
    if (a > maxAlt) {
      maxAlt = a;
      maxJd = jd;
    }
    if (prev < 0 && cur >= 0 && rise == null) {
      rise = _bisectAlt(id, prevJd, jd, h0, lat, lon, height);
    }
    if (prev > 0 && cur <= 0 && set == null) {
      set = _bisectAlt(id, prevJd, jd, h0, lat, lon, height);
    }
    prev = cur;
    prevJd = jd;
  }

  double? transit = maxJd;
  if (maxJd != null) {
    var a = maxJd - step, b = maxJd + step;
    for (var i = 0; i < 28; i++) {
      final m1 = a + (b - a) / 3, m2 = b - (b - a) / 3;
      if (_altOf(id, m1, lat, lon, height) < _altOf(id, m2, lat, lon, height)) {
        a = m1;
      } else {
        b = m2;
      }
    }
    transit = (a + b) / 2;
    maxAlt = _altOf(id, transit, lat, lon, height);
  }
  return RiseSet(rise: rise, set: set, transit: transit, maxAlt: maxAlt);
}

/// Analytic rise and set for a fixed star: far cheaper than sampling, and the
/// constellation list calls it forty times a repaint.
RiseSet starRiseSet(
    double ra, double dec, double jd0, double lat, double lon, double height) {
  final h0 = -0.5667 - horizonDip(height);
  final p = lat * d2r, d = dec * d2r;
  final cosH = (_sin(h0 * d2r) - _sin(p) * _sin(d)) / (_cos(p) * _cos(d));

  var jdT = jd0;
  for (var i = 0; i < 50; i++) {
    final diff = norm180(ra - norm360(gmst(jdT) + lon));
    jdT += diff / 360.98564736629;
    if (diff.abs() < 1e-8) break;
  }
  while (jdT < jd0) {
    jdT += 0.9972695663;
  }
  while (jdT > jd0 + 1) {
    jdT -= 0.9972695663;
  }

  if (cosH > 1) return RiseSet(transit: jdT, neverUp: true);
  if (cosH < -1) return RiseSet(transit: jdT, circumpolar: true);
  final h = math.acos(cosH) * r2d / 360.98564736629;
  return RiseSet(rise: jdT - h, set: jdT + h, transit: jdT);
}

class TwilightPair {
  final double? dawn, dusk;
  const TwilightPair(this.dawn, this.dusk);
}

class SunEvents {
  final double? rise, set, transit;
  final double maxAlt;
  final TwilightPair civil, nautical, astro;
  const SunEvents(this.rise, this.set, this.transit, this.maxAlt, this.civil,
      this.nautical, this.astro);
}

SunEvents sunEvents(double jd0, double lat, double lon, double height) {
  final base = riseSet('sun', jd0, lat, lon, height);
  final levels = {'civil': -6.0, 'nautical': -12.0, 'astro': -18.0};
  final out = <String, TwilightPair>{};
  levels.forEach((k, h0) {
    const step = 1 / 144.0;
    var prev = _altOf('sun', jd0, lat, lon, height) - h0;
    var prevJd = jd0;
    double? dawn, dusk;
    for (var jd = jd0 + step; jd <= jd0 + 1.0000001; jd += step) {
      final cur = _altOf('sun', jd, lat, lon, height) - h0;
      if (prev < 0 && cur >= 0 && dawn == null) {
        dawn = _bisectAlt('sun', prevJd, jd, h0, lat, lon, height);
      }
      if (prev > 0 && cur <= 0 && dusk == null) {
        dusk = _bisectAlt('sun', prevJd, jd, h0, lat, lon, height);
      }
      prev = cur;
      prevJd = jd;
    }
    out[k] = TwilightPair(dawn, dusk);
  });
  return SunEvents(base.rise, base.set, base.transit, base.maxAlt,
      out['civil']!, out['nautical']!, out['astro']!);
}

const List<String> compassThai = [
  'เหนือ', 'เหนือค่อนตะวันออก', 'ตะวันออกเฉียงเหนือ', 'ตะวันออกค่อนเหนือ',
  'ตะวันออก', 'ตะวันออกค่อนใต้', 'ตะวันออกเฉียงใต้', 'ใต้ค่อนตะวันออก',
  'ใต้', 'ใต้ค่อนตะวันตก', 'ตะวันตกเฉียงใต้', 'ตะวันตกค่อนใต้',
  'ตะวันตก', 'ตะวันตกค่อนเหนือ', 'ตะวันตกเฉียงเหนือ', 'เหนือค่อนตะวันตก',
];
const List<String> compassShortNames = [
  'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
  'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
];

int compassIdx(double az) => ((norm360(az) / 22.5).round()) % 16;
String compassTh(double az) => compassThai[compassIdx(az)];
String compassShort(double az) => compassShortNames[compassIdx(az)];

/// Angular separation between two alt/az points, degrees.
double angSep(double a1, double z1, double a2, double z2) {
  final p1 = a1 * d2r, p2 = a2 * d2r, dz = (z1 - z2) * d2r;
  return math.acos(clampD(
          _sin(p1) * _sin(p2) + _cos(p1) * _cos(p2) * _cos(dz), -1, 1)) *
      r2d;
}

/// Galactic to equatorial, used to lay the Milky Way across the chart.
Equatorial galToEq(double l, double b) {
  final lr = l * d2r, br = b * d2r;
  const ngpRa = 192.85948 * d2r, ngpDec = 27.12825 * d2r, lNcp = 122.93192 * d2r;
  final dec = math.asin(
      _sin(ngpDec) * _sin(br) + _cos(ngpDec) * _cos(br) * _cos(lNcp - lr));
  final ra = ngpRa +
      math.atan2(_cos(br) * _sin(lNcp - lr),
          _cos(ngpDec) * _sin(br) - _sin(ngpDec) * _cos(br) * _cos(lNcp - lr));
  return Equatorial(norm360(ra * r2d), dec * r2d);
}

/// Equatorial coordinates of a point given by its alt/az. Needed to ask when a
/// constellation, defined by where it sits now, will rise and set.
Equatorial altAzToEq(
    double alt, double az, double lat, double lon, double jd) {
  final a = alt * d2r, z = az * d2r, p = lat * d2r;
  final dec =
      math.asin(clampD(_sin(a) * _sin(p) + _cos(a) * _cos(p) * _cos(z), -1, 1));
  final h = math.atan2(
      -_sin(z) * _cos(a), _cos(a) * _sin(p) * -_cos(z) + _sin(a) * _cos(p));
  final lst = norm360(gmst(jd) + lon);
  return Equatorial(norm360(lst - h * r2d), dec * r2d);
}

double hmsToDeg(String s) {
  final p = s.trim().split(RegExp(r'\s+')).map(double.parse).toList();
  return (p[0] + p[1] / 60 + p[2] / 3600) * 15;
}

double dmsToDeg(String s) {
  s = s.trim();
  final sign = s.startsWith('-') ? -1.0 : 1.0;
  final p = s
      .replaceFirst(RegExp(r'^[+-]'), '')
      .split(RegExp(r'\s+'))
      .map(double.parse)
      .toList();
  return sign * (p[0] + p[1] / 60 + p[2] / 3600);
}
