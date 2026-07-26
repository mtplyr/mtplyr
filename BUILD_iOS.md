# Vela – iOS-App bauen (ohne Mac, via Codemagic)

Kurzanleitung, um aus diesem Projekt eine **signierte .ipa** fuer dein iPhone zu bekommen.

## Einmalig einrichten
1. **GitHub**: dieses Projekt in ein Repo pushen (privat reicht).
2. **Codemagic** ([codemagic.io](https://codemagic.io)) mit GitHub verbinden, App = dieses Repo.
3. **Apple API-Key** erzeugen: Apple Developer → *Users and Access* → *Integrations* →
   *App Store Connect API* → Key erstellen (Rolle „App Manager" oder „Admin").
   In Codemagic unter *Teams → Integrations → App Store Connect* hinterlegen,
   Integrations-Namen **`vela_asc`** vergeben (so heisst er in `codemagic.yaml`).
4. **iPhone-UDID** registrieren: Apple Developer → *Devices* → **+**, UDID
   `00008150-0016428234B9401C` (oder Codemagic legt das Geraet beim Ad-Hoc-Build an).

## Bauen
- In Codemagic den Workflow **„Vela iOS (Ad Hoc)"** starten.
- Nach ~10–15 Min faellt unter **Artifacts** die `*.ipa` raus (kommt auch per Mail).

## Aufs iPhone
- **Sideloadly** (Windows) oder **3uTools** oeffnen, iPhone per USB anstecken,
  die `.ipa` installieren. Beim ersten Start am iPhone unter
  *Einstellungen → Allgemein → VPN & Geraeteverwaltung* das Entwickler-Profil vertrauen.

## Hinweise
- Bundle-ID: **com.vela.velaplayer**
- Die App laeuft fest im **Querformat** (wie IBO).
- Wiedergabe nutzt den media_kit-Player (libmpv) – spielt HLS/TS/MP4/MKV/4K.
