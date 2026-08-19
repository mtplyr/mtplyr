import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:local_auth/local_auth.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:window_manager/window_manager.dart';
import 'xtream.dart';
import 'l10n.dart';
import 'brand.dart';
import 'downloads.dart';

/// Desktop (Windows/macOS/Linux) — dort gibt es Fenster-Vollbild.
final bool kDesktop = !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (kDesktop) { try { await windowManager.ensureInitialized(); } catch (_) {} }
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await Session.load();
  await FavStore.load();
  await Prefs.load();
  await ResumeStore.load();
  await ContinueStore.load();
  await License.load();
  if (kDesktop) { await Downloads.load(); } // Offline-Downloads (Desktop)
  unawaited(Session.registerDevice()); // MAC beim Hub anmelden (nicht blockierend)
  runApp(const BrandApp());
}

// Farben + Markenname kommen aus brand.dart (Vela = Blau, Nina = Grün).

class BrandApp extends StatelessWidget {
  const BrandApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: langTick,
      builder: (_, _, _) => MaterialApp(
        key: ValueKey(Prefs.lang),
        title: kBrandName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: kBg, fontFamily: 'Roboto'),
        home: !Session.isReady ? const ActivationScreen() : const HomeGate(),
      ),
    );
  }
}

BoxDecoration _bgDeco() => const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [kBg2, kBg, Color(0xFF080F1B)]),
    );
bool _narrow(BuildContext c) => MediaQuery.of(c).size.width < 700;

/// Fokussierbares Element für Fernbedienung/D-Pad (Android-TV, Samsung, LG).
/// Zeigt bei Fokus einen blauen Rahmen; Touch (onTap) bleibt erhalten.
class TvFocus extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool autofocus;
  final double radius;
  const TvFocus({super.key, required this.child, required this.onTap, this.autofocus = false, this.radius = 12});
  @override
  State<TvFocus> createState() => _TvFocusState();
}

// Fokusrahmen nur auf Nicht-iOS (Fernbedienung/TV/Web). Am iPhone = reines Touch.
final bool kTvRing = defaultTargetPlatform != TargetPlatform.iOS;

class _TvFocusState extends State<TvFocus> {
  bool _f = false;
  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: kTvRing && widget.autofocus,
      onFocusChange: (v) { if (v != _f) setState(() => _f = v); },
      mouseCursor: SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { widget.onTap(); return null; }),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: (_f && kTvRing) ? kBlue : Colors.transparent, width: 2.5),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

String _tsDate(dynamic v) {
  final s = '$v'.trim();
  if (s.isEmpty || s == '0' || s == 'null') return '—';
  final n = int.tryParse(s);
  final d = n != null ? DateTime.fromMillisecondsSinceEpoch(n * 1000) : DateTime.tryParse(s);
  if (d == null) return s;
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 34});
  @override
  Widget build(BuildContext context) {
    // Nina: Kreis + Stream-Icon (grün); Vela: Rundeck + Play-Pfeil (blau).
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [kBlue, kBlue2]), borderRadius: BorderRadius.circular(size * (kIsNina ? 0.5 : 0.28))),
        child: Icon(kIsNina ? Icons.sensors_rounded : Icons.play_arrow_rounded, color: kBg, size: size * (kIsNina ? 0.6 : 0.66)),
      ),
      const SizedBox(width: 9),
      Text.rich(
        const TextSpan(children: [
          TextSpan(text: kIsNina ? 'NI' : 'VE', style: TextStyle(color: kText, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          TextSpan(text: kIsNina ? 'NA' : 'LA', style: TextStyle(color: kBlue, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        ]),
        style: TextStyle(fontSize: size * 0.62, fontFamily: 'serif'),
      ),
    ]);
  }
}

// MAC + Geräteschlüssel als Panel (Aktivierung + Playlist-Screen).
// compact = kleiner (Konto-Screen, damit die Kacheln ohne Scrollen passen).
Widget _idRowT(BuildContext context, String label, String value, {bool compact = false}) => Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: kMuted, fontSize: compact ? 11 : 12)),
        SizedBox(height: compact ? 1 : 3),
        Text(value, style: TextStyle(color: kBlue, fontSize: compact ? 15 : 20, fontWeight: FontWeight.w800, letterSpacing: compact ? 1.0 : 1.5, fontFamily: 'monospace')),
      ])),
      IconButton(
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
        constraints: compact ? const BoxConstraints() : null,
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          await Clipboard.setData(ClipboardData(text: value));
          messenger.showSnackBar(SnackBar(backgroundColor: kPanel, content: Text(L.t('copied'), style: const TextStyle(color: kText))));
        },
        icon: Icon(Icons.copy_rounded, color: kMuted, size: compact ? 18 : 20),
      ),
    ]);

Widget _idPanel(BuildContext context, {bool compact = false}) => Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 18, vertical: compact ? 9 : 14),
      decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
      child: Column(children: [
        _idRowT(context, L.t('mac_address'), Session.mac, compact: compact),
        Divider(color: kLine, height: compact ? 13 : 20),
        _idRowT(context, L.t('device_key_label'), Session.deviceKey, compact: compact),
      ]),
    );

// ============================ GATE: entscheidet Home / Paywall / Playlist abgelaufen ============================
class HomeGate extends StatefulWidget {
  const HomeGate({super.key});
  @override
  State<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<HomeGate> {
  bool loading = true;
  bool playlistExpired = false;

  @override
  void initState() { super.initState(); _check(); }

  bool needsActivation = false;

  Future<void> _check() async {
    await License.startTrial();
    await License.syncFromServer(); // Trial/paid an MAC gebunden (Server = Wahrheit)
    // velaplayer.com ist die Wahrheit: Playlist dort gelöscht -> App verliert sie hier.
    // 'error' (offline) lässt den lokalen Stand unangetastet, damit die App offline läuft.
    if (Session.isReady) {
      final plState = await Session.syncFromActivation();
      if (plState == 'none') {
        await Session.clear();
        if (mounted) setState(() { needsActivation = true; loading = false; });
        return;
      }
    }
    bool exp = License.simExpiredPlaylist;
    if (!exp && Session.account != null) {
      try {
        final i = await Xtream.userInfo(Session.account!);
        if (i != null) {
          final status = '${i['status'] ?? ''}'.toLowerCase();
          final expTs = int.tryParse('${i['exp_date'] ?? ''}');
          exp = (status.isNotEmpty && status != 'active') ||
              (expTs != null && expTs > 0 && DateTime.fromMillisecondsSinceEpoch(expTs * 1000).isBefore(DateTime.now()));
        }
      } catch (_) {}
    }
    if (mounted) setState(() { playlistExpired = exp; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Scaffold(body: Container(decoration: _bgDeco(), child: _loading()));
    if (needsActivation || !Session.isReady) return const ActivationScreen();
    if (playlistExpired) return const PlaylistExpiredScreen();
    if (License.trialExpired) return const PaywallScreen();
    return const HomeScreen();
  }
}

// ============================ PAYWALL (Trial abgelaufen) ============================
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _bgDeco(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const BrandLogo(size: 44),
                  const SizedBox(height: 22),
                  Container(width: 72, height: 72, decoration: BoxDecoration(color: kBlue.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.lock_rounded, color: kBlue, size: 36)),
                  const SizedBox(height: 16),
                  Text(L.t('paywall_title'), textAlign: TextAlign.center, style: const TextStyle(color: kText, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'serif')),
                  const SizedBox(height: 6),
                  Text(L.t('paywall_body'), textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 13.5, height: 1.4)),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBlue)),
                    child: Row(children: [
                      Expanded(child: Text('$kBrandName · ${L.t('lifetime')}', style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700))),
                      const Text('10 €', style: TextStyle(color: kBlue, fontSize: 24, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: kBlue, foregroundColor: kBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        await License.setPaid(true); // TEST/Fake – auf iOS später Apple In-App-Kauf
                        if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeGate()));
                      },
                      child: Text('${L.t('buy_now')} · 10 €', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () async {
                      await License.setPaid(true);
                      if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeGate()));
                    },
                    child: Text(L.t('restore'), style: const TextStyle(color: kMuted, fontSize: 13)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================ PLAYLIST ABGELAUFEN / NICHT AKTIV ============================
class PlaylistExpiredScreen extends StatelessWidget {
  const PlaylistExpiredScreen({super.key});

  void _menu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.settings_rounded, color: kBlue),
            title: Text(L.t('settings_title'), style: const TextStyle(color: kText)),
            onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())); },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded, color: kBlue),
            title: Text(L.t('change_playlist'), style: const TextStyle(color: kText)),
            onTap: () async { Navigator.pop(context); await Session.clear(); if (context.mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ActivationScreen()), (_) => false); },
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: kMuted),
            title: Text(L.t('logout'), style: const TextStyle(color: kText)),
            onTap: () async { Navigator.pop(context); await Session.clear(); if (context.mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ActivationScreen()), (_) => false); },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _bgDeco(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const BrandLogo(size: 44),
                  const SizedBox(height: 20),
                  Container(width: 66, height: 66, decoration: BoxDecoration(color: const Color(0xFFE0B366).withValues(alpha: .16), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.event_busy_rounded, color: Color(0xFFE0B366), size: 32)),
                  const SizedBox(height: 14),
                  Text(L.t('playlist_expired_title'), textAlign: TextAlign.center, style: const TextStyle(color: kText, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'serif')),
                  const SizedBox(height: 6),
                  Text(L.t('playlist_expired_body'), textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 13.5, height: 1.4)),
                  const SizedBox(height: 18),
                  _idPanel(context),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: kLine), foregroundColor: kText),
                          onPressed: () => _menu(context),
                          icon: const Icon(Icons.menu_rounded, size: 20),
                          label: Text(L.t('menu'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: kBlue, foregroundColor: kBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeGate())),
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: Text(L.t('reload'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================ AKTIVIERUNG (velaplayer.com-Modell) ============================
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});
  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  bool busy = false;
  String? msg;

  // Querformat = breit & niedrig -> zwei Spalten, damit nichts scrollen muss.
  bool _wideAct(BuildContext c) => MediaQuery.of(c).size.width > 700;

  Widget _actHeader(BuildContext context) {
    final wide = _wideAct(context);
    return Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandLogo(size: 34),
        const SizedBox(height: 12),
        Text(L.t('welcome'), textAlign: wide ? TextAlign.left : TextAlign.center, style: const TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'serif')),
        const SizedBox(height: 3),
        Text(L.t('activate_intro'), textAlign: wide ? TextAlign.left : TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _idRow(L.t('mac_address'), Session.mac),
            const Divider(color: kLine, height: 18),
            _idRow(L.t('device_key_label'), Session.deviceKey),
          ]),
        ),
      ],
    );
  }

  Widget _actSteps(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _step('1', '${L.t('activate_s1')}  $kPortal'),
          _step('2', L.t('activate_s2')),
          _step('3', L.t('activate_s3')),
          if (msg != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(msg!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFF2A0A0), fontSize: 13))),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kBlue, foregroundColor: kBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
              onPressed: busy ? null : _check,
              child: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: kBg))
                  : Text(L.t('activate_check'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectScreen())),
            child: Text(L.t('activate_manual'), style: const TextStyle(color: kMuted, fontSize: 13)),
          ),
        ],
      );

  Future<void> _check() async {
    setState(() { busy = true; msg = null; });
    final ok = await Session.pullActivation(); // Xtream ODER M3U
    if (ok) {
      await License.startTrial();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeGate()));
      return;
    }
    if (mounted) setState(() { busy = false; msg = L.t('activate_pending'); });
  }

  Widget _idRow(String label, String value) => Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: kBlue, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontFamily: 'monospace')),
        ])),
        IconButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: value));
            messenger.showSnackBar(SnackBar(backgroundColor: kPanel, content: Text(L.t('copied'), style: const TextStyle(color: kText))));
          },
          icon: const Icon(Icons.copy_rounded, color: kMuted, size: 20),
        ),
      ]);

  Widget _step(String n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(color: kBlue.withValues(alpha: .16), borderRadius: BorderRadius.circular(13)), child: Text(n, style: const TextStyle(color: kBlue, fontWeight: FontWeight.w800, fontSize: 13))),
          const SizedBox(width: 12),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(text, style: const TextStyle(color: kText, fontSize: 14.5, height: 1.3)))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _bgDeco(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _wideAct(context) ? 780 : 460),
                child: _wideAct(context)
                    ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Expanded(child: _actHeader(context)),
                        const SizedBox(width: 28),
                        Expanded(child: _actSteps(context)),
                      ])
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        _actHeader(context),
                        const SizedBox(height: 18),
                        _actSteps(context),
                      ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================ VERBINDEN (manuell/Test) ============================
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final host = TextEditingController(text: 'http://d67.xyz:8080');
  final user = TextEditingController(text: 'alex_v_ali_3');
  final pass = TextEditingController(text: 'workfufufu');
  final m3u = TextEditingController();
  String mode = 'xtream'; // 'xtream' oder 'm3u'
  bool busy = false;
  String? err;

  Future<void> _connect() async {
    setState(() { busy = true; err = null; });
    bool pushed;
    if (mode == 'm3u') {
      final url = m3u.text.trim();
      if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
        setState(() { busy = false; err = L.t('m3u_url_err'); });
        return;
      }
      // M3U-Link an velaplayer.com melden -> erscheint dort (Kunde/Reseller), Server = Wahrheit.
      pushed = await Session.pushM3uToServer(url);
    } else {
      final a = Account(host.text.trim(), user.text.trim(), pass.text.trim());
      final info = await Xtream.userInfo(a);
      if (!mounted) return;
      if (info == null) {
        setState(() { busy = false; err = L.t('connect_err'); });
        return;
      }
      // Xtream an velaplayer.com melden -> erscheint dort (Kunde/Reseller), Server = Wahrheit.
      pushed = await Session.pushXtreamToServer(a);
    }
    if (!mounted) return;
    if (!pushed) {
      setState(() { busy = false; err = L.t('server_save_err'); });
      return;
    }
    // App zieht die jetzt server-hinterlegte Playlist (identisch zum velaplayer.com-Weg).
    final ok = await Session.pullActivation();
    if (!mounted) return;
    if (!ok) {
      setState(() { busy = false; err = L.t('server_save_err'); });
      return;
    }
    await License.startTrial();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeGate()), (_) => false);
  }

  // Umschalter Xtream / M3U-Link.
  Widget _modeToggle() {
    Widget seg(String m, String label) {
      final sel = mode == m;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() { mode = m; err = null; }),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? kBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(label, style: TextStyle(color: sel ? kBg : kMuted, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: kPanel2, borderRadius: BorderRadius.circular(11), border: Border.all(color: kLine)),
      child: Row(children: [seg('xtream', 'Xtream'), const SizedBox(width: 4), seg('m3u', L.t('manual_m3u'))]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _bgDeco(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const BrandLogo(size: 44),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(L.t('connect_title'), style: const TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'serif')),
                    const SizedBox(height: 4),
                    Text(L.t('connect_sub'), style: const TextStyle(color: kMuted, fontSize: 13)),
                    const SizedBox(height: 12),
                    _modeToggle(),
                    if (mode == 'xtream') ...[
                      _field(host, L.t('connect_server')),
                      _field(user, L.t('username')),
                      _field(pass, L.t('password'), obscure: true),
                    ] else ...[
                      _field(m3u, L.t('m3u_url_hint')),
                    ],
                    if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: const TextStyle(color: Color(0xFFF2A0A0), fontSize: 13))),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: kBlue, foregroundColor: kBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                        onPressed: busy ? null : _connect,
                        child: busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: kBg))
                            : Text(L.t('connect_btn'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {bool obscure = false}) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: TextField(
          controller: c, obscureText: obscure, style: const TextStyle(color: kText),
          decoration: InputDecoration(
            hintText: hint, hintStyle: const TextStyle(color: kMuted, fontSize: 13.5),
            filled: true, fillColor: kPanel2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBlue)),
          ),
        ),
      );
}

// ============================ HOME ============================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Item> _latestVod = [];
  List<Item> _latestSeries = [];
  final ScrollController _movieScroll = ScrollController();
  final ScrollController _seriesScroll = ScrollController();
  final ScrollController _favScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  @override
  void dispose() {
    _movieScroll.dispose();
    _seriesScroll.dispose();
    _favScroll.dispose();
    super.dispose();
  }

  // „Zuletzt hinzugefügt" – schlank über den Hub (Server sortiert + cacht).
  Future<void> _loadLatest() async {
    if (Session.mode != 'xtream') { return; }
    final res = await Xtream.homeLatest(limit: 10);
    if (mounted) {
      setState(() {
        _latestVod = res['movies'] ?? [];
        _latestSeries = res['series'] ?? [];
      });
    }
  }

  void _open(BuildContext c, Widget s) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => s)).then((_) { if (mounted) setState(() {}); });

  List<_Tile> _tiles(BuildContext c) => [
        _Tile(L.t('home_live'), L.t('home_live_sub'), Icons.live_tv_rounded, kTileAccents[0], () => _open(c, const LiveScreen())),
        _Tile(L.t('home_movies'), L.t('home_movies_sub'), Icons.movie_creation_rounded, kTileAccents[1], () => _open(c, CatalogScreen(title: L.t('home_movies'), type: 'vod'))),
        _Tile(L.t('home_series'), L.t('home_series_sub'), Icons.theaters_rounded, kTileAccents[2], () => _open(c, CatalogScreen(title: L.t('home_series'), type: 'series'))),
        _Tile(L.t('home_replay'), L.t('home_replay_sub'), Icons.replay_rounded, kTileAccents[3], () => _open(c, const LiveScreen(catchup: true))),
      ];

  @override
  Widget build(BuildContext context) {
    final narrow = _narrow(context);
    final cont = ContinueStore.items();
    final favSeries = FavStore.items('series');
    final favs = [...favSeries, ...FavStore.items('vod')];
    final favSeriesIds = favSeries.map((e) => e.id).toSet();
    return Scaffold(
      body: Container(
        decoration: _bgDeco(),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(narrow ? 16 : 24),
            child: Column(children: [
              Row(children: [
                const BrandLogo(size: 30),
                const Spacer(),
                _iconBox(Icons.search_rounded, onTap: () => _open(context, const SearchScreen())),
                const SizedBox(width: 10),
                if (kDesktop) ...[
                  _iconBox(Icons.download_rounded, onTap: () => _open(context, const DownloadsScreen())),
                  const SizedBox(width: 10),
                ],
                _iconBox(Icons.settings_rounded, onTap: () => _open(context, const SettingsScreen())),
                const SizedBox(width: 10),
                _iconBox(Icons.person_rounded, onTap: () => _open(context, const AccountScreen())),
              ]),
              SizedBox(height: narrow ? 14 : 18),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, cons) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: cons.maxHeight),
                      child: Column(
                        mainAxisAlignment: (_latestVod.isEmpty && _latestSeries.isEmpty) ? MainAxisAlignment.center : MainAxisAlignment.start,
                        children: [
                          if (cont.isNotEmpty) ...[
                            _continueRow(context, cont, narrow),
                            SizedBox(height: narrow ? 14 : 18),
                          ],
                          if (favs.isNotEmpty) ...[
                            _posterRow(context, '★ ${L.t('favorites')}', favs, false, narrow, _favScroll, seriesOf: (it) => favSeriesIds.contains(it.id), centerFew: false),
                            SizedBox(height: narrow ? 16 : 22),
                          ],
                          _grid(context, narrow),
                          if (_latestVod.isNotEmpty) ...[
                            SizedBox(height: narrow ? 16 : 22),
                            _posterRow(context, L.t('latest_movies'), _latestVod, false, narrow, _movieScroll),
                          ],
                          if (_latestSeries.isNotEmpty) ...[
                            SizedBox(height: narrow ? 16 : 22),
                            _posterRow(context, L.t('latest_series'), _latestSeries, true, narrow, _seriesScroll),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _continueRow(BuildContext context, List<ContinueItem> items, bool narrow) {
    final h = narrow ? 92.0 : 100.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(L.t('continue_watching'), style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'serif')),
      ),
      SizedBox(
        height: h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (ctx, i) {
            final it = items[i];
            return TvFocus(
              radius: 12,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(title: it.title, url: it.url, resume: true, poster: it.poster))).then((_) { if (mounted) setState(() {}); });
              },
              child: Container(
                width: 250,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 56, height: double.infinity, color: kPanel2,
                      child: it.poster.isEmpty
                          ? const Icon(Icons.movie_rounded, color: kMuted, size: 22)
                          : Image.network(it.poster, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.movie_rounded, color: kMuted, size: 22)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(value: it.progress, minHeight: 4, backgroundColor: kLine, valueColor: const AlwaysStoppedAnimation(kBlue)),
                      ),
                    ]),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // Poster-Reihe „Neueste Filme / Serien" — mittig, mit dezenten Blätter-Pfeilen
  // links/rechts. ~5–6 sichtbar, 10 geladen (Rest durch Blättern).
  Widget _posterRow(BuildContext context, String title, List<Item> items, bool isSeries, bool narrow, ScrollController ctrl, {bool Function(Item)? seriesOf, bool centerFew = true}) {
    final h = narrow ? 168.0 : 250.0;
    final w = narrow ? 110.0 : 172.0;
    void nudge(int dir) {
      if (!ctrl.hasClients) return;
      final target = (ctrl.offset + dir * (w + 14) * 3).clamp(0.0, ctrl.position.maxScrollExtent);
      ctrl.animateTo(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    }
    Widget arrow(IconData icon, VoidCallback onTap) => TvFocus(
          radius: 22,
          onTap: onTap,
          child: Container(
            width: 40, height: 40, margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: kPanel.withValues(alpha: .55), shape: BoxShape.circle, border: Border.all(color: kLine)),
            child: Icon(icon, color: kMuted, size: 24),
          ),
        );
    Widget poster(Item it) { final s = seriesOf?.call(it) ?? isSeries; return TvFocus(
          radius: 12,
          onTap: () => _open(context, s ? SeriesDetailScreen(item: it) : MovieDetailScreen(item: it)),
          child: SizedBox(
            width: w,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: w, height: h - 34,
                  child: it.icon.isEmpty
                      ? Container(color: kPanel2, child: Icon(s ? Icons.theaters_rounded : Icons.movie_rounded, color: kMuted, size: 34))
                      : Image.network(it.icon, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: kPanel2, child: Icon(s ? Icons.theaters_rounded : Icons.movie_rounded, color: kMuted, size: 34))),
                ),
              ),
              const SizedBox(height: 5),
              Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title, style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'serif')),
      ),
      SizedBox(
        height: h,
        child: LayoutBuilder(builder: (c, cons) {
          const gap = 14.0;
          final content = items.length * w + (items.length - 1) * gap;
          // Passt alles rein -> mittig, ohne Pfeile. Sonst -> Pfeile + scrollende Liste.
          if (content <= cons.maxWidth) {
            final row = Row(mainAxisSize: MainAxisSize.min, children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                poster(items[i]),
              ],
            ]);
            return centerFew ? Center(child: row) : Align(alignment: Alignment.centerLeft, child: row);
          }
          return Row(children: [
            arrow(Icons.chevron_left_rounded, () => nudge(-1)),
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: gap),
                itemBuilder: (ctx, i) => poster(items[i]),
              ),
            ),
            arrow(Icons.chevron_right_rounded, () => nudge(1)),
          ]);
        }),
      ),
    ]);
  }

  Widget _grid(BuildContext context, bool narrow) {
    final tiles = _tiles(context);
    Widget card(int i) => _tileCard(tiles[i], autofocus: i == 0);
    // Kacheln mit FESTER Höhe (mainAxisExtent) -> füllen nicht mehr den ganzen Bildschirm.
    if (narrow) {
      return GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, mainAxisExtent: 160),
        itemCount: tiles.length, itemBuilder: (c, i) => card(i),
      );
    }
    if (kIsNina) {
      // Nina: 2x2-Raster (Vela hat eine Reihe mit 4) -> eigenständiger Aufbau.
      return GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, mainAxisExtent: 175),
        itemCount: tiles.length, itemBuilder: (c, i) => card(i),
      );
    }
    // Vela breit: eine Reihe mit 4 Kacheln, Höhe begrenzt.
    return SizedBox(
      height: 172,
      child: Row(children: [
        for (int i = 0; i < tiles.length; i++) ...[
          Expanded(child: card(i)),
          if (i < tiles.length - 1) const SizedBox(width: 16),
        ],
      ]),
    );
  }

  Widget _iconBox(IconData i, {VoidCallback? onTap}) => TvFocus(
        onTap: onTap ?? () {},
        radius: 11,
        child: Container(width: 42, height: 42, decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(11), border: Border.all(color: kLine)), child: Icon(i, color: kMuted, size: 20)),
      );

  Widget _tileCard(_Tile t, {bool autofocus = false}) => TvFocus(
        onTap: t.onTap,
        radius: 18,
        autofocus: autofocus,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kPanel, kBg2]), borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(width: 62, height: 62, decoration: BoxDecoration(color: t.accent.withValues(alpha: .16), borderRadius: BorderRadius.circular(16)), child: Icon(t.icon, color: t.accent, size: 34)),
            const SizedBox(height: 14),
            Text(t.label, textAlign: TextAlign.center, style: const TextStyle(color: kText, fontSize: 21, fontWeight: FontWeight.w800, fontFamily: 'serif')),
            const SizedBox(height: 4),
            Text(t.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 13)),
          ]),
        ),
      );
}

class _Tile {
  final String label, subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  _Tile(this.label, this.subtitle, this.icon, this.accent, this.onTap);
}

PreferredSizeWidget _subBar(BuildContext c, String title, {List<Widget>? actions}) => AppBar(
      backgroundColor: Colors.transparent, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kText, size: 20), onPressed: () => Navigator.pop(c)),
      title: Text(title, style: const TextStyle(color: kText, fontWeight: FontWeight.w800, fontFamily: 'serif', fontSize: 22)),
      actions: actions,
    );

Widget _loading() => const Center(child: CircularProgressIndicator(color: kBlue));
Widget _empty(String t) => Center(child: Text(t, style: const TextStyle(color: kMuted)));

// ============================ DOWNLOADS (offline, nur Desktop) ============================
// Download-Steuerung als Button (voll) oder Icon (compact). Reflektiert live den Status.
Widget dlControl(BuildContext context, {required String key, required String title, required String url, required String ext, String poster = '', bool compact = false}) {
  if (!kDesktop) return const SizedBox.shrink();
  return ValueListenableBuilder<int>(
    valueListenable: Downloads.notifier,
    builder: (c, _, _) {
      final d = Downloads.get(key);
      final st = d?.status;
      IconData icon; Color color = kBlue; VoidCallback? onTap; String label;
      if (st == 'done') { icon = Icons.download_done_rounded; color = kOk; onTap = null; label = L.t('dl_offline'); }
      else if (st == 'downloading') { icon = Icons.downloading_rounded; onTap = () => Downloads.remove(key); label = '${(d!.progress * 100).round()}%'; }
      else if (st == 'queued') { icon = Icons.schedule_rounded; onTap = () => Downloads.remove(key); label = '…'; }
      else if (st == 'error') { icon = Icons.error_outline_rounded; color = const Color(0xFFF2A0A0); onTap = () => Downloads.add(key: key, title: title, url: url, ext: ext, poster: poster); label = L.t('retry'); }
      else { icon = Icons.download_rounded; onTap = () => Downloads.add(key: key, title: title, url: url, ext: ext, poster: poster); label = L.t('download'); }
      if (compact) return IconButton(tooltip: label, icon: Icon(icon, color: color, size: 22), onPressed: onTap);
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 26),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: color, width: 1.5)),
            child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Transform.translate(offset: const Offset(0, -2), child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color, height: 1.0, leadingDistribution: TextLeadingDistribution.even))),
            ]),
          ),
        ),
      );
    },
  );
}

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _subBar(context, L.t('downloads')),
      body: Container(
        decoration: _bgDeco(),
        child: SafeArea(
          child: ValueListenableBuilder<int>(
            valueListenable: Downloads.notifier,
            builder: (c, _, _) {
              final items = Downloads.all();
              if (items.isEmpty) return _empty(L.t('dl_none'));
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (c, i) {
                  final d = items[i];
                  final done = d.status == 'done';
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: kPanel.withValues(alpha: .6), borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
                    child: Row(children: [
                      Icon(done ? Icons.play_circle_fill_rounded : Icons.downloading_rounded, color: done ? kBlue : kMuted, size: 30),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        if (done)
                          Text(L.t('dl_offline'), style: const TextStyle(color: kOk, fontSize: 12.5, fontWeight: FontWeight.w600))
                        else if (d.status == 'error')
                          Text(L.t('player_err'), style: const TextStyle(color: Color(0xFFF2A0A0), fontSize: 12.5))
                        else
                          ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: d.total > 0 ? d.progress : null, minHeight: 5, backgroundColor: kLine, valueColor: const AlwaysStoppedAnimation(kBlue))),
                      ])),
                      const SizedBox(width: 12),
                      if (done)
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: kBlue, foregroundColor: kBg),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(title: d.title, url: d.path, resume: true, poster: d.poster))),
                          child: Text(L.t('play')),
                        ),
                      IconButton(onPressed: () => Downloads.remove(d.key), icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF2A0A0))),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================ LIVE ============================
class LiveScreen extends StatefulWidget {
  final bool catchup; // true = Replay: Sender antippen -> vergangene Sendungen
  const LiveScreen({super.key, this.catchup = false});
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<Category> cats = [];
  List<Item> chans = [];
  int catSel = 0;
  bool loadingCats = true, loadingChans = false;
  String? error;
  String query = '';
  List<Item> get _filtered => query.isEmpty ? chans : chans.where((c) => c.name.toLowerCase().contains(query.toLowerCase())).toList();

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  Future<void> _loadCats() async {
    try {
      final c = await Xtream.categories('live');
      if (!mounted) return;
      setState(() { cats = [Category('__fav__', '★ ${L.t('favorites')}'), ...c]; loadingCats = false; });
      _selectCat(cats.length > 1 ? 1 : 0);
    } catch (e) {
      if (mounted) setState(() { loadingCats = false; error = L.t('err_load'); });
    }
  }

  Future<void> _selectCat(int i) async {
    setState(() { catSel = i; loadingChans = true; chans = []; query = ''; });
    if (cats[i].id == '__fav__') {
      setState(() { chans = FavStore.items('live'); loadingChans = false; });
      return;
    }
    try {
      final ch = await Xtream.liveStreams(cats[i].id);
      if (!mounted) return;
      setState(() { chans = ch; loadingChans = false; });
    } catch (e) {
      if (mounted) setState(() { loadingChans = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = _narrow(context);
    return Scaffold(
      appBar: _subBar(context, widget.catchup ? L.t('replay_pick') : L.t('live_title')),
      body: Container(
        decoration: _bgDeco(),
        child: loadingCats
            ? _loading()
            : error != null
                ? _empty(error!)
                : narrow
                    ? Column(children: [_catBar(), const SizedBox(height: 6), Expanded(child: _list())])
                    : Row(children: [SizedBox(width: kDesktop ? 320 : 240, child: _sidebar()), Expanded(child: _list())]),
      ),
    );
  }

  Widget _sidebar() => ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: cats.length,
        separatorBuilder: (_, _) => const Divider(color: kLine, height: 1, thickness: 1, indent: 14, endIndent: 12),
        itemBuilder: (c, i) {
          final s = catSel == i;
          return TvFocus(
            onTap: () => _selectCat(i),
            radius: 10,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: kDesktop ? 3 : 2),
              padding: EdgeInsets.symmetric(horizontal: kDesktop ? 16 : 14, vertical: kDesktop ? 15 : 12),
              decoration: BoxDecoration(color: s ? kBlue : Colors.transparent, borderRadius: BorderRadius.circular(10)),
              child: Text(cats[i].name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: s ? kBg : kText, fontWeight: FontWeight.w700, fontSize: kDesktop ? 16 : 13.5)),
            ),
          );
        },
      );

  Widget _catBar() => SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: cats.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (c, i) {
            final s = catSel == i;
            return TvFocus(
              onTap: () => _selectCat(i),
              radius: 21,
              child: Container(
                alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(color: s ? kBlue : kPanel2, borderRadius: BorderRadius.circular(21), border: Border.all(color: s ? kBlue : kLine)),
                child: Text(cats[i].name, style: TextStyle(color: s ? kBg : kMuted, fontWeight: FontWeight.w600, fontSize: 12.5)),
              ),
            );
          },
        ),
      );

  Widget _list() {
    if (loadingChans) return _loading();
    final items = _filtered;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        child: TextField(
          onChanged: (v) => setState(() => query = v),
          style: const TextStyle(color: kText, fontSize: 14),
          decoration: InputDecoration(
            isDense: true, hintText: L.t('search_in_cat'), hintStyle: const TextStyle(color: kMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: kMuted, size: 18),
            filled: true, fillColor: kPanel2,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBlue)),
          ),
        ),
      ),
      Expanded(
        child: items.isEmpty
            ? _empty(cats[catSel].id == '__fav__' ? L.t('no_fav') : L.t('no_hits'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                itemCount: items.length,
                itemBuilder: (c, i) {
                  final ch = items[i];
                  final fav = FavStore.isFav(ch.id, 'live');
                  return TvFocus(
                    radius: 10,
                    autofocus: i == 0,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => widget.catchup
                        ? CatchupProgramsScreen(streamId: ch.id, name: ch.name)
                        : PlayerScreen(
                            title: ch.name, url: Xtream.liveUrl(ch.id),
                            channels: items, index: i, urlFor: (c) => Xtream.liveUrl(c.id),
                          ))),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: kPanel.withValues(alpha: .4), borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
                      child: Row(children: [
                        SizedBox(width: 34, child: Text(ch.num > 0 ? '${ch.num}' : '${i + 1}', style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700))),
                        _logo(ch.icon),
                        const SizedBox(width: 12),
                        Expanded(child: Text(ch.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600))),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded, color: fav ? kBlue : kMuted, size: 20),
                          onPressed: () async { await FavStore.toggle(ch, 'live'); if (mounted) setState(() {}); },
                        ),
                        const Icon(Icons.play_circle_outline_rounded, color: kMuted, size: 20),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _logo(String url) => Container(
        width: 42, height: 30, decoration: BoxDecoration(color: kPanel2, borderRadius: BorderRadius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: url.isEmpty ? const Icon(Icons.tv_rounded, size: 16, color: kMuted) : Image.network(url, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.tv_rounded, size: 16, color: kMuted)),
      );
}

// ============================ FILME / SERIEN ============================
class CatalogScreen extends StatefulWidget {
  final String title, type; // type: vod | series
  const CatalogScreen({super.key, required this.title, required this.type});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Category> cats = [];
  List<Item> items = [];
  int catSel = 0;
  bool loadingCats = true, loadingItems = false;
  String query = '';

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  List<Item>? _allCache; // „Alle" wird im Hintergrund vorgeladen
  String get _favKind => widget.type == 'series' ? 'series' : 'vod';

  Future<void> _loadCats() async {
    try {
      final c = await Xtream.categories(widget.type);
      if (!mounted) return;
      // Reihenfolge: Favoriten, Alle, dann die echten Kategorien. Start = Favoriten.
      setState(() {
        cats = [Category('__fav__', '★ ${L.t('favorites')}'), Category('__all__', L.t('all_cat')), ...c];
        loadingCats = false;
      });
      _selectCat(0);   // startet auf Favoriten
      _preloadAll();   // „Alle" schon im Hintergrund laden, auch wenn man bei Favoriten anfängt
    } catch (_) {
      if (mounted) setState(() => loadingCats = false);
    }
  }

  Future<void> _preloadAll() async {
    if (_allCache != null) return;
    try {
      final list = widget.type == 'series' ? await Xtream.allSeries() : await Xtream.allVod();
      if (!mounted) return;
      _allCache = list;
      // Falls der Nutzer inzwischen auf „Alle" gewechselt hat: direkt anzeigen.
      if (catSel < cats.length && cats[catSel].id == '__all__') {
        setState(() { items = list; loadingItems = false; });
      }
    } catch (_) {}
  }

  Future<void> _selectCat(int i) async {
    setState(() { catSel = i; loadingItems = true; items = []; query = ''; });
    final id = cats[i].id;
    if (id == '__fav__') {
      setState(() { items = FavStore.items(_favKind); loadingItems = false; });
      return;
    }
    if (id == '__all__' && _allCache != null) {
      setState(() { items = _allCache!; loadingItems = false; });
      return;
    }
    try {
      final list = id == '__all__'
          ? (widget.type == 'series' ? await Xtream.allSeries() : await Xtream.allVod())
          : (widget.type == 'series' ? await Xtream.seriesList(id) : await Xtream.vodStreams(id));
      if (!mounted) return;
      if (id == '__all__') _allCache = list;
      setState(() { items = list; loadingItems = false; });
    } catch (_) {
      if (mounted) setState(() => loadingItems = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = _narrow(context);
    return Scaffold(
      appBar: _subBar(context, widget.title),
      body: Container(
        decoration: _bgDeco(),
        child: loadingCats
            ? _loading()
            : cats.isEmpty
                ? _empty(L.t('no_content'))
                : narrow
                    ? Column(children: [_catBar(), Expanded(child: _grid())])
                    : Row(children: [SizedBox(width: kDesktop ? 320 : 240, child: _sidebar()), Expanded(child: _grid())]),
      ),
    );
  }

  Widget _sidebar() => ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: cats.length,
        separatorBuilder: (_, _) => const Divider(color: kLine, height: 1, thickness: 1, indent: 14, endIndent: 12),
        itemBuilder: (c, i) {
          final s = catSel == i;
          return TvFocus(
            onTap: () => _selectCat(i),
            radius: 10,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: kDesktop ? 3 : 2),
              padding: EdgeInsets.symmetric(horizontal: kDesktop ? 16 : 14, vertical: kDesktop ? 15 : 12),
              decoration: BoxDecoration(color: s ? kBlue : Colors.transparent, borderRadius: BorderRadius.circular(10)),
              child: Text(cats[i].name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: s ? kBg : kText, fontWeight: FontWeight.w700, fontSize: kDesktop ? 16 : 13.5)),
            ),
          );
        },
      );

  Widget _catBar() => SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: cats.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (c, i) {
            final s = catSel == i;
            return TvFocus(
              onTap: () => _selectCat(i),
              radius: 21,
              child: Container(
                alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(color: s ? kBlue : kPanel2, borderRadius: BorderRadius.circular(21), border: Border.all(color: s ? kBlue : kLine)),
                child: Text(cats[i].name, style: TextStyle(color: s ? kBg : kMuted, fontWeight: FontWeight.w600, fontSize: 12.5)),
              ),
            );
          },
        ),
      );

  Widget _grid() {
    if (loadingItems) return _loading();
    final list = query.isEmpty ? items : items.where((e) => e.name.toLowerCase().contains(query.toLowerCase())).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: TextField(
          onChanged: (v) => setState(() => query = v),
          style: const TextStyle(color: kText, fontSize: 14),
          decoration: InputDecoration(
            isDense: true, hintText: L.t('search_in_cat'), hintStyle: const TextStyle(color: kMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: kMuted, size: 18),
            filled: true, fillColor: kPanel2,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBlue)),
          ),
        ),
      ),
      Expanded(
        child: list.isEmpty
            ? _empty(cats[catSel].id == '__fav__' ? L.t('no_fav') : L.t('no_hits'))
            : LayoutBuilder(builder: (c, cons) {
                final cols = (cons.maxWidth / 130).floor().clamp(2, 8);
                return GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .58),
                  itemCount: list.length,
                  itemBuilder: (c, i) => _poster(list[i]),
                );
              }),
      ),
    ]);
  }

  Widget _poster(Item it) => TvFocus(
        radius: 10,
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => widget.type == 'series' ? SeriesDetailScreen(item: it) : MovieDetailScreen(item: it)));
          // Zurück aus dem Detail: falls wir auf „Favoriten" stehen, neu laden
          // (der Nutzer hat evtl. gerade einen Favoriten hinzugefügt/entfernt).
          if (mounted && cats[catSel].id == '__fav__') _selectCat(catSel);
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity, color: kPanel2,
                child: it.icon.isEmpty
                    ? const Icon(Icons.movie_rounded, color: kMuted, size: 34)
                    : Image.network(it.icon, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.movie_rounded, color: kMuted, size: 34)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ============================ SUCHE ============================
// Generischer Hover-Zoom: skaliert sein Kind beim Drübergehen mit der Maus.
class _HoverScale extends StatefulWidget {
  final Widget child;
  const _HoverScale({required this.child});
  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: AnimatedScale(
          scale: _h ? 1.09 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

// Klebende, farbcodierte Block-Überschrift (Filme/Serien/Live) für die Suche.
// Bleibt beim Scrollen oben stehen -> jederzeit klar, welcher Block gerade läuft.
class _StickySection extends SliverPersistentHeaderDelegate {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  const _StickySection({required this.title, required this.count, required this.icon, required this.color});

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: kBg,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)),
          child: Text('$count', style: const TextStyle(color: kBg, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySection old) =>
      old.title != title || old.count != count || old.color != color || old.icon != icon;
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Item> vod = [], series = [], live = [];
  bool loading = true;
  String query = '';
  int tab = 0; // 0 = Alle (gruppiert), 1 = Filme, 2 = Serien, 3 = Live

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Xtream.allVod(), Xtream.allSeries(), Xtream.allLive()]);
      vod = r[0];
      series = r[1];
      live = r[2];
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  List<Item> _match(List<Item> src) =>
      src.where((e) => e.name.toLowerCase().contains(query.toLowerCase())).take(80).toList();

  @override
  Widget build(BuildContext context) {
    final q = query.trim().length >= 2;
    final mVod = q ? _match(vod) : const <Item>[];
    final mSeries = q ? _match(series) : const <Item>[];
    final mLive = q ? _match(live) : const <Item>[];
    final anyHit = mVod.isNotEmpty || mSeries.isNotEmpty || mLive.isNotEmpty;

    Widget body;
    if (loading) {
      body = _loading();
    } else if (!q) {
      body = _empty(L.t('search_min2'));
    } else if (tab == 0) {
      body = anyHit ? _grouped(mVod, mSeries, mLive) : _empty(L.t('no_hits'));
    } else if (tab == 3) {
      body = mLive.isEmpty ? _empty(L.t('no_hits')) : _liveList(mLive);
    } else {
      final r = tab == 1 ? mVod : mSeries;
      body = r.isEmpty ? _empty(L.t('no_hits')) : _grid(r, tab == 2);
    }

    return Scaffold(
      appBar: _subBar(context, L.t('search_title')),
      body: Container(
        decoration: _bgDeco(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => query = v),
                style: const TextStyle(color: kText),
                decoration: InputDecoration(
                  hintText: L.t('search_hint'), hintStyle: const TextStyle(color: kMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: kMuted),
                  filled: true, fillColor: kPanel2,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBlue)),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                for (final t in [[0, L.t('all_cat')], [1, L.t('home_movies')], [2, L.t('home_series')], [3, L.t('type_live')]])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => tab = t[0] as int),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: tab == t[0] ? kBlue : kPanel2, borderRadius: BorderRadius.circular(18), border: Border.all(color: tab == t[0] ? kBlue : kLine)),
                        child: Text(t[1] as String, style: TextStyle(color: tab == t[0] ? kBg : kMuted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              Expanded(child: body),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _grid(List<Item> r, bool isSeries) => LayoutBuilder(builder: (c, cons) {
        final cols = (cons.maxWidth / 150).floor().clamp(2, 10);
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: .58),
          itemCount: r.length,
          itemBuilder: (c, i) => _gridPoster(r[i], isSeries),
        );
      });

  // „Alle": eine saubere Liste, jede Zeile mit Typ-Etikett (FILM/SERIE/LIVE).
  // Reihenfolge Filme -> Serien -> Live; per Etikett sofort erkennbar was was ist.
  // „Alle": IBO-artige Poster-Blöcke pro Typ (Filme/Serien/Live) mit farbiger,
  // klebender Überschrift. Senkrecht scrollend -> alles per Mausrad erreichbar.
  Widget _grouped(List<Item> mv, List<Item> ms, List<Item> ml) => LayoutBuilder(builder: (c, cons) {
        final cols = (cons.maxWidth / 165).floor().clamp(2, 9);
        final posterGrid = SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: .56);
        final tileGrid = SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: .82);
        return CustomScrollView(slivers: [
          if (mv.isNotEmpty) ...[
            SliverPersistentHeader(pinned: true, delegate: _StickySection(title: L.t('home_movies'), count: mv.length, icon: Icons.movie_rounded, color: kBlue)),
            SliverPadding(padding: const EdgeInsets.only(bottom: 12), sliver: SliverGrid(gridDelegate: posterGrid, delegate: SliverChildBuilderDelegate((c, i) => _gridPoster(mv[i], false), childCount: mv.length))),
          ],
          if (ms.isNotEmpty) ...[
            SliverPersistentHeader(pinned: true, delegate: _StickySection(title: L.t('home_series'), count: ms.length, icon: Icons.live_tv_rounded, color: const Color(0xFF34D399))),
            SliverPadding(padding: const EdgeInsets.only(bottom: 12), sliver: SliverGrid(gridDelegate: posterGrid, delegate: SliverChildBuilderDelegate((c, i) => _gridPoster(ms[i], true), childCount: ms.length))),
          ],
          if (ml.isNotEmpty) ...[
            SliverPersistentHeader(pinned: true, delegate: _StickySection(title: L.t('type_live'), count: ml.length, icon: Icons.sensors_rounded, color: const Color(0xFFF87171))),
            SliverGrid(gridDelegate: tileGrid, delegate: SliverChildBuilderDelegate((c, i) => _liveTile(ml, i), childCount: ml.length)),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]);
      });

  // Live-Kachel: Sender-Logo (mittig) + Name — wie IBOs „Live TV"-Block.
  Widget _liveTile(List<Item> live, int i) {
    final ch = live[i];
    return _HoverScale(
      child: TvFocus(
        radius: 10,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(
              title: ch.name, url: Xtream.liveUrl(ch.id), channels: live, index: i, urlFor: (c) => Xtream.liveUrl(c.id)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity, color: kPanel2, padding: const EdgeInsets.all(10),
                child: ch.icon.isEmpty
                    ? const Icon(Icons.tv_rounded, color: kMuted, size: 30)
                    : Image.network(ch.icon, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.tv_rounded, color: kMuted, size: 30)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(ch.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _liveList(List<Item> items) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: items.length,
        itemBuilder: (c, i) => _liveRow(items, i),
      );

  Widget _liveRow(List<Item> items, int i) {
    final ch = items[i];
    return TvFocus(
      radius: 10,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(
            title: ch.name, url: Xtream.liveUrl(ch.id),
            channels: items, index: i, urlFor: (c) => Xtream.liveUrl(c.id),
          ))),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: kPanel.withValues(alpha: .4), borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
        child: Row(children: [
          Container(
            width: 42, height: 30, clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: kPanel2, borderRadius: BorderRadius.circular(6)),
            child: ch.icon.isEmpty
                ? const Icon(Icons.tv_rounded, size: 16, color: kMuted)
                : Image.network(ch.icon, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.tv_rounded, size: 16, color: kMuted)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(ch.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600))),
          const Icon(Icons.play_circle_outline_rounded, color: kMuted, size: 20),
        ]),
      ),
    );
  }

  Widget _gridPoster(Item it, bool isSeries) => _HoverScale(
    child: TvFocus(
        radius: 10,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => isSeries ? SeriesDetailScreen(item: it) : MovieDetailScreen(item: it))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity, color: kPanel2,
                child: it.icon.isEmpty
                    ? const Icon(Icons.movie_rounded, color: kMuted, size: 32)
                    : Image.network(it.icon, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.movie_rounded, color: kMuted, size: 32)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
}

// Favoriten-Button (Stern) — sitzt direkt bei den Aktions-Buttons im Detail,
// nicht in der Fenster-Ecke. kind: 'vod' | 'series'.
class _FavButton extends StatefulWidget {
  final Item item;
  final String kind;
  const _FavButton({required this.item, required this.kind});
  @override
  State<_FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<_FavButton> {
  @override
  Widget build(BuildContext context) {
    final fav = FavStore.isFav(widget.item.id, widget.kind);
    final c = fav ? Colors.amber : kText;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async { await FavStore.toggle(widget.item, widget.kind); if (mounted) setState(() {}); },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: fav ? Colors.amber.withValues(alpha: .12) : Colors.transparent, border: Border.all(color: fav ? Colors.amber : kLine, width: 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(fav ? Icons.star_rounded : Icons.star_border_rounded, size: 20, color: c),
            const SizedBox(width: 8),
            Transform.translate(offset: const Offset(0, -2), child: Text(L.t('favorites'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c, height: 1.0, leadingDistribution: TextLeadingDistribution.even))),
          ]),
        ),
      ),
    );
  }
}

// ============================ FILM-DETAIL ============================
class MovieDetailScreen extends StatefulWidget {
  final Item item;
  const MovieDetailScreen({super.key, required this.item});
  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Map<String, dynamic>? info;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try { info = await Xtream.vodInfo(widget.item.id); } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final inf = (info?['info'] is Map) ? Map<String, dynamic>.from(info!['info']) : <String, dynamic>{};
    final md = (info?['movie_data'] is Map) ? Map<String, dynamic>.from(info!['movie_data']) : <String, dynamic>{};
    final cover = (inf['movie_image'] ?? inf['cover_big'] ?? widget.item.icon).toString();
    final plot = (inf['plot'] ?? inf['description'] ?? '').toString();
    final ext = (md['container_extension'] ?? widget.item.ext).toString();
    final meta = <String>[
      if ('${inf['releasedate'] ?? ''}'.isNotEmpty) '${inf['releasedate']}'.split('-').first,
      if ('${inf['genre'] ?? ''}'.isNotEmpty) '${inf['genre']}',
      if ('${inf['duration'] ?? ''}'.isNotEmpty) '${inf['duration']}',
      if ('${inf['rating'] ?? ''}'.isNotEmpty && '${inf['rating']}' != '0') '★ ${inf['rating']}',
    ];
    return Scaffold(
      appBar: _subBar(context, widget.item.name),
      body: Stack(
        fit: StackFit.expand,
        children: [
          cover.isEmpty
              ? Container(decoration: _bgDeco())
              : Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(decoration: _bgDeco())),
          if (cover.isNotEmpty)
            BackdropFilter(filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32), child: Container(color: kBg.withValues(alpha: .82))),
          loading
            ? _loading()
            : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Padding(
                padding: const EdgeInsets.all(28),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 250, height: 375,
                      child: cover.isEmpty
                          ? Container(color: kPanel2, child: const Icon(Icons.movie_rounded, color: kMuted, size: 54))
                          : Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: kPanel2, child: const Icon(Icons.movie_rounded, color: kMuted, size: 54))),
                    ),
                  ),
                  const SizedBox(width: 34),
                  Expanded(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.item.name, style: const TextStyle(color: kText, fontSize: 26, fontWeight: FontWeight.w800, fontFamily: 'serif')),
                      const SizedBox(height: 10),
                      if (meta.isNotEmpty) Text(meta.join('   ·   '), style: const TextStyle(color: kBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 18),
                      ConstrainedBox(constraints: const BoxConstraints(maxHeight: 320), child: SingleChildScrollView(child: Text(plot.isEmpty ? L.t('no_desc') : plot, style: const TextStyle(color: kMuted, fontSize: 15, height: 1.55)))),
                      const SizedBox(height: 20),
                      ValueListenableBuilder<int>(
                        valueListenable: Downloads.notifier,
                        builder: (c, _, _) {
                          final key = 'vod_${widget.item.id}';
                          final url = Xtream.vodUrl(widget.item.id, ext);
                          final local = Downloads.localPath(key); // offline, wenn vorhanden
                          return Row(children: [
                            Material(
                              color: kBlue,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                autofocus: kTvRing,
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(title: widget.item.name, url: local ?? url, resume: true, poster: cover))),
                                child: Container(
                                  height: 52,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 26),
                                  child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
                                    const Icon(Icons.play_arrow_rounded, size: 20, color: kBg),
                                    const SizedBox(width: 8),
                                    Transform.translate(offset: const Offset(0, -2), child: Text(L.t('play'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kBg, height: 1.0, leadingDistribution: TextLeadingDistribution.even))),
                                  ]),
                                ),
                              ),
                            ),
                            if (kDesktop) ...[
                              const SizedBox(width: 12),
                              dlControl(context, key: key, title: widget.item.name, url: url, ext: ext, poster: cover),
                            ],
                            const SizedBox(width: 12),
                            _FavButton(item: widget.item, kind: 'vod'),
                          ]);
                        },
                      ),
                    ]),
                  ),
                ]),
              ),
              ),
              ),
        ],
      ),
    );
  }
}

// ============================ SERIEN-DETAIL ============================
class SeriesDetailScreen extends StatefulWidget {
  final Item item;
  const SeriesDetailScreen({super.key, required this.item});
  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  SeriesDetail? det;
  bool loading = true;
  String season = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      det = await Xtream.seriesInfo(widget.item.id);
      if (det!.seasons.isNotEmpty) season = det!.seasons.keys.first;
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final inf = det?.info ?? {};
    final cover = (inf['cover'] ?? inf['cover_big'] ?? widget.item.icon).toString();
    final plot = (inf['plot'] ?? '').toString();
    final seasons = det?.seasons.keys.toList() ?? [];
    final eps = det?.seasons[season] ?? [];
    return Scaffold(
      appBar: _subBar(context, widget.item.name),
      body: Container(
        decoration: _bgDeco(),
        child: loading
            ? _loading()
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 200,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 200, height: 280,
                          child: cover.isEmpty
                              ? Container(color: kPanel2, child: const Icon(Icons.theaters_rounded, color: kMuted, size: 48))
                              : Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: kPanel2, child: const Icon(Icons.theaters_rounded, color: kMuted, size: 48))),
                        ),
                      ),
                      if (plot.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Expanded(child: SingleChildScrollView(child: Text(plot, style: const TextStyle(color: kMuted, fontSize: 12, height: 1.4)))),
                      ],
                    ]),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (seasons.length > 1)
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: seasons.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (c, i) {
                              final s = seasons[i] == season;
                              return TvFocus(
                                radius: 19,
                                onTap: () => setState(() => season = seasons[i]),
                                child: Container(
                                  alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(color: s ? kBlue : kPanel2, borderRadius: BorderRadius.circular(19), border: Border.all(color: s ? kBlue : kLine)),
                                  child: Text('${L.t('season')} ${seasons[i]}', style: TextStyle(color: s ? kBg : kMuted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(children: [
                        if (kDesktop && eps.isNotEmpty) ...[
                          SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: kBlue), foregroundColor: kBlue),
                              onPressed: () {
                                for (final list in det!.seasons.values) {
                                  for (final e in list) {
                                    Downloads.add(key: 'ep_${e.id}', title: '${widget.item.name} – ${e.title}', url: Xtream.seriesEpUrl(e.id, e.ext), ext: e.ext, poster: cover);
                                  }
                                }
                              },
                              icon: const Icon(Icons.download_rounded, size: 20),
                              label: Text(L.t('download_all'), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        _FavButton(item: widget.item, kind: 'series'),
                      ]),
                      const SizedBox(height: 10),
                      Expanded(
                        child: eps.isEmpty
                            ? _empty(L.t('no_eps'))
                            : ValueListenableBuilder<int>(
                                valueListenable: Downloads.notifier,
                                builder: (c, _, _) => ListView.builder(
                                  itemCount: eps.length,
                                  itemBuilder: (c, i) {
                                    final e = eps[i];
                                    final key = 'ep_${e.id}';
                                    final url = Xtream.seriesEpUrl(e.id, e.ext);
                                    final local = Downloads.localPath(key);
                                    return TvFocus(
                                      radius: 10,
                                      autofocus: i == 0,
                                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(
                                            title: e.title, url: local ?? url, resume: true, poster: cover,
                                            queue: [for (final ep in eps) Playable(ep.title, Downloads.localPath('ep_${ep.id}') ?? Xtream.seriesEpUrl(ep.id, ep.ext))],
                                            queueIndex: i,
                                          ))),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
                                        child: Row(children: [
                                          Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: kPanel2, borderRadius: BorderRadius.circular(8)), child: Text('${e.num}', style: const TextStyle(color: kBlue, fontWeight: FontWeight.w700, fontSize: 12))),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600))),
                                          if (kDesktop) dlControl(context, key: key, title: '${widget.item.name} – ${e.title}', url: url, ext: e.ext, poster: cover, compact: true)
                                          else const Icon(Icons.play_circle_outline_rounded, color: kMuted, size: 20),
                                        ]),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ]),
                  ),
                ]),
              ),
      ),
    );
  }
}

// ============================ CATCH-UP: vergangene Sendungen eines Senders ============================
class CatchupProgramsScreen extends StatefulWidget {
  final String streamId, name;
  const CatchupProgramsScreen({super.key, required this.streamId, required this.name});
  @override
  State<CatchupProgramsScreen> createState() => _CatchupProgramsScreenState();
}

class _CatchupProgramsScreenState extends State<CatchupProgramsScreen> {
  List<Program> progs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await Xtream.archive(widget.streamId);
      final now = DateTime.now();
      progs = all.where((p) => p.end.isBefore(now)).toList()..sort((a, b) => b.start.compareTo(a.start));
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  String _fmt(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}. ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _subBar(context, widget.name),
      body: Container(
        decoration: _bgDeco(),
        child: SafeArea(
          child: loading
              ? _loading()
              : progs.isEmpty
                  ? _empty(L.t('catchup_none'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: progs.length,
                      itemBuilder: (c, i) {
                        final p = progs[i];
                        return TvFocus(
                          radius: 10,
                          autofocus: i == 0,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(title: '${widget.name} · ${p.title}', url: Xtream.timeshiftUrl(widget.streamId, p)))),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(color: kPanel.withValues(alpha: .5), borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
                            child: Row(children: [
                              const Icon(Icons.history_rounded, color: kBlue, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('${_fmt(p.start)} · ${p.durationMin} ${L.t('minutes_short')}', style: const TextStyle(color: kMuted, fontSize: 12)),
                              ])),
                              const Icon(Icons.play_circle_outline_rounded, color: kMuted, size: 20),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

// Ein Eintrag der Vor/Zurück-Warteschlange (z. B. Serien-Episoden). Anders als
// „channels" (Live) bleibt hier der Seekbar/Fortsetzen-Modus erhalten.
class Playable { final String title, url; const Playable(this.title, this.url); }

// ============================ PLAYER (Platzhalter – VLC im nativen Build) ============================
class PlayerScreen extends StatefulWidget {
  final String title, url;
  final List<Item>? channels; // gesetzt = Live (Zapping möglich)
  final int index;
  final String Function(Item)? urlFor;
  final bool resume; // Filme/Serien: Position merken & fortsetzen
  final String poster; // fuer „Weiterschauen"
  final List<Playable>? queue; // gesetzt = Vor/Nächster-Track (Episoden), KEIN Live
  final int queueIndex;
  const PlayerScreen({super.key, required this.title, required this.url, this.channels, this.index = 0, this.urlFor, this.resume = false, this.poster = '', this.queue, this.queueIndex = 0});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player = Player(configuration: PlayerConfiguration(bufferSize: Prefs.bufferBytes));
  late final VideoController controller = VideoController(player);
  late String title = widget.title;
  late String _url = widget.url;
  late int idx = widget.index;
  late int _qi = widget.queueIndex; // Position in der Episoden-Warteschlange
  String epg = '';
  StreamSubscription? _durSub;
  StreamSubscription? _completedSub; // am Folgen-Ende automatisch die nächste starten
  StreamSubscription? _errSub;
  bool _seeked = false;
  double _brightness = 0.5;
  BoxFit _fit = BoxFit.contain;
  bool _errShown = false; // verhindert gestapelte Fehler-Dialoge
  static double _savedVol = 100; // zuletzt gewählte Lautstärke – bleibt über Player-Wechsel erhalten
  double _vol = _savedVol; // Lautstärke 0..100 (Regler rechts)
  bool _fs = false;  // Fenster-Vollbild (Desktop)
  String _clock = '';
  Timer? _clockTimer;
  bool _ui = true;   // Steuerung + Overlays (Lautstärke/Zurück) sichtbar?
  Timer? _uiTimer;   // blendet nach 1,5 s Ruhe alles aus
  Offset? _tapPos;   // letzte Tipp-Position (für Doppeltipp-Spulen links/rechts)
  String? _fitMsg;   // kurze Format-Anzeige beim Umschalten (Anpassen/Zoom/Strecken)
  Timer? _fitTimer;
  Timer? _saveTimer; // speichert die Position periodisch (auch wenn das Fenster hart geschlossen wird)

  // Alles einblenden und die 1,5-s-Uhr neu bei 0 starten. Jede Maus-/Tasten-
  // aktion ruft das auf -> bewegt man die Maus, zählt es wieder von vorne.
  void _revealUi() {
    _uiTimer?.cancel();
    if (!_ui && mounted) setState(() => _ui = true);
    _uiTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _ui = false);
    });
  }

  static String _fmtClock() { final n = DateTime.now(); return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}'; }

  void _cycleFit() {
    setState(() {
      _fit = _fit == BoxFit.contain ? BoxFit.cover : (_fit == BoxFit.cover ? BoxFit.fill : BoxFit.contain);
      _fitMsg = _fit == BoxFit.contain ? L.t('fit_fit') : (_fit == BoxFit.cover ? L.t('fit_zoom') : L.t('fit_stretch'));
    });
    _revealUi();
    _fitTimer?.cancel();
    _fitTimer = Timer(const Duration(milliseconds: 1300), () { if (mounted) setState(() => _fitMsg = null); });
  }

  void _setVol(double v) { _vol = v.clamp(0, 100); _savedVol = _vol; player.setVolume(_vol); setState(() {}); }

  Future<void> _toggleFs() async {
    _fs = !_fs;
    try { await windowManager.setFullScreen(_fs); } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _applySubScale() async {
    try { await (player.platform as dynamic).setProperty('sub-scale', Prefs.subScale.toStringAsFixed(2)); } catch (_) {}
  }

  // Manche Anbieter/CDNs (v. a. VOD) lehnen den Standard-Player-User-Agent ab.
  // Ein gängiger IPTV-UA wird überall akzeptiert.
  static const Map<String, String> _kHdr = {'User-Agent': 'IBOPlayer'};
  void _openUrl() { player.open(Media(_url, httpHeaders: _kHdr)); player.setVolume(_vol); }

  @override
  void initState() {
    super.initState();
    _openUrl();
    _revealUi(); // sichtbar starten, dann nach 1,5 s ausblenden
    _clock = _fmtClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) { if (mounted) setState(() => _clock = _fmtClock()); });
    _applySubScale();
    _loadEpg();
    ScreenBrightness().application.then((v) { if (mounted) setState(() => _brightness = v); }).catchError((_) {});
    _errSub = player.stream.error.listen((e) {
      if (!mounted || e.trim().isEmpty || _errShown) return;
      _errShown = true;
      showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (dctx) => AlertDialog(
          backgroundColor: kPanel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(L.t('player_err_title'), textAlign: TextAlign.center, style: const TextStyle(color: kText, fontWeight: FontWeight.w700)),
          content: Text(L.t('player_err'), textAlign: TextAlign.center, style: const TextStyle(color: kMuted)),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () { Navigator.pop(dctx); Navigator.of(context).maybePop(); },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.fromLTRB(22, 9, 22, 13),
                    child: Text(L.t('go_back'), textAlign: TextAlign.center, style: const TextStyle(color: kBlue, fontWeight: FontWeight.w700, height: 1.0, leadingDistribution: TextLeadingDistribution.even)),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: kBlue,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () { Navigator.pop(dctx); _openUrl(); },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.fromLTRB(28, 9, 28, 13),
                      child: Text(L.t('retry'), textAlign: TextAlign.center, style: const TextStyle(color: kBg, fontWeight: FontWeight.w700, height: 1.0, leadingDistribution: TextLeadingDistribution.even)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).then((_) { _errShown = false; });
    });
    // Serie: am Ende einer Folge automatisch die nächste starten (Binge-Watch, kein Zurück nötig).
    _completedSub = player.stream.completed.listen((done) {
      if (done && widget.queue != null && _qi < widget.queue!.length - 1) _queueJump(1);
    });
    if (widget.resume) {
      _durSub = player.stream.duration.listen((d) {
        if (!_seeked && d > Duration.zero) {
          _seeked = true;
          final s = ResumeStore.get(_url);
          if (s > 5) player.seek(Duration(seconds: s));
        }
      });
      // Fortschritt ALLE 5 s sichern -> „Weiterschauen" funktioniert auch, wenn man
      // das Fenster einfach schließt (dann läuft dispose() nicht zuverlässig).
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
    }
  }

  // Aktuelle Position sichern (Resume-Sprung + „Weiterschauen"-Reihe). Idempotent,
  // wird periodisch UND beim Verlassen aufgerufen.
  void _saveProgress() {
    if (!widget.resume) return;
    final pos = player.state.position.inSeconds;
    final dur = player.state.duration.inSeconds;
    if (pos <= 0) return;
    ResumeStore.set(_url, pos, dur);
    ContinueStore.record(url: _url, title: title, poster: widget.poster, pos: pos, dur: dur);
  }

  Future<void> _loadEpg() async {
    final ch = widget.channels;
    if (ch == null) return;
    setState(() => epg = '');
    final t = await Xtream.nowPlaying(ch[idx].id);
    if (mounted) setState(() => epg = t);
  }

  @override
  void dispose() {
    _saveProgress();
    _saveTimer?.cancel();
    _durSub?.cancel();
    _completedSub?.cancel();
    _errSub?.cancel();
    _clockTimer?.cancel();
    _uiTimer?.cancel();
    _fitTimer?.cancel();
    if (_fs) { try { windowManager.setFullScreen(false); } catch (_) {} }
    try { ScreenBrightness().resetApplicationScreenBrightness(); } catch (_) {}
    player.dispose();
    super.dispose();
  }

  void _seekBy(int seconds) {
    final pos = player.state.position + Duration(seconds: seconds);
    player.seek(pos < Duration.zero ? Duration.zero : pos);
  }

  void _zap(int delta) {
    final ch = widget.channels;
    if (ch == null || widget.urlFor == null) return;
    final n = idx + delta;
    if (n < 0 || n >= ch.length) return;
    _url = widget.urlFor!(ch[n]);
    setState(() { idx = n; title = ch[n].name; });
    _openUrl();
    _loadEpg();
  }

  // Vor/Nächste Episode (Serien-Warteschlange). Merkt die aktuelle Position zum
  // Fortsetzen, springt zum Nachbar-Titel und lässt den Resume-Listener neu greifen.
  void _queueJump(int delta) {
    final q = widget.queue;
    if (q == null) return;
    final n = _qi + delta;
    if (n < 0 || n >= q.length) return;
    if (widget.resume) {
      final pos = player.state.position.inSeconds, dur = player.state.duration.inSeconds;
      ResumeStore.set(_url, pos, dur);
      ContinueStore.record(url: _url, title: title, poster: widget.poster, pos: pos, dur: dur);
    }
    _qi = n; _url = q[n].url; _seeked = false;
    setState(() { title = q[n].title; });
    _openUrl();
    _revealUi();
  }

  void _tracks(bool audio) {
    final list = audio ? player.state.tracks.audio : player.state.tracks.subtitle;
    showModalBottomSheet(
      context: context,
      backgroundColor: kPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(audio ? L.t('pick_audio') : L.t('pick_subs'), style: const TextStyle(color: kText, fontWeight: FontWeight.w700, fontSize: 16))),
          if (list.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 20), child: Text(L.t('no_tracks'), style: const TextStyle(color: kMuted))),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final t in list)
                ListTile(
                  leading: const Icon(Icons.audiotrack_rounded, color: kBlue, size: 18),
                  title: Text(_trackLabel(t), style: const TextStyle(color: kText, fontSize: 14)),
                  onTap: () {
                    if (audio) { player.setAudioTrack(t as AudioTrack); } else { player.setSubtitleTrack(t as SubtitleTrack); }
                    Navigator.pop(context);
                  },
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _trackLabel(dynamic t) {
    final id = '${t.id}';
    if (id == 'no') return L.t('off');   // Untertitel/Audio AUS
    if (id == 'auto') return L.t('track_auto');
    final ttl = t.title as String?;
    final lang = t.language as String?;
    if (ttl != null && ttl.isNotEmpty) return ttl;
    if (lang != null && lang.isNotEmpty) return lang;
    return id;
  }

  // Eigene Steuer-Ebene: gleiches IBO-Layout wie media_kit (dessen fertige
  // Einzel-Widgets), ABER ohne dessen Einzeltipp-zum-Ein-/Ausblenden.
  // Sichtbarkeit steuert allein unser _ui-Timer (Mausbewegung/Taste).
  Widget _mkControls(BuildContext context, MaterialVideoControlsThemeData c, bool live) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Hintergrund: Doppeltipp = spulen (VOD); am Handy vertikal wischen =
        // Helligkeit (links) / Lautstärke (rechts). KEIN Einzeltipp -> kein Toggle.
        Positioned.fill(
          child: LayoutBuilder(
            builder: (ctx, cons) => GestureDetector(
              onDoubleTapDown: (d) => _tapPos = d.localPosition,
              onDoubleTap: live
                  ? null
                  : () {
                      final x = _tapPos?.dx ?? cons.maxWidth / 2;
                      _seekBy(x < cons.maxWidth / 2 ? -10 : 10);
                    },
              onVerticalDragUpdate: kDesktop
                  ? null
                  : (d) {
                      if (d.localPosition.dx < cons.maxWidth / 2) {
                        _brightness = (_brightness - d.delta.dy / 500).clamp(0.0, 1.0).toDouble();
                        try { ScreenBrightness().setApplicationScreenBrightness(_brightness); } catch (_) {}
                      } else {
                        _setVol(_vol - d.delta.dy / 500 * 100);
                      }
                    },
              child: const ColoredBox(color: Color(0x00000000)),
            ),
          ),
        ),
        // Ladeanzeige – unabhängig von _ui immer sichtbar.
        StreamBuilder<bool>(
          stream: player.stream.buffering,
          initialData: player.state.buffering,
          builder: (_, s) => (s.data ?? false)
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : const SizedBox.shrink(),
        ),
        // Buttons + Seekbar – blenden mit _ui ein/aus (200 ms), wie Lautstärke/Zurück.
        IgnorePointer(
          ignoring: !_ui,
          child: AnimatedOpacity(
            opacity: _ui ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: c.padding ?? EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    height: c.buttonBarHeight,
                    margin: c.topButtonBarMargin,
                    child: Row(children: c.topButtonBar),
                  ),
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: c.primaryButtonBar,
                      ),
                    ),
                  ),
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      if (!live) MaterialSeekBar(), // Live: kein Ladebalken/Seekbar
                      Container(
                        height: c.buttonBarHeight,
                        margin: c.bottomButtonBarMargin,
                        child: Row(children: c.bottomButtonBar),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.channels != null;
    final hasQueue = widget.queue != null && widget.queue!.length > 1;
    final safe = MediaQuery.of(context).padding;
    double ins(double v, double min) => v < min ? min : v;
    // Desktop = Maus -> alles größer/dicker als am Handy.
    final double bs = kDesktop ? 30 : 24;       // Buttons untere Leiste
    final double bigSec = kDesktop ? 44 : 34;   // seitliche Transport-Tasten
    final double bigPlay = kDesktop ? 64 : 52;  // zentrale Play/Pause-Taste
    // Bedienelemente von den (abgerundeten) Rändern wegrücken + oben auto-ausblenden.
    final controls = MaterialVideoControlsThemeData(
      seekOnDoubleTap: true, // Doppeltipp links/rechts = zurück/vor spulen (wie YouTube)
      // Vertikal wischen: links = Helligkeit, rechts = Lautstärke (wie IBO).
      volumeGesture: !kDesktop,      // Wischgesten nur am Handy (Desktop = Regler rechts)
      brightnessGesture: !kDesktop,
      initialBrightness: _brightness,
      onBrightnessChanged: (v) { try { ScreenBrightness().setApplicationScreenBrightness(v.clamp(0.0, 1.0)); } catch (_) {} },
      onBrightnessReset: () { try { ScreenBrightness().resetApplicationScreenBrightness(); } catch (_) {} },
      // Lautstärke-Geste (rechts): media_kit ruft nur diesen Callback – ohne ihn passiert nichts.
      initialVolume: (_vol / 100).clamp(0.0, 1.0),
      onVolumeChanged: (v) { _vol = (v * 100).clamp(0.0, 100.0); _savedVol = _vol; player.setVolume(_vol); },
      // media_kit soll NICHT selbst aus-/einblenden (sein Hover-Timer greift im
      // Vollbild nicht). Das Ein-/Ausblenden macht komplett unser _ui-Timer über
      // den controls-Schalter oben. days:1 = solange sichtbar, wie _ui an ist.
      controlsHoverDuration: const Duration(days: 1),
      visibleOnMount: true,
      padding: EdgeInsets.only(
        left: ins(safe.left, 16), right: ins(safe.right, 16),
        top: ins(safe.top, 8), bottom: ins(safe.bottom, 10),
      ),
      // Ladebalken: dick, gut sichtbar; klarer Abstand zur unteren Leiste, damit die
      // Buttons NICHT auf dem Balken sitzen.
      seekBarHeight: 6,
      seekBarThumbSize: 16,
      seekBarContainerHeight: 44,
      seekBarColor: Colors.white24,
      seekBarPositionColor: kBlue,
      seekBarThumbColor: kBlue,
      seekBarMargin: EdgeInsets.only(bottom: kDesktop ? 98 : 64, left: ins(safe.left, 20), right: ins(safe.right, 20)),
      bottomButtonBarMargin: EdgeInsets.only(bottom: kDesktop ? 22 : 12, left: ins(safe.left, 20), right: ins(safe.right, 20)),
      topButtonBarMargin: EdgeInsets.only(top: ins(safe.top, 8), left: 4, right: ins(safe.right, 10)),
      // Große zentrierte Transport-Tasten (Maus-freundlich, wie IBO).
      primaryButtonBar: live
          ? [
              const Spacer(flex: 2),
              MaterialCustomButton(onPressed: () => _zap(-1), iconSize: bigSec, icon: const Icon(Icons.skip_previous_rounded, color: Colors.white)),
              const Spacer(),
              MaterialPlayOrPauseButton(iconSize: bigPlay),
              const Spacer(),
              MaterialCustomButton(onPressed: () => _zap(1), iconSize: bigSec, icon: const Icon(Icons.skip_next_rounded, color: Colors.white)),
              const Spacer(flex: 2),
            ]
          : [
              const Spacer(flex: 2),
              if (hasQueue) MaterialCustomButton(onPressed: () => _queueJump(-1), iconSize: bigSec, icon: const Icon(Icons.skip_previous_rounded, color: Colors.white)),
              if (hasQueue) const Spacer(),
              MaterialCustomButton(onPressed: () => _seekBy(-10), iconSize: bigSec, icon: const Icon(Icons.replay_10_rounded, color: Colors.white)),
              const Spacer(),
              MaterialPlayOrPauseButton(iconSize: bigPlay),
              const Spacer(),
              MaterialCustomButton(onPressed: () => _seekBy(10), iconSize: bigSec, icon: const Icon(Icons.forward_10_rounded, color: Colors.white)),
              if (hasQueue) const Spacer(),
              if (hasQueue) MaterialCustomButton(onPressed: () => _queueJump(1), iconSize: bigSec, icon: const Icon(Icons.skip_next_rounded, color: Colors.white)),
              const Spacer(flex: 2),
            ],
      // Untere Leiste: große Restzeit-Anzeige links; Audio/Untertitel/Format/Vollbild rechts.
      bottomButtonBar: [
        if (!live) MaterialPositionIndicator(style: TextStyle(color: Colors.white, fontSize: kDesktop ? 16 : 13, fontWeight: FontWeight.w700)),
        const Spacer(),
        MaterialCustomButton(onPressed: () => _tracks(true), iconSize: bs, icon: const Icon(Icons.audiotrack_rounded, color: Colors.white)),
        MaterialCustomButton(onPressed: () => _tracks(false), iconSize: bs, icon: const Icon(Icons.closed_caption_rounded, color: Colors.white)),
        MaterialCustomButton(onPressed: _cycleFit, iconSize: bs, icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white)),
        if (kDesktop) MaterialCustomButton(onPressed: _toggleFs, iconSize: bs, icon: Icon(_fs ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white)),
      ],
      // Oben: Titel mittig + Uhr rechts (Zurück-Pfeil ist Overlay links).
      topButtonBar: [
        const SizedBox(width: 52),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontFamily: 'serif', fontSize: kDesktop ? 20 : 17)),
            if (epg.isNotEmpty) Text('${L.t('now')}: $epg', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ),
        SizedBox(width: 64, child: Text(_clock, textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: kDesktop ? 15 : 13, fontWeight: FontWeight.w600))),
      ],
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
          _revealUi(); // jede Taste holt die Steuerung zurück + startet die 1,5 s neu
          final k = event.logicalKey;
          // ESC / Zurück -> Player verlassen (Rettungsanker am Desktop).
          if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.browserBack) { Navigator.of(context).maybePop(); return KeyEventResult.handled; }
          if (live && (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.channelUp)) { _zap(-1); return KeyEventResult.handled; }
          if (live && (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.channelDown)) { _zap(1); return KeyEventResult.handled; }
          if (!live && k == LogicalKeyboardKey.arrowUp) { _setVol(_vol + 5); return KeyEventResult.handled; }
          if (!live && k == LogicalKeyboardKey.arrowDown) { _setVol(_vol - 5); return KeyEventResult.handled; }
          if (!live && hasQueue && (k == LogicalKeyboardKey.pageUp || k == LogicalKeyboardKey.mediaTrackPrevious)) { _queueJump(-1); return KeyEventResult.handled; }
          if (!live && hasQueue && (k == LogicalKeyboardKey.pageDown || k == LogicalKeyboardKey.mediaTrackNext)) { _queueJump(1); return KeyEventResult.handled; }
          if (!live && k == LogicalKeyboardKey.arrowLeft) { _seekBy(-10); return KeyEventResult.handled; }
          if (!live && k == LogicalKeyboardKey.arrowRight) { _seekBy(10); return KeyEventResult.handled; }
          if (k == LogicalKeyboardKey.mediaPlayPause || k == LogicalKeyboardKey.space ||
              k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) { player.playOrPause(); return KeyEventResult.handled; }
          return KeyEventResult.ignored;
        },
        child: Listener(
          // Jede Mausbewegung/-berührung zeigt die Steuerung und startet die 1,5 s neu.
          // translucent = Kinder (Steuerung/Regler) bekommen ihre Klicks trotzdem.
          behavior: HitTestBehavior.translucent,
          onPointerHover: (_) => _revealUi(),   // Maus bewegen (ohne Taste)
          onPointerMove: (_) => _revealUi(),    // Ziehen (Taste gedrückt, z. B. Regler)
          onPointerDown: (_) => _revealUi(),    // Klick/Tap
          onPointerSignal: (_) => _revealUi(),  // Mausrad
          child: Stack(children: [
          Positioned.fill(
            child: MaterialVideoControlsTheme(
              normal: controls,
              fullscreen: controls,
              // UNSERE eigene Steuer-Ebene (kein media_kit-Tap-Toggle). Ein-/
              // Ausblenden macht allein der _ui-Timer -> Klick toggelt NICHT mehr.
              child: Video(controller: controller, fit: _fit, controls: (state) => _mkControls(context, controls, live)),
            ),
          ),
          // Immer sichtbarer Zurück-Button oben links (unabhängig von der Steuerleiste,
          // damit man am Desktop/TV nie „festhängt").
          Positioned(
            top: ins(safe.top, 8), left: ins(safe.left, 8),
            child: IgnorePointer(
              ignoring: !_ui,
              child: AnimatedOpacity(
                opacity: _ui ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .45), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
              ),
            ),
          ),
          // Lautstärke: vertikaler Regler mittig rechts. Außerhalb der media_kit-Steuerung,
          // damit die Zieh-Geste sauber greift; immer erreichbar (oft benutzt).
          Positioned(
            right: ins(safe.right, 10), top: 0, bottom: 0,
            child: IgnorePointer(
              ignoring: !_ui,
              child: AnimatedOpacity(
                opacity: _ui ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .38), borderRadius: BorderRadius.circular(26)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // oben: lauter (wie IBO)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 22),
                    onPressed: () => _setVol(100),
                  ),
                  RotatedBox(
                    quarterTurns: 3,
                    child: SizedBox(
                      width: 150,
                      child: SliderTheme(
                        data: const SliderThemeData(trackHeight: 3, overlayShape: RoundSliderOverlayShape(overlayRadius: 12), thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7)),
                        child: Slider(value: _vol.clamp(0, 100), min: 0, max: 100, activeColor: kBlue, inactiveColor: Colors.white30, onChanged: _setVol),
                      ),
                    ),
                  ),
                  // unten: stumm (wie IBO)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(_vol <= 0 ? Icons.volume_off_rounded : Icons.volume_mute_rounded, color: Colors.white, size: 20),
                    onPressed: () => _setVol(0),
                  ),
                ]),
              ),
            ),
              ),
            ),
          ),
          // Kurze Format-Anzeige (Anpassen/Zoom/Strecken) beim Umschalten.
          if (_fitMsg != null)
            Center(
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .62), borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(_fitMsg!, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
        ]),
        ),
      ),
    );
  }
}

// ============================ EINSTELLUNGEN ============================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int sel = 0;
  List<String> get items => [L.t('s_stream_format'), L.t('s_buffer'), L.t('s_subsize'), L.t('s_language'), L.t('s_parental'), L.t('s_hidden'), L.t('favorites'), L.t('s_about')];

  @override
  Widget build(BuildContext context) {
    final narrow = _narrow(context);
    final list = Container(
      decoration: BoxDecoration(color: kPanel.withValues(alpha: .5), borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
      child: ListView.separated(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: kLine),
        itemBuilder: (c, i) => TvFocus(
          radius: 8,
          autofocus: i == 0,
          onTap: () => setState(() => sel = i),
          child: Container(
            color: sel == i ? kBlue.withValues(alpha: .12) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(children: [Text(items[i], style: TextStyle(color: sel == i ? kBlue : kText, fontSize: 15, fontWeight: FontWeight.w600)), const Spacer(), const Icon(Icons.chevron_right_rounded, color: kMuted, size: 20)]),
          ),
        ),
      ),
    );
    return Scaffold(
      appBar: _subBar(context, L.t('settings_title')),
      body: Container(
        decoration: _bgDeco(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: narrow
                ? ListView(children: [list, const SizedBox(height: 16), _detail()])
                : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: SingleChildScrollView(child: list)), const SizedBox(width: 16), Expanded(flex: 2, child: _detail())]),
          ),
        ),
      ),
    );
  }

  Widget _panel(Widget child) => Container(
        width: double.infinity,
        decoration: BoxDecoration(color: kPanel.withValues(alpha: .5), borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
        padding: const EdgeInsets.all(18),
        child: child,
      );

  Widget _detail() {
    switch (sel) {
      case 0: return _streamFormat();
      case 1: return _buffer();
      case 2: return _subs();
      case 3: return _language();
      case 4: return _parental();
      case 5: return const _HiddenCats();
      case 6: return _favs();
      case 7: return _about();
      default: return _about();
    }
  }

  Widget _buffer() => _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(L.t('s_buffer'), style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(L.t('buffer_desc'), style: const TextStyle(color: kMuted, fontSize: 12.5)),
        const SizedBox(height: 14),
        for (final o in [[0, L.t('buf_low')], [1, L.t('buf_default')], [2, L.t('buf_high')], [3, L.t('buf_extreme')]])
          _opt(o[1] as String, Prefs.bufferIdx == o[0], () { Prefs.setBufferIdx(o[0] as int); setState(() {}); }),
      ]));

  Widget _subs() => _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(L.t('s_subsize'), style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(L.t('subs_desc'), style: const TextStyle(color: kMuted, fontSize: 12.5)),
        const SizedBox(height: 14),
        for (final o in [[0, L.t('sub_large')], [1, L.t('sub_normal')], [2, L.t('sub_small')]])
          _opt(o[1] as String, Prefs.subIdx == o[0], () { Prefs.setSubIdx(o[0] as int); setState(() {}); }),
      ]));

  Widget _language() {
    final body = ListView(
      padding: const EdgeInsets.only(bottom: 4),
      children: [
        for (final l in kLangs)
          _opt(l[1], Prefs.lang == l[0], () async { await L.set(l[0]); setState(() {}); }),
      ],
    );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: kPanel.withValues(alpha: .5), borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L.t('s_language'), style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(L.t('lang_desc'), style: const TextStyle(color: kMuted, fontSize: 12.5)),
        const SizedBox(height: 14),
        _narrow(context) ? SizedBox(height: 320, child: body) : Expanded(child: body),
      ]),
    );
  }

  Widget _streamFormat() => _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(L.t('sf_title'), style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(L.t('sf_desc'), style: const TextStyle(color: kMuted, fontSize: 12.5)),
        const SizedBox(height: 14),
        _opt(L.t('sf_ts'), Prefs.liveExt == 'ts', () { Prefs.setLiveExt('ts'); setState(() {}); }),
        _opt(L.t('sf_hls'), Prefs.liveExt == 'm3u8', () { Prefs.setLiveExt('m3u8'); setState(() {}); }),
      ]));

  Widget _opt(String label, bool on, VoidCallback onTap) => TvFocus(
        radius: 10,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: on ? kBlue.withValues(alpha: .14) : kPanel2, borderRadius: BorderRadius.circular(10), border: Border.all(color: on ? kBlue : kLine)),
          child: Row(children: [Text(label, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600)), const Spacer(), if (on) const Icon(Icons.check_rounded, color: kBlue, size: 20)]),
        ),
      );

  Widget _parental() => _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(L.t('s_parental'), style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(L.t('parental_desc'), style: const TextStyle(color: kMuted, fontSize: 12.5)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text(L.t('hide_adult'), style: const TextStyle(color: kText, fontSize: 14))),
          Switch(value: Prefs.hideAdult, activeThumbColor: kBlue, onChanged: _toggleAdult),
        ]),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(side: const BorderSide(color: kLine)),
          onPressed: _pinDialog,
          icon: const Icon(Icons.lock_rounded, size: 18, color: kBlue),
          label: Text(Prefs.hasPin ? L.t('change_pin') : L.t('set_pin'), style: const TextStyle(color: kBlue)),
        ),
        // Face ID / Biometrie nur auf Mobilgeräten – Desktop hat das nicht (dort nur PIN).
        if (!kDesktop) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text(L.t('use_bio'), style: const TextStyle(color: kText, fontSize: 14))),
            Switch(
              value: Prefs.useFaceId,
              activeThumbColor: kBlue,
              onChanged: (v) async {
                if (v) { final ok = await _bioAuth(L.t('bio_enable')); if (!ok) return; }
                await Prefs.setUseFaceId(v);
                setState(() {});
              },
            ),
          ]),
        ],
      ]));

  Future<bool> _bioAuth(String reason) async {
    try {
      final auth = LocalAuthentication();
      final can = await auth.isDeviceSupported();
      if (!can) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: kPanel, content: Text(L.t('bio_none'), style: const TextStyle(color: kText))));
        return false;
      }
      return await auth.authenticate(localizedReason: reason, biometricOnly: false, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }

  void _toggleAdult(bool v) async {
    if (!v && (Prefs.hasPin || Prefs.useFaceId)) {
      final ok = Prefs.useFaceId ? await _bioAuth(L.t('bio_release')) : await _askPin(L.t('pin_release'));
      if (!ok) return;
    }
    await Prefs.setHideAdult(v);
    setState(() {});
  }

  Future<void> _pinDialog() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: Text(L.t('set_pin'), style: const TextStyle(color: kText)),
        content: TextField(controller: c, keyboardType: TextInputType.number, obscureText: true, style: const TextStyle(color: kText), decoration: InputDecoration(hintText: L.t('pin_min'), hintStyle: const TextStyle(color: kMuted))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(L.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(L.t('save'))),
        ],
      ),
    );
    if (ok == true && c.text.trim().length >= 4) { await Prefs.setPin(c.text.trim()); setState(() {}); }
  }

  Future<bool> _askPin(String title) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: Text(title, style: const TextStyle(color: kText)),
        content: TextField(controller: c, keyboardType: TextInputType.number, obscureText: true, style: const TextStyle(color: kText), decoration: const InputDecoration(hintText: 'PIN', hintStyle: TextStyle(color: kMuted))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(L.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK')),
        ],
      ),
    );
    return ok == true && Prefs.checkPin(c.text.trim());
  }

  Widget _favs() => _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(L.t('favorites'), style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${FavStore.count()} ${L.t('favs_saved')}', style: const TextStyle(color: kMuted, fontSize: 12.5)),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(side: const BorderSide(color: kLine)),
          onPressed: () async {
            await FavStore.clearAll();
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF2A0A0), size: 18),
          label: Text(L.t('favs_clear'), style: const TextStyle(color: kText)),
        ),
      ]));

  Widget _about() => _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: const [
        Text('$kBrandName Player', style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        Text('Version 1.0 · Beta', style: TextStyle(color: kMuted, fontSize: 13)),
      ]));

}

class _HiddenCats extends StatefulWidget {
  const _HiddenCats();
  @override
  State<_HiddenCats> createState() => _HiddenCatsState();
}

class _HiddenCatsState extends State<_HiddenCats> {
  String type = 'live';
  List<Category> cats = [];
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => loading = true);
    try { cats = await Xtream.categoriesRaw(type); } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = loading
        ? _loading()
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: cats.length,
            itemBuilder: (c, i) {
              final name = cats[i].name;
              final hidden = Prefs.hidden.contains(name);
              return ListTile(
                dense: true,
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 13.5)),
                trailing: Switch(value: !hidden, activeThumbColor: kBlue, onChanged: (v) async { await Prefs.toggleHidden(name); if (mounted) setState(() {}); }),
              );
            },
          );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: kPanel.withValues(alpha: .5), borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L.t('s_hidden'), style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(children: [
          for (final t in [['live', L.t('type_live')], ['vod', L.t('home_movies')], ['series', L.t('home_series')]])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TvFocus(
                radius: 18,
                onTap: () { type = t[0]; _load(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: type == t[0] ? kBlue : kPanel2, borderRadius: BorderRadius.circular(18), border: Border.all(color: type == t[0] ? kBlue : kLine)),
                  child: Text(t[1], style: TextStyle(color: type == t[0] ? kBg : kMuted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        _narrow(context) ? SizedBox(height: 300, child: body) : Expanded(child: body),
      ]),
    );
  }
}

// ============================ KONTO / PLAYLIST-INFO ============================
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? info;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final i = Session.account != null ? await Xtream.userInfo(Session.account!) : null;
    if (mounted) setState(() { info = i; loading = false; });
  }

  Future<void> _logout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ActivationScreen()), (_) => false);
  }

  /// Playlist erneut von velaplayer.com holen (fragt vorher nach). Holt den
  /// aktuellen Server-Stand — löscht/ändert man dort die Playlist, greift es hier.
  Future<void> _reload() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: Text(L.t('reload_playlist'), style: const TextStyle(color: kText)),
        content: Text(L.t('reload_confirm'), style: const TextStyle(color: kMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(L.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(L.t('reload'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => loading = true);
    final st = await Session.syncFromActivation(); // frischer Server-Stand (velaplayer.com = Wahrheit)
    if (!mounted) return;
    if (st == 'ok') {
      // Sitzung evtl. geändert → alles frisch aufbauen (Gate prüft Lizenz + Playlist neu).
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeGate()), (_) => false);
    } else if (st == 'none') {
      // Auf velaplayer.com gelöscht → lokale Playlist entfernen, App spielt nichts mehr.
      await Session.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ActivationScreen()), (_) => false);
    } else {
      // Server/Provider gerade nicht erreichbar → lokalen Stand behalten.
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: kPanel, content: Text(L.t('reload_offline'), style: const TextStyle(color: kText))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = info ?? {};
    final status = (i['status'] ?? '').toString();
    final data = [
      [L.t('username'), Session.account?.user ?? 'M3U-Playlist', Icons.person_rounded, false],
      [L.t('acc_status'), Session.mode == 'm3u' ? 'M3U (${Session.m3u.length} Sender)' : (status.isEmpty ? '—' : status), Icons.cloud_done_rounded, status.toLowerCase() == 'active' || Session.mode == 'm3u'],
      [L.t('acc_connections'), '${i['active_cons'] ?? 0} / ${i['max_connections'] ?? '?'}', Icons.link_rounded, false],
      [L.t('acc_expires'), _tsDate(i['exp_date']), Icons.event_rounded, false],
      [L.t('acc_trial'), ('${i['is_trial']}' == '1') ? L.t('yes') : L.t('no'), Icons.verified_user_rounded, false],
      [L.t('acc_created'), _tsDate(i['created_at']), Icons.calendar_month_rounded, false],
    ];
    // Querformat: 3 Spalten (2 Reihen) -> alles ohne Scrollen sichtbar.
    final cols = _narrow(context) ? 1 : (MediaQuery.of(context).size.width > 700 ? 3 : 2);
    return Scaffold(
      appBar: _subBar(context, L.t('account_title'), actions: [
        TextButton.icon(onPressed: _logout, icon: const Icon(Icons.logout_rounded, color: kMuted, size: 18), label: Text(L.t('logout'), style: const TextStyle(color: kMuted))),
        const SizedBox(width: 8),
      ]),
      body: Container(
        decoration: _bgDeco(),
        child: SafeArea(
          child: loading
            ? _loading()
            : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _idPanel(context, compact: true), // MAC + Geräteschlüssel — kompakt
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: kBlue), foregroundColor: kBlue),
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: Text(L.t('reload_playlist'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 60),
                      itemCount: data.length,
                      itemBuilder: (c, idx) {
                        final ok = data[idx][3] as bool;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(color: kPanel.withValues(alpha: .5), borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
                          child: Row(children: [
                            Icon(data[idx][2] as IconData, color: kBlue, size: 22),
                            const SizedBox(width: 12),
                            Expanded(child: Text(data[idx][0] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontWeight: FontWeight.w700, fontSize: 14.5))),
                            const SizedBox(width: 8),
                            Text(data[idx][1] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ok ? kOk : kText, fontWeight: FontWeight.w600, fontSize: 14)),
                          ]),
                        );
                      },
                    ),
                ]),
              ),
              ),
              ),
        ),
      ),
    );
  }
}
