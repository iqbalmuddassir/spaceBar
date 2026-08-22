# SpaceBar

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

SpaceBar is an open source macOS menu bar app for reclaiming disk space without digging through Finder.

Developer machines fill up with regenerable junk: Xcode DerivedData, package caches, simulators, Docker build cache, temp files, and piles of screenshots. SpaceBar makes that reclaimable space visible and removable from one panel.

<p align="center">
  <img src="Docs/spacebar-panel.png" alt="SpaceBar panel showing free space, reclaimable caches, and cleanup actions" width="420" />
</p>

## What is SpaceBar

- Shows free disk space in the menu bar as a colored pill (green/orange/red, thresholds configurable)
- Scans known cache and cleanup locations and lists how much each can free, sorted by payoff
- Tells you how long ago each target was actually touched — "Built 20 minutes ago", "Downloaded 40 days ago"
- Pre-selects only what is old enough to be safe, and says why anything was held back
- Reclaims everything you ticked in one press, after a confirmation that lists exactly what goes
- Lets you review screenshots/recordings, downloaded installers (`.dmg`, `.pkg`, `.iso`), and project build folders (`node_modules`, `target`, `Pods`, `.venv`, etc.) item by item before deleting
- Offers three panel layouts — Gauge (capacity meter), Ledger (compact list), Map (treemap by size/recency)

Sizes use decimal GB (1 GB = 1,000³ bytes), same as System Settings → Storage.

## How it works

SpaceBar runs as a menu-bar-only app (no Dock icon). Click the pill to open the panel. On open it scans cleanup targets under your home folder (and process temp), measures reclaimable size, and shows only targets that have something to free. Cleaning uses a path allowlist so deletes stay limited to approved cache locations, and sensitive targets ask for a stronger confirmation.

Project build folders are found by walking your home directory (skipping `Library`, `Pictures`, `Movies`, `Music`, `Applications`) and matching regenerable folder names against the project file that proves a tool owns them — e.g. `node_modules` next to `package.json`, `target` next to `Cargo.toml`, `.venv` containing `pyvenv.cfg`. Nothing is pre-ticked, and a delete guard re-checks every path before removing it.

Some cleanups need Full Disk Access; emptying Trash needs Automation access to Finder. When either is missing, SpaceBar shows a guided overlay with a link to System Settings.

Free space in the menu bar reflects the **startup disk** only.

Build and run from source (see below). Unsigned local builds are for contributors until a notarized or Homebrew distribution exists. Release engineering steps live in [Docs/DISTRIBUTION.md](Docs/DISTRIBUTION.md).

Screenshots & recordings are matched by English-style filenames (`Screenshot…`, `Screen Recording…`). Localized capture names may be missed.

## How to use

1. Launch SpaceBar. The free-space pill appears in the menu bar.
2. Click the pill to open the panel and wait for the first scan.
3. Read the headline: how much you can recover, and what it costs.
4. Adjust the ticks — rows touched recently are left off deliberately.
5. Press **Clean selected**, review the confirmation list, and confirm.
6. Use the refresh control to rescan after cleaning.

### Build from source

```bash
cd ~/Projects/SpaceBar
xcodegen generate
xcodebuild -scheme SpaceBar -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/SpaceBar.app
```

Or open `SpaceBar.xcodeproj` in Xcode and run.

Requires macOS 14+ and Xcode 15+ (Command Line Tools); [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the project. Built with Swift, SwiftUI, and AppKit — no third-party runtime dependencies.

## How to contribute

Contributions are welcome — bug reports, feature ideas, and pull requests alike.

1. Fork the repo and create a branch off `main`.
2. Make your change, following the build steps above.
3. Run formatting, linting, and tests before opening a PR:

   ```bash
   swiftformat SpaceBar SpaceBarTests --config .swiftformat
   swiftlint lint --config .swiftlint.yml --strict SpaceBar SpaceBarTests
   xcodebuild -scheme SpaceBar -destination 'platform=macOS,arch=arm64' -derivedDataPath build test
   ```

4. Open a PR describing what changed and why.

Snapshot tests cover the panel and menu bar pill across three free-space levels (good/low/critical); references live in `SpaceBarTests/__Snapshots__/`. If your change affects the UI, update the snapshots rather than leaving them failing.

Found a bug or have an idea? Open an issue.

## Copyright

Copyright © 2026 Muddassir Iqbal. Licensed under the [MIT License](LICENSE).
