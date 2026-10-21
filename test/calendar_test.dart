// The phase calendar, checked against figures this project did not produce.
//
// New Moon instants come from the US Naval Observatory's data service and
// Fred Espenak's six-millennium phase catalogue, cross-checked against an
// independent PyEphem run. Where those two official sources disagree they do
// so by one minute, which is why the tolerance here is two and not zero: a
// tighter bound would be asserting agreement that the published data does not
// itself have. If these fail, the search drifted; do not loosen the tolerance
// to make them pass.
//
//   flutter test          (or: dart test)

import 'package:flutter_test/flutter_test.dart';
import 'package:skyfinder/engine/calendar.dart';
import 'package:skyfinder/engine/engine.dart';

/// Two minutes, in days.
const double tol = 2 / 1440.0;

/// Non Sung, Nakhon Ratchasima.
const double lat = 15.18, lon = 102.26, height = 190.0;

void main() {
  group('เวลาจันทร์ดับตรงกับค่าที่เผยแพร่', () {
    // Julian Days of the published UTC instants.
    const published = <(double, String)>[
      (2461353.793056, '2026-11-09 07:02 UTC'),
      (2461383.536111, '2026-12-09 00:52 UTC'),
      (2461413.350000, '2027-01-07 20:24 UTC'),
      (2461443.163889, '2027-02-06 15:56 UTC'),
      (2461797.134028, '2028-01-26 15:13 UTC'),
      (2461945.269444, '2028-06-22 18:28 UTC'),
      (2461974.626389, '2028-07-22 03:02 UTC'),
    ];

    for (final p in published) {
      test(p.$2, () {
        final found = phaseAfter(p.$1 - 20, 0);
        expect(found, isNotNull);
        expect(found!, closeTo(p.$1, tol));
      });
    }

    // The returned instant is on the UT scale, while the series that produced
    // it run on Terrestrial Time, so checking the geometry means handing back
    // the delta T that was taken off. Getting 0.0000 here rather than the
    // 0.0100 degrees that skipping the conversion would leave is the whole
    // evidence that the conversion happens and happens in the right direction.
    double tt(double jd) => jd + deltaTSeconds(jd) / 86400.0;

    test('ดวงจันทร์กับดวงอาทิตย์อยู่ตำแหน่งเดียวกันจริงตอนจันทร์ดับ', () {
      final jd = phaseAfter(2461353.793056 - 20, 0)!;
      expect(moonSunElong(tt(jd)).abs(), lessThan(0.0001));
      // Without the correction the elongation is visibly short of zero.
      expect(moonSunElong(jd).abs(), greaterThan(0.005));
    });

    test('จันทร์เพ็ญอยู่ตรงข้ามดวงอาทิตย์', () {
      // 2026-11-24 14:53 UTC.
      final jd = phaseAfter(2461368.5, 180);
      expect(jd, isNotNull);
      expect(jd!, closeTo(2461369.120139, tol));
      expect(norm180(moonSunElong(tt(jd)) - 180).abs(), lessThan(0.0001));
    });

    test('delta T อยู่ราว 69 วินาทีนับแต่ปี 2017', () {
      // The old Espenak-Meeus curve projects 75.4 s for 2026. The Earth stopped
      // slowing around 2017 and the real figure has not moved since, so the
      // curve is six seconds of drift that never happened.
      expect(deltaTSeconds(2461353.0), closeTo(69.2, 1.0));
    });

    test('ตรงกับตัวอย่าง 49.a ของ Meeus (จันทร์ดับ 18 ก.พ. 1977)', () {
      // Meeus solves this with his chapter 49 series, a completely separate set
      // of coefficients from the lunar theory used here. Agreeing with it from
      // 1977, half a century from the epoch the series are centred on and far
      // outside every other fixture in this file, is the strongest evidence
      // that the search is sound rather than tuned to the dates it was built
      // against. Expected JDE 2443192.65118.
      final ut = phaseAfter(2443190.0, 0)!;
      final jde = ut + deltaTSeconds(ut) / 86400.0;
      expect(jde, closeTo(2443192.65118, 60 / 86400.0));
    });
  });

  group('เดือนจันทรคติยาวไม่เท่ากัน', () {
    // Adding a fixed 29.53 days to step from one New Moon to the next would be
    // out by a third of a day inside a single year, which is why the app
    // searches for every one of them instead.
    test('ช่วงสั้นที่สุดในกรอบ 2027 คือ 29.2938 วัน', () {
      final a = phaseAfter(2461955.0, 0)!; // 2027-07-04
      final b = phaseAfter(a + 1, 0)!; // 2027-08-02
      expect(b - a, closeTo(29.29375, 2 * tol));
    });

    test('ช่วงยาวที่สุดในกรอบ 2026-2027 คือ 29.8139 วัน', () {
      final a = phaseAfter(2461383.536111 - 1, 0)!; // 2026-12-09
      final b = phaseAfter(a + 1, 0)!; // 2027-01-07
      expect(b - a, closeTo(29.81389, 2 * tol));
    });

    test('ค่าเฉลี่ยของ 24 เดือนเข้าใกล้ค่าคงที่ synodic', () {
      var jd = 2461353.0;
      final gaps = <double>[];
      for (var i = 0; i < 24; i++) {
        final a = phaseAfter(jd, 0)!;
        final b = phaseAfter(a + 1, 0)!;
        gaps.add(b - a);
        jd = a + 1;
      }
      final mean = gaps.reduce((x, y) => x + y) / gaps.length;
      expect(mean, closeTo(synodicMonth, 0.002));
      expect(gaps.reduce((x, y) => x < y ? x : y), greaterThan(29.2));
      expect(gaps.reduce((x, y) => x > y ? x : y), lessThan(29.9));
    });
  });

  group('แสงจันทร์ไม่ได้แปรผันตรงกับส่วนสว่าง', () {
    // Half the disc lit is not half the light: the lit area halves and the
    // albedo collapses as the surface shadows itself, leaving roughly a tenth.
    // A linear penalty would write off every usable quarter-Moon evening.
    test('จันทร์กึ่งดวงสว่างราว 9% ของจันทร์เพ็ญ', () {
      final half = moonGlare(0.5, 90) / moonGlare(1.0, 90);
      expect(half, closeTo(0.09, 0.02));
    });

    test('เสี้ยวบาง 10% แทบไม่มีผล', () {
      expect(moonGlare(0.10, 90), lessThan(0.01));
    });

    test('ดวงจันทร์ใต้ขอบฟ้าไม่รบกวนเลย', () {
      expect(moonGlare(1.0, 0), 0);
      expect(moonGlare(1.0, -20), 0);
    });

    test('ยิ่งดวงจันทร์สูง ยิ่งรบกวนมาก', () {
      expect(moonGlare(1.0, 10), lessThan(moonGlare(1.0, 60)));
    });
  });

  group('ปฏิทินคืนฟ้ามืดที่โนนสูง นครราชสีมา', () {
    // Julian Day of local midnight in Thailand, passed explicitly so the
    // figures do not move with the timezone of the machine running the test.
    NightQuality night(double jd0) => nightQualityAt(
        DateTime.utc(2026), lat, lon, height, jdOverride: jd0);

    test('คืนก่อนจันทร์ดับ 8 พ.ย. 2569 มืดสนิทไร้จันทร์ทั้งคืน', () {
      final n = night(2461352.208333);
      expect(n.darkHours, closeTo(10.083, 0.05));
      expect(n.moonFreeHours, closeTo(10.083, 0.05));
      expect(n.effectiveDarkHours, closeTo(10.083, 0.05));
      expect(n.illum, closeTo(0.0052, 0.002));
      expect(n.moonAltMax, lessThan(0));
      expect(n.moonAge, closeTo(29.045, 0.05));
      expect(n.score, closeTo(1.0, 0.01));
      expect(n.verdict, 'ดีเยี่ยม');
    });

    test('คืนจันทร์เพ็ญ 26 ต.ค. 2569 ไม่มีชั่วโมงไร้จันทร์เลย', () {
      final n = night(2461339.208333);
      expect(n.darkHours, closeTo(9.917, 0.05));
      expect(n.moonFreeHours, 0);
      expect(n.effectiveDarkHours, closeTo(0.758, 0.05));
      expect(n.illum, closeTo(0.9944, 0.002));
      expect(n.moonAltMax, closeTo(85.5, 0.5));
      expect(n.score, lessThan(0.1));
      expect(n.bestFrom, isNull);
    });

    test('คืนจันทร์ค่อนดวง 16 พ.ย. 2569 ยังเหลือครึ่งคืนที่ใช้ได้', () {
      final n = night(2461360.208333);
      expect(n.moonFreeHours, closeTo(5.667, 0.05));
      expect(n.illum, closeTo(0.4255, 0.002));
      // The Moon sets partway through, so the useful stretch runs to dawn.
      expect(n.bestFrom, isNotNull);
      expect(n.bestTo! - n.bestFrom!, closeTo(5.667 / 24, 0.01));
      // Glare weighting rescues the night that a strict moon-down count would
      // have marked barely usable.
      expect(n.effectiveDarkHours, greaterThan(n.moonFreeHours));
      expect(n.score, greaterThan(0.9));
    });

    test('คืนถัดจากจันทร์ดับต้องนับอายุใหม่ ไม่ใช่ย้อนไปรอบก่อน', () {
      // The window that hunts for the preceding New Moon is wider than a
      // lunation, so on the nights just after one it reaches back far enough to
      // find the New Moon before that as well. Picking the wrong one turns a
      // one-day-old Moon into a twenty-nine-day-old one, which is the
      // difference between the darkest nights of the month and the brightest.
      expect(night(2461354.208333).moonAge, closeTo(1.41, 0.05));
      expect(night(2461355.208333).moonAge, closeTo(2.41, 0.05));
      expect(lastNewMoon(2461354.5)!, closeTo(2461353.793, 0.01));
    });

    test('ค่าทุกคืนอยู่ในกรอบที่สมเหตุสมผล', () {
      for (var i = 0; i < 30; i++) {
        final n = night(2461339.208333 + i);
        expect(n.moonFreeHours, lessThanOrEqualTo(n.darkHours + 1e-9));
        expect(n.effectiveDarkHours, greaterThanOrEqualTo(n.moonFreeHours - 1e-9));
        expect(n.effectiveDarkHours, lessThanOrEqualTo(n.darkHours + 1e-9));
        expect(n.score, inInclusiveRange(0, 1));
        expect(n.illum, inInclusiveRange(0, 1));
        // Thailand sits far enough from the poles that astronomical night
        // never vanishes, so every night has real darkness in it.
        expect(n.darkHours, greaterThan(8));
      }
    });
  });

  group('รายการข้างขึ้นข้างแรม', () {
    test('90 วันได้ครบทั้งสี่ระยะ เรียงตามเวลา', () {
      final ph = upcomingPhases(2461339.0, 90);
      expect(ph.length, greaterThanOrEqualTo(11));
      for (var i = 1; i < ph.length; i++) {
        expect(ph[i].jd, greaterThan(ph[i - 1].jd));
      }
      for (final p in Phase.values) {
        expect(ph.where((x) => x.phase == p).length, greaterThanOrEqualTo(2));
      }
    });

    test('มุมของแต่ละระยะตรงตามนิยาม', () {
      for (final p in upcomingPhases(2461339.0, 60)) {
        final ttJd = p.jd + deltaTSeconds(p.jd) / 86400.0;
        expect(norm180(moonSunElong(ttJd) - p.phase.angle).abs(),
            lessThan(0.0001),
            reason: 'ระยะ ${p.phase.th} ที่ jd ${p.jd}');
      }
    });
  });
}
