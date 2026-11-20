import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

import '../engine/orientation.dart';
import 'orientation_base.dart';

OrientationSource createOrientationSource() => _SensorOrientation();

/// Orientation from the accelerometer and magnetometer rather than a prebuilt
/// orientation stream, because those two are the sensors every phone has.
class _SensorOrientation implements OrientationSource {
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  // About a third of the way to each new reading at the UI rate: the needle
  // settles in a fifth of a second and stops shivering at rest.
  final VectorSmoother _acc = VectorSmoother(0.3);
  final VectorSmoother _mag = VectorSmoother(0.3);

  @override
  bool get needsTap => false;

  @override
  bool get running => _accSub != null || _magSub != null;

  @override
  void start({
    required void Function(Axes axes) onAxes,
    required void Function() onListening,
    required void Function(String note) onFailed,
    required void Function(String note) onHint,
    bool quiet = false,
  }) {
    if (_accSub != null || _magSub != null) {
      onListening();
      return;
    }

    void fuse() {
      final a = _acc.value, m = _mag.value;
      if (a == null || m == null) return;
      final axes = axesFromSensors(a, m);
      if (axes != null) onAxes(axes);
    }

    try {
      _accSub = accelerometerEventStream(
              samplingPeriod: SensorInterval.uiInterval)
          .listen((e) {
        _acc.add(e.x, e.y, e.z);
        fuse();
      }, onError: (_) {
        onFailed('อ่านเซ็นเซอร์ความเร่งไม่ได้ ใช้แถบเลื่อนปรับเองด้านล่างแทน');
      });
      _magSub = magnetometerEventStream(
              samplingPeriod: SensorInterval.uiInterval)
          .listen((e) {
        _mag.add(e.x, e.y, e.z);
        fuse();
      }, onError: (_) {
        onFailed('เครื่องนี้ไม่มีเข็มทิศ ใช้แถบเลื่อนปรับเองด้านล่างแทน');
      });
    } catch (_) {
      stop();
      onFailed('เปิดเซ็นเซอร์ไม่ได้ ใช้แถบเลื่อนปรับเองด้านล่างแทน');
      return;
    }
    onListening();
  }

  @override
  void stop() {
    _accSub?.cancel();
    _magSub?.cancel();
    _accSub = null;
    _magSub = null;
    _acc.reset();
    _mag.reset();
  }
}
