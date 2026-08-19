# Vela – iOS-App aufs iPhone (ohne Mac, via Codemagic)

Zwei Wege. **Empfohlen: TestFlight** – die App kommt über die Apple-„TestFlight"-App
aufs iPhone, ganz ohne Kabel/PC. Braucht die (bezahlte) Apple-Developer-Mitgliedschaft.

---

## Weg 1 – TestFlight (empfohlen)

### Einmalig einrichten
1. **GitHub**: Projekt liegt schon im Repo `mtplyr/mtplyr` (Branch `master`).
2. **Codemagic** ([codemagic.io](https://codemagic.io)) mit GitHub verbinden, App = dieses Repo.
3. **Apple API-Key**: Apple Developer → *Users and Access* → *Integrations* →
   *App Store Connect API* → Key erstellen (Rolle **App Manager**).
   In Codemagic unter *Teams → Integrations → App Store Connect* hinterlegen,
   Integrations-Name **`vela_asc`** (genau so heißt er in `codemagic.yaml`).
4. **App anlegen** in App Store Connect: *Apps → + → Neue App*, Plattform iOS,
   Bundle-ID **`com.vela.velaplayer`**, Name **Vela**, SKU frei (z. B. `vela1`).

### Bauen & installieren
- In Codemagic den Workflow **„Vela iOS (TestFlight)"** starten
  (oder einfach auf `master` pushen – der Workflow läuft automatisch).
- Nach ~15 Min ist der Build in **App Store Connect → TestFlight**
  (kurz „Processing", dann bereit).
- Auf dem iPhone die **TestFlight**-App aus dem App Store laden, mit der Apple-ID
  anmelden → **Vela** erscheint zum Testen.

> Die Export-Compliance-Frage ist über `ITSAppUsesNonExemptEncryption=false`
> (Info.plist) schon beantwortet – Vela nutzt nur normales HTTPS/TLS.

---

## Weg 2 – Sideload (Fallback, ohne fertige Apple-Freischaltung)

- Workflow **„Vela iOS (unsigniert, fuer Sideloadly)"** oder **„Vela iOS (Ad Hoc)"**
  in Codemagic manuell starten → unter *Artifacts* fällt eine `*.ipa` raus (auch per Mail).
- Mit **Sideloadly** (Windows) / **3uTools** aufs per USB angesteckte iPhone installieren.
  Beim ersten Start am iPhone unter *Einstellungen → Allgemein → VPN & Geräteverwaltung*
  das Entwickler-Profil vertrauen.

---

## Hinweise
- Bundle-ID: **com.vela.velaplayer** · Anzeigename: **Vela** · fest im **Querformat**.
- Build-Nummer zählt bei TestFlight automatisch hoch (`--build-number=$BUILD_NUMBER`).
- Wiedergabe nutzt den media_kit-Player (libmpv) – spielt HLS/TS/MP4/MKV/4K.
- Nur **Vela** (kein Nina) – der Nina-iOS-Workflow bleibt manuell/separat.
