# Deskboard

macOS-Dashboard, optimiert für ein iPad als Zweitbildschirm (Sidecar).
Schlichtes, professionelles Design, Light + Dark, UI auf Englisch.

## Widgets

| Widget | Quelle |
|---|---|
| Today (Uhr + Wetter) | Open-Meteo (kein API-Key; Ort in den Settings) |
| System | CPU/RAM/Disk/Netz des Macs (Mach/IOKit) |
| Batteries | Mac-Akku (IOKit) + iPad/iPhone via `libimobiledevice` |
| Claude Code | `claude-status-api` (REST + WebSocket, live) |
| Calendar | EventKit — alles, was in der macOS-Kalender-App eingerichtet ist |
| Reminders | inTouch Reminders-Addon (`X-API-Key`), Lesen/Abhaken/Hinzufügen |
| Mail | IONOS via minimalem, eigenem IMAP-Client (nur lesend) |
| GitHub | Offene PRs + Aktivität (PAT in den Settings) |

## Build

```bash
brew install xcodegen            # einmalig
xcodegen generate
xcodebuild -project Deskboard.xcodeproj -scheme Deskboard -configuration Debug build
```

Das `.xcodeproj` ist generiert und nicht eingecheckt — Quelle der Wahrheit ist `project.yml`.

## Konfiguration

Alles in den App-Settings (⌘,). Credentials landen im Keychain, Rest in UserDefaults.
Der Claude-Status-Token wird beim ersten Start automatisch aus
`~/.claude/settings.json` (env.CLAUDE_STATUS_TOKEN) übernommen.

Für das Batterie-Widget: `brew install libimobiledevice` und das iPad im Finder
mit „iPad über WLAN anzeigen" koppeln (oder per USB anschließen).

## Zusammenhängende Projekte

- `maaxvogt/claude-status` — Backend/Hooks für das Claude-Code-Widget
- inTouch (Backend + iOS) — Reminders-Addon (Klartext-Spiegel pro freigegebenem Bereich)

Stand & nächste Schritte: [PROGRESS.md](PROGRESS.md)
