import 'dart:convert';
import 'dart:math';
import 'dart:ui' show PlatformDispatcher;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Proxy auf dem Hub (umgeht CORS, holt Provider-Daten server-zu-server).
const String kProxy = 'https://hub.mtplyr.com/api/xt.php';

/// Web-Erkennung ohne Flutter-Import (auf Web sind int/double identisch).
const bool kOnWeb = identical(0, 0.0);

/// Aktivierung: Hub-Endpunkt, der zu einem Geräte-Code die verknüpfte Playlist zurückgibt.
const String kActivate = 'https://hub.mtplyr.com/api/vela_activate.php';

/// Playlist an den Hub melden (App-seitige Eingabe erscheint dann auf velaplayer.com).
const String kAddPlaylist = 'https://hub.mtplyr.com/api/playlist_add.php';

/// Lizenz-/Trial-Status (an die MAC gebunden, serverseitig) — Quelle der Wahrheit.
const String kLicense = 'https://hub.mtplyr.com/api/license_status.php';

/// Portal, auf dem Nutzer ihre Playlist (M3U/Xtream) mit dem Code hochladen.
const String kPortal = 'velaplayer.com';

class Account {
  final String host, user, pass;
  Account(this.host, this.user, this.pass);
}

/// Ein Sender aus einer M3U-Playlist (direkte Stream-URL, kein Xtream).
class M3uChannel {
  final String name, logo, group, url;
  M3uChannel(this.name, this.logo, this.group, this.url);
}

/// Aktuelle Sitzung (Zugangsdaten), persistiert.
class Session {
  static Account? account;
  static String mac = '';
  static String deviceKey = '';

  // Playlist-Quelle: 'xtream' (Account/Proxy) oder 'm3u' (direkte Senderliste).
  static String mode = 'xtream';
  static List<M3uChannel> m3u = [];
  static String m3uUrl = '';

  /// Ist eine Playlist eingerichtet? (Xtream ODER M3U)
  static bool get isReady => mode == 'm3u' ? m3u.isNotEmpty : account != null;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final h = p.getString('xt_host');
    final u = p.getString('xt_user');
    final pw = p.getString('xt_pass');
    if (h != null && u != null && pw != null) account = Account(h, u, pw);
    mac = p.getString('device_mac') ?? '';
    deviceKey = p.getString('device_key') ?? '';
    if (mac.isEmpty) { mac = _genMac(); await p.setString('device_mac', mac); }
    if (deviceKey.isEmpty) { deviceKey = _genKey(); await p.setString('device_key', deviceKey); }
    // Playlist-Quelle wiederherstellen (M3U -> beim Start neu laden).
    mode = p.getString('src_mode') ?? 'xtream';
    m3uUrl = p.getString('m3u_url') ?? '';
    if (mode == 'm3u' && m3uUrl.isNotEmpty) { await loadM3u(m3uUrl, persist: false); }
  }

  // Geräte-Identität wie vela/mtplyr/IBO: virtuelle MAC + Geräteschlüssel.
  // iOS gibt die echte MAC nicht her -> einmal generiert & gespeichert.
  static String _genMac() {
    final r = Random.secure();
    String h2() => r.nextInt(256).toRadixString(16).padLeft(2, '0').toUpperCase();
    return '1A:2B:3C:${h2()}:${h2()}:${h2()}';
  }

  static String _genKey() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  /// Server-Stand (velaplayer.com) holen UND anwenden — die Homepage ist die Wahrheit.
  ///   'ok'    = Playlist vom Server geladen/aktualisiert (Sitzung eingerichtet)
  ///   'none'  = Server erreichbar, aber KEINE Playlist mehr verknüpft (auf velaplayer.com gelöscht)
  ///   'error' = Server nicht erreichbar / Provider-Aussetzer -> lokalen Stand behalten (offline)
  static Future<String> syncFromActivation() async {
    if (mac.isEmpty) return 'error';
    try {
      final uri = Uri.parse(kActivate).replace(queryParameters: {'mac': mac, 'key': deviceKey});
      final r = await http.get(uri).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return 'error';
      final j = jsonDecode(r.body);
      if (j is! Map) return 'error';
      if ('${j['host'] ?? ''}'.isNotEmpty) {
        final a = Account('${j['host']}', '${j['username'] ?? j['user'] ?? ''}', '${j['password'] ?? j['pass'] ?? ''}');
        if (await Xtream.userInfo(a) == null) return 'error'; // Provider gerade nicht erreichbar -> nicht löschen
        await save(a);
        return 'ok';
      }
      if (j['message'] == 'm3u_only' && '${j['raw_url'] ?? ''}'.isNotEmpty) {
        return await loadM3u('${j['raw_url']}') ? 'ok' : 'error';
      }
      // 'pending' = Gerät ohne (aktive) Playlist -> auf velaplayer.com gelöscht/noch keine.
      if (j['message'] == 'pending') return 'none';
    } catch (_) {}
    return 'error'; // expired/blocked/unbekannt: Lizenz-Gate regelt das, Playlist NICHT anfassen
  }

  /// Holt die dem MAC/Key zugewiesene Playlist vom Hub und richtet die Sitzung ein.
  /// true = bereit (Xtream ODER M3U geladen).
  static Future<bool> pullActivation() async => (await syncFromActivation()) == 'ok';

  /// Manuell in der App eingegebene Xtream-Playlist an velaplayer.com melden,
  /// damit sie dort (für Kunde/Reseller) sichtbar ist und der Server die Wahrheit bleibt.
  /// true = auf dem Server gespeichert.
  static Future<bool> pushXtreamToServer(Account a) async {
    if (mac.isEmpty) return false;
    try {
      final r = await http.post(Uri.parse(kAddPlaylist), body: {
        'mac': mac, 'key': deviceKey, 'brand': 'vela',
        'type': 'xtream', 'xt_server': a.host, 'xt_user': a.user, 'xt_pass': a.pass,
      }).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body);
      return j is Map && j['success'] == true;
    } catch (_) { return false; }
  }

  /// Manuell in der App eingegebene M3U-Link-Playlist an velaplayer.com melden.
  /// true = auf dem Server gespeichert.
  static Future<bool> pushM3uToServer(String url) async {
    if (mac.isEmpty) return false;
    try {
      final r = await http.post(Uri.parse(kAddPlaylist), body: {
        'mac': mac, 'key': deviceKey, 'brand': 'vela',
        'type': 'url', 'url': url,
      }).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body);
      return j is Map && j['success'] == true;
    } catch (_) { return false; }
  }

  /// M3U-Playlist von einer URL laden, parsen und als aktive Quelle setzen.
  static Future<bool> loadM3u(String url, {bool persist = true}) async {
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) return false;
      final chans = parseM3u(r.body);
      if (chans.isEmpty) return false;
      m3u = chans; m3uUrl = url; mode = 'm3u'; account = null;
      if (persist) {
        final p = await SharedPreferences.getInstance();
        await p.setString('src_mode', 'm3u');
        await p.setString('m3u_url', url);
        await p.remove('xt_host'); await p.remove('xt_user'); await p.remove('xt_pass');
      }
      return true;
    } catch (_) { return false; }
  }

  /// Standard-M3U parsen: #EXTINF (tvg-logo, group-title, Name) + folgende URL-Zeile.
  static List<M3uChannel> parseM3u(String text) {
    final out = <M3uChannel>[];
    String name = '', logo = '', group = '';
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF')) {
        logo = _m3uAttr(line, 'tvg-logo');
        group = _m3uAttr(line, 'group-title');
        final comma = line.lastIndexOf(',');
        name = comma >= 0 ? line.substring(comma + 1).trim() : '';
      } else if (line.startsWith('#')) {
        continue; // andere Direktiven ignorieren
      } else {
        out.add(M3uChannel(name.isEmpty ? line : name, logo, group.isEmpty ? 'Sender' : group, line));
        name = ''; logo = ''; group = '';
      }
    }
    return out;
  }

  static String _m3uAttr(String line, String key) {
    final m = RegExp('$key="([^"]*)"').firstMatch(line);
    return m != null ? m.group(1)! : '';
  }

  static Future<void> save(Account a) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('xt_host', a.host);
    await p.setString('xt_user', a.user);
    await p.setString('xt_pass', a.pass);
    account = a; mode = 'xtream'; m3u = []; m3uUrl = '';
    await p.setString('src_mode', 'xtream');
    await p.remove('m3u_url');
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('xt_host');
    await p.remove('xt_user');
    await p.remove('xt_pass');
    await p.remove('src_mode');
    await p.remove('m3u_url');
    account = null; mode = 'xtream'; m3u = []; m3uUrl = '';
  }
}

class Category {
  final String id, name;
  Category(this.id, this.name);
}

class Item {
  final String id, name, icon;
  final int num;
  final String ext; // container_extension (Filme)
  Item(this.id, this.name, this.icon, {this.num = 0, this.ext = ''});
}

class Xtream {
  static String base(String host) {
    var b = host.trim();
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(b)) b = 'http://$b';
    return b.replaceAll(RegExp(r'/+$'), '');
  }

  static Future<dynamic> _get(String action, [Map<String, String>? extra]) async {
    final a = Session.account!;
    final uri = Uri.parse(kProxy).replace(queryParameters: {
      'action': action, 'host': a.host, 'username': a.user, 'password': a.pass, ...?extra,
    });
    final r = await http.get(uri).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return jsonDecode(r.body);
  }

  /// Verbindung testen + Konto-Infos holen.
  static Future<Map<String, dynamic>?> userInfo(Account a) async {
    final uri = Uri.parse(kProxy).replace(queryParameters: {
      'action': 'user_info', 'host': a.host, 'username': a.user, 'password': a.pass,
    });
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body);
      if (j is Map && j['user_info'] is Map) {
        return Map<String, dynamic>.from(j['user_info']);
      }
    } catch (_) {}
    return null;
  }

  static Future<List<Category>> categoriesRaw(String type) async {
    if (Session.mode == 'm3u') {
      if (type != 'live') return []; // M3U kennt keine VOD-/Serien-Kategorien
      final seen = <String>{}; final out = <Category>[];
      for (final c in Session.m3u) { if (seen.add(c.group)) out.add(Category(c.group, c.group)); }
      return out;
    }
    final action = type == 'live'
        ? 'live_categories'
        : type == 'vod'
            ? 'vod_categories'
            : 'series_categories';
    final j = await _get(action);
    if (j is! List) return [];
    return j
        .map((e) => Category(e['category_id'].toString(), (e['category_name'] ?? '').toString()))
        .toList();
  }

  /// Sichtbare Kategorien (versteckte + Adult je nach Einstellung ausgeblendet).
  static Future<List<Category>> categories(String type) async {
    final all = await categoriesRaw(type);
    return all.where((c) => Prefs.visible(c.name)).toList();
  }

  static Future<List<Item>> liveStreams(String catId) async {
    if (Session.mode == 'm3u') {
      return Session.m3u.where((c) => c.group == catId).map((c) => Item(c.url, c.name, c.logo)).toList();
    }
    final j = await _get('live_streams', {'category_id': catId});
    if (j is! List) return [];
    return j
        .map((e) => Item(e['stream_id'].toString(), (e['name'] ?? '').toString(),
            (e['stream_icon'] ?? '').toString(), num: int.tryParse('${e['num']}') ?? 0))
        .toList();
  }

  static Future<List<Item>> vodStreams(String catId) async {
    if (Session.mode == 'm3u') return [];
    final j = await _get('vod_streams', {'category_id': catId});
    if (j is! List) return [];
    return j
        .map((e) => Item(e['stream_id'].toString(), (e['name'] ?? '').toString(),
            (e['stream_icon'] ?? e['cover'] ?? '').toString(),
            ext: (e['container_extension'] ?? 'mp4').toString()))
        .toList();
  }

  /// Alle Filme / Serien (ohne Kategorie) – für die globale Suche.
  static Future<List<Item>> allVod() async {
    if (Session.mode == 'm3u') return [];
    final j = await _get('vod_streams');
    if (j is! List) return [];
    return j
        .map((e) => Item(e['stream_id'].toString(), (e['name'] ?? '').toString(),
            (e['stream_icon'] ?? e['cover'] ?? '').toString(),
            ext: (e['container_extension'] ?? 'mp4').toString()))
        .toList();
  }

  static Future<List<Item>> allSeries() async {
    if (Session.mode == 'm3u') return [];
    final j = await _get('series');
    if (j is! List) return [];
    return j
        .map((e) => Item(e['series_id'].toString(), (e['name'] ?? '').toString(), (e['cover'] ?? '').toString()))
        .toList();
  }

  /// Alle Live-Sender (ohne Kategorie) – für die globale Suche. Adult-Filter je nach Einstellung.
  static Future<List<Item>> allLive() async {
    if (Session.mode == 'm3u') {
      final all = Session.m3u.map((c) => Item(c.url, c.name, c.logo)).toList();
      return Prefs.hideAdult ? all.where((c) => !Prefs.isAdult(c.name)).toList() : all;
    }
    final j = await _get('live_streams');
    if (j is! List) return [];
    final list = j
        .map((e) => Item(e['stream_id'].toString(), (e['name'] ?? '').toString(),
            (e['stream_icon'] ?? '').toString(), num: int.tryParse('${e['num']}') ?? 0))
        .toList();
    return Prefs.hideAdult ? list.where((c) => !Prefs.isAdult(c.name)).toList() : list;
  }

  static Future<List<Item>> seriesList(String catId) async {
    if (Session.mode == 'm3u') return [];
    final j = await _get('series', {'category_id': catId});
    if (j is! List) return [];
    return j
        .map((e) => Item(e['series_id'].toString(), (e['name'] ?? '').toString(),
            (e['cover'] ?? '').toString()))
        .toList();
  }

  /// Stream-URLs fuer den Player (nativer Build).
  static String liveUrl(String streamId) {
    if (Session.mode == 'm3u') return streamId; // bei M3U ist die ID bereits die direkte URL
    final a = Session.account!;
    return '${base(a.host)}/live/${a.user}/${a.pass}/$streamId.${Prefs.liveExt}';
  }

  static String vodUrl(String streamId, String ext) {
    final a = Session.account!;
    return '${base(a.host)}/movie/${a.user}/${a.pass}/$streamId.${ext.isEmpty ? 'mp4' : ext}';
  }

  static String seriesEpUrl(String epId, String ext) {
    final a = Session.account!;
    return '${base(a.host)}/series/${a.user}/${a.pass}/$epId.${ext.isEmpty ? 'mp4' : ext}';
  }

  /// EPG-Archiv (vergangene Sendungen mit Aufzeichnung) eines Senders – für Catch-Up.
  static Future<List<Program>> archive(String streamId) async {
    if (Session.mode == 'm3u') return []; // M3U hat kein EPG-Archiv
    final j = await _get('simple_data_table', {'stream_id': streamId});
    final list = (j is Map && j['epg_listings'] is List)
        ? j['epg_listings'] as List
        : (j is List ? j : const []);
    final out = <Program>[];
    for (final e in list) {
      final startRaw = '${e['start'] ?? ''}';
      final endRaw = '${e['end'] ?? ''}';
      DateTime? s = DateTime.tryParse(startRaw.replaceFirst(' ', 'T'));
      DateTime? en = DateTime.tryParse(endRaw.replaceFirst(' ', 'T'));
      if (s == null) { final t = int.tryParse('${e['start_timestamp']}'); if (t != null) s = DateTime.fromMillisecondsSinceEpoch(t * 1000); }
      if (en == null) { final t = int.tryParse('${e['stop_timestamp']}'); if (t != null) en = DateTime.fromMillisecondsSinceEpoch(t * 1000); }
      if (s == null || en == null) continue;
      String title = '${e['title'] ?? ''}';
      try { title = utf8.decode(base64.decode(title)); } catch (_) {}
      final has = '${e['has_archive'] ?? e['now_playing'] ?? '0'}' == '1';
      out.add(Program(title, startRaw, s, en, has));
    }
    return out;
  }

  /// Timeshift-/Catch-Up-URL für eine vergangene Sendung.
  static String timeshiftUrl(String streamId, Program p) {
    final a = Session.account!;
    String start;
    if (p.startRaw.contains(' ') && p.startRaw.length >= 16) {
      final parts = p.startRaw.split(' ');
      start = '${parts[0]}:${parts[1].substring(0, 5).replaceAll(':', '-')}';
    } else {
      String two(int x) => x.toString().padLeft(2, '0');
      start = '${p.start.year}-${two(p.start.month)}-${two(p.start.day)}:${two(p.start.hour)}-${two(p.start.minute)}';
    }
    final dur = p.durationMin <= 0 ? 60 : p.durationMin;
    return '${base(a.host)}/streaming/timeshift.php?username=${a.user}&password=${a.pass}&stream=$streamId&start=$start&duration=$dur';
  }

  /// Aktuell laufende Sendung (EPG) eines Live-Senders – Titel (base64-dekodiert).
  static Future<String> nowPlaying(String streamId) async {
    if (Session.mode == 'm3u') return ''; // M3U hat kein EPG
    try {
      final j = await _get('short_epg', {'stream_id': streamId, 'limit': '1'});
      if (j is Map && j['epg_listings'] is List && (j['epg_listings'] as List).isNotEmpty) {
        final t = '${(j['epg_listings'] as List).first['title'] ?? ''}';
        try { return utf8.decode(base64.decode(t)); } catch (_) { return t; }
      }
    } catch (_) {}
    return '';
  }

  /// Film-Details (Plot, Cover, Meta).
  static Future<Map<String, dynamic>> vodInfo(String vodId) async {
    final j = await _get('vod_info', {'vod_id': vodId});
    return (j is Map) ? Map<String, dynamic>.from(j) : {};
  }

  /// Serien-Details (info + episodes je Staffel).
  static Future<SeriesDetail> seriesInfo(String seriesId) async {
    final j = await _get('series_info', {'series_id': seriesId});
    final info = (j is Map && j['info'] is Map) ? Map<String, dynamic>.from(j['info']) : <String, dynamic>{};
    final seasons = <String, List<Episode>>{};
    if (j is Map && j['episodes'] is Map) {
      (j['episodes'] as Map).forEach((season, eps) {
        if (eps is List) {
          seasons[season.toString()] = eps
              .map((e) => Episode(
                    e['id'].toString(),
                    (e['title'] ?? 'Ep. ${e['episode_num'] ?? ''}').toString(),
                    (e['container_extension'] ?? 'mp4').toString(),
                    int.tryParse('${e['episode_num']}') ?? 0,
                  ))
              .toList();
        }
      });
    }
    return SeriesDetail(info, seasons);
  }
}

class Episode {
  final String id, title, ext;
  final int num;
  Episode(this.id, this.title, this.ext, this.num);
}

class Program {
  final String title, startRaw;
  final DateTime start, end;
  final bool hasArchive;
  Program(this.title, this.startRaw, this.start, this.end, this.hasArchive);
  int get durationMin => end.difference(start).inMinutes;
}

/// App-Einstellungen (persistiert).
class Prefs {
  static String liveExt = 'ts'; // 'ts' oder 'm3u8'
  static bool hideAdult = false;
  static Set<String> hidden = {};
  static String? pinHash;
  static int bufferIdx = 1; // 0 niedrig, 1 standard, 2 hoch, 3 extrem
  static int subIdx = 1; // 0 groß, 1 normal, 2 klein
  static bool useFaceId = false;
  static String lang = 'de'; // App-Sprache

  static const _adult = ['XXX', 'ADULT', '+18', '18+', 'EROTIC', 'EROTIK', 'PORN', 'PORNO', 'FSK18', 'NIGHT CLUB'];

  static int get bufferBytes => const [8, 32, 64, 128][bufferIdx.clamp(0, 3)] * 1024 * 1024;
  static double get subScale => const [1.6, 1.0, 0.7][subIdx.clamp(0, 2)];

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    liveExt = p.getString('live_ext') ?? (kOnWeb ? 'm3u8' : 'ts'); // Web/TV: HLS (media_kit-Web spielt nur HLS)
    hideAdult = p.getBool('hide_adult') ?? false;
    hidden = (p.getStringList('hidden_cats') ?? []).toSet();
    pinHash = p.getString('pin_hash');
    bufferIdx = p.getInt('buffer_idx') ?? 1;
    subIdx = p.getInt('sub_idx') ?? 1;
    useFaceId = p.getBool('use_faceid') ?? false;
    lang = p.getString('lang') ?? _deviceLang();
  }

  static const _supportedLangs = ['de', 'en', 'tr', 'ar', 'fr', 'it', 'el'];
  static String _deviceLang() {
    try {
      final code = PlatformDispatcher.instance.locale.languageCode;
      return _supportedLangs.contains(code) ? code : 'en';
    } catch (_) { return 'en'; }
  }

  static Future<void> _p(Function(SharedPreferences) f) async => f(await SharedPreferences.getInstance());

  static Future<void> setLiveExt(String v) async { liveExt = v; await _p((p) => p.setString('live_ext', v)); }
  static Future<void> setHideAdult(bool v) async { hideAdult = v; await _p((p) => p.setBool('hide_adult', v)); }
  static Future<void> setBufferIdx(int v) async { bufferIdx = v; await _p((p) => p.setInt('buffer_idx', v)); }
  static Future<void> setSubIdx(int v) async { subIdx = v; await _p((p) => p.setInt('sub_idx', v)); }
  static Future<void> setUseFaceId(bool v) async { useFaceId = v; await _p((p) => p.setBool('use_faceid', v)); }
  static Future<void> setLang(String v) async { lang = v; await _p((p) => p.setString('lang', v)); }
  static Future<void> toggleHidden(String name) async {
    hidden.contains(name) ? hidden.remove(name) : hidden.add(name);
    await _p((p) => p.setStringList('hidden_cats', hidden.toList()));
  }

  static String _sha(String s) => sha256.convert(utf8.encode(s)).toString();
  static bool get hasPin => pinHash != null && pinHash!.isNotEmpty;
  static bool checkPin(String pin) => !hasPin || pinHash == _sha(pin);
  static Future<void> setPin(String pin) async { pinHash = _sha(pin); await _p((p) => p.setString('pin_hash', pinHash!)); }

  static bool isAdult(String name) { final u = name.toUpperCase(); return _adult.any((k) => u.contains(k)); }
  static bool visible(String name) => !hidden.contains(name) && !(hideAdult && isAdult(name));
}

/// Vela-Lizenz/Trial (lokal, persistiert). 10 Tage gratis ab erstem Verbinden,
/// danach Freischaltung (Lifetime). Playlist-Ablauf kommt separat vom Anbieter (exp_date).
class License {
  static const int trialDays = 10;
  static DateTime? trialStart;
  static bool paid = false;
  static bool simExpiredPlaylist = false; // nur zum Testen

  // Serverseitiger Status (an MAC gebunden). Wenn bekannt, ist er die Wahrheit;
  // lokale trialStart-Logik bleibt nur Offline-Fallback.
  static bool serverKnown = false;
  static String serverStatus = ''; // trial | active | lifetime | expired | blocked
  static int? serverDaysLeft;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt('trial_start');
    trialStart = ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
    paid = p.getBool('lic_paid') ?? false;
    simExpiredPlaylist = p.getBool('sim_expired') ?? false;
  }

  static Future<void> startTrial() async {
    if (trialStart != null) return;
    trialStart = DateTime.now();
    final p = await SharedPreferences.getInstance();
    await p.setInt('trial_start', trialStart!.millisecondsSinceEpoch);
  }

  /// Server-Status (an MAC gebunden) holen. Setzt paid/serverStatus/serverDaysLeft.
  /// Schlaegt der Aufruf fehl (offline / Geraet noch nicht registriert), bleibt der
  /// lokale Fallback aktiv.
  static Future<void> syncFromServer() async {
    if (Session.mac.isEmpty) return;
    try {
      final uri = Uri.parse(kLicense).replace(
          queryParameters: {'mac': Session.mac, 'key': Session.deviceKey, 'brand': 'vela'});
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return;
      final j = jsonDecode(r.body);
      if (j is Map && j['success'] == true && j['device'] is Map) {
        serverKnown = true;
        serverStatus = '${j['device']['license_status'] ?? ''}';
        final dl = j['device']['days_left'];
        serverDaysLeft = dl is int ? dl : int.tryParse('${dl ?? ''}');
        final p = await SharedPreferences.getInstance();
        if (j['paid'] == true) {
          paid = true;
          await p.setBool('lic_paid', true);
        } else if (serverStatus == 'trial' || serverStatus == 'expired') {
          paid = false;
          await p.setBool('lic_paid', false);
        }
      }
    } catch (_) {}
  }

  static int get daysLeft {
    if (paid) return trialDays;
    if (serverKnown && serverDaysLeft != null) return serverDaysLeft!.clamp(0, trialDays);
    if (trialStart == null) return trialDays;
    final used = DateTime.now().difference(trialStart!).inDays;
    return (trialDays - used).clamp(0, trialDays);
  }

  static bool get trialExpired {
    if (paid) return false;
    if (serverKnown) return serverStatus == 'expired' || (serverDaysLeft != null && serverDaysLeft! <= 0);
    return trialStart != null && DateTime.now().difference(trialStart!).inDays >= trialDays;
  }

  // ---- Test-Schalter ----
  static Future<void> setPaid(bool v) async { serverKnown = false; paid = v; final p = await SharedPreferences.getInstance(); await p.setBool('lic_paid', v); }
  static Future<void> resetTrial() async { serverKnown = false; trialStart = DateTime.now(); paid = false; final p = await SharedPreferences.getInstance(); await p.setInt('trial_start', trialStart!.millisecondsSinceEpoch); await p.setBool('lic_paid', false); }
  static Future<void> expireTrial() async { serverKnown = false; trialStart = DateTime.now().subtract(const Duration(days: trialDays + 1)); paid = false; final p = await SharedPreferences.getInstance(); await p.setInt('trial_start', trialStart!.millisecondsSinceEpoch); await p.setBool('lic_paid', false); }
  static Future<void> setSimExpired(bool v) async { simExpiredPlaylist = v; final p = await SharedPreferences.getInstance(); await p.setBool('sim_expired', v); }
}

/// Wiedergabe-Position merken (Weiterschauen), persistiert. Schlüssel = Stream-URL.
class ResumeStore {
  static Map<String, int> _pos = {};

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('resume_pos');
    if (s != null) {
      try { _pos = Map<String, int>.from(jsonDecode(s)); } catch (_) {}
    }
  }

  static int get(String url) => _pos[url] ?? 0;

  static Future<void> set(String url, int pos, int dur) async {
    // nur merken, wenn mittendrin (nicht ganz am Anfang/Ende)
    if (pos > 20 && (dur == 0 || pos < dur - 90)) {
      _pos[url] = pos;
    } else {
      _pos.remove(url);
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('resume_pos', jsonEncode(_pos));
  }
}

/// „Weiterschauen" – zuletzt angesehene Filme/Folgen mit Restposition (persistiert).
class ContinueItem {
  final String url, title, poster;
  final int pos, dur;
  ContinueItem(this.url, this.title, this.poster, this.pos, this.dur);
  double get progress => dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
}

class ContinueStore {
  static const _k = 'continue_v1';
  static List<Map<String, dynamic>> _items = [];

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    if (s != null) {
      try { _items = (jsonDecode(s) as List).map((e) => Map<String, dynamic>.from(e)).toList(); } catch (_) {}
    }
  }

  static List<ContinueItem> items() => _items
      .map((e) => ContinueItem('${e['url']}', '${e['title']}', '${e['poster'] ?? ''}', e['pos'] ?? 0, e['dur'] ?? 0))
      .toList();

  static Future<void> record({required String url, required String title, required String poster, required int pos, required int dur}) async {
    _items.removeWhere((e) => e['url'] == url);
    // Nur merken, wenn mittendrin (nicht ganz am Anfang/Ende).
    if (pos > 30 && (dur == 0 || pos < dur - 90)) {
      _items.insert(0, {'url': url, 'title': title, 'poster': poster, 'pos': pos, 'dur': dur});
      if (_items.length > 15) _items = _items.sublist(0, 15);
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(_items));
  }

  static Future<void> remove(String url) async {
    _items.removeWhere((e) => e['url'] == url);
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(_items));
  }
}

/// Lokale Favoriten-Sender (persistiert).
class FavStore {
  static const _k = 'fav_live';
  static List<Map<String, dynamic>> _cache = [];

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    if (s != null) {
      try { _cache = (jsonDecode(s) as List).map((e) => Map<String, dynamic>.from(e)).toList(); } catch (_) {}
    }
  }

  static bool isFav(String id) => _cache.any((e) => e['id'] == id);
  static List<Item> items() => _cache.map((e) => Item('${e['id']}', '${e['name']}', '${e['icon'] ?? ''}', num: e['num'] ?? 0)).toList();

  static Future<void> toggle(Item it) async {
    if (isFav(it.id)) {
      _cache.removeWhere((e) => e['id'] == it.id);
    } else {
      _cache.add({'id': it.id, 'name': it.name, 'icon': it.icon, 'num': it.num});
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(_cache));
  }
}

class SeriesDetail {
  final Map<String, dynamic> info;
  final Map<String, List<Episode>> seasons;
  SeriesDetail(this.info, this.seasons);
}
