# tbdflow-ui

A desktop dashboard for [tbdflow](https://github.com/cladam/tbdflow) — the Trunk-Based Development CLI.  
Built with [Hica](https://hica.dev) and Dear ImGui.

## What it does

tbdflow-ui puts your trunk workflow in a persistent window alongside your editor:

| Panel | Contents |
|-------|----------|
| **Left** | Active repository path (Browse or use current dir), branch, mode, trunk target, CI and Radar status indicators |
| **Center** | Sync, Intent Log (add notes with `tbdflow note`), Commit form (type dropdown from live config, message, advanced options), Recent Commits list |
| **Right** | Radar panel — trunk proximity (ahead/behind), CI status, changed files |

### Key behaviours

- **Multi-repo** — click Browse to pick any local repo; data reloads automatically on selection.
- **Intent Log** — type a note and press Add Note; runs `tbdflow note "<text>"` and immediately refreshes the notes view.
- **Commit form** — type dropdown is driven by the repo's live `tbdflow --json info` config. Supports scope, body, tag, issue, breaking-change, and skip-DoD flags via the Advanced options toggle.
- **Recent Commits** — last 25 commits; click a hash to open the commit on GitHub.
- **Refresh** — forces a full data reload without changing the active repo path.

## Prerequisites

- [tbdflow](https://github.com/cladam/tbdflow) on `PATH`
- [Hica](https://hica.dev) on `PATH`
- SDL2: `brew install sdl2`

## Build and run

```sh
hica run     # compile and launch
hica build   # compile to binary only
hica check   # type-check without emitting
hica clean   # remove generated files
```
