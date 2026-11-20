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
//   webkitCompassHeading.
// * Any other `deviceorientation` that says it is absolute is taken as is.
//
// Where DeviceOrientationEvent.requestPermission() exists (WebKit, and
// Chromium since version 151) events only flow once it has said "granted".
// It answers at once, without a tap, when the user has already allowed
// motion sensors, which is Chrome's default and what Safari remembers for
// the rest of a session, so the quiet attempt at launch covers that; a
// prompt can only be shown from inside a tap, which the compass provides.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../engine/orientation.dart';
import 'orientation_base.dart';

OrientationSource createOrientationSource() => _BrowserOrientation();

const _deniedNote = 'ไม่ได้รับอนุญาตให้ใช้เซ็นเซอร์ทิศทาง ปิดแท็บแล้วเปิดหน้าเว็บใหม่ '
    'แล้วแตะเข็มทิศอีกครั้ง หรือใช้แถบเลื่อน "ปรับเอง" ด้านล่างแทน';
const _tapAgainNote =
    'แตะเข็มทิศอีกครั้งเพื่อให้เครื่องถามสิทธิ์ใช้เซ็นเซอร์ทิศทาง';

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
    if (!quiet && _tapsAreNotGestures) {
      _askOnNextGesture(cls, onListening, onFailed);
      onFailed(_tapAgainNote);
      return;
    }
    _ask(cls, quiet: quiet, onListening: onListening, onFailed: onFailed);
  }

  /// Browsers treat every event a touch produces as part of the gesture, the
  /// pointerup Flutter delivers its taps from included, so asking straight
  /// from the tap is enough. Should some version turn that down anyway, the
  /// touchend and click that end a touch always count: from then on the
  /// request is made from the next one of those instead.
  bool _tapsAreNotGestures = false;

  void _ask(
    JSObject cls, {
    required bool quiet,
    required void Function() onListening,
    required void Function(String note) onFailed,
  }) {
    if (_asking) return;
    _asking = true;
    // Called straight from the tap with nothing awaited first: a prompt is
    // only shown while the browser is still handling the touch. Chromium
    // also needs to be told the magnetometer is wanted, or it allows only
    // the relative angles; WebKit takes no argument and ignores it.
    final JSPromise<JSAny?> answer;
    try {
      answer = globalContext.has('ondeviceorientationabsolute')
          ? cls.callMethod<JSPromise<JSAny?>>(
              'requestPermission'.toJS, true.toJS)
          : cls.callMethod<JSPromise<JSAny?>>('requestPermission'.toJS);
    } catch (_) {
      _asking = false;
      if (!quiet) onFailed(_deniedNote);
      return;
    }
    answer.toDart.then((value) {
      _asking = false;
      if (value.dartify() == 'granted') {
        _cancelRetry();
        _listen();
        onListening();
      } else if (!quiet) {
        onFailed(_deniedNote);
      }
    }, onError: (Object _) {
      _asking = false;
      // WebKit refuses to ask at all outside a gesture. That is the expected
      // answer to the quiet attempt at launch: the compass waits for a tap.
      if (quiet) return;
      _tapsAreNotGestures = true;
      _askOnNextGesture(cls, onListening, onFailed);
      onFailed(_tapAgainNote);
    });
  }

  JSFunction? _retryListener;
  static const _gestureEnds = ['touchend', 'click'];

  void _askOnNextGesture(JSObject cls, void Function() onListening,
      void Function(String note) onFailed) {
    if (_retryListener != null) return;
    void onGesture(JSObject _) {
      _cancelRetry();
      _ask(cls, quiet: false, onListening: onListening, onFailed: onFailed);
    }

    final listener = onGesture.toJS;
    _retryListener = listener;
    for (final type in _gestureEnds) {
      globalContext.callMethod<JSAny?>(
          'addEventListener'.toJS, type.toJS, listener, true.toJS);
    }
  }

  void _cancelRetry() {
    final l = _retryListener;
    if (l == null) return;
    _retryListener = null;
    for (final type in _gestureEnds) {
      globalContext.callMethod<JSAny?>(
          'removeEventListener'.toJS, type.toJS, l, true.toJS);
    }
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
    _cancelRetry();
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
