# CLAUDE.md — Deskboard

macOS-Dashboard (SwiftUI, macOS 14+), optimiert für ein iPad als Sidecar-Zweitbildschirm.
**Bei Wiedereinstieg zuerst [PROGRESS.md](PROGRESS.md) lesen** — dort stehen Stand, Blocker
und die offenen Schritte.

## Regeln

- UI-Sprache **Englisch**, schlicht/professionell, kein „KI-Look". Farben/Fonts NUR über
  `Support/Theme.swift` — nichts hardcoden. Jeder Farb-Token hat drei Werte
  (light / dark / darkColor, s. `Appearance`); neue Tokens immer für alle drei anlegen.
  Karten-Chrome (Inset in Light/Dark, Tint in Dark Color) lebt ausschließlich in `WidgetCard`.
- `.xcodeproj` ist generiert (XcodeGen) und gitignored. Neue Dateien einfach anlegen,
  dann `xcodegen generate`. Quelle der Wahrheit: `project.yml`.
- Build-Verifikation:
  ```bash
  xcodegen generate
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    xcodebuild -project Deskboard.xcodeproj -scheme Deskboard -configuration Debug \
    -derivedDataPath build build
  ```
  (für den signierten Build `--spec project.local.yml` an `xcodegen generate` hängen.)
  Visuelle Prüfung ohne Screen-Recording-Berechtigung (Debug-Build):
  `build/Build/Products/Debug/Deskboard.app/Contents/MacOS/Deskboard --appearance=light|dark|darkColor --snapshot=/pfad.png`
  — rendert das Fenster nach ~8 s als PNG und beendet sich (`--appearance` gilt nur für
  diesen Start, nichts wird gespeichert); `--demo` dazu zeigt Fixtures statt echter Daten; `--move-next` wechselt
  vorher das Display (PNG-Größe = Auflösung des Ziel-Displays im Vollbild). Fenster-Log:
  `/usr/bin/log show --info --predicate 'subsystem == "com.maxvogt.deskboard" AND category == "window"'`.
- Fenster-/Vollbild-Logik nur in `Support/WindowManager.swift` (Auto-Vollbild, Display-Wechsel,
  gemerktes Display). Vollbild ist das native macOS-Vollbild, kein Kiosk-Fenster.
- Ein Widget = ein Ordner unter `Widgets/` (View + @Observable-Service). Neue Widgets in
  `DashboardView` einhängen.
- Credentials IMMER über `KeychainHelper`, nie in UserDefaults.
- App ist bewusst NICHT sandboxed (liest `~/.claude/settings.json`, spawnt `ideviceinfo`).

## Externe Verträge

- **Claude-Widget** ↔ `claude-status-api` (Repo `maaxvogt/claude-status`, Root-CLAUDE.md
  „Architektur-Vertrag"). Status-Set `queued|running|waiting|done|failed`; Heartbeat via
  PostToolUse-Hook → „Stalled?"-Heuristik (running + 5 min ohne Update).
  Rate-Limit-Balken (`ClaudeRateLimitService`) ↔ interner Anthropic-Endpunkt
  `/api/oauth/usage` mit dem Claude-Code-Token aus dem Keychain (`security`-CLI) — kann
  sich ohne Vorwarnung ändern; Parser bewusst tolerant, Details in PROGRESS.md.
- **Reminders-Widget** ↔ inTouch `api/addons/reminders.js` (X-API-Key). Der Spiegel ist
  Klartext, aber NUR für in der App pro Bereich freigegebene, LOKALE Bereiche — geteilte
  Bereiche bleiben E2E und tauchen hier nie auf. Diese Grenze nicht aufweichen.
- **Spotify-Widget** ↔ Spotify Web API (`/v1/me/player`, Auth-Code + PKCE, eigene Developer-App
  des Nutzers, Client-ID in den Settings, Refresh-Token im Keychain). Redirect über das
  URL-Scheme `deskboard://spotify-callback` (`Deskboard/Info.plist`, wird in die generierte
  Info.plist gemergt; Empfang im `AppDelegate`). Steuerung braucht Premium (403
  `PREMIUM_REQUIRED` → Hinweis im Widget).
- **Mail**: eigener minimaler IMAP-Client (`Widgets/Email/IMAPClient.swift`), bewusst ohne
  Fremd-Dependency und nur lesend (EXAMINE statt SELECT).

## Öffentliches Repo — was NICHT hinein darf

- GitHub: `maaxvogt/deskboard` ist **öffentlich**. Keine Tokens, Hostnamen eigener Worker,
  E-Mail-Adressen, Account-Namen oder die Apple-Team-ID committen — auch nicht in
  PROGRESS.md. Endpunkte/Accounts sind reine Settings-Werte (Defaults leer).
- Die Team-ID steht nur im gitignorierten `project.local.yml`; generieren mit
  `xcodegen generate --spec project.local.yml`. Das nackte `project.yml` baut ad-hoc
  signiert („Sign to Run Locally").
- inTouch/claude-status-Worker liegen auf dem privaten Cloudflare-Account; Wrangler ist
  ggf. mit dem Arbeits-Account eingeloggt → vor Worker-Arbeit `npx wrangler whoami`.
- Screenshots nur mit Demo-Daten: `Deskboard --demo --appearance=light|dark|darkColor
  --snapshot=/pfad.png` (Fixtures in `Support/Demo.swift`, kein Netz/Keychain/EventKit).
