# CLAUDE.md — mde

A native macOS Markdown viewer (SwiftUI, no WebKit). The user-facing `README.md` is the entry point for humans; this file orients fresh agent sessions.

This is a personal project the user is using to learn Swift and AppKit. Match the spirit: keep changes proportionate, don't refactor surrounding code unprompted, and prefer to teach-by-doing in small steps over sweeping rewrites.

## Read this first

This project uses two local-first agent tools, both with skills available:

- **`ant foundation`** — single-command read of the project's guiding principle. Run it before making scope or design judgement calls. The foundation here is load-bearing: most natural feature requests for a Markdown viewer drift toward turning it into a Markdown editor, and the foundation is the bulwark against that.
- **`ait status` / `ait ready`** — current work and what's unblocked. ADRs and notes captured in `ant` are linked to ait IDs via `--issue`.
- **`ant for <issue-id>`** — when picking up a specific task, this surfaces ADRs/notes attached to it. Several tasks under epic `mde-gbHJd` (the embedded quick-edit pane) have important *why* context that lives in `ant`, not in the code.

If `ant foundation` reports "no foundation recorded" or `ait` is empty, proceed without — but at time of writing both are populated.

## Project shape

- Swift / SwiftUI app, macOS 14 (Sonoma) deployment target.
- Xcode project at `MDE/MDE.xcodeproj`. SPM dependencies resolve on first open.
- Two direct dependencies — MarkdownUI (body rendering, on cmark-gfm) and Highlightr (code blocks). NetworkImage and swift-cmark come along transitively.
- Pure SwiftUI rendering, no WebKit. This is a deliberate stance, not an accident — weigh new dependencies against it.
- Settings persisted in `UserDefaults`.
- Ad-hoc signed, not sandboxed, not Apple-notarised. Distributed as zip via GitHub Releases.

## Working with the codebase

- Dev run: open `MDE/MDE.xcodeproj` in Xcode, `Cmd-R`.
- Release build: scheme selector → **Edit Scheme…** → Run → Build Configuration → **Release**, then `Cmd-B`. Output in the Products group.
- No test target yet. Confirm with the user before adding one.
- Frontend-style "did I break the UI?" checks need a real Xcode run — there's no headless preview path that exercises file-open or rendering end-to-end.

## Recommended session opener

1. `ant foundation` — guiding principle.
2. `ait ready` — what's unblocked.
3. `ant for <issue-id>` if you're starting a specific task.

That's enough to make good calls.
