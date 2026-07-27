import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Proxy auf dem Hub (umgeht CORS, holt Provider-Daten server-zu-server).
const String kProxy = 'https://hub.mtplyr.com/api/xt.php';

class Account {
  final String host, user, pass;
  Account(this.host, this.user, this.pass);
}

/// Aktuelle Sitzung (Zugangsdaten), persistiert.
class Session {
  static Account? account;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final h = p.getString('xt_host');
    final u = p.getString('xt_user');
    final pw = p.getString('xt_pass');
    if (h != null && u != null && pw != null) account = Account(h, u, pw);
  }

  static Future<void> save(Account a) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('xt_host', a.host);
    await p.setString('xt_user', a.user);
    await p.setString('xt_pass', a.pass);
    account = a;
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('xt_host');
    await p.remove('xt_user');
    await p.remove('xt_pass');
    account = null;
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
    final j = await _get('live_streams', {'category_id': catId});
    if (j is! List) return [];
    return j
        .map((e) => Item(e['stream_id'].toString(), (e['name'] ?? '').toString(),
            (e['stream_icon'] ?? '').toString(), num: int.tryParse('${e['num']}') ?? 0))
        .toList();
  }

  static Future<List<Item>> vodStreams(String catId) async {
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
    final j = await _get('vod_streams');
    if (j is! List) return [];
    return j
        .map((e) => Item(e['stream_id'].toString(), (e['name'] ?? '').toString(),
            (e['stream_icon'] ?? e['cover'] ?? '').toString(),
            ext: (e['container_extension'] ?? 'mp4').toString()))
        .toList();
  }

  static Future<List<Item>> allSeries() async {
    final j = await _get('series');
    if (j is! List) return [];
    return j
        .map((e) => Item(e['series_id'].toString(), (e['name'] ?? '').toString(), (e['cover'] ?? '').toString()))
        .toList();
  }

  static Future<List<Item>> seriesList(String catId) async {
    final j = await _get('series', {'category_id': catId});
    if (j is! List) return [];
    return j
        .map((e) => Item(e['series_id'].toString(), (e['name'] ?? '').toString(),
            (e['cover'] ?? '').toString()))
        .toList();
  }

  /// Stream-URLs fuer den Player (nativer Build).
  static String liveUrl(String streamId) {
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
                    (e['title'] ?? 'Folge ${e['episode_num'] ?? ''}').toString(),
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

  static const _adult = ['XXX', 'ADULT', '+18', '18+', 'EROTIC', 'EROTIK', 'PORN', 'PORNO', 'FSK18', 'NIGHT CLUB'];

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    liveExt = p.getString('live_ext') ?? 'ts';
    hideAdult = p.getBool('hide_adult') ?? false;
    hidden = (p.getStringList('hidden_cats') ?? []).toSet();
    pinHash = p.getString('pin_hash');
  }

  static Future<void> _p(Function(SharedPreferences) f) async => f(await SharedPreferences.getInstance());

  static Future<void> setLiveExt(String v) async { liveExt = v; await _p((p) => p.setString('live_ext', v)); }
  static Future<void> setHideAdult(bool v) async { hideAdult = v; await _p((p) => p.setBool('hide_adult', v)); }
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
