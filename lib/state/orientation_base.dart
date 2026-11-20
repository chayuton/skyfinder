import '../engine/orientation.dart';

/// Something that reports which way the phone faces. The app reads the
/// accelerometer and magnetometer itself; the web build reads the browser's
/// DeviceOrientation events instead, because no shipping browser lets a page
/// read the magnetometer.
abstract class OrientationSource {
  /// True when [start] only gets anywhere from inside a tap: iOS Safari shows
  /// its motion permission prompt for nothing else.
  bool get needsTap;

  /// Listening for readings, whether or not a usable one has come yet.
  bool get running;

  /// Begins delivering readings to [onAxes]; calling it again while running
  /// is harmless. [onListening] fires once readings may arrive, after any
  /// permission prompt. [onFailed] means the sensors are not coming;
  /// [onHint] is advice while still waiting for a first usable reading.
  ///
  /// When [quiet], a source that would have to ask stays silent and off,
  /// unless the user already allowed it earlier in the session.
  void start({
    required void Function(Axes axes) onAxes,
    required void Function() onListening,
    required void Function(String note) onFailed,
    required void Function(String note) onHint,
    bool quiet = false,
  });

  void stop();
}
