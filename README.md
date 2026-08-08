# SpaceBar

SpaceBar is a macOS menu bar app for reclaiming disk space without digging through Finder.

Developer machines fill up with regenerable junk: Xcode DerivedData, package caches, simulators, Docker build cache, temp files, and piles of screenshots. Trash does not free space until you empty it. SpaceBar makes that reclaimable space visible and removable from one panel.

**Copyright © 2026 Muddassir Iqbal**

## What it does

- Shows free disk space in the menu bar as a colored pill (green when plenty is free, orange under 50%, red under 10%)
- Scans known cache and cleanup locations and lists how much each can free
- Deletes regenerable caches permanently after you confirm (so space frees immediately)
- Empties Trash via Finder when you choose Empty Trash
- Lets you review screenshots and screen recordings, select what to delete, and keep the rest

Sizes use decimal GB (1 GB = 1,000³ bytes), same style as System Settings → Storage.

## Tech stack

| Layer | Choice |
| --- | --- |
| Language | Swift 5 |
| UI | SwiftUI |
| Menu bar / panel | AppKit (`NSStatusItem`, `NSPanel`) so the free-space pill can stay colored |
| Project generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`) |
| Platform | Native macOS app (non-sandboxed, Hardened Runtime) |
| Tooling | SwiftFormat + SwiftLint (pre-build scripts, warnings as errors) |

No third-party runtime dependencies. Cleanup and sizing use Foundation, `Process` (`du`, `rm`, `simctl`, `docker`, Finder via AppleScript), and system APIs.

## Prerequisites

### To use SpaceBar

- macOS 14 Sonoma or later
- A built `SpaceBar.app` (from Releases or built locally)
- Full Disk Access for some cleanups; Automation access to Finder for Trash (prompted when needed)

Optional tools only matter if you clean those targets (Xcode, Docker, pnpm, and so on). SpaceBar skips targets that are not present.

### To build from source

- macOS 14+
- Xcode 15+ (Command Line Tools / `xcodebuild`)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

Optional: [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) and [SwiftLint](https://github.com/realm/SwiftLint) for local checks (also run automatically on build if installed).

## How it works

SpaceBar runs as a menu-bar-only app (no Dock icon). Click the pill to open the panel.

On open it scans cleanup targets under your home folder (and process temp), measures reclaimable size, and shows only targets that have something to free. Cleaning uses a path allowlist so deletes stay limited to approved cache locations. Sensitive targets ask for a stronger confirmation.

Screenshots and recordings are found by common macOS filenames (`Screenshot…`, `Screen Recording…`) in Desktop, Pictures, Movies, Downloads, and your custom screencapture folder if it is under your home directory. You pick what to remove; nothing is deleted until you confirm.

Some folders need Full Disk Access. Emptying Trash may need Automation access to Finder.

## How to use

1. Launch SpaceBar. The free-space pill appears in the menu bar.
2. Click the pill to open the panel. Wait for the first scan to finish.
3. Check the reclaimable total and the per-target list.
4. Click Clean on a target, read the confirmation, then confirm to delete permanently.
5. For screenshots and recordings, open Review, select items (or use age filters), then delete the selection.
6. Use the refresh control to rescan sizes and free space after cleaning.

Quit from the panel footer when you are done, or leave it running for a live free-space meter.

### Permissions

**Full Disk Access** (needed for some Library caches and related cleanups):

1. System Settings → Privacy & Security → Full Disk Access
2. Enable SpaceBar (add the `.app` with + if it is missing)
3. Quit and reopen SpaceBar

Debug builds are tied to the built binary path. After rebuilding, toggle access off/on or re-add the app.

**Automation → Finder** may be requested the first time Trash size or Empty Trash runs.

### Cleanup targets

| Area | Examples |
| --- | --- |
| General | User temp files, app caches |
| Xcode | DerivedData, Archives, iOS DeviceSupport, unavailable simulators |
| Android / Java | AVDs, Gradle caches |
| Packages | CocoaPods, SwiftPM, npm, pnpm |
| Tools | Homebrew, uv, pip, Docker build cache |
| Trash | Empty Trash |
| Media | Screenshots and screen recordings (review before delete) |

Caches are regenerable; the next build or install may take longer. Archives, AVDs, and Trash are treated as higher risk and use stronger confirmation.

## Build from source

```bash
cd ~/Projects/SpaceBar
xcodegen generate
xcodebuild -scheme SpaceBar -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/SpaceBar.app
```

Or open `SpaceBar.xcodeproj` in Xcode and run.

```bash
swiftformat SpaceBar --config .swiftformat
swiftlint lint --config .swiftlint.yml --strict SpaceBar
```

## Project layout

```
SpaceBar/
├── project.yml
├── SpaceBar.xcodeproj
└── SpaceBar/
    ├── SpaceBarApp.swift
    ├── Models/
    ├── Services/
    ├── Views/
    └── Utilities/
```

## License

Copyright © 2026 Muddassir Iqbal

Licensed under the [MIT License](LICENSE).
