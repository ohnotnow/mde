# mde

A native macOS Markdown viewer. Double-click a `.md` file in Finder, get a nicely rendered, screen-sharable reading window.

![screenshot](screenshot.png)

## What it does

`mde` opens Markdown files (`.md`, `.markdown`, `.mdown`, `.mkd`) and renders them for reading: decent typography, GitHub-flavoured Markdown, and YAML front-matter pulled out and shown as metadata above the body instead of being mangled into a giant heading. It is a viewer, not an editor. Files open via Finder, drag-and-drop, the standard Open dialog, or Open Recent.

For quick fixes without leaving the window, `⌘E` opens the current file in an inline terminal running your preferred TUI editor (`vim`, `nvim`, `nano`, etc.) and `⇧⌘E` hands it off to a GUI editor (VS Code, Cursor, Sublime, etc.). Both are configured in **mde → Settings…**, and the preview auto-reloads when the editor saves.

## Quick install (no Xcode required)

Grab the latest `MDE-vX.Y.Z.zip` from the [Releases page](https://github.com/ohnotnow/mde/releases), expand it, and drag `MDE.app` into `/Applications`. Built on GitHub's macOS runners, ad-hoc signed.

### First-launch Gatekeeper

The app isn't Apple-notarised (notarisation needs a paid Apple Developer account), so the first time you double-click it from `/Applications` macOS will refuse with *"MDE.app cannot be opened because Apple cannot check it for malicious software"*. Three workarounds, easiest first:

1. In Finder, right-click `MDE.app` → **Open** → click **Open** again in the warning dialog. macOS only enforces this on first launch; double-clicking works normally afterwards.
2. If that doesn't work, in Terminal: `xattr -dr com.apple.quarantine /Applications/MDE.app`
3. Or skip the dance entirely: download via `curl` or `wget` rather than a browser. The quarantine attribute is set by LaunchServices-aware apps (Safari, Mail, AirDrop) when they save a file from the internet; command-line tools don't apply it. Example:

   ```bash
   curl -L -o mde.zip https://github.com/ohnotnow/mde/releases/latest/download/MDE-v0.1.0.zip
   unzip mde.zip
   mv MDE.app /Applications/
   ```

   (Adjust the version in the URL.)

If you'd rather build from source, read on.

## Build from source

You only need the Xcode **Command Line Tools** — not the full Xcode app.

### Prerequisites

- A Mac running macOS 14 (Sonoma) or later
- The Command Line Tools — run `xcode-select --install` if you don't already have them

The Command Line Tools provide the Swift compiler and `swift build`, which is all that's needed — no full Xcode (that multi-gigabyte download), no Homebrew, no extra package managers. If you *do* have the full Xcode installed, it works too.

### 1. Clone the repository

```bash
git clone https://github.com/ohnotnow/mde.git
cd mde
```

### 2. Build

```bash
./build.sh
```

This compiles an optimised release build with Swift Package Manager, assembles `MDE.app`, and ad-hoc signs it. The first build fetches the Swift package dependencies (swift-cmark, SwiftTerm), which takes a minute or two depending on your connection. The finished app lands at `build/MDE.app`.

### 3. Run it, or move it to /Applications

```bash
open build/MDE.app                  # just launch it
cp -R build/MDE.app /Applications/  # or keep it around like any other app
```

Because *you* built it, there's no Gatekeeper *"cannot be opened"* hurdle — that only applies to apps **downloaded** from the internet. Building it yourself sidesteps the whole thing.

> **Prefer an IDE?** There's no `.xcodeproj` to open. Instead, `open Package.swift` opens the package directly in Xcode (if you have the full app installed), where `Cmd-R` builds and runs it.

## Piping to mde from the terminal

`Scripts/mde` is a small launcher script for terminal use. Copy it onto your `PATH`:

```bash
install -m 755 Scripts/mde ~/.local/bin/mde
```

Then:

```bash
mde notes.md                  # open a file, same as double-clicking it
some-command | mde            # render whatever arrives on stdin
some-command | mde ait-42     # same, but call the window "ait-42"
```

Piped input is written to a temp file under `$TMPDIR/mde-pipes` and opened from there, so there is nothing to clean up by hand (macOS sweeps `$TMPDIR` on its own). The filename doubles as the window title: an explicit argument wins; otherwise the first content line of the document is used (front-matter skipped, `#` markers stripped, capped at 30 characters); and if the input offers nothing usable, you get the random temp name and can live with it.

Set `MDE_APP` to point the script at a different build, e.g. `MDE_APP="$PWD/build/MDE.app" some-command | mde`.

## What's in the Settings dialog

Open **mde → Settings…** (or `Cmd-,`):

- **Font Size** — slider plus zoom shortcuts (`Cmd-=`, `Cmd--`, `Cmd-0` from the View menu)
- **Font** — picker showing System Sans, System Serif, Monospaced, and every font installed on your Mac
- **Line Height** — slider from tight (1.1) to airy (2.2)

Settings are persisted in `UserDefaults`, so they survive restarts.

## How the rendering works

Body Markdown is converted to HTML by [cmark-gfm](https://github.com/swiftlang/swift-cmark) — GitHub-flavoured, so tables, strikethrough, autolinks and task lists all work — and then displayed in a `WKWebView` styled after the University of Glasgow house style. Handing layout and scrolling to the web engine is what keeps long documents fast. Code blocks are shown as plain monospaced panels (no syntax highlighting).

Because a viewer opens files from anywhere, the web view is deliberately locked down: page JavaScript is disabled, and the document is blocked from loading any remote (`http`/`https`) content. So a hostile file can neither run scripts nor quietly phone home when you open it. The trade-off is that remote images and badges won't render; local images (relative to the file) do.

YAML front-matter at the top of a file (`--- … ---`) gets pulled out and rendered as a subdued monospaced block above the body. CommonMark has no concept of front-matter, so otherwise it parses as a giant H2 heading, which looks awful.

## Dependencies

Two direct Swift Package Manager dependencies, plus one transitive. `swift build` (which `build.sh` runs) resolves them all on the first build:

- [swiftlang/swift-cmark](https://github.com/swiftlang/swift-cmark) — the cmark-gfm parser, used to convert Markdown to HTML
- [migueldeicaza/SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) — the embedded terminal that powers `⌘E` quick edits
- [apple/swift-argument-parser](https://github.com/apple/swift-argument-parser) — pulled in transitively by swift-cmark

Versions are pinned in `Package.resolved` at the repository root.

## Contributing

This is a personal project I'm using to learn Swift and AppKit, so I'm not actively soliciting contributions. That said — if you spot something obviously wrong, or want to use the codebase as a starting point for your own viewer, fork away. To get a development environment going, follow the *Build from source* section above. There is no test target yet.

## Licence

MIT. See [LICENSE](LICENSE).
