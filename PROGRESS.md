# PROGRESS — Deskboard

**Quelle der Wahrheit für den Projektstand.** Nach jedem Schritt pflegen → committen → pushen.

---

## Aktueller Stand (1.9.2026)

**GitHub-Widget „No open PRs" — gelöst (1.9.2026, PR #1):** Die Widget-Query selbst war
korrekt. Ursache: Der Settings-Token im Keychain (classic PAT `ghp_`, hat sogar
`repo`-Scope) hat Vorrang, sieht aber 0 PRs/0 Events — er gehört sehr wahrscheinlich zum
falschen GitHub-Account (vermutlich `poddie-box` statt `maaxvogt`); GitHub antwortet
dann mit HTTP 200 und leeren Listen, kein Fehler. Fix auf Branch
`github-widget-scope-hint` (PR #1): (a) Liefert der Settings-Token nichts, fällt das
Widget automatisch auf den gh-CLI-Token zurück; (b) `X-OAuth-Scopes`-Check mit
Hinweis-Platzhalter statt stummem „No open PRs"; (c) os_log-Diagnose
(`/usr/bin/log show --predicate 'subsystem == "com.maxvogt.deskboard"'`).
Live verifiziert: Widget zeigt nach Fallback 2 PRs + 8 Events. PR #1 dient zugleich
als Testdatensatz. **Empfehlung:** den falschen Token in den Settings trotzdem leeren.

**Fixes 1.9.2026:** GitHub-Widget zeigte nichts an — die GitHub-Events-API liefert bei
PushEvents kein `commits`-Feld mehr im Payload, dadurch wurden alle Push-Events als „leer"
rausgefiltert. Fix: Fallback auf Branch-Name („Pushed to main") via `payload.ref`; zusätzlich
Platzhalter statt leerer Karte, wenn weder PRs noch Events da sind. Uhr-Widget: Minuten jetzt
immer zweistellig (`.minute(.twoDigits)`, „09:05" statt „09:5"). Gegen Live-API-Daten
verifiziert, Build grün. Hinweis: Im Keychain liegt ein `githubToken` (Settings), der Vorrang
vor dem gh-CLI-Token hat — falls das Widget einen Token-Fehler zeigt, den in den Settings leeren.

Erste Session (31.8.2026): App steht komplett als lokaler Debug-Build, alle 8 Widgets
implementiert, Build grün. Repo `maaxvogt/deskboard` (privat).

**Offen / Blocker:**

1. ~~inTouch-Backend nicht deployt~~ → **ERLEDIGT 31.8.2026**: Max hat Wrangler auf
   `mavoxgt@gmail.com` umgeloggt; Schema `api_reminders.sql` remote eingespielt,
   `intouch-backend` deployt (Version ddde4aff). Kompletter Flow in Produktion
   getestet: push → extern lesen → extern add/PATCH → pending (beide Op-Typen) →
   ack → Opt-out räumt Spiegel; falscher Key → 403.
2. **inTouch-App:** Änderungen (Opt-in pro Bereich, Sync-Service) sind im Working Tree,
   Device-Build grün, aber UNCOMMITTET (Backend-Stand ist deployt → committen empfohlen)
   und ungetestet am Gerät. Simulator-Build des Repos bricht schon vorher an
   RealtimeKit (vorbestehend, nicht von uns).
3. **Gerätetest Reminders-Flow:** App-Build aufs iPhone, Bereich freigeben (Menü des
   Bereichs → „Über API freigeben"), Sync in beide Richtungen prüfen
   (Widget abhaken → App; App-Änderung → Widget).
   **Gefixter Live-Sync-Bug (31.8.2026, 1. Gerätetest):** kick() cancelte den
   EIGENEN laufenden Sync (Op anwenden → store.save → Notification → kick →
   Task.cancel → ack/push flogen als CancellationError raus) → Ops blieben
   pending, wurden bei jedem Lauf erneut angewendet (Duplikate in der App),
   push kam nie an. Fix: Debounce-Cancel trifft nur noch das Warten, Sync läuft
   in eigenem Task (launchSync + rerunRequested); zusätzlich Op-Anwendung
   idempotent über persistierte applied-Op-IDs. Erfordert NEUEN App-Build.
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
