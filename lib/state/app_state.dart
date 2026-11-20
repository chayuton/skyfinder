import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../engine/engine.dart';
import '../engine/orientation.dart';
import '../engine/sky.dart';
import 'orientation_source.dart';

enum SkyTab { sky, aim, con, list, night, settings }

class Selection {
  final String kind; // body | star | dso
  final String id;
  const Selection(this.kind, this.id);
  @override
  bool operator ==(Object other) =>
      other is Selection && other.kind == kind && other.id == id;
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
  bool sensorOn = false;       // readings are live
  bool sensorStarting = false; // waiting on a permission prompt or a reading
  String sensorNote = '';
  /// Compass bearing of the top edge of the phone: what the compass shows,
  /// and what the sky map turns to when locked to the compass.
  double? deviceHeading;
  /// Where the camera, out of the back of the phone, points: the aim view.
  double aimAlt = 40;
  double aimAz = 90;
  bool wakeOn = false;

  final OrientationSource _orientation = createOrientationSource();
  Timer? _clock, _sensorWait, _publish;

  AppState() {
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      _now = DateTime.now();
      notifyListeners();
    });
    _restore();
    // The compass is on screen on every tab, so it starts by itself wherever
    // no permission prompt is in the way. iOS Safari only prompts from a tap,
    // but a page it already allowed this session gets going here as well.
    _beginSensors(quiet: _orientation.needsTap);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _sensorWait?.cancel();
    _publish?.cancel();
    _orientation.stop();
    super.dispose();
  }

  DateTime get now => _now.add(Duration(minutes: offsetMinutes));
  double get jd => jdFromMs(now.millisecondsSinceEpoch);

  Scene? _scene;
  double _sceneJd = double.nan, _sceneLat = double.nan;
  double _sceneLon = double.nan, _sceneH = double.nan;

  /// The tree rebuilds for compass updates as well as clock ticks, and a
  /// scene places every star, so it is reused until the time or the place
  /// actually changes.
  Scene scene() {
    final t = jd;
    final cached = _scene;
    if (cached != null &&
        t == _sceneJd &&
        lat == _sceneLat &&
        lon == _sceneLon &&
        height == _sceneH) {
      return cached;
    }
    final fresh = buildScene(t, lat, lon, height);
    _scene = fresh;
    _sceneJd = t;
    _sceneLat = lat;
    _sceneLon = lon;
    _sceneH = height;
    return fresh;
  }

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
    // Locking the map to a compass that is not running would do nothing.
    if (key == 'faceLock' && faceLock && !sensorOn) startSensors();
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

  static const _waitingNote = 'กำลังรอค่าจากเข็มทิศ…';
  bool _hinted = false;

  /// iOS Safari asks for motion access only from a tap, so until it has
  /// been asked the compass says "tap" instead of a dash.
  bool get compassNeedsTap =>
      _orientation.needsTap && !sensorOn && !sensorStarting &&
      !_orientation.running;

  /// Starts the compass. Call it from a tap where there is one: that is the
  /// only moment iOS Safari will show its permission prompt.
  void startSensors() {
    if (sensorOn) return;
    _beginSensors(quiet: false);
  }

  void _beginSensors({required bool quiet}) {
    _hinted = false;
    if (!quiet) {
      sensorStarting = true;
      sensorNote = _waitingNote;
      notifyListeners();
    }
    _orientation.start(
      onAxes: _onAxes,
      onListening: _onListening,
      onFailed: _onSensorFailed,
      onHint: _onSensorHint,
      quiet: quiet,
    );
  }

  void stopSensors() {
    _orientation.stop();
    _sensorWait?.cancel();
    _publish?.cancel();
    _publish = null;
    _hinted = false;
    sensorOn = false;
    sensorStarting = false;
    notifyListeners();
  }

  void _onListening() {
    if (sensorOn) return;
    sensorStarting = true;
    if (!_hinted) sensorNote = _waitingNote;
    _sensorWait?.cancel();
    _sensorWait = Timer(const Duration(seconds: 3), () {
      // A hint (hold the phone flat, wave a figure eight) means readings are
      // arriving and only need a moment, so the compass keeps waiting.
      if (sensorOn || _hinted) return;
      sensorStarting = false;
      sensorNote = 'ยังไม่ได้ค่าจากเซ็นเซอร์ เครื่องนี้อาจไม่มีเข็มทิศ '
          'ใช้แถบเลื่อน "ปรับเอง" ด้านล่างกวาดหาดาวได้';
      notifyListeners();
    });
    notifyListeners();
  }

  void _onSensorFailed(String note) {
    _sensorWait?.cancel();
    sensorStarting = false;
    sensorNote = note;
    notifyListeners();
  }

  void _onSensorHint(String note) {
    if (sensorOn) return;
    _hinted = true;
    sensorStarting = true;
    sensorNote = note;
    notifyListeners();
  }

  void _onAxes(Axes axes) {
    final p = pointingOf(axes);
    _cameraAlt = p.cameraAlt;
    aimAlt = clampD(p.cameraAlt, -20, 90);
    aimAz = p.cameraAz;
    // Stood on its side the phone has no top edge to read; holding the last
    // bearing beats a needle that swings a quarter turn.
    final h = p.heading;
    if (h != null) deviceHeading = h;
    if (!sensorOn) {
      sensorOn = true;
      sensorStarting = false;
      _sensorWait?.cancel();
      sensorNote = 'เปิดเซ็นเซอร์แล้ว ยกมือถือขึ้นชี้ฟ้าได้เลย';
      _publishNow();
      return;
    }
    _publishSoon();
  }

  // A browser fires orientation events at the display rate and every
  // notification rebuilds the whole tree, so readings are passed on at most
  // about sixteen times a second and only once they have moved by more than
  // the screen can show.
  static const _publishGap = Duration(milliseconds: 60);
  DateTime _published = DateTime.fromMillisecondsSinceEpoch(0);
  double? _shownHeading;
  double _cameraAlt = 0, _shownAlt = 0, _shownAz = 0;

  bool get _orientationMoved {
    final h = deviceHeading, shown = _shownHeading;
    if (h != null && (shown == null || norm180(h - shown).abs() >= 0.3)) {
      return true;
    }
    // Measured as an angle on the sky, so the bearing of a camera pointed
    // straight down, which is noise, does not count as movement.
    return angSep(_cameraAlt, aimAz, _shownAlt, _shownAz) >= 0.2;
  }

  void _publishSoon() {
    if (_publish != null || !_orientationMoved) return;
    final wait = _publishGap - DateTime.now().difference(_published);
    if (wait <= Duration.zero) {
      _publishNow();
      return;
    }
    _publish = Timer(wait, () {
      _publish = null;
      if (_orientationMoved) _publishNow();
    });
  }

  void _publishNow() {
    _published = DateTime.now();
    _shownHeading = deviceHeading;
    _shownAlt = _cameraAlt;
    _shownAz = aimAz;
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
