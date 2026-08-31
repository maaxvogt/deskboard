# PROGRESS — Deskboard

**Quelle der Wahrheit für den Projektstand.** Nach jedem Schritt pflegen → committen → pushen.

---

## Aktueller Stand (31.8.2026)

Erste Session: App steht komplett als lokaler Debug-Build, alle 8 Widgets implementiert,
Build grün. Repo `maaxvogt/deskboard` (privat).

**Offen / Blocker:**

1. **inTouch-Backend nicht deployt.** Wrangler ist global mit `max.vogt@quietoffice.de`
   (Poddie) eingeloggt; inTouch + D1 `noolp` liegen auf `mavoxgt@gmail.com`.
   Nötig: `CLOUDFLARE_API_TOKEN` für den mavoxgt-Account setzen (oder umloggen), dann:
   ```bash
   cd ~/Documents/inTouch/backend
   npx wrangler d1 execute noolp --remote --file=src/sql-schema/api_reminders.sql -y
   npx wrangler deploy
   ```
   Bis dahin zeigt das Reminders-Widget „inTouch unreachable"/leer.
2. **inTouch-App:** Änderungen (Opt-in pro Bereich, Sync-Service) sind im Working Tree,
   Device-Build grün, aber UNCOMMITTET und ungetestet am Gerät. Simulator-Build des
   Repos bricht schon vorher an RealtimeKit (vorbestehend, nicht von uns).
3. **Gerätetest Reminders-Flow:** App-Build aufs iPhone, Bereich freigeben, Sync in
   beide Richtungen prüfen (Widget abhaken → App; App-Änderung → Widget).
4. **iPad-Batterie:** iPad war zur Bauzeit nicht gekoppelt sichtbar — im Finder
   „iPad über WLAN anzeigen" aktivieren, dann liefert `idevice_id -n` das Gerät.
5. **API-Doku:** Reminders-Capability-Seite für intouch-api-docs fehlt noch
   (gleicher Deploy-Blocker).
6. **TestFlight:** bisher nur lokaler Debug-Build. Für TestFlight (macOS) braucht die
   App App Sandbox + App-Store-Signierung — bewusst verschoben; lokal reicht erstmal.

## Erledigt

- [x] **Schritt 1 — Gerüst:** project.yml (XcodeGen), Theme (Light/Dark, dezent),
      WidgetCard-Chrome, 4-Spalten-Layout (1180×800 ≈ iPad-Sidecar), Settings-Fenster,
      KeychainHelper, AppSettings (Token-Autoimport aus ~/.claude/settings.json).
- [x] **Schritt 2 — Widgets:** Clock+Weather (Open-Meteo + Geocoding), System-Monitor
      (host_cpu_load_info-Delta, vm_statistics64, statfs, getifaddrs-Raten), Batteries
      (IOKit + ideviceinfo mit Timeout), Claude Code (REST `?filter=all` + WS
      `/api/stream?token=`, Live-Events, „Stalled?" ab 5 min ohne Heartbeat),
      Calendar (EventKit, 7 Tage), Mail (eigener IMAP4rev1-Client: LOGIN/EXAMINE/
      STATUS/FETCH-Header, RFC-2047-Decoding), GitHub (Search-API PRs + Events),
      Reminders (inTouch-Addon, Area-Picker, Abhaken optimistisch, Hinzufügen).
- [x] **Schritt 3 — claude-status-Pipeline** (im Repo `claude-status`, gepusht):
      `begin` legt sofort synchron an, Titel async, stale Locks heilen sich,
      `touch`-Heartbeat + globaler PostToolUse-Hook. Live getestet.
- [x] **Schritt 4 — inTouch Reminders-Addon (Code fertig, Deploy offen):**
      Backend `api/addons/reminders.js` (+ `sql-schema/api_reminders.sql`, Routen in
      `api/index.js`): extern GET areas/items, POST items, PATCH items/:id (X-API-Key);
      App-Sync push/pending/ack (Snapshot-Modell, App = Quelle der Wahrheit).
      iOS: `ReminderArea.apiExposed` (abwärtskompatibel), Menü-Schalter in
      ReminderChatSettingsView (nur lokale Bereiche, geteilte bleiben E2E),
      `RemindersSyncAPI` + `ReminderAPISyncService` (Trigger: .reminderStoreChanged +
      Foreground, 3 s entprellt), Lokalisierung in 19 Sprachen. Device-Build grün.

## Architektur-Notizen

- Design-Tokens in `Support/Theme.swift`; keine Hardcodes in Widgets.
- Jedes Widget = eigener Ordner unter `Widgets/` mit View + Service (@Observable).
- Polling-Kadenz: Wetter 20 min, System 3 s, Batterien 60 s, Kalender 5 min,
  Mail 3 min, GitHub 5 min, Reminders 60 s; Claude live per WebSocket mit
  REST-Refetch als Lückenfüller nach Reconnect.
- Nicht sandboxed (liest ~/.claude/settings.json, spawnt ideviceinfo). Für App
  Store/TestFlight müsste beides raus bzw. anders gelöst werden.
