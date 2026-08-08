# SpaceBar

Menu bar utility for macOS that shows free disk space and helps reclaim storage from developer caches, trash, screenshots, and screen recordings.

**Copyright © 2026 Muddassir Iqbal**

## Features

- **Menu bar meter** — colored pill with free space (green &gt; 50%, orange &lt; 50%, red &lt; 10%)
- **Cleanup targets** — temp files, app caches, Xcode DerivedData / Archives / DeviceSupport, Gradle, CocoaPods, SwiftPM, npm, pnpm, Homebrew, uv, pip, unavailable simulators, Docker build cache
- **Empty Trash** — size via Finder; permanent empty when needed
- **Screenshots & recordings** — review Desktop / Pictures / Movies / Downloads, select what to delete or keep
- **Decimal GB** — sizes match System Settings Storage (1 GB = 1,000³ bytes)

## Requirements

- macOS 14+
- Xcode 15+ (or newer)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) to regenerate the project from `project.yml`

## Build & run

```bash
cd ~/Projects/SpaceBar
xcodegen generate
xcodebuild -scheme SpaceBar -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/SpaceBar.app
```

Or open `SpaceBar.xcodeproj` in Xcode and run.

The app is menu-bar only (`LSUIElement`) — no Dock icon. Click the free-space pill to open the panel.

## Permissions

Some cleanups need **Full Disk Access**:

1. System Settings → Privacy & Security → Full Disk Access  
2. Enable **SpaceBar** (add the `.app` with **+** if missing)  
3. Quit and reopen SpaceBar  

Debug / ad-hoc builds are tied to that binary path — after rebuilding, toggle access off/on or re-add the app.

Empty Trash / Finder sizing may also prompt for **Automation** access to Finder.

## Usage

1. Click the menu bar indicator to open SpaceBar  
2. Review reclaimable caches and media  
3. **Clean** permanently deletes safe regenerable caches (frees space immediately)  
4. **Review** screenshots & recordings → check items to delete, leave unchecked to keep  
5. Refresh rescans sizes and free space  

## Project layout

```
SpaceBar/
├── project.yml                 # XcodeGen spec
├── SpaceBar.xcodeproj
└── SpaceBar/
    ├── SpaceBarApp.swift       # App entry + status item bootstrap
    ├── Info.plist
    ├── Assets.xcassets/        # App icon
    ├── Models/
    ├── Services/               # Scan, clean, disk monitor, media
    ├── Views/
    └── Utilities/
```

## Notes

- Free space uses System Settings–style available capacity when possible  
- Moving items to Trash does not free space; SpaceBar deletes regenerable caches permanently after confirm  
- Menu bar colors require an AppKit status item (SwiftUI `MenuBarExtra` templates icons to monochrome)

## License

Copyright © 2026 Muddassir Iqbal

This project is licensed under the [MIT License](LICENSE).
