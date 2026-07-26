import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'xtream.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await Session.load();
  await FavStore.load();
  await Prefs.load();
  await ResumeStore.load();
  runApp(const VelaApp());
}

const kBg = Color(0xFF0C1524);
const kBg2 = Color(0xFF17283F);
const kPanel = Color(0xFF152134);
const kPanel2 = Color(0xFF1D2B42);
const kLine = Color(0xFF2B3E59);
const kBlue = Color(0xFF6FB1F2);
const kBlue2 = Color(0xFF4685C4);
const kText = Color(0xFFEAF1FB);
const kMuted = Color(0xFF93A4BE);
const kOk = Color(0xFF3FDA7C);

class VelaApp extends StatelessWidget {
  const VelaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vela',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: kBg, fontFamily: 'Roboto'),
      home: Session.account == null ? const ConnectScreen() : const HomeScreen(),
    );
  }
}

BoxDecoration _bgDeco() => const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [kBg2, kBg, Color(0xFF080F1B)]),
    );
bool _narrow(BuildContext c) => MediaQuery.of(c).size.width < 700;

String _tsDate(dynamic v) {
  final s = '$v'.trim();
  if (s.isEmpty || s == '0' || s == 'null') return '—';
  final n = int.tryParse(s);
  final d = n != null ? DateTime.fromMillisecondsSinceEpoch(n * 1000) : DateTime.tryParse(s);
  if (d == null) return s;
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

class VelaLogo extends StatelessWidget {
  final double size;
  const VelaLogo({super.key, this.size = 34});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [kBlue, kBlue2]), borderRadius: BorderRadius.circular(size * 0.28)),
        child: Icon(Icons.play_arrow_rounded, color: kBg, size: size * 0.66),
      ),
      const SizedBox(width: 9),
      Text.rich(
        const TextSpan(children: [
          TextSpan(text: 'VE', style: TextStyle(color: kText, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          TextSpan(text: 'LA', style: TextStyle(color: kBlue, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        ]),
        style: TextStyle(fontSize: size * 0.62, fontFamily: 'serif'),
      ),
    ]);
  }
}

// ============================ VERBINDEN ============================
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final host = TextEditingController(text: 'http://d67.xyz:8080');
  final user = TextEditingController(text: 'alex_v_ali_3');
  final pass = TextEditingController(text: 'workfufufu');
  bool busy = false;
  String? err;

  Future<void> _connect() async {
    setState(() { busy = true; err = null; });
    final a = Account(host.text.trim(), user.text.trim(), pass.text.trim());
    final info = await Xtream.userInfo(a);
    if (!mounted) return;
    if (info == null) {
      setState(() { busy = false; err = 'Verbindung fehlgeschlagen – Zugangsdaten prüfen.'; });
      return;
    }
    await Session.save(a);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
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
                const VelaLogo(size: 44),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('Playlist verbinden', style: TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'serif')),
                    const SizedBox(height: 4),
                    const Text('Gib deine Xtream-Zugangsdaten ein.', style: TextStyle(color: kMuted, fontSize: 13)),
                    const SizedBox(height: 8),
                    _field(host, 'Server (http://host:port)'),
                    _field(user, 'Benutzername'),
                    _field(pass, 'Passwort', obscure: true),
                    if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: const TextStyle(color: Color(0xFFF2A0A0), fontSize: 13))),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: kBlue, foregroundColor: kBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                        onPressed: busy ? null : _connect,
                        child: busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: kBg))
                            : const Text('Verbinden', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  void _open(BuildContext c, Widget s) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => s));

  List<_Tile> _tiles(BuildContext c) => [
        _Tile('Live-TV', 'Fernsehen live', Icons.live_tv_rounded, const Color(0xFF6FB1F2), () => _open(c, const LiveScreen())),
        _Tile('Filme', 'Spielfilme', Icons.movie_creation_rounded, const Color(0xFF8FA6F0), () => _open(c, const CatalogScreen(title: 'Filme', type: 'vod'))),
        _Tile('Serien', 'Serien & Staffeln', Icons.theaters_rounded, const Color(0xFF6FD0C8), () => _open(c, const CatalogScreen(title: 'Serien', type: 'series'))),
        _Tile('Replay', 'Verpasstes nachholen', Icons.replay_rounded, const Color(0xFFE0B366), () => _open(c, const CatalogScreen(title: 'Replay', type: 'vod'))),
      ];

  @override
  Widget build(BuildContext context) {
    final narrow = _narrow(context);
    return Scaffold(
      body: Container(
        decoration: _bgDeco(),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(narrow ? 16 : 24),
            child: Column(children: [
              Row(children: [
                const VelaLogo(size: 30),
                const Spacer(),
                _iconBox(Icons.search_rounded),
                const SizedBox(width: 10),
                _iconBox(Icons.settings_rounded, onTap: () => _open(context, const SettingsScreen())),
                const SizedBox(width: 10),
                _iconBox(Icons.person_rounded, onTap: () => _open(context, const AccountScreen())),
              ]),
              SizedBox(height: narrow ? 14 : 22),
              Expanded(child: _grid(context, narrow)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, bool narrow) {
    final tiles = _tiles(context);
    if (narrow) {
      return GridView.count(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.2, children: [for (final t in tiles) _tileCard(t)]);
    }
    return Row(children: [
      for (int i = 0; i < tiles.length; i++) ...[
        Expanded(child: _tileCard(tiles[i])),
        if (i < tiles.length - 1) const SizedBox(width: 16),
      ],
    ]);
  }

  Widget _iconBox(IconData i, {VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(width: 42, height: 42, decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(11), border: Border.all(color: kLine)), child: Icon(i, color: kMuted, size: 20)),
      );

  Widget _tileCard(_Tile t) => GestureDetector(
        onTap: t.onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kPanel, kBg2]), borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 58, height: 58, decoration: BoxDecoration(color: t.accent.withValues(alpha: .16), borderRadius: BorderRadius.circular(16)), child: Icon(t.icon, color: t.accent, size: 32)),
              const Spacer(),
              const Icon(Icons.north_east_rounded, color: kMuted, size: 22),
            ]),
            const Spacer(),
            Text(t.label, style: const TextStyle(color: kText, fontSize: 21, fontWeight: FontWeight.w800, fontFamily: 'serif')),
            const SizedBox(height: 3),
            Text(t.subtitle, style: const TextStyle(color: kMuted, fontSize: 13)),
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

// ============================ LIVE ============================
class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});
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
      setState(() { cats = [Category('__fav__', '★ Favoriten'), ...c]; loadingCats = false; });
      _selectCat(cats.length > 1 ? 1 : 0);
    } catch (e) {
      if (mounted) setState(() { loadingCats = false; error = 'Fehler beim Laden.'; });
    }
  }

  Future<void> _selectCat(int i) async {
    setState(() { catSel = i; loadingChans = true; chans = []; query = ''; });
    if (cats[i].id == '__fav__') {
      setState(() { chans = FavStore.items(); loadingChans = false; });
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
      appBar: _subBar(context, 'Live-Sender'),
      body: Container(
        decoration: _bgDeco(),
        child: loadingCats
            ? _loading()
            : error != null
                ? _empty(error!)
                : narrow
                    ? Column(children: [_catBar(), const SizedBox(height: 6), Expanded(child: _list())])
                    : Row(children: [SizedBox(width: 240, child: _sidebar()), Expanded(child: _list())]),
      ),
    );
  }

  Widget _sidebar() => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: cats.length,
        itemBuilder: (c, i) {
          final s = catSel == i;
          return GestureDetector(
            onTap: () => _selectCat(i),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 6, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: s ? kBlue : Colors.transparent, borderRadius: BorderRadius.circular(10)),
              child: Text(cats[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: s ? kBg : kText, fontWeight: FontWeight.w600, fontSize: 13.5)),
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
            return GestureDetector(
              onTap: () => _selectCat(i),
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
            isDense: true, hintText: 'In Kategorie suchen…', hintStyle: const TextStyle(color: kMuted, fontSize: 13),
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
            ? _empty(cats[catSel].id == '__fav__' ? 'Noch keine Favoriten' : 'Keine Treffer')
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                itemCount: items.length,
                itemBuilder: (c, i) {
                  final ch = items[i];
                  final fav = FavStore.isFav(ch.id);
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(
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
                          onPressed: () async { await FavStore.toggle(ch); if (mounted) setState(() {}); },
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

  Future<void> _loadCats() async {
    try {
      final c = await Xtream.categories(widget.type);
      if (!mounted) return;
      setState(() { cats = c; loadingCats = false; });
      if (c.isNotEmpty) _selectCat(0);
    } catch (_) {
      if (mounted) setState(() => loadingCats = false);
    }
  }

  Future<void> _selectCat(int i) async {
    setState(() { catSel = i; loadingItems = true; items = []; query = ''; });
    try {
      final list = widget.type == 'series' ? await Xtream.seriesList(cats[i].id) : await Xtream.vodStreams(cats[i].id);
      if (!mounted) return;
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
                ? _empty('Keine Inhalte')
                : narrow
                    ? Column(children: [_catBar(), Expanded(child: _grid())])
                    : Row(children: [SizedBox(width: 240, child: _sidebar()), Expanded(child: _grid())]),
      ),
    );
  }

  Widget _sidebar() => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: cats.length,
        itemBuilder: (c, i) {
          final s = catSel == i;
          return GestureDetector(
            onTap: () => _selectCat(i),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 6, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: s ? kBlue : Colors.transparent, borderRadius: BorderRadius.circular(10)),
              child: Text(cats[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: s ? kBg : kText, fontWeight: FontWeight.w600, fontSize: 13.5)),
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
            return GestureDetector(
              onTap: () => _selectCat(i),
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
            isDense: true, hintText: 'In Kategorie suchen…', hintStyle: const TextStyle(color: kMuted, fontSize: 13),
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
            ? _empty('Keine Treffer')
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

  Widget _poster(Item it) => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => widget.type == 'series' ? SeriesDetailScreen(item: it) : MovieDetailScreen(item: it))),
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
      body: Container(
        decoration: _bgDeco(),
        child: loading
            ? _loading()
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 200, height: 300,
                      child: cover.isEmpty
                          ? Container(color: kPanel2, child: const Icon(Icons.movie_rounded, color: kMuted, size: 48))
                          : Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: kPanel2, child: const Icon(Icons.movie_rounded, color: kMuted, size: 48))),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.item.name, style: const TextStyle(color: kText, fontSize: 24, fontWeight: FontWeight.w800, fontFamily: 'serif')),
                      const SizedBox(height: 10),
                      if (meta.isNotEmpty) Text(meta.join('   ·   '), style: const TextStyle(color: kBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      Expanded(child: SingleChildScrollView(child: Text(plot.isEmpty ? 'Keine Beschreibung verfügbar.' : plot, style: const TextStyle(color: kMuted, fontSize: 14, height: 1.5)))),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 220, height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: kBlue, foregroundColor: kBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(title: widget.item.name, url: Xtream.vodUrl(widget.item.id, ext), resume: true))),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Abspielen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                              return GestureDetector(
                                onTap: () => setState(() => season = seasons[i]),
                                child: Container(
                                  alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(color: s ? kBlue : kPanel2, borderRadius: BorderRadius.circular(19), border: Border.all(color: s ? kBlue : kLine)),
                                  child: Text('Staffel ${seasons[i]}', style: TextStyle(color: s ? kBg : kMuted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: eps.isEmpty
                            ? _empty('Keine Folgen')
                            : ListView.builder(
                                itemCount: eps.length,
                                itemBuilder: (c, i) {
                                  final e = eps[i];
                                  return GestureDetector(
                                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(title: e.title, url: Xtream.seriesEpUrl(e.id, e.ext), resume: true))),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
                                      child: Row(children: [
                                        Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: kPanel2, borderRadius: BorderRadius.circular(8)), child: Text('${e.num}', style: const TextStyle(color: kBlue, fontWeight: FontWeight.w700, fontSize: 12))),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600))),
                                        const Icon(Icons.play_circle_outline_rounded, color: kMuted, size: 20),
                                      ]),
                                    ),
                                  );
                                },
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

// ============================ PLAYER (Platzhalter – VLC im nativen Build) ============================
class PlayerScreen extends StatefulWidget {
  final String title, url;
  final List<Item>? channels; // gesetzt = Live (Zapping möglich)
  final int index;
  final String Function(Item)? urlFor;
  final bool resume; // Filme/Serien: Position merken & fortsetzen
  const PlayerScreen({super.key, required this.title, required this.url, this.channels, this.index = 0, this.urlFor, this.resume = false});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  late String title = widget.title;
  late int idx = widget.index;
  String epg = '';
  StreamSubscription? _durSub;
  bool _seeked = false;

  @override
  void initState() {
    super.initState();
    player.open(Media(widget.url));
    _loadEpg();
    if (widget.resume) {
      _durSub = player.stream.duration.listen((d) {
        if (!_seeked && d > Duration.zero) {
          _seeked = true;
          final s = ResumeStore.get(widget.url);
          if (s > 5) player.seek(Duration(seconds: s));
        }
      });
    }
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
    if (widget.resume) {
      ResumeStore.set(widget.url, player.state.position.inSeconds, player.state.duration.inSeconds);
    }
    _durSub?.cancel();
    player.dispose();
    super.dispose();
  }

  void _zap(int delta) {
    final ch = widget.channels;
    if (ch == null || widget.urlFor == null) return;
    final n = idx + delta;
    if (n < 0 || n >= ch.length) return;
    setState(() { idx = n; title = ch[n].name; });
    player.open(Media(widget.urlFor!(ch[n])));
    _loadEpg();
  }

  void _tracks(bool audio) {
    final list = audio ? player.state.tracks.audio : player.state.tracks.subtitle;
    showModalBottomSheet(
      context: context,
      backgroundColor: kPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(audio ? 'Audiospur wählen' : 'Untertitel wählen', style: const TextStyle(color: kText, fontWeight: FontWeight.w700, fontSize: 16))),
          if (list.isEmpty) const Padding(padding: EdgeInsets.only(bottom: 20), child: Text('Keine Spuren verfügbar', style: TextStyle(color: kMuted))),
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
    final ttl = t.title as String?;
    final lang = t.language as String?;
    if (ttl != null && ttl.isNotEmpty) return ttl;
    if (lang != null && lang.isNotEmpty) return lang;
    return '${t.id}';
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.channels != null;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kText, size: 20), onPressed: () => Navigator.pop(context)),
        title: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontWeight: FontWeight.w800, fontFamily: 'serif', fontSize: 20)),
          if (epg.isNotEmpty) Text('Jetzt: $epg', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
        actions: [
          if (live) IconButton(icon: const Icon(Icons.skip_previous_rounded, color: kText), tooltip: 'Vorheriger Sender', onPressed: () => _zap(-1)),
          if (live) IconButton(icon: const Icon(Icons.skip_next_rounded, color: kText), tooltip: 'Nächster Sender', onPressed: () => _zap(1)),
          IconButton(icon: const Icon(Icons.audiotrack_rounded, color: kText), tooltip: 'Audiospur', onPressed: () => _tracks(true)),
          IconButton(icon: const Icon(Icons.closed_caption_rounded, color: kText), tooltip: 'Untertitel', onPressed: () => _tracks(false)),
          const SizedBox(width: 8),
        ],
      ),
      body: Video(controller: controller, controls: AdaptiveVideoControls),
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
  final items = const ['Stream-Format', 'Kindersicherung', 'Versteckte Kategorien', 'Favoriten', 'Über Vela'];

  @override
  Widget build(BuildContext context) {
    final narrow = _narrow(context);
    final list = Container(
      decoration: BoxDecoration(color: kPanel.withValues(alpha: .5), borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
      child: ListView.separated(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: kLine),
        itemBuilder: (c, i) => GestureDetector(
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
      appBar: _subBar(context, 'Einstellungen'),
      body: Container(
        decoration: _bgDeco(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: narrow
              ? ListView(children: [list, const SizedBox(height: 16), _detail()])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: list), const SizedBox(width: 16), Expanded(flex: 2, child: _detail())]),
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
      case 1: return _parental();
      case 2: return const _HiddenCats();
      case 3: return _favs();
      default: return _about();
    }
  }

  Widget _streamFormat() => _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Stream-Format (Live)', style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Falls ein Sender nicht startet, das andere Format probieren.', style: TextStyle(color: kMuted, fontSize: 12.5)),
        const SizedBox(height: 14),
        _opt('TS (Standard)', Prefs.liveExt == 'ts', () { Prefs.setLiveExt('ts'); setState(() {}); }),
        _opt('HLS (m3u8)', Prefs.liveExt == 'm3u8', () { Prefs.setLiveExt('m3u8'); setState(() {}); }),
      ]));

  Widget _opt(String label, bool on, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: on ? kBlue.withValues(alpha: .14) : kPanel2, borderRadius: BorderRadius.circular(10), border: Border.all(color: on ? kBlue : kLine)),
          child: Row(children: [Text(label, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600)), const Spacer(), if (on) const Icon(Icons.check_rounded, color: kBlue, size: 20)]),
        ),
      );

  Widget _parental() => _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Kindersicherung', style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Blendet XXX-/18+-Kategorien überall aus.', style: TextStyle(color: kMuted, fontSize: 12.5)),
        const SizedBox(height: 10),
        Row(children: [
          const Expanded(child: Text('Erwachsenen-Inhalte ausblenden', style: TextStyle(color: kText, fontSize: 14))),
          Switch(value: Prefs.hideAdult, activeThumbColor: kBlue, onChanged: _toggleAdult),
        ]),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(side: const BorderSide(color: kLine)),
          onPressed: _pinDialog,
          icon: const Icon(Icons.lock_rounded, size: 18, color: kBlue),
          label: Text(Prefs.hasPin ? 'PIN ändern' : 'PIN festlegen', style: const TextStyle(color: kBlue)),
        ),
      ]));

  void _toggleAdult(bool v) async {
    if (!v && Prefs.hasPin) {
      final ok = await _askPin('PIN zum Freigeben');
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
        title: const Text('PIN festlegen', style: TextStyle(color: kText)),
        content: TextField(controller: c, keyboardType: TextInputType.number, obscureText: true, style: const TextStyle(color: kText), decoration: const InputDecoration(hintText: 'Mind. 4 Ziffern', hintStyle: TextStyle(color: kMuted))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Speichern')),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK')),
        ],
      ),
    );
    return ok == true && Prefs.checkPin(c.text.trim());
  }

  Widget _favs() => _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Favoriten', style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${FavStore.items().length} gespeicherte Sender', style: const TextStyle(color: kMuted, fontSize: 12.5)),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(side: const BorderSide(color: kLine)),
          onPressed: () async {
            for (final it in FavStore.items()) { await FavStore.toggle(it); }
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF2A0A0), size: 18),
          label: const Text('Alle Favoriten löschen', style: TextStyle(color: kText)),
        ),
      ]));

  Widget _about() => _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: const [
        Text('Vela Player', style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: kPanel.withValues(alpha: .5), borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Versteckte Kategorien', style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(children: [
          for (final t in const [['live', 'Live'], ['vod', 'Filme'], ['series', 'Serien']])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
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
        SizedBox(
          height: 300,
          child: loading
              ? _loading()
              : ListView.builder(
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
                ),
        ),
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
    final i = await Xtream.userInfo(Session.account!);
    if (mounted) setState(() { info = i; loading = false; });
  }

  Future<void> _logout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ConnectScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final i = info ?? {};
    final status = (i['status'] ?? '').toString();
    final data = [
      ['Benutzername', Session.account!.user, Icons.person_rounded, false],
      ['Status', status.isEmpty ? '—' : status, Icons.cloud_done_rounded, status.toLowerCase() == 'active'],
      ['Verbindungen', '${i['active_cons'] ?? 0} / ${i['max_connections'] ?? '?'}', Icons.link_rounded, false],
      ['Läuft ab', _tsDate(i['exp_date']), Icons.event_rounded, false],
      ['Testzugang', ('${i['is_trial']}' == '1') ? 'Ja' : 'Nein', Icons.verified_user_rounded, false],
      ['Erstellt am', _tsDate(i['created_at']), Icons.calendar_month_rounded, false],
    ];
    final cols = _narrow(context) ? 1 : 2;
    return Scaffold(
      appBar: _subBar(context, 'Playlist-Info', actions: [
        TextButton.icon(onPressed: _logout, icon: const Icon(Icons.logout_rounded, color: kMuted, size: 18), label: const Text('Abmelden', style: TextStyle(color: kMuted))),
        const SizedBox(width: 8),
      ]),
      body: Container(
        decoration: _bgDeco(),
        child: loading
            ? _loading()
            : Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 14, crossAxisSpacing: 14, mainAxisExtent: 64),
                  itemCount: data.length,
                  itemBuilder: (c, idx) {
                    final ok = data[idx][3] as bool;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(color: kPanel.withValues(alpha: .5), borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
                      child: Row(children: [
                        Icon(data[idx][2] as IconData, color: kBlue, size: 22),
                        const SizedBox(width: 14),
                        Text(data[idx][0] as String, style: const TextStyle(color: kText, fontWeight: FontWeight.w700, fontSize: 15)),
                        const Spacer(),
                        Text(data[idx][1] as String, style: TextStyle(color: ok ? kOk : kText, fontWeight: FontWeight.w600, fontSize: 14.5)),
                      ]),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
