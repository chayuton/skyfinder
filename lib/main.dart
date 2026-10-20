import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine/sky.dart';
import 'state/app_state.dart';
import 'ui/compass.dart';
import 'ui/sheets.dart';
import 'ui/tabs_aim.dart';
import 'ui/tabs_con.dart';
import 'ui/tabs_rest.dart';
import 'ui/tabs_sky.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const SkyFinderApp());
}

class SkyFinderApp extends StatefulWidget {
  const SkyFinderApp({super.key});
  @override
  State<SkyFinderApp> createState() => _SkyFinderAppState();
}

class _SkyFinderAppState extends State<SkyFinderApp> {
  final AppState _state = AppState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final colors = _state.nightMode ? Sky.red : Sky.night;
        return MaterialApp(
          title: 'ดาวนำทาง',
          debugShowCheckedModeBanner: false,
          theme: skyTheme(colors),
          home: SkyColors(colors: colors, child: HomePage(state: _state)),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  final AppState state;
  const HomePage({super.key, required this.state});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _scrolling = false;
  DateTime _lastScroll = DateTime.fromMillisecondsSinceEpoch(0);

  void _onScroll() {
    _lastScroll = DateTime.now();
    if (!_scrolling) setState(() => _scrolling = true);
    Future.delayed(const Duration(milliseconds: 460), () {
      if (!mounted) return;
      if (DateTime.now().difference(_lastScroll).inMilliseconds >= 450) {
        setState(() => _scrolling = false);
      }
    });
  }

  void _pick(Selection sel) {
    final s = widget.state;
    s.select(sel);
    showSkySheet(context, SkyColors.of(context),
        ObjectSheet(s: s, sc: s.scene(), sel: sel));
  }

  void _openCon(String id) {
    final s = widget.state;
    showSkySheet(
        context,
        SkyColors.of(context),
        ConstellationSheet(s: s, sc: s.scene(), conId: id, onPick: _pick));
  }

  void _openPlace() {
    showSkySheet(context, SkyColors.of(context), LocationSheet(widget.state));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final c = SkyColors.of(context);
    final sc = s.scene();

    final Widget body = switch (s.tab) {
      SkyTab.sky => SkyTabView(s: s, sc: sc, onPick: _pick),
      SkyTab.aim => AimTabView(s: s, sc: sc),
      SkyTab.con => ConTabView(s: s, sc: sc, onOpen: _openCon),
      SkyTab.list => ListTabView(s: s, sc: sc, onPick: _pick),
      SkyTab.night => NightTabView(s: s, sc: sc, onPick: _pick),
      SkyTab.settings => SettingsTabView(s: s, onOpenPlace: _openPlace),
    };

    return Scaffold(
      backgroundColor: c.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context, s, c),
            Expanded(
              child: Stack(
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollUpdateNotification) _onScroll();
                      return false;
                    },
                    child: body,
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: SkyCompass(state: s, scrolling: _scrolling),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _tabBar(context, s, c),
    );
  }

  Widget _header(BuildContext context, AppState s, Sky c) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;

    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 10, compact ? 12 : 16, 8),
      color: c.ink,
      child: Row(
        children: [
          Text('ดาวนำทาง',
              style: TextStyle(
                  fontFamily: fDisplay,
                  fontSize: compact ? 16 : 17,
                  fontWeight: FontWeight.w700,
                  color: c.fg)),
          const Spacer(),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 120 : 170),
              child: GestureDetector(
                onTap: _openPlace,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: compact ? 9 : 11, vertical: compact ? 4 : 5),
                  decoration: BoxDecoration(
                    color: c.panel,
                    border: Border.all(color: c.line),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('📍 ${s.place}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 11.5 : 12.5,
                          color: c.fg)),
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtClock(s.now),
                  style: TextStyle(
                      fontFamily: fMono,
                      fontSize: compact ? 12 : 13,
                      color: c.fg)),
              Text(
                  s.offsetMinutes == 0
                      ? 'ตอนนี้'
                      : '${s.offsetMinutes > 0 ? '+' : ''}${s.offsetMinutes} น.',
                  style: TextStyle(
                      fontFamily: fMono,
                      fontSize: compact ? 9.2 : 10,
                      color: c.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabBar(BuildContext context, AppState s, Sky c) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;
    final tabs = [
      (SkyTab.sky, 'แผนที่ฟ้า', Icons.public),
      (SkyTab.aim, 'เล็ง', Icons.my_location),
      (SkyTab.con, 'กลุ่มดาว', Icons.auto_graph),
      (SkyTab.list, 'รายการ', Icons.format_list_bulleted),
      (SkyTab.night, 'คืนนี้', Icons.nightlight_round),
      (SkyTab.settings, 'ตั้งค่า', Icons.settings),
    ];

    return Container(
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(top: BorderSide(color: c.line)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: InkWell(
                onTap: () => s.setTab(t.$1),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: compact ? 7.5 : 9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.$3,
                          size: compact ? 18 : 20,
                          color: s.tab == t.$1 ? c.amber : c.muted),
                      SizedBox(height: compact ? 2 : 3),
                      Text(t.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: fDisplay,
                              fontSize: compact ? 8.4 : 9.5,
                              color: s.tab == t.$1 ? c.amber : c.muted)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
