import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../engine/sky.dart';
import '../painters/aim_painter.dart';
import '../painters/sky_painter.dart';
import '../state/app_state.dart';
import 'theme.dart';

class AimTabView extends StatefulWidget {
  final AppState s;
  final Scene sc;
  const AimTabView({super.key, required this.s, required this.sc});

  @override
  State<AimTabView> createState() => _AimTabViewState();
}

class _AimTabViewState extends State<AimTabView> {
  NearHit? _hit;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final sc = widget.sc;
    final c = SkyColors.of(context);
    final compact = compactPhone(context);

    final tgt = s.target;
    final found = tgt != null ? findInScene(tgt, sc, s) : null;
    var steer = '';
    var sep = 0.0;
    if (found != null) {
      sep = angSep(s.aimAlt, s.aimAz, found.alt, found.az);
      final dAz = norm180(found.az - s.aimAz);
      final dAlt = found.alt - s.aimAlt;
      if (sep < 4) {
        steer = 'ตรงเป้าแล้ว';
      } else {
        final turn = dAz.abs() < 3
            ? ''
            : (dAz > 0
                ? 'หมุนขวา ${dAz.abs().round()}°'
                : 'หมุนซ้าย ${dAz.abs().round()}°');
        final tilt = dAlt.abs() < 3
            ? ''
            : (dAlt > 0
                ? 'เงยขึ้น ${dAlt.abs().round()}°'
                : 'ก้มลง ${dAlt.abs().round()}°');
        steer = [turn, tilt].where((x) => x.isNotEmpty).join(' · ');
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
          compact ? 12 : 16, 2, compact ? 12 : 16, 96 + MediaQuery.of(context).padding.bottom),
      children: [
        if (!s.sensorOn)
          SkyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('เล็งมือถือขึ้นฟ้า',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                    'ยกมือถือขึ้นชี้ไปบนฟ้า แล้วแอปจะบอกว่าคุณกำลังเล็งไปที่ดาวดวงไหน '
                    'ต้องใช้เข็มทิศและเซ็นเซอร์เอียงของเครื่อง',
                    style: TextStyle(
                        fontSize: compact ? 12 : 12.5,
                        height: 1.5,
                        color: c.muted)),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: s.startSensors,
                  child: const Text('เปิดเซ็นเซอร์ทิศทาง'),
                ),
                if (s.sensorNote.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(s.sensorNote,
                        style: TextStyle(fontSize: 12, height: 1.5, color: c.muted)),
                  ),
              ],
            ),
          ),
        Container(
          margin: EdgeInsets.only(top: compact ? 8 : 12),
          decoration: BoxDecoration(
            color: c.panel,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (_, box) {
              final w = box.maxWidth;
              final h = w * (compact ? 0.85 : 4 / 3);
              return SizedBox(
                width: w,
                height: h,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: AimPainter(sc, s, c, (hit) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && hit?.name != _hit?.name) {
                              setState(() => _hit = hit);
                            }
                          });
                        }),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ทิศ ${s.aimAz.round()}° ${compassTh(s.aimAz)}',
                              style: TextStyle(
                                  fontFamily: fMono,
                                  fontSize: compact ? 10.5 : 11.5,
                                  color: c.muted)),
                          Text('เงย ${s.aimAlt.round()}°',
                              style: TextStyle(
                                  fontFamily: fMono,
                                  fontSize: compact ? 10.5 : 11.5,
                                  color: c.muted)),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(14, 26, 14, compact ? 10 : 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              c.ink.withOpacity(0),
                              c.ink.withOpacity(0.8),
                              c.ink.withOpacity(0.93),
                            ],
                            stops: const [0, 0.42, 1],
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(_hit?.name ?? 'ไม่มีวัตถุเด่นตรงนี้',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: fDisplay,
                                    fontSize: compact ? 17 : 19,
                                    fontWeight: FontWeight.w700,
                                    color: c.fg)),
                            Text(
                                _hit != null
                                    ? '${_hit!.sub} · โชติมาตร ${_hit!.mag.toStringAsFixed(1)}'
                                        ' · ห่างจากจุดเล็ง ${_hit!.sep.toStringAsFixed(1)}°'
                                    : 'กวาดมือถือไปรอบ ๆ ช้า ๆ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: compact ? 11 : 12,
                                    color: c.muted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (!s.sensorOn)
          SkyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('ปรับเอง'),
                const SizedBox(height: 6),
                _slider(context, 'ทิศ (อะซิมุท)',
                    '${s.aimAz.round()}° ${compassShort(s.aimAz)}',
                    s.aimAz, 0, 359, (v) => s.setAim(s.aimAlt, v)),
                _slider(context, 'มุมเงย', '${s.aimAlt.round()}°',
                    s.aimAlt, 0, 90, (v) => s.setAim(v, s.aimAz)),
              ],
            ),
          ),
        SkyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('นำทางไปหาเป้าหมาย',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              if (tgt == null)
                Text(
                    'ยังไม่ได้เลือกเป้าหมาย — เลือกจากแท็บรายการ หรือแตะดาวบนแผนที่',
                    style: TextStyle(
                        fontSize: compact ? 12 : 12.5,
                        color: c.muted))
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('${sep.round()}°',
                        style: TextStyle(
                            fontFamily: fDisplay,
                            fontSize: compact ? 22 : 26,
                            fontWeight: FontWeight.w700,
                            color: sep < 4 ? c.up : c.amber)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(steer, style: TextStyle(fontSize: 14, color: c.fg)),
                          Text(
                              found != null && found.alt > 0
                                  ? 'อยู่ทาง${compassTh(found.az)} '
                                      'สูง ${refract(found.alt).round()}°'
                                  : 'เป้าหมายอยู่ใต้ขอบฟ้าตอนนี้',
                              style: TextStyle(
                                  fontSize: compact ? 11.5 : 12.5,
                                  color: c.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => s.setTarget(null),
                  child: const Text('ยกเลิกเป้าหมาย'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _slider(BuildContext context, String label, String value, double v,
      double min, double max, ValueChanged<double> onChanged) {
    final c = SkyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
            Text(value,
                style: TextStyle(fontSize: 12, fontFamily: fMono, color: c.muted)),
          ],
        ),
        Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged),
      ],
    );
  }
}
