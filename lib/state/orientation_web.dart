// The web build's compass.
//
// sensors_plus reads the magnetic field on the web through the Generic Sensor
// Magnetometer, which no shipping browser exposes to pages, and on iOS it has
// no accelerometer either, so through it the compass and the aim view never
// moved in a browser. Browsers do publish their own fused orientation as
// DeviceOrientation events, and that is what this reads:
//
// * Chrome and the other Chromium browsers on Android fire
//   `deviceorientationabsolute`, whose alpha is measured from north.
// * Safari, and every iOS browser since they all run WebKit, fire plain
//   `deviceorientation` with alpha from an arbitrary zero plus a separate
//   webkitCompassHeading, and only once DeviceOrientationEvent
//   .requestPermission() has been answered, which WebKit will only ask from
//   inside a tap. A page already allowed earlier in the session is answered
//   without a tap, so the quiet attempt at launch picks that up.
// * Any other `deviceorientation` that says it is absolute is taken as is.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../engine/orientation.dart';
import 'orientation_base.dart';

OrientationSource createOrientationSource() => _BrowserOrientation();

const _deniedNote = 'ไม่ได้รับอนุญาตให้ใช้เซ็นเซอร์ทิศทาง ปิดแท็บแล้วเปิดหน้าเว็บใหม่ '
    'แล้วแตะเข็มทิศอีกครั้ง หรือใช้แถบเลื่อน "ปรับเอง" ด้านล่างแทน';

class _BrowserOrientation implements OrientationSource {
  JSFunction? _listener;
  String _eventName = '';
  bool _asking = false;
  String _lastHint = '';
  final HeadingCalibration _calibration = HeadingCalibration();

  void Function(Axes axes)? _onAxes;
  void Function(String note)? _onHint;

  static JSObject? get _eventClass {
    final c = globalContext['DeviceOrientationEvent'];
    return c != null && c.typeofEquals('function') ? c as JSObject : null;
  }

  static bool get _hasPrompt {
    final c = _eventClass;
    if (c == null) return false;
    final f = c['requestPermission'];
    return f != null && f.typeofEquals('function');
  }

  @override
  bool get needsTap => _hasPrompt;

  @override
  bool get running => _listener != null;

  @override
  void start({
    required void Function(Axes axes) onAxes,
    required void Function() onListening,
    required void Function(String note) onFailed,
    required void Function(String note) onHint,
    bool quiet = false,
  }) {
    _onAxes = onAxes;
    _onHint = onHint;
    // Say again whatever is still holding the compass up; the caller has
    // just replaced its note with a generic one.
    _lastHint = '';
    if (_listener != null) {
      onListening();
      return;
    }
    final cls = _eventClass;
    if (cls == null) {
      if (!quiet) {
        onFailed('เบราว์เซอร์นี้ไม่ส่งค่าทิศทางของเครื่องให้หน้าเว็บ '
            'ใช้แถบเลื่อน "ปรับเอง" ด้านล่างแทน');
      }
      return;
    }
    if (!_hasPrompt) {
      _listen();
      onListening();
      return;
    }
    if (_asking) return;
    _asking = true;
    // Called straight from the tap with nothing awaited first: WebKit only
    // shows the prompt while it is still handling the touch.
    final JSPromise<JSAny?> answer;
    try {
      answer = cls.callMethod<JSPromise<JSAny?>>('requestPermission'.toJS);
    } catch (_) {
      _asking = false;
      if (!quiet) onFailed(_deniedNote);
      return;
    }
    answer.toDart.then((value) {
      _asking = false;
      if (value.dartify() == 'granted') {
        _listen();
        onListening();
      } else if (!quiet) {
        onFailed(_deniedNote);
      }
    }, onError: (Object _) {
      _asking = false;
      // WebKit refuses to ask at all without a tap. That is the expected
      // answer to the quiet attempt at launch: the compass waits for a tap.
      if (!quiet) {
        onFailed('แตะเข็มทิศอีกครั้งเพื่อให้เครื่องถามสิทธิ์ใช้เซ็นเซอร์ทิศทาง');
      }
    });
  }

  void _listen() {
    _eventName = globalContext.has('ondeviceorientationabsolute')
        ? 'deviceorientationabsolute'
        : 'deviceorientation';
    final listener = ((JSObject e) => _onEvent(e)).toJS;
    _listener = listener;
    globalContext.callMethod<JSAny?>(
        'addEventListener'.toJS, _eventName.toJS, listener);
  }

  @override
  void stop() {
    final l = _listener;
    if (l != null) {
      globalContext.callMethod<JSAny?>(
          'removeEventListener'.toJS, _eventName.toJS, l);
    }
    _listener = null;
    _lastHint = '';
    _calibration.reset();
  }

  void _onEvent(JSObject e) {
    final beta = _number(e, 'beta'), gamma = _number(e, 'gamma');
    if (beta == null || gamma == null) return;
    final alpha = _number(e, 'alpha');
    final compass = _number(e, 'webkitCompassHeading');

    final Axes axes;
    if (compass != null) {
      // WebKit: alpha runs from an arbitrary zero, so learn where north is
      // from the compass while the phone is held like one. Its heading
      // belongs to the phone's own portrait top whichever way the page has
      // turned, so this happens before the turn to the screen frame.
      final relative = axesFromEuler(alpha ?? 0, beta, gamma);
      final accuracy = _number(e, 'webkitCompassAccuracy');
      _calibration.feed(relative, compass, accuracy);
      final fixed = _calibration.apply(relative);
      if (fixed == null) {
        _hint(accuracy != null && accuracy < 0
            ? 'เข็มทิศของเครื่องยังไม่พร้อม ลองแกว่งมือถือเป็นรูปเลขแปดสักสองสามรอบ'
            : 'ถือมือถือหงายจอขึ้นนิ่ง ๆ สักครู่ ให้เข็มทิศหาทิศเหนือก่อน');
        return;
      }
      axes = fixed;
    } else if (alpha != null &&
        (_eventName == 'deviceorientationabsolute' || _isTrue(e, 'absolute'))) {
      axes = axesFromEuler(alpha, beta, gamma);
    } else {
      // A relative alpha with no compass to anchor it says nothing about
      // where north is.
      return;
    }
    _onAxes?.call(toScreenFrame(axes, _screenAngle()));
  }

  void _hint(String note) {
    if (note == _lastHint) return;
    _lastHint = note;
    _onHint?.call(note);
  }

  static double? _number(JSObject o, String key) {
    final v = o[key];
    if (v == null || !v.typeofEquals('number')) return null;
    final d = (v as JSNumber).toDartDouble;
    return d.isFinite ? d : null;
  }

  static bool _isTrue(JSObject o, String key) {
    final v = o[key];
    return v != null && v.typeofEquals('boolean') && (v as JSBoolean).toDart;
  }

  /// How far the page is turned from the phone's portrait, counter-clockwise.
  static double _screenAngle() {
    final screen = globalContext['screen'];
    if (screen != null && screen.typeofEquals('object')) {
      final o = (screen as JSObject)['orientation'];
      if (o != null && o.typeofEquals('object')) {
        final a = _number(o as JSObject, 'angle');
        if (a != null) return a;
      }
    }
    // Safari before 16.4 only has the older window.orientation.
    return _number(globalContext, 'orientation') ?? 0;
  }
}
