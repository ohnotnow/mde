# CLAUDE.md — mde

A native macOS Markdown viewer (SwiftUI; Markdown is rendered to HTML and shown in a `WKWebView`). The user-facing `README.md` is the entry point for humans; this file orients fresh agent sessions.

This is a personal project the user is using to learn Swift and AppKit. Match the spirit: keep changes proportionate, don't refactor surrounding code unprompted, and prefer to teach-by-doing in small steps over sweeping rewrites.

## Read this first

This project uses two local-first agent tools, both with skills available:

- **`ant foundation`** — single-command read of the project's guiding principle. Run it before making scope or design judgement calls. The foundation here is load-bearing: most natural feature requests for a Markdown viewer drift toward turning it into a Markdown editor, and the foundation is the bulwark against that. (Note: the foundation entry predates the WebKit rendering pivot — see the `ant` pivot `mde-VXQvH`.)
- **`ait status` / `ait ready`** — current work and what's unblocked. ADRs and notes captured in `ant` are linked to ait IDs via `--issue`.
- **`ant for <issue-id>`** — when picking up a specific task, this surfaces ADRs/notes attached to it. Several tasks under epic `mde-gbHJd` (the embedded quick-edit pane) have important *why* context that lives in `ant`, not in the code.

If `ant foundation` reports "no foundation recorded" or `ait` is empty, proceed without — but at time of writing both are populated.

## Project shape

- Swift / SwiftUI app, macOS 14 (Sonoma) deployment target.
- SwiftPM package — `Package.swift` at the repo root. Builds with only the Xcode **Command Line Tools** via `./build.sh`; there is no `.xcodeproj`. (`open Package.swift` in Xcode if you want the IDE.)
- Two direct dependencies — swift-cmark (cmark-gfm, Markdown→HTML) and SwiftTerm (the `⌘E` quick-edit terminal). swift-argument-parser comes along transitively.
- Rendering is Markdown→HTML (cmark-gfm) shown in a `WKWebView` — pivoted from pure-SwiftUI/MarkdownUI for large-file performance (see the `ant` pivot `mde-VXQvH`). The web view disables page JavaScript and blocks remote content.
- Settings persisted in `UserDefaults`.
- Ad-hoc signed, not sandboxed, not Apple-notarised. Released as a zip via GitHub Releases (built on macOS runners with SwiftPM).

## Working with the codebase

- Build: `./build.sh` produces `build/MDE.app` (SwiftPM + Command Line Tools, no full Xcode). Then `open build/MDE.app`.
- `build.sh` already builds `-c release` and ad-hoc signs it. For an IDE, `open Package.swift` in Xcode and `Cmd-R`.
- No test target yet. Confirm with the user before adding one.
- Frontend-style "did I break the UI?" checks need a real build+launch (`./build.sh && open build/MDE.app`) — there's no headless preview path that exercises file-open or rendering end-to-end.

## Recommended session opener

1. `ant foundation` — guiding principle.
2. `ait ready` — what's unblocked.
3. `ant for <issue-id>` if you're starting a specific task.

That's enough to make good calls.
