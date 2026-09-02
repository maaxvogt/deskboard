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
  Visuelle Prüfung ohne Screen-Recording-Berechtigung (Debug-Build):
  `defaults write com.maxvogt.deskboard appearance light|dark|darkColor|auto`, dann
  `build/Build/Products/Debug/Deskboard.app/Contents/MacOS/Deskboard --snapshot=/pfad.png`
  — rendert das Fenster nach ~8 s als PNG und beendet sich; `--move-next` dazu wechselt
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
- **Reminders-Widget** ↔ inTouch `api/addons/reminders.js` (X-API-Key). Der Spiegel ist
  Klartext, aber NUR für in der App pro Bereich freigegebene, LOKALE Bereiche — geteilte
  Bereiche bleiben E2E und tauchen hier nie auf. Diese Grenze nicht aufweichen.
- **Mail**: eigener minimaler IMAP-Client (`Widgets/Email/IMAPClient.swift`), bewusst ohne
  Fremd-Dependency und nur lesend (EXAMINE statt SELECT).

## Accounts

- GitHub: `maaxvogt/deskboard` (privat).
- inTouch/claude-status-Worker liegen auf Cloudflare-Account `mavoxgt@gmail.com` —
  Wrangler ist ggf. mit dem Poddie-Account (`quietoffice`) eingeloggt, siehe PROGRESS.md.
