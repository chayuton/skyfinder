// The app and the web build reach the phone's orientation by different roads;
// both hand AppState the same Axes. Pick the road at compile time.
export 'orientation_base.dart';
export 'orientation_native.dart'
    if (dart.library.js_interop) 'orientation_web.dart';
