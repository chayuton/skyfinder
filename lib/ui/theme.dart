import 'package:flutter/material.dart';

/// Two palettes only, both dark on purpose: a star chart that flips to light
/// would blind an eye that has spent twenty minutes adapting to the dark.
/// The red mode exists for the same reason observatories use red torches.
class Sky {
  final Color ink, panel, panel2, line, fg, muted, dim, amber, cool, up, down,
      warn, star, milky;
  const Sky({
    required this.ink, required this.panel, required this.panel2,
    required this.line, required this.fg, required this.muted,
    required this.dim, required this.amber, required this.cool,
    required this.up, required this.down, required this.warn,
    required this.star, required this.milky,
  });

  static const night = Sky(
    ink: Color(0xFF070A14), panel: Color(0xFF0E1424), panel2: Color(0xFF141C30),
    line: Color(0xFF1E2840), fg: Color(0xFFE7ECFA), muted: Color(0xFF8291B0),
    dim: Color(0x99556080), amber: Color(0xFFFFC24D), cool: Color(0xFF6FC3FF),
    up: Color(0xFF6FE3A8), down: Color(0xFF4E5A78), warn: Color(0xFFFF9B6B),
    star: Color(0xFFF4F7FF), milky: Color(0xFF8FA6D8),
  );

  static const red = Sky(
    ink: Color(0xFF0B0203), panel: Color(0xFF190506), panel2: Color(0xFF230809),
    line: Color(0xFF3A0F10), fg: Color(0xFFFF7A68), muted: Color(0xFFB04A3E),
    dim: Color(0x997A2E28), amber: Color(0xFFFF5A3C), cool: Color(0xFFE06A52),
    up: Color(0xFFFF8A6B), down: Color(0xFF6B2420), warn: Color(0xFFFF5A3C),
    star: Color(0xFFFF9B82), milky: Color(0xFF8A2C24),
  );
}

const String fDisplay = 'BaiJamjuree';
const String fBody = 'IBMPlexSansThai';
const String fMono = 'IBMPlexMono';

ThemeData skyTheme(Sky c) {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: c.ink,
    canvasColor: c.panel,
    fontFamily: fBody,
    colorScheme: ColorScheme.dark(
      primary: c.amber,
      secondary: c.cool,
      surface: c.panel,
      onPrimary: const Color(0xFF120B00),
      onSurface: c.fg,
      error: c.warn,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.amber,
      inactiveTrackColor: c.line,
      thumbColor: c.amber,
      overlayColor: c.amber.withOpacity(0.15),
      trackHeight: 4,
    ),
    textTheme: TextTheme(
      headlineSmall: TextStyle(
          fontFamily: fDisplay, fontWeight: FontWeight.w700, color: c.fg),
      titleMedium: TextStyle(
          fontFamily: fDisplay, fontWeight: FontWeight.w600, fontSize: 14,
          color: c.fg),
      bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: c.fg),
      bodySmall: TextStyle(fontSize: 12.5, height: 1.5, color: c.muted),
      labelSmall: TextStyle(
          fontFamily: fDisplay, fontSize: 11, letterSpacing: 1.5,
          color: c.muted),
    ),
  );
}

/// An all-caps label with wide tracking, used above every card heading.
class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelSmall);
}

class SkyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const SkyCard({super.key, required this.child,
      this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final String kind; // up | dn | am
  const Pill(this.text, this.kind, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    final col = kind == 'up' ? c.up : (kind == 'am' ? c.amber : c.down);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: kind == 'dn' ? null : col.withOpacity(0.08),
        border: Border.all(color: col.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10.5, color: col, letterSpacing: 0.3)),
    );
  }
}

/// A pill-shaped on/off chip, used for the chart layers.
class Tog extends StatelessWidget {
  final String label;
  final bool on;
  final bool hot;
  final VoidCallback onTap;
  const Tog(this.label, this.on, this.onTap, {super.key, this.hot = false});

  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: on ? c.panel2 : c.panel,
          border: Border.all(
              color: on ? (hot ? c.amber : const Color(0xFF2E3B5E)) : c.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: on ? (hot ? c.amber : c.fg) : c.muted)),
      ),
    );
  }
}

/// A right-aligned key/value table; digits line up because the values are mono.
class Kv extends StatelessWidget {
  final List<(String, String)> rows;
  const Kv(this.rows, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.$1, style: TextStyle(fontSize: 13, color: c.muted)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(r.$2,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontFamily: fMono,
                            fontSize: 13,
                            color: c.fg,
                            fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class Hint extends StatelessWidget {
  final Widget child;
  const Hint({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final c = SkyColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: c.panel2,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DefaultTextStyle(
        style: TextStyle(fontSize: 12.5, height: 1.6, color: c.muted),
        child: child,
      ),
    );
  }
}

/// Carries the active palette down the tree so painters and widgets agree.
class SkyColors extends InheritedWidget {
  final Sky colors;
  const SkyColors({super.key, required this.colors, required super.child});

  static Sky of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkyColors>()?.colors ??
      Sky.night;

  @override
  bool updateShouldNotify(SkyColors old) => old.colors != colors;
}
