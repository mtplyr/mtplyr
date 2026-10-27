import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show PlatformDispatcher;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'brand.dart';

/// Proxy auf dem Hub (umgeht CORS, holt Provider-Daten server-zu-server).
const String kProxy = 'https://hub.mtplyr.com/api/xt.php';

/// Web-Erkennung ohne Flutter-Import (auf Web sind int/double identisch).
const bool kOnWeb = identical(0, 0.0);

/// Aktivierung: Hub-Endpunkt, der zu einem Geräte-Code die verknüpfte Playlist zurückgibt.
const String kActivate = 'https://hub.mtplyr.com/api/vela_activate.php';

/// Playlist an den Hub melden (App-seitige Eingabe erscheint dann auf velaplayer.com).
const String kAddPlaylist = 'https://hub.mtplyr.com/api/playlist_add.php';

/// Geraet beim Hub anmelden (MAC+Key) — damit die Website getippte MACs gegen
/// echte Geraete pruefen kann (verhindert Tippfehler-„Geistergeraete").
const String kRegister = 'https://hub.mtplyr.com/api/register_device.php';

/// „Zuletzt hinzugefügt" — Server holt VOD/Serien, App bekommt nur die neuesten N
/// (statt ~40.000 Einträge). Serverseitig gecacht -> schnelle Lobby.
const String kHomeLatest = 'https://hub.mtplyr.com/api/home_latest.php';

/// Lizenz-/Trial-Status (an die MAC gebunden, serverseitig) — Quelle der Wahrheit.
const String kLicense = 'https://hub.mtplyr.com/api/license_status.php';

class Account {
  final String host, user, pass;
  Account(this.host, this.user, this.pass);
}

/// Ein Eintrag aus einer M3U-Playlist (direkte Stream-URL, kein Xtream).
/// kind: 'live' | 'vod' | 'series' (aus dem URL-Pfad erkannt). ext: Datei-Endung (Filme/Serien).
class M3uChannel {
  final String name, logo, group, url, kind, ext;
  M3uChannel(this.name, this.logo, this.group, this.url, {this.kind = 'live', this.ext = ''});
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
    // Playlist-Quelle nur MERKEN (nicht laden!). Das Laden der (großen) M3U passiert
    // NACH dem ersten Frame im HomeGate (mit Spinner) -> Fenster erscheint sofort.
    mode = p.getString('src_mode') ?? 'xtream';
    m3uUrl = p.getString('m3u_url') ?? '';
  }

  /// Gibt es eine gespeicherte M3U-Quelle, die noch geladen werden muss?
  static bool get hasStoredM3u => mode == 'm3u' && m3uUrl.isNotEmpty;

  /// Die gemerkte M3U-Quelle jetzt tatsächlich laden (Cache -> schnell). Nach UI-Start aufrufen.
  static Future<bool> restoreActive() async {
    if (hasStoredM3u && m3u.isEmpty) return await loadM3u(m3uUrl, persist: false, allowCache: true);
    return true;
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
    if (mac.isEmpty) { lastErr = 'act: MAC leer'; return 'error'; }
    try {
      final uri = Uri.parse(kActivate).replace(queryParameters: {'mac': mac, 'key': deviceKey, 'brand': kBrandKey});
      final r = await http.get(uri).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) { lastErr = 'act HTTP ${r.statusCode}'; return 'error'; }
      final j = jsonDecode(r.body);
      if (j is! Map) { lastErr = 'act kein-json'; return 'error'; }
      if ('${j['host'] ?? ''}'.isNotEmpty) {
        final host = '${j['host']}', user = '${j['username'] ?? j['user'] ?? ''}', pass = '${j['password'] ?? j['pass'] ?? ''}';
        // M3U-FIRST (wie Android/Samsung-TV & IBO): den get.php-m3u_plus-Export laden.
        // Zuverlässig auch bei gesperrtem player_api (z. B. d67 liefert dort nur user_info).
        final m3uLink = '${Xtream.base(host)}/get.php?username=${Uri.encodeQueryComponent(user)}&password=${Uri.encodeQueryComponent(pass)}&type=m3u_plus&output=ts';
        if (await loadM3u(m3uLink, allowCache: true)) return 'ok';
        // Rückfall: doch als Xtream (falls M3U-Export gesperrt, player_api aber funktioniert).
        final a = Account(host, user, pass);
        if (await Xtream.userInfo(a) != null) { await save(a); return 'ok'; }
        lastErr = 'weder M3U noch Xtream nutzbar (host=$host) [$lastErr]';
        return 'error';
      }
      if (j['message'] == 'm3u_only' && '${j['raw_url'] ?? ''}'.isNotEmpty) {
        final okm = await loadM3u('${j['raw_url']}'); if (!okm) lastErr = 'm3u load fehl'; return okm ? 'ok' : 'error';
      }
      if (j['message'] == 'pending') return 'none';
      lastErr = 'act body=${r.body}';
    } catch (e) { lastErr = 'act ex: $e'; }
    return 'error'; // expired/blocked/unbekannt: Lizenz-Gate regelt das, Playlist NICHT anfassen
  }

  /// Holt die dem MAC/Key zugewiesene Playlist vom Hub und richtet die Sitzung ein.
  /// true = bereit (Xtream ODER M3U geladen).
  static Future<bool> pullActivation() async => (await syncFromActivation()) == 'ok'; // lastErr wird in syncFromActivation gesetzt

  /// Manuell in der App eingegebene Xtream-Playlist an velaplayer.com melden,
  /// damit sie dort (für Kunde/Reseller) sichtbar ist und der Server die Wahrheit bleibt.
  /// true = auf dem Server gespeichert.
  static Future<bool> pushXtreamToServer(Account a, {String name = ''}) async {
    if (mac.isEmpty) return false;
    try {
      final r = await http.post(Uri.parse(kAddPlaylist), body: {
        'mac': mac, 'key': deviceKey, 'brand': kBrandKey,
        'type': 'xtream', 'xt_server': a.host, 'xt_user': a.user, 'xt_pass': a.pass,
        if (name.isNotEmpty) 'name': name,
      }).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body);
      return j is Map && j['success'] == true;
    } catch (_) { return false; }
  }

  /// Manuell in der App eingegebene M3U-Link-Playlist an velaplayer.com melden.
  /// true = auf dem Server gespeichert.
  static String lastErr = ''; // DIAGNOSE: warum push/pull fehlschlug
  static Future<bool> pushM3uToServer(String url, {String name = ''}) async {
    if (mac.isEmpty) { lastErr = 'MAC leer'; return false; }
    try {
      final r = await http.post(Uri.parse(kAddPlaylist), body: {
        'mac': mac, 'key': deviceKey, 'brand': kBrandKey,
        'type': 'url', 'url': url,
        if (name.isNotEmpty) 'name': name,
      }).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) { lastErr = 'HTTP ${r.statusCode}'; return false; }
      final j = jsonDecode(r.body);
      if (j is Map && j['success'] == true) return true;
      lastErr = 'Antwort: ${r.body}';
      return false;
    } catch (e) { lastErr = 'Ausnahme: $e'; return false; }
  }

  /// Geraet beim Hub anmelden (MAC+Key+Marke). Idempotent: legt das Geraet an bzw.
  /// aktualisiert last_seen. So existiert die echte MAC serverseitig, bevor der
  /// Nutzer sie auf der Website eintraegt -> die Website kann Tippfehler ablehnen.
  static Future<void> registerDevice() async {
    if (mac.isEmpty) return;
    try {
      await http.post(Uri.parse(kRegister), body: {
        'mac': mac, 'key': deviceKey, 'brand': kBrandKey,
      }).timeout(const Duration(seconds: 12));
    } catch (_) {}
  }

  /// Lokale Cache-Dateien für eine M3U-URL (im Temp-Verzeichnis, per URL-Hash benannt).
  /// .cache = rohe M3U (spart Download), .parsed = schon geparste Liste (spart auch das Parsen
  /// von ~320.000 Einträgen -> JEDER weitere Start ist fast sofort, wie IBO).
  static const Duration _m3uCacheTtl = Duration(days: 3);
  static String? _cacheBase(String url) {
    try { return '${Directory.systemTemp.path}${Platform.pathSeparator}vela_m3u_${md5.convert(utf8.encode(url))}'; }
    catch (_) { return null; }
  }
  static File? _m3uCacheFile(String url) { final b = _cacheBase(url); return b == null ? null : File('$b.cache'); }
  static File? _m3uParsedFile(String url) { final b = _cacheBase(url); return b == null ? null : File('$b.parsed'); }

  /// Lokalen Cache (roh + geparst) einer M3U löschen -> erzwingt frischen Download.
  static Future<void> clearM3uCache(String url) async {
    for (final f in [_m3uCacheFile(url), _m3uParsedFile(url)]) {
      try { if (f != null && f.existsSync()) await f.delete(); } catch (_) {}
    }
  }

  /// Alte Playlist-Caches im Temp aufräumen (älter als TTL), damit sich nicht GB anstauen.
  /// Die aktuell aktive M3U wird NIE gelöscht. Läuft im Hintergrund beim Start.
  static Future<void> cleanupOldCaches() async {
    try {
      final dir = Directory(Directory.systemTemp.path);
      if (!dir.existsSync()) return;
      final keepBase = (mode == 'm3u' && m3uUrl.isNotEmpty) ? _cacheBase(m3uUrl) : null;
      final cutoff = DateTime.now().subtract(_m3uCacheTtl);
      for (final e in dir.listSync()) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.isNotEmpty ? e.uri.pathSegments.last : '';
        if (!name.startsWith('vela_m3u_')) continue;
        if (keepBase != null && e.path.startsWith(keepBase)) continue; // aktive behalten
        try { if (e.lastModifiedSync().isBefore(cutoff)) e.deleteSync(); } catch (_) {}
      }
    } catch (_) {}
  }

  /// Geparste Liste kompakt serialisieren (Tab-getrennt) -> beim nächsten Start nur split statt
  /// #EXTINF-Attribute neu zu zerlegen. Deutlich schneller als parseM3u.
  static String _serializeM3u(List<M3uChannel> list) {
    final sb = StringBuffer();
    for (final c in list) {
      sb.write(c.name.replaceAll('\t', ' ')); sb.write('\t');
      sb.write(c.logo); sb.write('\t');
      sb.write(c.group.replaceAll('\t', ' ')); sb.write('\t');
      sb.write(c.url); sb.write('\t');
      sb.write(c.kind); sb.write('\t');
      sb.write(c.ext); sb.write('\n');
    }
    return sb.toString();
  }
  static List<M3uChannel> _deserializeM3u(String text) {
    final out = <M3uChannel>[];
    for (final line in text.split('\n')) {
      if (line.isEmpty) continue;
      final p = line.split('\t');
      if (p.length < 6) continue;
      out.add(M3uChannel(p[0], p[1], p[2], p[3], kind: p[4], ext: p[5]));
    }
    return out;
  }
  static Future<void> _writeParsed(String url, List<M3uChannel> chans) async {
    try { final pf = _m3uParsedFile(url); if (pf != null) await pf.writeAsString(_serializeM3u(chans), flush: false); } catch (_) {}
  }

  static void _applyM3u(List<M3uChannel> chans, String url) {
    m3u = chans; m3uUrl = url; mode = 'm3u'; account = null;
  }

  /// Session-Cookie holen: erst player_api (Login) aufrufen, Set-Cookie zurückgeben.
  /// Nötig für Anbieter, die get.php nur mit gültiger Session ausliefern (403 sonst).
  static Future<String?> _primeCookie(String getUrl) async {
    try {
      final u = Uri.parse(getUrl);
      final user = u.queryParameters['username'], pass = u.queryParameters['password'];
      if (user == null || pass == null) return null;
      final api = u.replace(path: '/player_api.php', queryParameters: {'username': user, 'password': pass});
      final r = await http.get(api).timeout(const Duration(seconds: 15));
      final sc = r.headers['set-cookie'];
      if (sc == null || sc.isEmpty) return null;
      return sc.split(';').first.trim(); // nur name=value (z. B. PHPSESSID=…)
    } catch (_) { return null; }
  }

  static Future<void> _persistM3u(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('src_mode', 'm3u');
    await p.setString('m3u_url', url);
    await p.remove('xt_host'); await p.remove('xt_user'); await p.remove('xt_pass');
  }

  /// M3U-Playlist laden, parsen, als aktive Quelle setzen.
  /// allowCache=true: wenn eine frische lokale Kopie (<12 h) da ist, OHNE Netz laden
  /// (macht den 2. Start so schnell wie IBO). Sonst 89 MB neu ziehen + Cache schreiben.
  static Future<bool> loadM3u(String url, {bool persist = true, bool allowCache = false}) async {
    // 1) Frischer Cache? -> ohne Download laden.
    if (allowCache) {
      try {
        // a) Schon GEPARSTER Cache -> nur einlesen (schnellster Weg, wie IBO).
        final pf = _m3uParsedFile(url);
        if (pf != null && pf.existsSync() && DateTime.now().difference(pf.lastModifiedSync()) < _m3uCacheTtl) {
          final chans = _deserializeM3u(await pf.readAsString());
          if (chans.isNotEmpty) { _applyM3u(chans, url); if (persist) await _persistM3u(url); return true; }
        }
        // b) Rohe M3U im Cache -> parsen und geparsten Cache fürs nächste Mal schreiben.
        final f = _m3uCacheFile(url);
        if (f != null && f.existsSync() && DateTime.now().difference(f.lastModifiedSync()) < _m3uCacheTtl) {
          final chans = parseM3u(utf8.decode(await f.readAsBytes(), allowMalformed: true));
          if (chans.isNotEmpty) { _applyM3u(chans, url); await _writeParsed(url, chans); if (persist) await _persistM3u(url); return true; }
        }
      } catch (_) { /* Cache kaputt -> normal laden */ }
    }
    // 2) Aus dem Netz laden — mit Wiederholung, falls der Anbieter die Verbindung
    //    mitten im Download abwirft ("Connection closed", Timeout). Manche Server (d67)
    //    drosseln/kappen große Transfers; ein erneuter Versuch kommt oft durch.
    Object? dlErr;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        var r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 300)); // sehr große m3u_plus (100+ MB)
        // Session-Sperre (403/401 ohne Login): erst player_api (Login) -> Cookie -> get.php erneut (wie IBO).
        if (r.statusCode == 403 || r.statusCode == 401) {
          final cookie = await _primeCookie(url);
          if (cookie != null) { r = await http.get(Uri.parse(url), headers: {'cookie': cookie}).timeout(const Duration(seconds: 300)); }
        }
        if (r.statusCode != 200) { dlErr = 'HTTP ${r.statusCode}'; }
        else {
          // M3U ist UTF-8 -> Rohbytes explizit dekodieren (sonst kaputte Zeichen).
          final chans = parseM3u(utf8.decode(r.bodyBytes, allowMalformed: true));
          if (chans.isEmpty) { dlErr = 'leer: 0 Kanäle aus ${r.bodyBytes.length} Bytes'; }
          else {
            _applyM3u(chans, url);
            try { final f = _m3uCacheFile(url); if (f != null) await f.writeAsBytes(r.bodyBytes, flush: false); } catch (_) {} // rohe M3U cachen
            await _writeParsed(url, chans); // geparste Liste cachen -> nächster Start fast sofort
            if (persist) await _persistM3u(url);
            return true;
          }
        }
      } catch (e) { dlErr = e; }
      if (attempt < 3) await Future.delayed(Duration(seconds: 2 * attempt)); // kurze Pause, dann neuer Versuch
    }
    lastErr = 'm3u $dlErr (nach 3 Versuchen)';
    return false;
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
        // Typ aus dem URL-Pfad: .../series/... = Serie, .../movie/... = Film, sonst Live.
        final kind = line.contains('/series/') ? 'series' : (line.contains('/movie/') ? 'vod' : 'live');
        out.add(M3uChannel(name.isEmpty ? line : name, logo, group.isEmpty ? 'Sender' : group, line,
            kind: kind, ext: kind == 'live' ? '' : _extOf(line)));
        name = ''; logo = ''; group = '';
      }
    }
    return out;
  }

  /// Datei-Endung aus einer Stream-URL (mkv/mp4/…); leer wenn keine sinnvolle.
  static String _extOf(String url) {
    var q = url.indexOf('?'); final u = q < 0 ? url : url.substring(0, q);
    final slash = u.lastIndexOf('/');
    final dot = u.lastIndexOf('.');
    if (dot < 0 || dot < slash) return '';
    final e = u.substring(dot + 1).toLowerCase();
    if (e.isEmpty || e.length > 4) return '';
    for (var i = 0; i < e.length; i++) { final c = e.codeUnitAt(i); if (!((c >= 97 && c <= 122) || (c >= 48 && c <= 57))) return ''; }
    return e;
  }

  // Ohne Regex (wird pro Zeile 2× aufgerufen -> bei 320k Zeilen entscheidend fürs Tempo).
  static String _m3uAttr(String line, String key) {
    final k = '$key="';
    final i = line.indexOf(k);
    if (i < 0) return '';
    final start = i + k.length;
    final end = line.indexOf('"', start);
    return end < 0 ? '' : line.substring(start, end);
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

  /// Eine gespeicherte Playlist zur aktiven Quelle machen (Umschalten in der Playlist-Liste).
  static Future<bool> applyProfile(PlaylistProfile p) async {
    if (p.mode == 'm3u') return await loadM3u(p.url, allowCache: true); // nutzt Cache -> schnell
    await save(Account(p.host, p.user, p.pass));
    return true;
  }

  /// Eine Playlist NUR als aktive Quelle setzen, OHNE sie zu laden (schnell).
  /// Die Liste wird erst beim nächsten Öffnen (HomeGate.restoreActive) geladen.
  /// -> Löschen/Umschalten blockiert nicht auf großen M3U-Downloads.
  static Future<void> setProfileNoLoad(PlaylistProfile p) async {
    final pr = await SharedPreferences.getInstance();
    if (p.mode == 'm3u') {
      account = null; mode = 'm3u'; m3u = []; m3uUrl = p.url;
      await pr.setString('src_mode', 'm3u');
      await pr.setString('m3u_url', p.url);
      await pr.remove('xt_host'); await pr.remove('xt_user'); await pr.remove('xt_pass');
    } else {
      await save(Account(p.host, p.user, p.pass)); // Xtream: ohnehin ohne Laden
    }
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
  final int added; // Unix-Zeit „hinzugefügt" (für „Neueste …")
  Item(this.id, this.name, this.icon, {this.num = 0, this.ext = '', this.added = 0});
}

class Xtream {
  /// Serienname aus einem Episoden-Titel (alles vor „S01E02"). Für M3U-Serien-Gruppierung.
  static final RegExp _seRe = RegExp(r'[\s\-_.]*S(\d{1,3})\s*E(\d{1,4})', caseSensitive: false);
  static String _seriesName(String title) {
    final m = _seRe.firstMatch(title);
    return (m != null ? title.substring(0, m.start) : title).trim();
  }
  static List<int> _seNums(String title) {
    final m = _seRe.firstMatch(title);
    if (m == null) return const [1, 1];
    return [int.tryParse(m.group(1)!) ?? 1, int.tryParse(m.group(2)!) ?? 1];
  }

  static String base(String host) {
    var b = host.trim();
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(b)) b = 'http://$b';
    return b.replaceAll(RegExp(r'/+$'), '');
  }

  /// Xtream-API-URL bauen. Nicht-Web (Desktop/Handy) hat kein CORS -> DIREKT zum
  /// Anbieter (player_api.php). Das umgeht Provider, die die Hub-/Datacenter-IP
  /// blocken (z. B. d67 timeoutet vom Server, klappt aber von der Heim-IP).
  /// Nur der Web-Build (velatv) muss über den Hub-Proxy (CORS).
  static Uri _apiUri(String host, String user, String pass, String? action, [Map<String, String>? extra]) {
    // Standard-Xtream-Aktionen heißen get_* (get_live_categories, get_live_streams, get_series …).
    // Ohne das Präfix liefern strenge Panels (z. B. ip.sltv.be) nur das user_info-Objekt zurück
    // -> „kein-array". Darum hier immer get_ voranstellen (außer user_info).
    final act = (action != null && action != 'user_info' && !action.startsWith('get_')) ? 'get_$action' : action;
    if (!kOnWeb) {
      final q = <String, String>{'username': user, 'password': pass};
      if (act != null && act != 'user_info') q['action'] = act; // user_info = player_api ohne action
      if (extra != null) q.addAll(extra);
      return Uri.parse('${base(host)}/player_api.php').replace(queryParameters: q);
    }
    final q = <String, String>{'host': host, 'username': user, 'password': pass};
    if (act != null) q['action'] = act;
    if (extra != null) q.addAll(extra);
    return Uri.parse(kProxy).replace(queryParameters: q);
  }

  static String diag = ''; // letzte API-Diagnose (für sichtbare Fehlermeldungen)

  static Future<dynamic> _get(String action, [Map<String, String>? extra]) async {
    final a = Session.account!;
    final uri = _apiUri(a.host, a.user, a.pass, action, extra);
    Object? lastErr;
    dynamic lastJson; bool gotJson = false;
    // Manche Anbieter (z. B. d67, max 1 Verbindung) antworten sporadisch leer/abweisend,
    // wenn parallele Abfragen laufen -> bis zu 3 Versuche mit kurzer Pause.
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final r = await http.get(uri).timeout(const Duration(seconds: 25));
        if (r.statusCode != 200) { lastErr = 'HTTP ${r.statusCode}'; }
        else {
          final body = r.body.trim();
          if (body.isEmpty) { lastErr = 'leere Antwort'; }
          else {
            final j = jsonDecode(body);
            gotJson = true; lastJson = j;
            if (j is! List) { diag = '$action: kein-array: ${body.substring(0, body.length < 180 ? body.length : 180)}'; return j; } // Map/Detail
            if (j.isNotEmpty) { diag = '$action: ok(${j.length})'; return j; }
            lastErr = 'leeres Array';                                   // evtl. transient -> nochmal
          }
        }
      } catch (e) { lastErr = e; }
      if (attempt < 3) await Future.delayed(Duration(milliseconds: 500 * attempt));
    }
    if (gotJson) { diag = '$action: leer nach 3 Versuchen'; return lastJson; } // ehrlich leer
    diag = '$action: $lastErr';
    throw Exception('$lastErr');
  }

  /// Verbindung testen + Konto-Infos holen.
  static Future<Map<String, dynamic>?> userInfo(Account a) async {
    final uri = _apiUri(a.host, a.user, a.pass, 'user_info');
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) { diag = 'user_info HTTP ${r.statusCode}'; return null; }
      final j = jsonDecode(r.body);
      final ui = (j is Map) ? j['user_info'] : null;
      if (ui is Map) {
        if ('${ui['auth']}' == '0') { diag = 'auth=0 (Zugangsdaten abgelehnt/abgelaufen)'; return null; } // ungültige Creds
        return Map<String, dynamic>.from(ui);
      }
      diag = 'user_info fehlt in Antwort';
    } catch (e) { diag = 'user_info ex: $e'; }
    return null;
  }

  static Future<List<Category>> categoriesRaw(String type) async {
    if (Session.mode == 'm3u') {
      // Kategorien = Gruppen (group-title) der Einträge dieses Typs (live/vod/series).
      final seen = <String>{}; final out = <Category>[];
      for (final c in Session.m3u) { if (c.kind == type && seen.add(c.group)) out.add(Category(c.group, c.group)); }
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

  /// Anzahl Einträge je Kategorie (für „(S|DE) … (42)" wie IBO). Schlüssel = category_id (Xtream)
  /// bzw. group-title (M3U) — passt zu Category.id. Ein Aufruf lädt alle Streams des Typs.
  static Future<Map<String, int>> categoryCounts(String type) async {
    final m = <String, int>{};
    if (Session.mode == 'm3u') {
      for (final c in Session.m3u) { if (c.kind == type) m[c.group] = (m[c.group] ?? 0) + 1; }
      return m;
    }
    final action = type == 'live' ? 'live_streams' : (type == 'series' ? 'series' : 'vod_streams');
    final j = await _get(action);
    if (j is List) {
      for (final e in j) { final c = '${e['category_id'] ?? ''}'; if (c.isNotEmpty) m[c] = (m[c] ?? 0) + 1; }
    }
    return m;
  }

  static Future<List<Item>> liveStreams(String catId) async {
    if (Session.mode == 'm3u') {
      return Session.m3u.where((c) => c.kind == 'live' && c.group == catId).map((c) => Item(c.url, c.name, c.logo)).toList();
    }
    final j = await _get('live_streams', {'category_id': catId});
    if (j is! List) return [];
    return j
        .map((e) => Item(e['stream_id'].toString(), (e['name'] ?? '').toString(),
            (e['stream_icon'] ?? '').toString(), num: int.tryParse('${e['num']}') ?? 0))
        .toList();
  }

  static Future<List<Item>> vodStreams(String catId) async {
    if (Session.mode == 'm3u') {
      return Session.m3u.where((c) => c.kind == 'vod' && c.group == catId)
          .map((c) => Item(c.url, c.name, c.logo, ext: c.ext)).toList();
    }
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
    if (Session.mode == 'm3u') {
      return Session.m3u.where((c) => c.kind == 'vod').map((c) => Item(c.url, c.name, c.logo, ext: c.ext)).toList();
    }
    final j = await _get('vod_streams');
    if (j is! List) return [];
    return j
        .map((e) => Item(e['stream_id'].toString(), (e['name'] ?? '').toString(),
            (e['stream_icon'] ?? e['cover'] ?? '').toString(),
            ext: (e['container_extension'] ?? 'mp4').toString(),
            added: int.tryParse('${e['added'] ?? ''}') ?? 0))
        .toList();
  }

  static Future<List<Item>> allSeries() async {
    if (Session.mode == 'm3u') {
      final seen = <String>{}; final out = <Item>[];
      for (final c in Session.m3u) { if (c.kind == 'series') { final sn = _seriesName(c.name); if (seen.add(sn)) out.add(Item(sn, sn, c.logo)); } }
      return out;
    }
    final j = await _get('series');
    if (j is! List) return [];
    return j
        .map((e) => Item(e['series_id'].toString(), (e['name'] ?? '').toString(), (e['cover'] ?? '').toString(),
            added: int.tryParse('${e['last_modified'] ?? ''}') ?? 0))
        .toList();
  }

  /// „Zuletzt hinzugefügt" für die Lobby — SCHLANK über den Hub (Server sortiert
  /// + cacht; App bekommt nur die neuesten N). {'movies': [...], 'series': [...]}.
  static Future<Map<String, List<Item>>> homeLatest({int limit = 6}) async {
    const empty = {'movies': <Item>[], 'series': <Item>[]};
    if (Session.mode != 'xtream' || Session.account == null || Session.mac.isEmpty) return empty;
    try {
      final a = Session.account!;
      final uri = Uri.parse(kHomeLatest).replace(queryParameters: {
        'mac': Session.mac, 'key': Session.deviceKey, 'brand': kBrandKey, 'limit': '$limit',
        // aktuelle Playlist direkt mitschicken -> Lobby passt IMMER zur aktiven (nicht zur am Hub registrierten)
        'host': a.host, 'username': a.user, 'password': a.pass,
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) return empty;
      final j = jsonDecode(r.body);
      if (j is! Map) return empty;
      List<Item> parse(dynamic list) => (list is List)
          ? list.map((e) => Item('${e['id']}', '${e['name']}', '${e['icon'] ?? ''}', ext: '${e['ext'] ?? ''}')).toList()
          : <Item>[];
      return {'movies': parse(j['movies']), 'series': parse(j['series'])};
    } catch (_) { return empty; }
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
    if (Session.mode == 'm3u') {
      final seen = <String>{}; final out = <Item>[];
      for (final c in Session.m3u) {
        if (c.kind != 'series' || c.group != catId) continue;
        final sn = _seriesName(c.name);
        if (seen.add(sn)) out.add(Item(sn, sn, c.logo)); // id = Serienname (Schlüssel für seriesInfo)
      }
      return out;
    }
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
    if (Session.mode == 'm3u') return streamId; // bei M3U ist die ID bereits die direkte URL
    final a = Session.account!;
    return '${base(a.host)}/movie/${a.user}/${a.pass}/$streamId.${ext.isEmpty ? 'mp4' : ext}';
  }

  static String seriesEpUrl(String epId, String ext) {
    if (Session.mode == 'm3u') return epId; // bei M3U ist die Episoden-ID bereits die direkte URL
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
    if (Session.mode == 'm3u') return {}; // M3U hat keine TMDB-Detailinfos -> direkt abspielen
    final j = await _get('vod_info', {'vod_id': vodId});
    return (j is Map) ? Map<String, dynamic>.from(j) : {};
  }

  /// Serien-Details (info + episodes je Staffel).
  static Future<SeriesDetail> seriesInfo(String seriesId) async {
    if (Session.mode == 'm3u') {
      // Episoden dieser Serie aus der M3U sammeln, nach Staffel gruppieren (id = direkte URL).
      final seasons = <String, List<Episode>>{};
      for (final c in Session.m3u) {
        if (c.kind != 'series' || _seriesName(c.name) != seriesId) continue;
        final se = _seNums(c.name);
        seasons.putIfAbsent('${se[0]}', () => []).add(Episode(c.url, c.name, c.ext, se[1]));
      }
      seasons.forEach((k, v) => v.sort((a, b) => a.num.compareTo(b.num)));
      return SeriesDetail({'name': seriesId}, seasons);
    }
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
  static double volume = 60; // zuletzt gewählte Lautstärke 0..100 (bleibt erhalten, auch über Neustart)

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
    langChosen = p.getBool('lang_chosen') ?? false;
    downloadDir = p.getString('download_dir') ?? '';
    volume = (p.getDouble('volume') ?? 60).clamp(0.0, 100.0);
  }

  static Future<void> setVolume(double v) async { volume = v.clamp(0.0, 100.0); await _p((p) => p.setDouble('volume', volume)); }

  static String downloadDir = ''; // leer = Standard (D:\VelaDownloads). Vom Nutzer wählbar.
  static Future<void> setDownloadDir(String v) async { downloadDir = v; await _p((p) => p.setString('download_dir', v)); }

  static bool langChosen = false; // beim ersten Start Sprach-Screen zeigen, danach nie wieder
  static Future<void> markLangChosen() async { langChosen = true; await _p((p) => p.setBool('lang_chosen', true)); }

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
  static const bool freeForTesting = true; // TEST-Freischaltung: Paywall/Testphase aus (für Release wieder false)
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
          queryParameters: {'mac': Session.mac, 'key': Session.deviceKey, 'brand': kBrandKey});
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
    if (freeForTesting || paid) return trialDays;
    if (serverKnown && serverDaysLeft != null) return serverDaysLeft!.clamp(0, trialDays);
    if (trialStart == null) return trialDays;
    final used = DateTime.now().difference(trialStart!).inDays;
    return (trialDays - used).clamp(0, trialDays);
  }

  static bool get trialExpired {
    if (freeForTesting) return false; // Test-Freischaltung: nie Paywall
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
  final List<dynamic>? queue; // Episoden-Warteschlange [{'t':titel,'u':url}] -> Weiter/Zurueck aus „Weiterschauen"
  ContinueItem(this.url, this.title, this.poster, this.pos, this.dur, [this.queue]);
  double get progress => dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
}

class ContinueStore {
  static const _k = 'continue_v1';
  static String scope = ''; // aktive Playlist-ID -> „Weiterschauen" pro Playlist getrennt
  static String _sk() => scope.isEmpty ? _k : '${_k}_$scope';
  static List<Map<String, dynamic>> _items = [];

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    var s = p.getString(_sk());
    if (s == null && scope.isNotEmpty) {
      // einmalige Migration: alten GLOBALEN Verlauf der aktiven Playlist zuschlagen
      final g = p.getString(_k);
      if (g != null) { s = g; await p.setString(_sk(), g); await p.remove(_k); }
    }
    _items = [];
    if (s != null) {
      try { _items = (jsonDecode(s) as List).map((e) => Map<String, dynamic>.from(e)).toList(); } catch (_) {}
    }
  }

  static List<ContinueItem> items() => _items
      .map((e) => ContinueItem('${e['url']}', '${e['title']}', '${e['poster'] ?? ''}', e['pos'] ?? 0, e['dur'] ?? 0, e['queue'] as List<dynamic>?))
      .toList();

  /// Fortschritt (0..1) einer angefangenen Folge/eines Films, sonst null.
  static double? progressOf(String url) {
    for (final e in _items) {
      if (e['url'] == url) {
        final pos = (e['pos'] ?? 0) as int, dur = (e['dur'] ?? 0) as int;
        return dur > 0 ? (pos / dur).clamp(0.02, 1.0) : null;
      }
    }
    return null;
  }

  static Future<void> record({required String url, required String title, required String poster, required int pos, required int dur, List<Map<String, String>>? queue}) async {
    _items.removeWhere((e) => e['url'] == url);
    // Nur merken, wenn mittendrin (nicht ganz am Anfang/Ende).
    if (pos > 30 && (dur == 0 || pos < dur - 90)) {
      final m = {'url': url, 'title': title, 'poster': poster, 'pos': pos, 'dur': dur};
      if (queue != null && queue.isNotEmpty) m['queue'] = queue; // Staffel-Warteschlange fuer Weiter/Zurueck
      _items.insert(0, m);
      if (_items.length > 15) _items = _items.sublist(0, 15);
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_sk(), jsonEncode(_items));
  }

  static Future<void> remove(String url) async {
    _items.removeWhere((e) => e['url'] == url);
    final p = await SharedPreferences.getInstance();
    await p.setString(_sk(), jsonEncode(_items));
  }
}

/// Fertig gesehene Folgen/Filme (URL-Set) — fürs „✓ Gesehen" in der Folgen-Liste.
/// Pro Playlist getrennt (scope = Playlist-ID), persistiert.
class WatchedStore {
  static const _k = 'watched_v1';
  static String scope = '';
  static String _sk() => scope.isEmpty ? _k : '${_k}_$scope';
  static Set<String> _set = {};

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _set = (p.getStringList(_sk()) ?? []).toSet();
  }
  static bool isWatched(String url) => _set.contains(url);
  static Future<void> mark(String url) async {
    if (_set.add(url)) { final p = await SharedPreferences.getInstance(); await p.setStringList(_sk(), _set.toList()); }
  }
  static Future<void> unmark(String url) async {
    if (_set.remove(url)) { final p = await SharedPreferences.getInstance(); await p.setStringList(_sk(), _set.toList()); }
  }
}

/// Eine gespeicherte Playlist (Profil) für die Mehr-Playlist-Verwaltung (wie IBO „Change Playlist").
class PlaylistProfile {
  final String id, name, mode, url, host, user, pass;
  PlaylistProfile({required this.id, required this.name, required this.mode,
      this.url = '', this.host = '', this.user = '', this.pass = ''});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'mode': mode, 'url': url, 'host': host, 'user': user, 'pass': pass};
  static PlaylistProfile fromJson(Map e) => PlaylistProfile(
        id: '${e['id']}', name: '${e['name']}', mode: '${e['mode']}',
        url: '${e['url'] ?? ''}', host: '${e['host'] ?? ''}', user: '${e['user'] ?? ''}', pass: '${e['pass'] ?? ''}');
  String get identity => mode == 'm3u' ? 'm|$url' : 'x|$host|$user';
  String get subtitle => mode == 'm3u' ? 'M3U-Playlist' : 'Xtream · $user';
}

/// Speicher für mehrere Playlists + welche aktiv ist. Persistiert.
class PlaylistStore {
  static const _k = 'playlists_v1';
  static const _kActive = 'active_playlist';
  static List<PlaylistProfile> _items = [];
  static String activeId = '';

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    if (s != null) { try { _items = (jsonDecode(s) as List).map((e) => PlaylistProfile.fromJson(Map<String, dynamic>.from(e))).toList(); } catch (_) {} }
    activeId = p.getString(_kActive) ?? '';
  }

  static List<PlaylistProfile> items() => List.unmodifiable(_items);
  static PlaylistProfile? active() { for (final p in _items) { if (p.id == activeId) return p; } return null; }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(_items.map((e) => e.toJson()).toList()));
    await p.setString(_kActive, activeId);
  }

  /// Playlist speichern (vorhandene gleicher Identität wird wiederverwendet) und aktiv setzen.
  static Future<PlaylistProfile> upsert({required String name, required String mode, String url = '', String host = '', String user = '', String pass = ''}) async {
    final prof = PlaylistProfile(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name, mode: mode, url: url, host: host, user: user, pass: pass);
    final idx = _items.indexWhere((e) => e.identity == prof.identity);
    if (idx >= 0) { activeId = _items[idx].id; } else { _items.insert(0, prof); activeId = prof.id; }
    await _persist();
    return active() ?? prof;
  }

  static Future<void> setActive(String id) async { activeId = id; await _persist(); }
  static Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    if (activeId == id) activeId = _items.isNotEmpty ? _items.first.id : '';
    await _persist();
  }
}

/// Lokale Favoriten (Live-Sender, Filme, Serien) — pro `kind` getrennt, persistiert.
/// kind: 'live' | 'vod' | 'series'.
class FavStore {
  static const _k = 'fav_v2';
  static String scope = ''; // aktive Playlist-ID -> Favoriten pro Playlist getrennt
  static String _sk() => scope.isEmpty ? _k : '${_k}_$scope';
  static List<Map<String, dynamic>> _cache = [];

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    var s = p.getString(_sk());
    if (s == null && scope.isNotEmpty) {
      // einmalige Migration: alte GLOBALE Favoriten der aktiven Playlist zuschlagen
      final g = p.getString(_k);
      if (g != null) { s = g; await p.setString(_sk(), g); await p.remove(_k); }
    }
    _cache = [];
    if (s != null) {
      try { _cache = (jsonDecode(s) as List).map((e) => Map<String, dynamic>.from(e)).toList(); } catch (_) {}
      return;
    }
    // Migration: alte reine Live-Favoriten (Key 'fav_live') übernehmen.
    final old = p.getString('fav_live');
    if (old != null) {
      try {
        _cache = (jsonDecode(old) as List).map((e) {
          final m = Map<String, dynamic>.from(e);
          m['kind'] ??= 'live';
          return m;
        }).toList();
        await _save();
      } catch (_) {}
    }
  }

  static String _kindOf(Map e) => (e['kind'] ?? 'live').toString();

  static bool isFav(String id, String kind) => _cache.any((e) => e['id'] == id && _kindOf(e) == kind);

  static List<Item> items(String kind) => _cache
      .where((e) => _kindOf(e) == kind)
      .map((e) => Item('${e['id']}', '${e['name']}', '${e['icon'] ?? ''}', num: e['num'] ?? 0))
      .toList();

  static int count() => _cache.length;

  static Future<void> toggle(Item it, String kind) async {
    if (isFav(it.id, kind)) {
      _cache.removeWhere((e) => e['id'] == it.id && _kindOf(e) == kind);
    } else {
      _cache.add({'id': it.id, 'name': it.name, 'icon': it.icon, 'num': it.num, 'kind': kind});
    }
    await _save();
  }

  static Future<void> clearAll() async {
    _cache = [];
    await _save();
  }

  static Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_sk(), jsonEncode(_cache));
  }
}

class SeriesDetail {
  final Map<String, dynamic> info;
  final Map<String, List<Episode>> seasons;
  SeriesDetail(this.info, this.seasons);
}
