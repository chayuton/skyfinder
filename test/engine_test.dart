// GENERATED. Expected values come from the JavaScript implementation that was
// checked against Meeus, "Astronomical Algorithms" (Moon ex.47.a to six decimals,
// Sun ex.25.b to 1e-5 deg). If this suite passes, the Dart port reproduces those
// same numbers; if it fails, the port drifted and the figures in the app are wrong.
//
//   flutter test          (or: dart test)

import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:skyfinder/engine/engine.dart';

void main() {
  group('ตัวอย่างอ้างอิงของ Meeus', () {
    test('ดวงจันทร์ ตัวอย่าง 47.a (1992-04-12 0h TD)', () {
      final m = moonEcliptic(2448724.5);
      expect(m.lon, closeTo(133.162655, 1e-5));
      expect(m.lat, closeTo(-3.229126, 1e-5));
      expect(m.distKm, closeTo(368409.7, 0.1));
    });

    test('ดวงอาทิตย์ ตัวอย่าง 25.b (1992-10-13 0h TD)', () {
      final s = sunEcliptic(2448908.5);
      expect(s.lon, closeTo(199.90895, 1e-4));
      expect(s.dist, closeTo(0.99760775, 1e-4));
    });
  });

  group('การแปลงพิกัดและค่าคงที่', () {
    test('ใจกลางทางช้างเผือกอยู่ที่ RA 17h45.6m Dec -28.94', () {
      final gc = galToEq(0, 0);
      expect(gc.ra / 15, closeTo(17.76, 0.02));
      expect(gc.dec, closeTo(-28.94, 0.02));
    });

    test('ขอบฟ้ากดลงตามความสูง', () {
      expect(horizonDip(0), 0);
      expect(horizonDip(2457), closeTo(1.4524, 1e-3));
    });

    test('ทิศเป็นภาษาไทย', () {
      expect(compassShort(0), 'N');
      expect(compassShort(90), 'E');
      expect(compassShort(180), 'S');
      expect(compassShort(270), 'W');
      expect(compassTh(0), 'เหนือ');
      expect(compassTh(180), 'ใต้');
    });

    test('แปลงสตริงพิกัดดาว', () {
      expect(hmsToDeg('06 45 08.9'), closeTo(101.287083, 1e-5));
      expect(dmsToDeg('-16 42 58'), closeTo(-16.716111, 1e-5));
      expect(dmsToDeg('+07 24 25'), closeTo(7.406944, 1e-5));
    });
  });

  group('ผังกลุ่มดาวเอียงตรงตามมุมพารัลแลกติก', () {
    // The figures are drawn about the group centre with the zenith up, so the
    // tilt of the drawing must equal the parallactic angle. Getting the sign
    // wrong mirrors every figure, which is worse than drawing none.
    double parallactic(double h, double dec, double lat) => math.atan2(
          math.sin(h * d2r),
          math.tan(lat * d2r) * math.cos(dec * d2r) -
              math.sin(dec * d2r) * math.cos(h * d2r),
        ) * r2d;

    test('ตรงกับสูตรเชิงทฤษฎี', () {
      for (final hours in [-4.0, -2.0, 2.0, 4.0]) {
        const ra = 83.5, dec = -1.0, lat = 13.7563, lon = 100.5018;
        const jd0 = 2461400.0;
        final lst = norm360(gmst(jd0) + lon);
        final want = norm360(ra + hours * 15);
        final jd = jd0 + norm180(want - lst) / 360.98564736629;
        final aa = eqToAltAz(ra, dec, lat, lon, jd);
        final n = eqToAltAz(ra, dec + 0.5, lat, lon, jd);

        final fwd = _vec(aa.alt, aa.az);
        var right = [-fwd[1], fwd[0], 0.0];
        final rn = math.sqrt(right[0] * right[0] + right[1] * right[1]);
        right = [right[0] / rn, right[1] / rn, 0.0];
        final up = [
          fwd[1] * right[2] - fwd[2] * right[1],
          fwd[2] * right[0] - fwd[0] * right[2],
          fwd[0] * right[1] - fwd[1] * right[0],
        ];
        final v = _vec(n.alt, n.az);
        final k = 2 / (1 + _dot(v, fwd));
        final px = k * _dot(v, right), py = -k * _dot(v, up);
        final screen = math.atan2(px, -py) * r2d;
        final q = parallactic(norm180(hours * 15), dec, lat);
        expect(norm180(screen - q).abs(), lessThan(0.05),
            reason: 'hour angle ${hours}h');
      }
    });
  });

  group('ค่าที่คำนวณได้ตรงกับเวอร์ชันที่ตรวจสอบแล้ว', () {
    test("กรุงเทพฯ กลางคืน", () {
      const jd = 2461334.1041666665, lat = 13.7563, lon = 100.5018, h = 5.0;
      final sun = bodyPosition('sun', jd, lat, lon, h);
      expect(sun.alt, closeTo(-52.5524210, 1e-6));
      expect(sun.az, closeTo(270.6670402, 1e-6));
      expect(sun.mag, closeTo(-26.7000000, 1e-6));
      final moon = bodyPosition('moon', jd, lat, lon, h);
      expect(moon.alt, closeTo(50.1695975, 1e-6));
      expect(moon.az, closeTo(221.4001474, 1e-6));
      expect(moon.mag, closeTo(-10.8603650, 1e-6));
      expect(moon.illum!, closeTo(0.683102999, 1e-8));
      expect(moon.distKm!, closeTo(396328.7011, 1e-3));
      expect(moon.age!, closeTo(9.1333513, 1e-6));
      final mercury = bodyPosition('mercury', jd, lat, lon, h);
      expect(mercury.alt, closeTo(-32.8325937, 1e-6));
      expect(mercury.az, closeTo(253.8524284, 1e-6));
      expect(mercury.mag, closeTo(0.2272024, 1e-6));
      final venus = bodyPosition('venus', jd, lat, lon, h);
      expect(venus.alt, closeTo(-50.3414913, 1e-6));
      expect(venus.az, closeTo(256.6055904, 1e-6));
      expect(venus.mag, closeTo(-4.2433910, 1e-6));
      final mars = bodyPosition('mars', jd, lat, lon, h);
      expect(mars.alt, closeTo(-45.3484374, 1e-6));
      expect(mars.az, closeTo(44.9150217, 1e-6));
      expect(mars.mag, closeTo(0.9724616, 1e-6));
      final jupiter = bodyPosition('jupiter', jd, lat, lon, h);
      expect(jupiter.alt, closeTo(-54.4995956, 1e-6));
      expect(jupiter.az, closeTo(38.0151729, 1e-6));
      expect(jupiter.mag, closeTo(-1.9983412, 1e-6));
      final saturn = bodyPosition('saturn', jd, lat, lon, h);
      expect(saturn.alt, closeTo(63.8995634, 1e-6));
      expect(saturn.az, closeTo(115.9357501, 1e-6));
      expect(saturn.mag, closeTo(0.6453829, 1e-6));
      final uranus = bodyPosition('uranus', jd, lat, lon, h);
      expect(uranus.alt, closeTo(17.6616531, 1e-6));
      expect(uranus.az, closeTo(71.9987001, 1e-6));
      expect(uranus.mag, closeTo(5.6844351, 1e-6));
      final neptune = bodyPosition('neptune', jd, lat, lon, h);
      expect(neptune.alt, closeTo(69.0366677, 1e-6));
      expect(neptune.az, closeTo(131.1357744, 1e-6));
      expect(neptune.mag, closeTo(7.6865143, 1e-6));
      final ev = sunEvents(2461333.5, lat, lon, h);
      expect(ev.rise!, closeTo(2461334.46490027, 1e-6));
      expect(ev.set!, closeTo(2461333.95571766, 1e-6));
      expect(ev.astro.dusk!, closeTo(2461334.00516682, 1e-6));
      expect(ev.astro.dawn!, closeTo(2461334.41540633, 1e-6));
      final sirius = precess(101.28715, -16.71611, jd);
      expect(sirius.ra, closeTo(101.5866010, 1e-6));
      expect(sirius.dec, closeTo(-16.7456960, 1e-6));
      final srs = starRiseSet(sirius.ra, sirius.dec, 2461333.5, lat, lon, h);
      expect(srs.transit!, closeTo(2461334.42140757, 1e-6));
      expect(srs.rise!, closeTo(2461334.18190503, 1e-6));
    });

    test("เชียงใหม่ หัวค่ำ", () {
      const jd = 2461207.0416666665, lat = 18.7883, lon = 98.9853, h = 310.0;
      final sun = bodyPosition('sun', jd, lat, lon, h);
      expect(sun.alt, closeTo(-12.9447018, 1e-6));
      expect(sun.az, closeTo(300.4829312, 1e-6));
      expect(sun.mag, closeTo(-26.7000000, 1e-6));
      final moon = bodyPosition('moon', jd, lat, lon, h);
      expect(moon.alt, closeTo(-6.6384767, 1e-6));
      expect(moon.az, closeTo(301.9951171, 1e-6));
      expect(moon.mag, closeTo(-4.7020406, 1e-6));
      expect(moon.illum!, closeTo(0.004264710, 1e-8));
      expect(moon.distKm!, closeTo(357515.4106, 1e-3));
      expect(moon.age!, closeTo(0.4932445, 1e-6));
      final mercury = bodyPosition('mercury', jd, lat, lon, h);
      expect(mercury.alt, closeTo(9.7945191, 1e-6));
      expect(mercury.az, closeTo(291.2563105, 1e-6));
      expect(mercury.mag, closeTo(0.5001397, 1e-6));
      final venus = bodyPosition('venus', jd, lat, lon, h);
      expect(venus.alt, closeTo(22.4361459, 1e-6));
      expect(venus.az, closeTo(286.2643313, 1e-6));
      expect(venus.mag, closeTo(-4.0011218, 1e-6));
      final mars = bodyPosition('mars', jd, lat, lon, h);
      expect(mars.alt, closeTo(-43.1255207, 1e-6));
      expect(mars.az, closeTo(318.7038959, 1e-6));
      expect(mars.mag, closeTo(1.2909611, 1e-6));
      final jupiter = bodyPosition('jupiter', jd, lat, lon, h);
      expect(jupiter.alt, closeTo(16.7788140, 1e-6));
      expect(jupiter.az, closeTo(287.2228008, 1e-6));
      expect(jupiter.mag, closeTo(-1.8581691, 1e-6));
      final saturn = bodyPosition('saturn', jd, lat, lon, h);
      expect(saturn.alt, closeTo(-67.5968968, 1e-6));
      expect(saturn.az, closeTo(12.0439811, 1e-6));
      expect(saturn.mag, closeTo(1.0629435, 1e-6));
      final uranus = bodyPosition('uranus', jd, lat, lon, h);
      expect(uranus.alt, closeTo(-32.2954329, 1e-6));
      expect(uranus.az, closeTo(310.8650875, 1e-6));
      expect(uranus.mag, closeTo(5.8828263, 1e-6));
      final neptune = bodyPosition('neptune', jd, lat, lon, h);
      expect(neptune.alt, closeTo(-66.7120644, 1e-6));
      expect(neptune.az, closeTo(35.7324227, 1e-6));
      expect(neptune.mag, closeTo(7.7650521, 1e-6));
      final ev = sunEvents(2461206.5, lat, lon, h);
      expect(ev.rise!, closeTo(2461207.44766485, 1e-6));
      expect(ev.set!, closeTo(2461207.00320423, 1e-6));
      expect(ev.astro.dusk!, closeTo(2461207.05914439, 1e-6));
      expect(ev.astro.dawn!, closeTo(2461207.39172179, 1e-6));
      final sirius = precess(101.28715, -16.71611, jd);
      expect(sirius.ra, closeTo(101.5827140, 1e-6));
      expect(sirius.dec, closeTo(-16.7453071, 1e-6));
      final srs = starRiseSet(sirius.ra, sirius.dec, 2461206.5, lat, lon, h);
      expect(srs.transit!, closeTo(2461206.77509332, 1e-6));
      expect(srs.rise!, closeTo(2461206.53872880, 1e-6));
    });

    test("ดอยอินทนนท์ บนยอด", () {
      const jd = 2461396.1666666665, lat = 18.5875, lon = 98.4867, h = 2565.0;
      final sun = bodyPosition('sun', jd, lat, lon, h);
      expect(sun.alt, closeTo(-69.7793227, 1e-6));
      expect(sun.az, closeTo(252.4760623, 1e-6));
      expect(sun.mag, closeTo(-26.7000000, 1e-6));
      final moon = bodyPosition('moon', jd, lat, lon, h);
      expect(moon.alt, closeTo(73.4948298, 1e-6));
      expect(moon.az, closeTo(293.1100520, 1e-6));
      expect(moon.mag, closeTo(-11.8392690, 1e-6));
      expect(moon.illum!, closeTo(0.914264704, 1e-8));
      expect(moon.distKm!, closeTo(363566.1831, 1e-3));
      expect(moon.age!, closeTo(11.9931587, 1e-6));
      final mercury = bodyPosition('mercury', jd, lat, lon, h);
      expect(mercury.alt, closeTo(-75.6432959, 1e-6));
      expect(mercury.az, closeTo(244.8387726, 1e-6));
      expect(mercury.mag, closeTo(-0.8706914, 1e-6));
      final venus = bodyPosition('venus', jd, lat, lon, h);
      expect(venus.alt, closeTo(-63.8125635, 1e-6));
      expect(venus.az, closeTo(81.3831765, 1e-6));
      expect(venus.mag, closeTo(-4.6786775, 1e-6));
      final mars = bodyPosition('mars', jd, lat, lon, h);
      expect(mars.alt, closeTo(1.5400236, 1e-6));
      expect(mars.az, closeTo(78.6633045, 1e-6));
      expect(mars.mag, closeTo(0.0885917, 1e-6));
      final jupiter = bodyPosition('jupiter', jd, lat, lon, h);
      expect(jupiter.alt, closeTo(12.8382389, 1e-6));
      expect(jupiter.az, closeTo(80.0051140, 1e-6));
      expect(jupiter.mag, closeTo(-2.3813349, 1e-6));
      final saturn = bodyPosition('saturn', jd, lat, lon, h);
      expect(saturn.alt, closeTo(28.3447319, 1e-6));
      expect(saturn.az, closeTo(260.6649324, 1e-6));
      expect(saturn.mag, closeTo(0.9316758, 1e-6));
      final uranus = bodyPosition('uranus', jd, lat, lon, h);
      expect(uranus.alt, closeTo(82.1050878, 1e-6));
      expect(uranus.az, closeTo(285.6862536, 1e-6));
      expect(uranus.mag, closeTo(5.6720594, 1e-6));
      final neptune = bodyPosition('neptune', jd, lat, lon, h);
      expect(neptune.alt, closeTo(21.8181639, 1e-6));
      expect(neptune.az, closeTo(261.5457504, 1e-6));
      expect(neptune.mag, closeTo(7.7497559, 1e-6));
      final ev = sunEvents(2461395.5, lat, lon, h);
      expect(ev.rise!, closeTo(2461396.49108974, 1e-6));
      expect(ev.set!, closeTo(2461395.95924721, 1e-6));
      expect(ev.astro.dusk!, closeTo(2461396.00869376, 1e-6));
      expect(ev.astro.dawn!, closeTo(2461396.44164288, 1e-6));
      final sirius = precess(101.28715, -16.71611, jd);
      expect(sirius.ra, closeTo(101.5884996, 1e-6));
      expect(sirius.dec, closeTo(-16.7458860, 1e-6));
      final srs = starRiseSet(sirius.ra, sirius.dec, 2461395.5, lat, lon, h);
      expect(srs.transit!, closeTo(2461396.25770816, 1e-6));
      expect(srs.rise!, closeTo(2461396.01820009, 1e-6));
    });

    test("เกาะหลีเป๊ะ ใต้สุด", () {
      const jd = 2461120.1250000000, lat = 6.4894, lon = 99.3018, h = 2.0;
      final sun = bodyPosition('sun', jd, lat, lon, h);
      expect(sun.alt, closeTo(-51.9690480, 1e-6));
      expect(sun.az, closeTo(278.3722150, 1e-6));
      expect(sun.mag, closeTo(-26.7000000, 1e-6));
      final moon = bodyPosition('moon', jd, lat, lon, h);
      expect(moon.alt, closeTo(-33.0383749, 1e-6));
      expect(moon.az, closeTo(287.7350991, 1e-6));
      expect(moon.mag, closeTo(-6.0355945, 1e-6));
      expect(moon.illum!, closeTo(0.033075270, 1e-8));
      expect(moon.distKm!, closeTo(368740.1483, 1e-3));
      expect(moon.age!, closeTo(1.6918864, 1e-6));
      final mercury = bodyPosition('mercury', jd, lat, lon, h);
      expect(mercury.alt, closeTo(-72.8213178, 1e-6));
      expect(mercury.az, closeTo(265.8557479, 1e-6));
      expect(mercury.mag, closeTo(1.0863115, 1e-6));
      final venus = bodyPosition('venus', jd, lat, lon, h);
      expect(venus.alt, closeTo(-34.5556529, 1e-6));
      expect(venus.az, closeTo(282.0214949, 1e-6));
      expect(venus.mag, closeTo(-3.8986551, 1e-6));
      final mars = bodyPosition('mars', jd, lat, lon, h);
      expect(mars.alt, closeTo(-66.7624366, 1e-6));
      expect(mars.az, closeTo(266.8249715, 1e-6));
      expect(mars.mag, closeTo(1.1621337, 1e-6));
      final jupiter = bodyPosition('jupiter', jd, lat, lon, h);
      expect(jupiter.alt, closeTo(51.7597889, 1e-6));
      expect(jupiter.az, closeTo(299.2807920, 1e-6));
      expect(jupiter.mag, closeTo(-2.3487455, 1e-6));
      final saturn = bodyPosition('saturn', jd, lat, lon, h);
      expect(saturn.alt, closeTo(-47.4052740, 1e-6));
      expect(saturn.az, closeTo(276.6867453, 1e-6));
      expect(saturn.mag, closeTo(1.0885909, 1e-6));
      final uranus = bodyPosition('uranus', jd, lat, lon, h);
      expect(uranus.alt, closeTo(5.5911204, 1e-6));
      expect(uranus.az, closeTo(289.1642644, 1e-6));
      expect(uranus.mag, closeTo(5.8392316, 1e-6));
      final neptune = bodyPosition('neptune', jd, lat, lon, h);
      expect(neptune.alt, closeTo(-49.9610261, 1e-6));
      expect(neptune.az, closeTo(276.9994907, 1e-6));
      expect(neptune.mag, closeTo(7.8250882, 1e-6));
      final ev = sunEvents(2461119.5, lat, lon, h);
      expect(ev.rise!, closeTo(2461120.47675550, 1e-6));
      expect(ev.set!, closeTo(2461119.98177814, 1e-6));
      expect(ev.astro.dusk!, closeTo(2461120.02966187, 1e-6));
      expect(ev.astro.dawn!, closeTo(2461120.42888104, 1e-6));
      final sirius = precess(101.28715, -16.71611, jd);
      expect(sirius.ra, closeTo(101.5800551, 1e-6));
      expect(sirius.dec, closeTo(-16.7450412, 1e-6));
      final srs = starRiseSet(sirius.ra, sirius.dec, 2461119.5, lat, lon, h);
      expect(srs.transit!, closeTo(2461120.01175692, 1e-6));
      expect(srs.rise!, closeTo(2461119.76610126, 1e-6));
    });

    test("หนองคาย เช้ามืด", () {
      const jd = 2461255.3958333335, lat = 17.8783, lon = 102.742, h = 170.0;
      final sun = bodyPosition('sun', jd, lat, lon, h);
      expect(sun.alt, closeTo(-18.0386540, 1e-6));
      expect(sun.az, closeTo(63.9750355, 1e-6));
      expect(sun.mag, closeTo(-26.7000000, 1e-6));
      final moon = bodyPosition('moon', jd, lat, lon, h);
      expect(moon.alt, closeTo(66.7806513, 1e-6));
      expect(moon.az, closeTo(230.1704085, 1e-6));
      expect(moon.mag, closeTo(-11.4104015, 1e-6));
      expect(moon.illum!, closeTo(0.822682126, 1e-8));
      expect(moon.distKm!, closeTo(385608.0547, 1e-3));
      expect(moon.age!, closeTo(18.8557096, 1e-6));
      final mercury = bodyPosition('mercury', jd, lat, lon, h);
      expect(mercury.alt, closeTo(0.7555994, 1e-6));
      expect(mercury.az, closeTo(69.0705041, 1e-6));
      expect(mercury.mag, closeTo(0.0730325, 1e-6));
      final venus = bodyPosition('venus', jd, lat, lon, h);
      expect(venus.alt, closeTo(-62.1086674, 1e-6));
      expect(venus.az, closeTo(48.3251030, 1e-6));
      expect(venus.mag, closeTo(-4.3068492, 1e-6));
      final mars = bodyPosition('mars', jd, lat, lon, h);
      expect(mars.alt, closeTo(27.5046752, 1e-6));
      expect(mars.az, closeTo(72.3532534, 1e-6));
      expect(mars.mag, closeTo(1.3046598, 1e-6));
      final jupiter = bodyPosition('jupiter', jd, lat, lon, h);
      expect(jupiter.alt, closeTo(-14.7995509, 1e-6));
      expect(jupiter.az, closeTo(64.0906400, 1e-6));
      expect(jupiter.mag, closeTo(-1.7835782, 1e-6));
      final saturn = bodyPosition('saturn', jd, lat, lon, h);
      expect(saturn.alt, closeTo(75.4552921, 1e-6));
      expect(saturn.az, closeTo(188.5311768, 1e-6));
      expect(saturn.mag, closeTo(0.8710177, 1e-6));
      final uranus = bodyPosition('uranus', jd, lat, lon, h);
      expect(uranus.alt, closeTo(46.2474937, 1e-6));
      expect(uranus.az, closeTo(78.0358318, 1e-6));
      expect(uranus.mag, closeTo(5.8223848, 1e-6));
      final neptune = bodyPosition('neptune', jd, lat, lon, h);
      expect(neptune.alt, closeTo(68.7419959, 1e-6));
      expect(neptune.az, closeTo(215.9944432, 1e-6));
      expect(neptune.mag, closeTo(7.7085718, 1e-6));
      final ev = sunEvents(2461254.5, lat, lon, h);
      expect(ev.rise!, closeTo(2461255.44893761, 1e-6));
      expect(ev.set!, closeTo(2461254.98912788, 1e-6));
      expect(ev.astro.dusk!, closeTo(2461255.04211741, 1e-6));
      expect(ev.astro.dawn!, closeTo(2461255.39595891, 1e-6));
      final sirius = precess(101.28715, -16.71611, jd);
      expect(sirius.ra, closeTo(101.5841932, 1e-6));
      expect(sirius.dec, closeTo(-16.7454551, 1e-6));
      final srs = starRiseSet(sirius.ra, sirius.dec, 2461254.5, lat, lon, h);
      expect(srs.transit!, closeTo(2461254.63362981, 1e-6));
      expect(srs.rise!, closeTo(2461254.39684648, 1e-6));
    });

  });
}

List<double> _vec(double alt, double az) => [
      math.cos(alt * d2r) * math.cos(az * d2r),
      math.cos(alt * d2r) * math.sin(az * d2r),
      math.sin(alt * d2r),
    ];

double _dot(List<double> a, List<double> b) =>
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
