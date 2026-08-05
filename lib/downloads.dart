import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Offline-Download eines Films/einer Folge (Desktop). Lädt die direkte Anbieter-URL
/// als Datei nach D:\VelaDownloads und spielt danach lokal (ohne Netz).
class Download {
  final String key, title, url, ext, poster;
  String path;    // lokale Datei (wenn fertig)
  String status;  // queued | downloading | done | error | canceled
  int received, total;
  Download({required this.key, required this.title, required this.url, required this.ext,
      this.poster = '', this.path = '', this.status = 'queued', this.received = 0, this.total = 0});
  double get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
  Map<String, dynamic> toJson() => {'key': key, 'title': title, 'url': url, 'ext': ext, 'poster': poster, 'path': path, 'status': status, 'total': total, 'received': received};
  static Download fromJson(Map j) => Download(
        key: '${j['key']}', title: '${j['title']}', url: '${j['url']}', ext: '${j['ext']}',
        poster: '${j['poster'] ?? ''}', path: '${j['path'] ?? ''}', status: '${j['status'] ?? 'queued'}',
        total: j['total'] ?? 0, received: j['received'] ?? 0);
}

class Downloads {
  static const _k = 'downloads_v1';
  static final List<Download> _items = [];
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0); // UI-Refresh
  static bool _busy = false;
  static http.Client? _client;

  static List<Download> all() => List.unmodifiable(_items.reversed); // neueste zuerst
  static Download? get(String key) { for (final d in _items) { if (d.key == key) return d; } return null; }
  static bool has(String key) => get(key) != null;
  /// Lokaler Pfad, wenn fertig heruntergeladen und Datei vorhanden – sonst null.
  static String? localPath(String key) {
    final d = get(key);
    if (d != null && d.status == 'done' && d.path.isNotEmpty && File(d.path).existsSync()) return d.path;
    return null;
  }

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    if (s != null) {
      try {
        _items.clear();
        for (final e in (jsonDecode(s) as List)) { _items.add(Download.fromJson(e)); }
        // durch App-Schließen abgebrochene Downloads wieder einreihen
        for (final d in _items) { if (d.status == 'downloading') { d.status = 'queued'; d.received = 0; } }
      } catch (_) {}
    }
    _kick();
  }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  static void _notify() => notifier.value++;

  static Directory dir() {
    if (Platform.isWindows) return Directory('D:\\VelaDownloads'); // viel Platz auf D:
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return Directory('$home/VelaDownloads');
  }

  static String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9 _.-]'), '_').trim();

  /// Download einreihen (macht nichts, wenn schon vorhanden).
  static Future<void> add({required String key, required String title, required String url, required String ext, String poster = ''}) async {
    if (has(key)) return;
    _items.add(Download(key: key, title: title, url: url, ext: ext.isEmpty ? 'mp4' : ext, poster: poster));
    await _persist(); _notify(); _kick();
  }

  /// Download abbrechen + Datei/Eintrag entfernen.
  static Future<void> remove(String key) async {
    final d = get(key);
    if (d == null) return;
    if (d.status == 'downloading') { d.status = 'canceled'; try { _client?.close(); } catch (_) {} }
    if (d.path.isNotEmpty) { try { final f = File(d.path); if (f.existsSync()) f.deleteSync(); } catch (_) {} }
    _items.remove(d);
    await _persist(); _notify();
  }

  static void _kick() { if (!_busy) _process(); }

  static Future<void> _process() async {
    _busy = true;
    while (true) {
      Download? next;
      for (final d in _items) { if (d.status == 'queued') { next = d; break; } }
      if (next == null) break;
      await _run(next);
    }
    _busy = false;
  }

  static Future<void> _run(Download d) async {
    d.status = 'downloading'; d.received = 0; _notify();
    try {
      final folder = dir();
      if (!folder.existsSync()) folder.createSync(recursive: true);
      final file = File('${folder.path}${Platform.pathSeparator}${d.key}_${_safe(d.title)}.${d.ext}');
      final req = http.Request('GET', Uri.parse(d.url))..headers['User-Agent'] = 'IBOPlayer';
      _client = http.Client();
      final resp = await _client!.send(req);
      d.total = resp.contentLength ?? 0;
      final sink = file.openWrite();
      int lastNotify = 0;
      await for (final chunk in resp.stream) {
        if (d.status == 'canceled') break;
        sink.add(chunk);
        d.received += chunk.length;
        if (d.received - lastNotify > 3 * 1024 * 1024) { lastNotify = d.received; _notify(); await _persist(); }
      }
      await sink.flush();
      await sink.close();
      if (d.status == 'canceled') { try { file.deleteSync(); } catch (_) {} }
      else { d.path = file.path; d.status = 'done'; }
    } catch (_) {
      if (d.status != 'canceled') d.status = 'error';
    } finally {
      try { _client?.close(); } catch (_) {}
      _client = null;
      await _persist(); _notify();
    }
  }
}
