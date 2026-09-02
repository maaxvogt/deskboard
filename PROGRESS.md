# PROGRESS — Deskboard

**Quelle der Wahrheit für den Projektstand.** Nach jedem Schritt pflegen → committen → pushen.

---

## Aktueller Stand (2.9.2026)

**Reminders „Erledigte löschen" (2.9.2026):** Papierkorb-Button in der Titelzeile des
Reminders-Widgets (nur sichtbar, wenn abgehakte Todos da sind), Bestätigungsdialog wie in
der App, dann `DELETE /api/addons/reminders/items?area=<id>&done=true`, optimistisch
lokal entfernt, bei Fehler Rollback + Meldung. Backend-Seite (inTouch `reminders.js`):
Soft-Delete `is_deleted=1, pending=1`, Spiegel blendet sofort aus, App löscht per
Pending-Op (`deleted: true` → `ReminderStore.deleteItem`) und räumt per ack. **Neue
Spalte** `is_deleted` → einmalig auf der Prod-D1: `ALTER TABLE api_reminder_items ADD COLUMN
is_deleted INTEGER NOT NULL DEFAULT 0;` Migration + Deploy am 2.9.2026 erledigt (Worker-Version fd140d0a; Route live, antwortet
ohne Key mit 401 statt 404). **Offen:** App-Seite (Lösch-Op im Sync) liegt uncommittet im
inTouch-Working-Tree und braucht einen neuen Device-Build — bis dahin verschwinden gelöschte
Items zwar im Widget, aber noch nicht in der App.

**Spotify-Widget (2.9.2026, uncommittet):** Neuntes Widget in der dritten Spalte zwischen
Calendar und Reminders (feste Höhe 136): Albumcover links (84 pt), rechts Titel, „Artist ·
Album" und eine Reihe mit ⏮ ⏯ ⏭ + Fortschrittsbalken + Position. Quelle: **Spotify Web API**
(Max' Entscheidung, weil keine Spotify-Desktop-App auf dem Mac liegt; zeigt jedes Gerät des
Accounts). `Widgets/Spotify/`: `SpotifyService` (View-Modell, Backend-Seam
`SpotifyBackend`, Demo-Backend), `SpotifyWebAPI` (`GET /v1/me/player?additional_types=track,episode`,
PUT play/pause, POST next/previous, Fehler-Mapping 401/403 PREMIUM_REQUIRED/404/429),
`SpotifyAuth` (Auth-Code + PKCE gegen die eigene Developer-App, Client-ID in UserDefaults,
Refresh-Token im Keychain `spotifyRefreshToken`, Access-Token nur im RAM, `invalid_grant` →
Disconnect + Hinweis). Redirect `deskboard://spotify-callback`: URL-Scheme in
`Deskboard/Info.plist` (per `INFOPLIST_FILE` in die generierte Plist gemergt, verifiziert per
`plutil`), Empfang über `AppDelegate.application(_:open:)` (kein zweites Fenster). Settings →
Tab „Spotify" (Client-ID, Redirect-URI zum Kopieren, Connect/Disconnect, Fehlerzeile).
Polling 3 s, Fortschritt per `TimelineView` sekündlich interpoliert. Verifiziert: Build grün,
Demo-Snapshots in allen drei Appearances, Callback-Empfang per os_log (Kategorie `spotify`:
„Callback ignored: state mismatch"), PKCE-Challenge gegen den RFC-7636-Testvektor.
**Offen:** Ende-zu-Ende-Login braucht Max' Spotify-Developer-App (Client-ID) — noch nicht
durchgeführt; 429-Handling ist nur Hinweistext (kein Retry-After-Backoff). Hinweis: Spotify
gewährt neuen Apps im Development-Mode nur wenige Nutzer, für den Eigengebrauch reicht das.

**Veröffentlichung (2.9.2026):** Repo ist öffentlich; Historie neu aufgesetzt (ein Root-Commit „Initial public release“, alte Commits nur noch lokal als Bundle unter `~/Documents/Deskboard-history-backup.bundle`). Audit ohne Befund bei
Secrets (Code + komplette Historie), aber persönliche Werte entfernt: Defaults für
claudeAPIBase / inTouchAPIBase / githubUser / imapHost sind jetzt **leer** (Werte liegen in den
UserDefaults dieses Macs, per `defaults write` nachgetragen — Widgets zeigen bei leerer URL
einen Settings-Hinweis), Apple-Team-ID aus `project.yml` ins gitignorierte
`project.local.yml` (`xcodegen generate --spec project.local.yml`; nacktes Spec baut
„Sign to Run Locally"), E-Mail-/Account-Namen aus PROGRESS.md/CLAUDE.md, Provider-Bezug aus
den Settings-Texten. Neu: `Support/Demo.swift` (`--demo` = Fixtures für alle 8 Widgets ohne
Netz/Keychain/EventKit, `--appearance=` nur für den Start), `CalendarEntry` statt EKEvent
im Widget, Query-Parameter (GitHub-User, Reminders-Area) percent-encoded, MIT-LICENSE,
englische README mit drei Demo-Screenshots unter `docs/screenshots/`. Build grün (beide
Specs), Screenshots verifiziert.

**PR #1 (Widget-Fixes vom 1.9.) am 2.9.2026 in main gemergt.**

**Rate-Limit-Balken im Claude-Widget (2.9.2026):** Unter der Session-Liste dieselben drei Fenster wie `/usage`
in Claude Code — „Session" (5-h), „Week · all", „Week · Fable" — je mit Prozent, Capsule-Bar
(accent / warn ≥70 % / bad ≥90 %) und Reset-Zeit („resets 13:20", „resets tomorrow 02:00",
„resets Mon 00:00"). Quelle: `Widgets/Claude/ClaudeRateLimitService.swift` liest das
Claude-Code-OAuth-Token per `/usr/bin/security find-generic-password -s "Claude Code-credentials" -w`
(kein Keychain-Prompt, weil Claude Code das Item selbst über `security` schreibt) und
fragt alle 120 s `GET https://api.anthropic.com/api/oauth/usage` ab (Header
`anthropic-beta: oauth-2025-04-20`). **Undokumentierter interner Endpunkt** — Antwortfelder:
`five_hour`/`seven_day` `{utilization, resets_at}`, `limits[]` mit `kind == "weekly_scoped"`,
`scope.model.display_name`, `percent`, `resets_at` (daraus der Fable-Balken); Fallback auf
`seven_day_opus`/`seven_day_sonnet`. Bei 401 wird das Token einmal neu aus dem Keychain
gelesen (Claude Code refresht es selbst); abgelaufenes Token → Hinweis „login expired".
Diagnose: os_log-Kategorie `usage` (Antwort-Keys + geparste Fenster, nie das Token).
Live verifiziert per Snapshot: 79 % / 11 % / 20 %, identisch zu `/usage`-Log.

**Appearance-Redesign (2.9.2026):** Drei Modi in Settings → General → „Appearance":
**Auto** (System hell → Light, dunkel → Dark Color), **Light** (Soft-UI: einheitliche
graue Fläche `#DDE1E7`, Karten mit Inner-Shadow in den Hintergrund „gedrückt", Inhalt
flach, Titel farbig), **Dark** (dieselbe Inset-Technik auf dunkelgrauer Fläche `#1C1C20`,
Titel farbig, keine Kanten), **Dark Color** (der bisherige getönte Look, unverändert). Umsetzung: Tokens in
`Theme.swift` sind computed und lesen `AppSettings.appearance`; Karten-Chrome in
`WidgetCard.surface` per `Theme.mode(for: colorScheme)`; `preferredColorScheme` auf
Dashboard + Settings. Alle vier Zustände per Snapshot verifiziert (Debug-Hook
`Deskboard --snapshot=/pfad.png`, s. CLAUDE.md), Build grün.

**Vollbild + Display-Wechsel (2.9.2026):** `Support/WindowManager.swift`
bekommt das NSWindow über `WindowAccessor` (im Hintergrund der DashboardView). Natives
macOS-Vollbild automatisch beim Start (Settings → General „Start in full screen“,
Default an). Display wechseln: Settings → General „Display“-Picker oder View →
„Move to Next Display“ (⇧⌘M); Ablauf leave → setFrame → re-enter, weil ein
Vollbild-Fenster nicht direkt verschiebbar ist. Das zuletzt gewählte Display wird als
`lastDisplayID` gemerkt (SwiftUIs Frame-Restore vergisst es sonst; live beobachtet).
Verifiziert über drei Displays (2× BenQ, Sidecar) per `--snapshot … --move-next` und
os_log-Kategorie `window` (`log show --info` nötig, sonst fehlen die Info-Zeilen).


**GitHub-Widget „No open PRs" — gelöst (1.9.2026, PR #1):** Die Widget-Query selbst war
korrekt. Ursache: Der Settings-Token im Keychain (classic PAT `ghp_`, hat sogar
`repo`-Scope) hat Vorrang, sieht aber 0 PRs/0 Events — er gehört sehr wahrscheinlich zum
falschen GitHub-Account (ein Arbeits-Account statt dem eigenen); GitHub antwortet
dann mit HTTP 200 und leeren Listen, kein Fehler. Fix auf Branch
`github-widget-scope-hint` (PR #1): (a) Liefert der Settings-Token nichts, fällt das
Widget automatisch auf den gh-CLI-Token zurück; (b) `X-OAuth-Scopes`-Check mit
Hinweis-Platzhalter statt stummem „No open PRs"; (c) os_log-Diagnose
(`/usr/bin/log show --predicate 'subsystem == "com.maxvogt.deskboard"'`).
Live verifiziert: Widget zeigt nach Fallback 2 PRs + 8 Events. PR #1 dient zugleich
als Testdatensatz. **Empfehlung:** den falschen Token in den Settings trotzdem leeren.

**Reminders „inTouch error 500" (1.9.2026):** Nicht reproduzierbar — nach App-Neustart
liefen Areas-/Items-Polls über mehrere Zyklen fehlerfrei; sehr wahrscheinlich ein
transienter D1/Worker-Fehler, der genau den ERSTEN Refresh nach Neustart traf (der
Fehler-Platzhalter steht dann bis zum nächsten 60s-Poll). Wrangler war zudem wieder
mit dem Arbeits-Account eingeloggt (Worker liegt auf dem privaten Cloudflare-Account) →
kein `wrangler tail` möglich. Vorsorge im Widget: (a) InTouchClient loggt Fehler-Bodies
nach os_log (Kategorie `intouch`) und zeigt die Server-Fehlermeldung statt nur
„inTouch error 500"; (b) PATCH-Fehler (z.B. 404 nach ID-Churn durch App-Snapshot-Push,
live beobachtet bei Item 32) lösen jetzt ein Items-Resync aus statt nur Rollback.
**Merker Backend-Repo:** `reminders.js` + `api_reminders.sql` sind dort noch
UNTRACKED (deployt wurde aus dem Working Tree) — committen!

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
   den privaten Cloudflare-Account umgeloggt; Schema `api_reminders.sql` remote eingespielt,
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
