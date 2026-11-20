// Which way the phone points, from whatever the platform can measure.
//
// Everything here works on the Earth's three axes written in the phone's own
// frame: x toward the right edge, y toward the top edge, z out of the screen.
// The native sensors and the browser's DeviceOrientation API arrive at those
// three vectors by different roads; from there one piece of code decides
// where the camera looks and which way the top of the phone faces, so the
// app and the web build cannot drift apart.
//
// No Flutter imports, so `flutter test` checks all of it.

import 'dart:math' as math;

import 'engine.dart';

/// East, north and up as unit vectors in phone coordinates.
class Axes {
  final List<double> east, north, up;
  const Axes(this.east, this.north, this.up);
}

List<double> _cross(List<double> a, List<double> b) => [
      a[1] * b[2] - a[2] * b[1],
      a[2] * b[0] - a[0] * b[2],
      a[0] * b[1] - a[1] * b[0],
    ];

/// The construction Android's SensorManager.getRotationMatrix uses: the
/// accelerometer at rest reads the reaction to gravity, which points up, and
/// the magnetic field crossed with up points east whatever the dip angle.
/// Null in free fall or beside a magnet, when either vector collapses.
Axes? axesFromSensors(List<double> acc, List<double> mag) {
  final h = _cross(mag, acc);
  final hn = math.sqrt(h[0] * h[0] + h[1] * h[1] + h[2] * h[2]);
  final an =
      math.sqrt(acc[0] * acc[0] + acc[1] * acc[1] + acc[2] * acc[2]);
  if (hn < 0.1 || an < 0.1) return null;
  final east = [h[0] / hn, h[1] / hn, h[2] / hn];
  final up = [acc[0] / an, acc[1] / an, acc[2] / an];
  return Axes(east, _cross(up, east), up);
}

/// The W3C DeviceOrientation angles, in degrees. Their rotation matrix
/// R = Rz(alpha)·Rx(beta)·Ry(gamma) takes phone coordinates to east, north and
/// up, so its rows are those three axes written in phone coordinates.
Axes axesFromEuler(double alpha, double beta, double gamma) {
  final cA = math.cos(alpha * d2r), sA = math.sin(alpha * d2r);
  final cB = math.cos(beta * d2r), sB = math.sin(beta * d2r);
  final cG = math.cos(gamma * d2r), sG = math.sin(gamma * d2r);
  return Axes(
    [cA * cG - sA * sB * sG, -cB * sA, cG * sA * sB + cA * sG],
    [cG * sA + cA * sB * sG, cA * cB, sA * sG - cA * cG * sB],
    [-cB * sG, sB, cB * cG],
  );
}

/// The browser reports angles in the phone's natural portrait frame even when
/// the page has turned to landscape. [screenAngle] is how far the page is
/// turned counter-clockwise from portrait (screen.orientation.angle); the
/// result is in the frame of the screen as the reader sees it, so "the top"
/// means the top of the page.
Axes toScreenFrame(Axes a, double screenAngle) {
  final t = norm360(screenAngle);
  if (t == 0) return a;
  final c = math.cos(t * d2r), s = math.sin(t * d2r);
  List<double> f(List<double> v) =>
      [c * v[0] - s * v[1], s * v[0] + c * v[1], v[2]];
  return Axes(f(a.east), f(a.north), f(a.up));
}

/// Turns the Earth frame about the vertical so every azimuth grows by
/// [degrees]: what a reading against an arbitrary zero needs once the true
/// north is known.
Axes turnAzimuth(Axes a, double degrees) {
  final c = math.cos(degrees * d2r), s = math.sin(degrees * d2r);
  return Axes(
    [
      for (var i = 0; i < 3; i++) s * a.north[i] + c * a.east[i],
    ],
    [
      for (var i = 0; i < 3; i++) c * a.north[i] - s * a.east[i],
    ],
    a.up,
  );
}

class Pointing {
  /// Where the camera looks, out of the back of the phone.
  final double cameraAlt, cameraAz;

  /// Compass heading of the top edge, as if the phone were tipped flat about
  /// its left-right axis: the reading a compass app gives. Null when the phone
  /// stands on its side and that axis is vertical, so there is no top to tip.
  final double? heading;

  const Pointing(this.cameraAlt, this.cameraAz, this.heading);
}

/// The heading is taken from the phone's left-right axis rather than from the
/// top edge itself. Flat on a palm the two agree exactly. Raised upright the
/// top edge points at the sky and its compass bearing turns to noise, which
/// is why compass apps switch to the camera axis there; tipped further back
/// to aim at the sky the top edge even points behind the user. The left-right
/// axis stays level through all of that while it stays square to the way
/// the user faces, so the needle holds steady from flat to overhead with no
/// switch-over and no flip.
Pointing pointingOf(Axes a) {
  // The back of the phone is -z; in east, north, up terms that is
  // (-E.z, -N.z, -Up.z).
  final bE = -a.east[2], bN = -a.north[2], bU = -a.up[2];
  final alt = math.asin(clampD(bU, -1, 1)) * r2d;
  final az = norm360(math.atan2(bE, bN) * r2d);

  // The x axis is (E.x, N.x, Up.x); up crossed with it points ahead.
  final dE = -a.north[0], dN = a.east[0];
  final double? heading = math.sqrt(dE * dE + dN * dN) < 0.15
      ? null
      : norm360(math.atan2(dE, dN) * r2d);
  return Pointing(alt, az, heading);
}

/// iOS Safari measures alpha from an arbitrary starting direction and reports
/// the compass separately, as webkitCompassHeading. That compass bearing
/// belongs to the top edge, so it is only trustworthy while the phone is held
/// the way a compass is: screen up, not rolled far, top edge neither pointing
/// at the sky nor tipped well down. Then it and [pointingOf] agree on what
/// "the top" means, and their difference is the offset between the
/// arbitrary zero and north.
///
/// The offset is learned only inside that pose and kept outside it, so the
/// camera keeps its true bearing while it is aimed at the sky, where the
/// compass bearing of the top edge would point behind the user. Smoothing the
/// offset rather than the heading leaves the gyro's quick response intact and
/// takes the compass's jitter out.
class HeadingCalibration {
  double? _offset;

  bool get ready => _offset != null;

  /// [relative] comes from the arbitrary-zero angles, [compass] is the
  /// browser's heading in degrees and [accuracy] its stated error, negative
  /// when the compass has no fix.
  void feed(Axes relative, double compass, double? accuracy) {
    if (accuracy != null && accuracy < 0) return;
    if (!holdsLikeACompass(relative)) return;
    final h = pointingOf(relative).heading;
    if (h == null) return;
    final target = norm180(compass - h);
    final o = _offset;
    _offset = o == null ? target : norm180(o + 0.1 * norm180(target - o));
  }

  /// The same reading against true north, or null until the first fix.
  Axes? apply(Axes relative) {
    final o = _offset;
    return o == null ? null : turnAzimuth(relative, o);
  }

  void reset() => _offset = null;

  /// Screen facing up, roll within about 20°, top edge between about 20°
  /// below and 70° above the horizon.
  static bool holdsLikeACompass(Axes a) {
    final u = a.up;
    return u[2] > 0 && u[0].abs() <= 0.35 && u[1] >= -0.34 && u[1] <= 0.94;
  }
}

/// Exponential smoothing for a raw 3-axis reading. A phone magnetometer
/// jitters by a few per cent at rest, which unsmoothed shakes the needle by
/// several degrees.
class VectorSmoother {
  final double k;
  List<double>? _v;
  VectorSmoother(this.k);

  List<double>? get value => _v;

  void add(double x, double y, double z) {
    final v = _v;
    _v = v == null
        ? [x, y, z]
        : [v[0] + k * (x - v[0]), v[1] + k * (y - v[1]), v[2] + k * (z - v[2])];
  }

  void reset() => _v = null;
}
