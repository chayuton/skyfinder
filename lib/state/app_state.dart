import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../engine/engine.dart';
import '../engine/sky.dart';

enum SkyTab { sky, aim, con, list, night, settings }

class Selection {
  final String kind; // body | star | dso
  final String id;
  const Selection(this.kind, this.id);
  @override
  bool operator ==(Object o) => o is Selection && o.kind == kind && o.id == id;
  @override
  int get hashCode => Object.hash(kind, id);
}

class AppState extends ChangeNotifier {
  static const _prefsKey = 'skyfinder';

  // observer
  double lat = 13.7563;
  double lon = 100.5018;
  double height = 5;
  String place = 'กรุงเทพมหานคร';

  // chart options
  bool lines = true;
  bool names = true;
  bool milky = true;
  bool ecliptic = false;
  bool faceLock = false;
  double magLim = 5;
  bool nightMode = false;

  // session only
  SkyTab tab = SkyTab.sky;
  int offsetMinutes = 0;
  DateTime _now = DateTime.now();
  Selection? selected;
  Selection? target;
  String listFilter = 'all';
  String conFilter = 'now';

  // sensors
  bool sensorOn = false;
  String sensorNote = '';
  double? heading;        // where the back of the phone points
  double? deviceHeading;  // what a plain compass would read
  double aimAlt = 40;
  double aimAz = 90;
  bool wakeOn = false;

  Timer? _clock;
  StreamSubscription? _accSub, _magSub;
  List<double>? _acc, _mag;

  AppState() {
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      _now = DateTime.now();
      notifyListeners();
    });
    _restore();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _accSub?.cancel();
    _magSub?.cancel();
    super.dispose();
  }

  DateTime get now => _now.add(Duration(minutes: offsetMinutes));
  double get jd => jdFromMs(now.millisecondsSinceEpoch);

  Scene scene() => buildScene(jd, lat, lon, height);
  Almanac get alm => almanac(now, lat, lon, height);

  // ---------------- persistence ----------------

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_prefsKey);
      if (raw == null) {
        await _firstRunLocation();
        return;
      }
      final m = jsonDecode(raw) as Map<String, dynamic>;
      lat = (m['lat'] as num?)?.toDouble() ?? lat;
      lon = (m['lon'] as num?)?.toDouble() ?? lon;
      height = (m['h'] as num?)?.toDouble() ?? height;
      place = m['place'] as String? ?? place;
      lines = m['lines'] as bool? ?? lines;
      names = m['names'] as bool? ?? names;
      milky = m['milky'] as bool? ?? milky;
      ecliptic = m['ecliptic'] as bool? ?? ecliptic;
      faceLock = m['faceLock'] as bool? ?? faceLock;
      magLim = (m['magLim'] as num?)?.toDouble() ?? magLim;
      nightMode = m['night'] as bool? ?? nightMode;
      notifyListeners();
    } catch (_) {
      // a corrupt or unavailable store should never stop the app opening
    }
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _prefsKey,
          jsonEncode({
            'lat': lat, 'lon': lon, 'h': height, 'place': place,
            'lines': lines, 'names': names, 'milky': milky,
            'ecliptic': ecliptic, 'faceLock': faceLock,
            'magLim': magLim, 'night': nightMode,
          }));
    } catch (_) {
      // ignore
    }
  }

  // ---------------- chart options ----------------

  void setTab(SkyTab t) {
    tab = t;
    notifyListeners();
  }

  void toggle(String key) {
    switch (key) {
      case 'lines': lines = !lines; break;
      case 'names': names = !names; break;
      case 'milky': milky = !milky; break;
      case 'ecliptic': ecliptic = !ecliptic; break;
      case 'faceLock': faceLock = !faceLock; break;
      case 'night': nightMode = !nightMode; break;
    }
    _save();
    notifyListeners();
  }

  void setMagLimit(double v) {
    magLim = v;
    _save();
    notifyListeners();
  }

  void setOffset(int minutes) {
    offsetMinutes = minutes.clamp(-720, 720);
    notifyListeners();
  }

  void nudgeOffset(int delta) => setOffset(offsetMinutes + delta);

  void setListFilter(String f) {
    listFilter = f;
    notifyListeners();
  }

  void setConFilter(String f) {
    conFilter = f;
    notifyListeners();
  }

  void select(Selection? s) {
    selected = s;
    notifyListeners();
  }

  void setTarget(Selection? s) {
    target = s;
    if (s != null) selected = s;
    notifyListeners();
  }

  void setAim(double alt, double az) {
    aimAlt = alt;
    aimAz = az;
    notifyListeners();
  }

  void setPlace(String name, double la, double lo, double h) {
    place = name;
    lat = la;
    lon = lo;
    height = h;
    _save();
    notifyListeners();
  }

  // ---------------- location ----------------

  Future<String> requestLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'บริการระบุตำแหน่งของเครื่องปิดอยู่ เปิดในตั้งค่าของเครื่องแล้วลองใหม่';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        return 'ยังไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง เลือกจังหวัดหรือกรอกพิกัดเองด้านล่างได้';
      }
      if (perm == LocationPermission.deniedForever) {
        return 'ปิดสิทธิ์ตำแหน่งไว้ถาวร ต้องเปิดใหม่ในตั้งค่าของเครื่อง';
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final near = nearestPlace(pos.latitude, pos.longitude);
      // Phones very often report no usable altitude, and on a mountain that
      // silently discards the horizon dip, so borrow a nearby known elevation
      // and say plainly that it was borrowed.
      var h = pos.altitude;
      var note = '';
      final hasAlt = h.isFinite && h.abs() > 0.5;
      if (!hasAlt) {
        if (near.km < 25) {
          h = near.place.h.toDouble();
          note = ' · เครื่องไม่ส่งความสูงมา ใช้ค่าของ${near.place.name} '
              '(${near.place.h} ม.) แทนไปก่อน แก้ได้ด้านล่าง';
        } else {
          h = 0;
          note = ' · เครื่องไม่ส่งความสูงมา ถ้าอยู่บนที่สูงให้กรอกด้านล่าง';
        }
      }
      final label = near.km < 12
          ? 'ตำแหน่งปัจจุบัน · ใกล้${near.place.name}'
          : 'ตำแหน่งปัจจุบัน';
      setPlace(label, pos.latitude, pos.longitude, h);
      return 'ใช้พิกัดจากเครื่องแล้ว · คลาดเคลื่อนราว '
          '${pos.accuracy.round()} ม.$note';
    } on TimeoutException {
      return 'หาสัญญาณตำแหน่งไม่ทัน ลองออกไปที่โล่งแล้วลองใหม่';
    } catch (e) {
      return 'อ่านพิกัดไม่สำเร็จ เลือกจังหวัดหรือกรอกพิกัดเองด้านล่างได้';
    }
  }

  Future<void> _firstRunLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8)),
        );
        final near = nearestPlace(pos.latitude, pos.longitude);
        final h = (pos.altitude.isFinite && pos.altitude.abs() > 0.5)
            ? pos.altitude
            : (near.km < 25 ? near.place.h.toDouble() : 0.0);
        setPlace(
            near.km < 12
                ? 'ตำแหน่งปัจจุบัน · ใกล้${near.place.name}'
                : 'ตำแหน่งปัจจุบัน',
            pos.latitude,
            pos.longitude,
            h);
      }
    } catch (_) {
      // staying on the default place is a perfectly good outcome
    }
  }

  // ---------------- orientation ----------------

  /// Orientation is derived from the accelerometer and magnetometer rather
  /// than a prebuilt orientation stream, because those two are the sensors
  /// every phone exposes. This is the same construction Android's
  /// SensorManager.getRotationMatrix uses.
  void startSensors() {
    if (sensorOn) return;
    sensorNote = 'กำลังรอค่าจากเข็มทิศ…';
    notifyListeners();

    _accSub = accelerometerEventStream().listen((e) {
      _acc = [e.x, e.y, e.z];
      _fuse();
    }, onError: (_) {
      sensorNote = 'อ่านเซ็นเซอร์ความเร่งไม่ได้ ใช้แถบเลื่อนปรับเองด้านล่างแทน';
      notifyListeners();
    });

    _magSub = magnetometerEventStream().listen((e) {
      _mag = [e.x, e.y, e.z];
      _fuse();
    }, onError: (_) {
      sensorNote = 'เครื่องนี้ไม่มีเข็มทิศ ใช้แถบเลื่อนปรับเองด้านล่างแทน';
      notifyListeners();
    });

    Timer(const Duration(seconds: 3), () {
      if (!sensorOn) {
        sensorNote = 'ยังไม่ได้ค่าจากเซ็นเซอร์ เครื่องนี้อาจไม่มีเข็มทิศ '
            'ใช้แถบเลื่อน "ปรับเอง" ด้านล่างกวาดหาดาวได้';
        notifyListeners();
      }
    });
  }

  void stopSensors() {
    _accSub?.cancel();
    _magSub?.cancel();
    _accSub = null;
    _magSub = null;
    sensorOn = false;
    notifyListeners();
  }

  void _fuse() {
    final a = _acc, m = _mag;
    if (a == null || m == null) return;

    // H = m x a points east, M = a x H points north, a itself points up.
    final hx = m[1] * a[2] - m[2] * a[1];
    final hy = m[2] * a[0] - m[0] * a[2];
    final hz = m[0] * a[1] - m[1] * a[0];
    final hn = math.sqrt(hx * hx + hy * hy + hz * hz);
    final an = math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
    if (hn < 0.1 || an < 0.1) return; // free fall, or a magnet nearby

    final ex = hx / hn, ey = hy / hn, ez = hz / hn;
    final ax = a[0] / an, ay = a[1] / an, az = a[2] / an;
    final nx = ay * ez - az * ey;
    final ny = az * ex - ax * ez;
    final nz = ax * ey - ay * ex;

    // The back of the phone is device -Z; in world terms that is
    // (-E.z, -N.z, -Up.z).
    final bE = -ez, bN = -nz, bU = -az;
    final alt = math.asin(clampD(bU, -1, 1)) * r2d;
    final azim = norm360(math.atan2(bE, bN) * r2d);

    aimAlt = clampD(alt, -20, 90);
    aimAz = azim;
    heading = azim;

    // Held flat, the top edge of the phone is the compass; raised at the sky
    // that edge points at nothing, so fall back to the back of the phone.
    final tE = ey, tN = ny;
    deviceHeading = math.sqrt(tE * tE + tN * tN) > math.sqrt(bE * bE + bN * bN)
        ? norm360(math.atan2(tE, tN) * r2d)
        : azim;

    if (!sensorOn) {
      sensorOn = true;
      sensorNote = 'เปิดเซ็นเซอร์แล้ว ยกมือถือขึ้นชี้ฟ้าได้เลย';
    }
    notifyListeners();
  }

  // ---------------- screen ----------------

  Future<void> toggleWake() async {
    wakeOn = !wakeOn;
    try {
      await WakelockPlus.toggle(enable: wakeOn);
    } catch (_) {
      wakeOn = false;
    }
    notifyListeners();
  }
}
