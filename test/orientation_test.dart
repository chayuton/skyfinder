// The compass and the aim view, checked against geometry worked out by hand
// and against the W3C DeviceOrientation specification's own example, not
// against this code's earlier output.
//
//   flutter test test/orientation_test.dart

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:skyfinder/engine/engine.dart';
import 'package:skyfinder/engine/orientation.dart';

/// Two bearings agree when the short way round between them is small, so
/// 359.9° and 0.1° are 0.2° apart, not 359.8°.
Matcher bearing(double expected, [double tolerance = 1e-6]) =>
    predicate<double?>(
        (v) => v != null && norm180(v - expected).abs() <= tolerance,
        'a bearing within $tolerance° of $expected°');

List<List<double>> _mul(List<List<double>> a, List<List<double>> b) => [
      for (var i = 0; i < 3; i++)
        [
          for (var j = 0; j < 3; j++)
            a[i][0] * b[0][j] + a[i][1] * b[1][j] + a[i][2] * b[2][j],
        ],
    ];

List<List<double>> _rx(double deg) {
  final c = math.cos(deg * d2r), s = math.sin(deg * d2r);
  return [
    [1, 0, 0],
    [0, c, -s],
    [0, s, c],
  ];
}

List<List<double>> _rz(double deg) {
  final c = math.cos(deg * d2r), s = math.sin(deg * d2r);
  return [
    [c, -s, 0],
    [s, c, 0],
    [0, 0, 1],
  ];
}

void main() {
  group('เข็มทิศอ่านจากขอบบนของเครื่อง', () {
    test('วางราบ ขอบบนชี้เหนือ อ่านได้ 0° และกล้องชี้ลงพื้น', () {
      final p = pointingOf(axesFromEuler(0, 0, 0));
      expect(p.heading, bearing(0));
      expect(p.cameraAlt, closeTo(-90, 1e-9));
    });

    test('alpha นับทวนเข็ม: alpha 90° คือขอบบนชี้ตะวันตก', () {
      expect(pointingOf(axesFromEuler(90, 0, 0)).heading, bearing(270));
    });

    test('ไม่เอียงข้าง เข็มทิศคือทิศของขอบบน (360° − alpha) ทุกมุมก้มเงย', () {
      for (var alpha = 0.0; alpha < 360; alpha += 30) {
        for (var beta = -80.0; beta <= 80; beta += 20) {
          expect(pointingOf(axesFromEuler(alpha, beta, 0)).heading,
              bearing(-alpha), reason: 'alpha $alpha beta $beta');
        }
      }
    });

    test('ยกตั้งตรง อ่านเท่ากับทิศที่กล้องหลังมอง', () {
      final p = pointingOf(axesFromEuler(-30, 90, 0));
      expect(p.heading, bearing(30));
      expect(p.cameraAz, bearing(30));
      expect(p.cameraAlt, closeTo(0, 1e-9));
    });

    test('เงยกล้องขึ้นฟ้า 60° เข็มทิศยังชี้ทางที่หันหน้า ไม่กลับ 180°', () {
      // Tipped back past upright the top edge points behind the user; the
      // reading must stay on the way they face, which is where the camera
      // looks.
      final p = pointingOf(axesFromEuler(-30, 150, 0));
      expect(p.heading, bearing(30));
      expect(p.cameraAz, bearing(30));
      expect(p.cameraAlt, closeTo(60, 1e-9));
    });

    test('วางราบแล้วเอียงซ้ายขวา เข็มทิศไม่ขยับ', () {
      for (final gamma in [-40.0, -15.0, 15.0, 40.0]) {
        expect(pointingOf(axesFromEuler(-45, 0, gamma)).heading, bearing(45),
            reason: 'gamma $gamma');
      }
    });

    test('ยกตั้งแล้วหมุนในระนาบจอ เข็มทิศยังตามกล้องหลัง', () {
      for (final face in [0.0, 75.0, 200.0]) {
        for (final twist in [10.0, 35.0, 60.0]) {
          // Face [face], stand the phone upright, then turn it in the plane
          // of its screen like a steering wheel.
          final r = _mul(_rz(-face), _mul(_rx(90), _rz(twist)));
          final p = pointingOf(Axes(r[0], r[1], r[2]));
          expect(p.heading, bearing(face), reason: 'face $face twist $twist');
          expect(p.cameraAz, bearing(face), reason: 'face $face twist $twist');
        }
      }
    });

    test('ตั้งข้างจนแกนซ้าย-ขวาตั้งดิ่ง ไม่มีขอบบนให้อ่าน', () {
      expect(pointingOf(axesFromEuler(0, 0, 90)).heading, isNull);
    });
  });

  group('สองเส้นทางให้แกนเดียวกัน', () {
    test('ความเร่งกับสนามแม่เหล็กสร้างแกนเดียวกับมุม DeviceOrientation', () {
      // Gravity's reaction points up; the field points north and dips 20°
      // into the ground, roughly as it does over Thailand.
      const dip = 20 * d2r, field = 42.0, g = 9.81;
      final rnd = math.Random(7);
      for (var i = 0; i < 300; i++) {
        final alpha = rnd.nextDouble() * 360;
        final beta = rnd.nextDouble() * 360 - 180;
        final gamma = rnd.nextDouble() * 178 - 89;
        final want = axesFromEuler(alpha, beta, gamma);
        final acc = [for (final u in want.up) g * u];
        final mag = [
          for (var k = 0; k < 3; k++)
            field *
                (math.cos(dip) * want.north[k] - math.sin(dip) * want.up[k]),
        ];
        final got = axesFromSensors(acc, mag)!;
        for (var k = 0; k < 3; k++) {
          expect(got.east[k], closeTo(want.east[k], 1e-9));
          expect(got.north[k], closeTo(want.north[k], 1e-9));
          expect(got.up[k], closeTo(want.up[k], 1e-9));
        }
      }
    });

    test('ตกอิสระหรือใกล้แม่เหล็กจนเวกเตอร์ยุบ ไม่ให้ค่ามั่ว', () {
      expect(axesFromSensors([0, 0, 0], [0, 30, -15]), isNull);
      expect(axesFromSensors([0, 0, 9.81], [0, 0, 0]), isNull);
    });

    test('ทิศกล้องตรงกับสูตรตัวอย่างในข้อกำหนด W3C DeviceOrientation', () {
      // Section "Calculating compass heading" of the specification.
      final rnd = math.Random(11);
      var compared = 0;
      for (var i = 0; i < 300; i++) {
        final alpha = rnd.nextDouble() * 360;
        final beta = rnd.nextDouble() * 360 - 180;
        final gamma = rnd.nextDouble() * 178 - 89;
        final x = beta * d2r, y = gamma * d2r, z = alpha * d2r;
        final vx = -math.cos(z) * math.sin(y) -
            math.sin(z) * math.sin(x) * math.cos(y);
        final vy = -math.sin(z) * math.sin(y) +
            math.cos(z) * math.sin(x) * math.cos(y);
        if (math.sqrt(vx * vx + vy * vy) < 1e-3) continue;
        final spec = norm360(math.atan2(vx, vy) * r2d);
        expect(pointingOf(axesFromEuler(alpha, beta, gamma)).cameraAz,
            bearing(spec, 1e-7));
        compared++;
      }
      expect(compared, greaterThan(250));
    });
  });

  group('หน้าเว็บหมุนเป็นแนวนอน', () {
    test('มุม 0 คืนแกนเดิม', () {
      final a = axesFromEuler(123, 45, -10);
      expect(identical(toScreenFrame(a, 0), a), isTrue);
    });

    test('หมุนทวนเข็ม 90°: ขอบบนเครื่องชี้ตะวันตก ขอบบนจอชี้เหนือ', () {
      expect(pointingOf(toScreenFrame(axesFromEuler(90, 0, 0), 90)).heading,
          bearing(0));
    });

    test('หมุนตามเข็ม 90°: ขอบบนเครื่องชี้ตะวันออก ขอบบนจอชี้เหนือ', () {
      expect(pointingOf(toScreenFrame(axesFromEuler(-90, 0, 0), -90)).heading,
          bearing(0));
      expect(pointingOf(toScreenFrame(axesFromEuler(-90, 0, 0), 270)).heading,
          bearing(0));
    });

    test('กลับหัว 180°', () {
      expect(pointingOf(toScreenFrame(axesFromEuler(180, 0, 0), 180)).heading,
          bearing(0));
    });

    test('กล้องหลังไม่ขึ้นกับการหมุนจอ', () {
      final a = axesFromEuler(-30, 90, 0);
      for (final angle in [90.0, 180.0, 270.0]) {
        final p = pointingOf(toScreenFrame(a, angle));
        expect(p.cameraAz, bearing(30));
        expect(p.cameraAlt, closeTo(0, 1e-9));
      }
    });
  });

  group('หมุนกรอบอ้างอิงรอบแนวดิ่ง', () {
    test('ทุกทิศเพิ่มเท่ากัน มุมเงยไม่เปลี่ยน', () {
      final rnd = math.Random(3);
      for (var i = 0; i < 200; i++) {
        final a = axesFromEuler(rnd.nextDouble() * 360,
            rnd.nextDouble() * 160 - 80, rnd.nextDouble() * 160 - 80);
        final turn = rnd.nextDouble() * 360 - 180;
        final before = pointingOf(a), after = pointingOf(turnAzimuth(a, turn));
        expect(after.cameraAz, bearing(before.cameraAz + turn, 1e-7));
        expect(after.cameraAlt, closeTo(before.cameraAlt, 1e-9));
        expect(after.heading, bearing(before.heading! + turn, 1e-7));
      }
    });
  });

  group('iOS: หาทิศเหนือจาก webkitCompassHeading', () {
    // The phone truly faces 110°, but Safari's alpha counts from an
    // arbitrary zero 37° away.
    const trueAlpha = 250.0, arbitrary = 37.0;
    Axes truth(double beta, double gamma) =>
        axesFromEuler(trueAlpha, beta, gamma);
    Axes reported(double beta, double gamma) =>
        axesFromEuler(trueAlpha + arbitrary, beta, gamma);

    test('ก่อนได้ค่าที่เชื่อได้ ยังไม่บอกทิศ', () {
      final cal = HeadingCalibration();
      expect(cal.apply(reported(40, 0)), isNull);
      // No fix yet: Safari says so with a negative accuracy.
      cal.feed(reported(40, 0), 110, -1);
      expect(cal.ready, isFalse);
      // Aimed at the sky the compass bearing of the top edge is no use.
      cal.feed(reported(150, 0), 110, 10);
      expect(cal.ready, isFalse);
    });

    test('เรียนรู้ทิศเหนือตอนถือแบบเข็มทิศ แล้วใช้ต่อตอนเงยกล้องขึ้นฟ้า', () {
      final cal = HeadingCalibration();
      for (final pose in [(35.0, 5.0), (40.0, -8.0), (60.0, 0.0), (10.0, 12.0)]) {
        final compass = pointingOf(truth(pose.$1, pose.$2)).heading!;
        expect(HeadingCalibration.holdsLikeACompass(reported(pose.$1, pose.$2)),
            isTrue);
        cal.feed(reported(pose.$1, pose.$2), compass, 12);
      }
      expect(cal.ready, isTrue);
      final fixed = pointingOf(cal.apply(reported(150, 0))!);
      final want = pointingOf(truth(150, 0));
      expect(fixed.cameraAz, bearing(want.cameraAz, 1e-6));
      expect(fixed.cameraAlt, closeTo(want.cameraAlt, 1e-9));
      expect(fixed.heading, bearing(want.heading!, 1e-6));
    });

    test('ค่าเข็มทิศตอนเงยขึ้นฟ้าไม่ถูกนำมาใช้', () {
      final cal = HeadingCalibration();
      cal.feed(reported(40, 0), pointingOf(truth(40, 0)).heading!, 12);
      final before = pointingOf(cal.apply(reported(150, 0))!).cameraAz;
      // Up there iOS may give the bearing of the top edge, which points
      // behind the user. Taking it would turn the sky round by 180°.
      cal.feed(reported(150, 0), pointingOf(truth(40, 0)).heading! + 180, 12);
      expect(pointingOf(cal.apply(reported(150, 0))!).cameraAz,
          bearing(before, 1e-9));
    });

    test('ค่าเข็มทิศที่แกว่งถูกกรองจนนิ่ง', () {
      final cal = HeadingCalibration();
      final good = pointingOf(truth(40, 0)).heading!;
      for (var i = 0; i < 60; i++) {
        cal.feed(reported(40, 0), good + (i.isEven ? 4 : -4), 12);
      }
      expect(pointingOf(cal.apply(reported(40, 0))!).heading,
          bearing(good, 0.5));
    });
  });

  group('กรองค่าดิบของเซ็นเซอร์', () {
    test('ค่าแรกใช้ตามจริง ค่าถัดไปขยับไปทีละส่วน', () {
      final f = VectorSmoother(0.25);
      expect(f.value, isNull);
      f.add(4, 8, -4);
      expect(f.value, [4, 8, -4]);
      f.add(8, 8, 0);
      expect(f.value![0], closeTo(5, 1e-12));
      expect(f.value![1], closeTo(8, 1e-12));
      expect(f.value![2], closeTo(-3, 1e-12));
      f.reset();
      expect(f.value, isNull);
    });
  });
}
