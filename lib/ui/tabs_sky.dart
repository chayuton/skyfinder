import 'package:flutter/material.dart';

import '../data/places.dart';
import '../engine/engine.dart';
import '../engine/sky.dart';
import '../painters/constellation_painter.dart';
import '../painters/sky_painter.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showSkySheet(BuildContext context, Sky colors, Widget child) {
  final compact = compactPhone(context);
  final landscape = landscapeLikeLayout(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.panel,
    barrierColor: const Color(0xCC02050B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SkyColors(
      colors: colors,
      child: DraggableScrollableSheet(
        initialChildSize: compact ? 0.82 : (landscape ? 0.8 : 0.72),
        minChildSize: compact ? 0.46 : 0.4,
        maxChildSize: compact ? 0.96 : (landscape ? 0.9 : 0.94),
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: colors.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 16, 0, compact ? 12 : 16, 20 + MediaQuery.of(ctx).padding.bottom),
                children: [child],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------ location

class LocationSheet extends StatefulWidget {
  final AppState s;
  const LocationSheet(this.s, {super.key});
  @override
  State<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<LocationSheet> {
  String? _selKey;
  String _gpsNote = '';
  String _manualNote = '';
  bool _busy = false;
  late final TextEditingController _lat =
      TextEditingController(text: widget.s.lat.toStringAsFixed(4));
  late final TextEditingController _lon =
      TextEditingController(text: widget.s.lon.toStringAsFixed(4));
  late final TextEditingController _h =
      TextEditingController(text: widget.s.height.round().toString());

  @override
  void initState() {
    super.initState();
    for (final p in placeIndex) {
      if (p.name == widget.s.place) {
        _selKey = p.key;
        break;
      }
    }
  }

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    _h.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final c = SkyColors.of(context);
    final info = _selKey != null ? placeByKey[_selKey!] : null;
    final compact = compactPhone(context);

    final latLonRow = compact
        ? Column(
            children: [
              Row(children: [
                Expanded(child: _field(c, _lat, 'ละติจูด')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _field(c, _lon, 'ลองจิจูด')),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: _field(c, _h, 'สูง (ม.)')),
            ],
          )
        : Row(
            children: [
              Expanded(child: _field(c, _lat, 'ละติจูด')),
              const SizedBox(width: 8),
              Expanded(child: _field(c, _lon, 'ลองจิจูด')),
              const SizedBox(width: 8),
              SizedBox(width: 86, child: _field(c, _h, 'สูง (ม.)')),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('ตำแหน่งผู้สังเกต'),
        const SizedBox(height: 3),
        Text('คุณดูดาวจากที่ไหน',
            style: TextStyle(
                fontFamily: fDisplay,
                fontSize: compact ? 17 : 18,
                fontWeight: FontWeight.w700,
                color: c.fg)),
        Text('ตำแหน่งเปลี่ยนไป 1 องศา ทำให้ดาวขึ้นเร็วขึ้นหรือช้าลงราว 4 นาที',
            style: TextStyle(fontSize: compact ? 12 : 12.5, color: c.muted)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() {
                      _busy = true;
                      _gpsNote = 'กำลังอ่านพิกัดจากเครื่อง…';
                    });
                    final note = await s.requestLocation();
                    if (!mounted) return;
                    setState(() {
                      _busy = false;
                      _gpsNote = note;
                      _selKey = null;
                      _lat.text = s.lat.toStringAsFixed(4);
                      _lon.text = s.lon.toStringAsFixed(4);
                      _h.text = s.height.round().toString();
                    });
                  },
            child: Text(_busy ? 'กำลังอ่าน…' : 'ใช้พิกัด GPS ของเครื่อง'),
          ),
        ),
        if (_gpsNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_gpsNote,
                style: TextStyle(fontSize: 12, height: 1.5, color: c.muted)),
          ),
        _sep(c),
        const Eyebrow('จังหวัดและจุดดูดาว'),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.panel2,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(11),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selKey,
              hint: Text('— เลือกสถานที่ —',
                  style: TextStyle(fontSize: 15, color: c.muted)),
              dropdownColor: c.panel,
              style: TextStyle(fontSize: 15, color: c.fg, fontFamily: fBody),
              items: _items(c),
              onChanged: (k) {
                if (k == null) return;
                final pl = placeByKey[k];
                if (pl == null) return;
                setState(() {
                  _selKey = k;
                  _lat.text = pl.lat.toStringAsFixed(4);
                  _lon.text = pl.lon.toStringAsFixed(4);
                  _h.text = pl.h.toString();
                  _gpsNote = '';
                });
                s.setPlace(pl.name, pl.lat, pl.lon, pl.h.toDouble());
              },
            ),
          ),
        ),
        if (info != null && info.kind == 'spot')
          Hint(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.blurb ?? ''),
                const SizedBox(height: 6),
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '${info.lat.toStringAsFixed(4)}°, '
                          '${info.lon.toStringAsFixed(4)}° · สูง ${info.h} ม.',
                      style: TextStyle(fontFamily: fMono, color: c.muted)),
                  if (info.approximate)
                    TextSpan(
                        text: ' · พิกัดเป็นค่าประมาณระดับพื้นที่',
                        style: TextStyle(color: c.warn)),
                ])),
              ],
            ),
          ),
        _sep(c),
        const Eyebrow('กรอกพิกัดเอง'),
        const SizedBox(height: 8),
        latLonRow,
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            final la = double.tryParse(_lat.text.trim());
            final lo = double.tryParse(_lon.text.trim());
            final hv = double.tryParse(_h.text.trim());
            if (la == null || lo == null || la.abs() > 90 || lo.abs() > 180) {
              setState(() => _manualNote =
                  'พิกัดไม่ถูกต้อง: ละติจูดอยู่ระหว่าง −90 ถึง 90 และลองจิจูด −180 ถึง 180');
              return;
            }
            s.setPlace('${la.toStringAsFixed(3)}°, ${lo.toStringAsFixed(3)}°',
                la, lo, (hv ?? 0).clamp(-500.0, 9000.0));
            setState(() {
              _manualNote = 'ใช้พิกัดที่กรอกแล้ว';
              _selKey = null;
            });
          },
          child: const Text('ใช้พิกัดนี้'),
        ),
        if (_manualNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_manualNote,
                style: TextStyle(fontSize: 12, color: c.muted)),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('เสร็จแล้ว'),
          ),
        ),
      ],
    );
  }

  /// Flutter's DropdownButton has no option groups, so each region gets a
  /// non-selectable header row instead.
  List<DropdownMenuItem<String>> _items(Sky c) {
    final out = <DropdownMenuItem<String>>[];
    void header(String label) {
      out.add(DropdownMenuItem<String>(
        enabled: false,
        value: '#$label',
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: c.muted)),
      ));
    }

    for (final g in spotGroups) {
      header('★ ${g.label}');
      for (final sp in g.spots) {
        out.add(DropdownMenuItem(
            value: 's:${sp.name}',
            child: Text('${sp.name} · ${sp.province}',
                maxLines: 1, overflow: TextOverflow.ellipsis)));
      }
    }
    for (final r in regions) {
      header('${r.label} (${r.places.length} จังหวัด)');
      for (final p in r.places) {
        out.add(DropdownMenuItem(value: 'p:${p.name}', child: Text(p.name)));
      }
    }
    return out;
  }

  Widget _field(Sky c, TextEditingController ctl, String hint) => TextField(
        controller: ctl,
        keyboardType: const TextInputType.numberWithOptions(
            decimal: true, signed: true),
        style: TextStyle(fontFamily: fMono, fontSize: 13, color: c.fg),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.muted, fontSize: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          filled: true,
          fillColor: c.panel2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: c.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: c.line),
          ),
        ),
      );

  Widget _sep(Sky c) => Container(
      height: 1, color: c.line, margin: const EdgeInsets.symmetric(vertical: 14));
}

