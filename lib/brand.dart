import 'package:flutter/material.dart';

/// Aktive Marke — zur BUILD-Zeit gesetzt:
///   flutter build ipa --dart-define=BRAND=nina
/// Ohne Angabe = vela. EINE Codebasis, pro Marke umgeskinnt + neu gebaut
/// (Player-/Xtream-/Sync-Logik bleibt für alle Marken identisch).
const String kBrand = String.fromEnvironment('BRAND', defaultValue: 'vela');
const bool kIsNina = kBrand == 'nina';

/// Marken-Key für die Hub-API (`?brand=`) und der Anzeigename in der App.
const String kBrandKey = kIsNina ? 'nina' : 'vela';
const String kBrandName = kIsNina ? 'Nina' : 'Vela';

/// Portal, auf dem Nutzer ihre Playlist eintragen (pro Marke eigene Domain).
const String kPortal = kIsNina ? 'ninaplayer.com' : 'velaplayer.com';

// ---- Farbpalette — Vela: Blau/Navy · Nina: Grün/Teal ----
// const-Bedingung (kIsNina ist compile-time-const) -> alle Farben bleiben const.
const Color kBlue   = kIsNina ? Color(0xFF5FC9A6) : Color(0xFF6FB1F2); // Akzent
const Color kBlue2  = kIsNina ? Color(0xFF3E9E86) : Color(0xFF4685C4); // Akzent dunkel
const Color kBg     = kIsNina ? Color(0xFF0A1612) : Color(0xFF0C1524);
const Color kBg2    = kIsNina ? Color(0xFF122820) : Color(0xFF17283F);
const Color kPanel  = kIsNina ? Color(0xFF10221B) : Color(0xFF152134);
const Color kPanel2 = kIsNina ? Color(0xFF172E25) : Color(0xFF1D2B42);
const Color kLine   = kIsNina ? Color(0xFF294036) : Color(0xFF2B3E59);
const Color kText   = kIsNina ? Color(0xFFEAF6F0) : Color(0xFFEAF1FB);
const Color kMuted  = kIsNina ? Color(0xFF8CB3A6) : Color(0xFF93A4BE);
const Color kOk     = kIsNina ? Color(0xFF43E0A0) : Color(0xFF3FDA7C);

/// Akzentfarben der Home-Kacheln (Live/Filme/Serien/Replay) je Marke.
const List<Color> kTileAccents = kIsNina
    ? [Color(0xFF5FC9A6), Color(0xFF6FD9B0), Color(0xFF4FBFA0), Color(0xFFE0B366)]
    : [Color(0xFF6FB1F2), Color(0xFF8FA6F0), Color(0xFF6FD0C8), Color(0xFFE0B366)];
