# SyncSaves

A multiplatform Swift/SwiftUI app for macOS and iOS that synchronizes save files on-demand across multiple gaming systems:

## Supported Systems

1. **Nintendo DS** (.dsv ↔ .sav conversion)
   - OpenEmu (.dsv format with 122-byte DeSmuME footer)
   - iOS Delta (.sav format in Cloud folder)
   - Modded 3DS (.sav format via FTP)

2. **Game Boy Advance** (.sav format)
   - OpenEmu (mGBA core, raw .sav)
   - iOS Delta (.sav format in Cloud folder)

3. **Game Boy Color** (.sav format)
   - OpenEmu (Gambatte core, raw .sav)
   - iOS Delta (.sav format in Cloud folder)

## How It Works

### DS Files (Special Handling)
OpenEmu's .dsv file is exactly the same as a raw .sav file, but it has a **122-byte DeSmuME footer** appended to the end.

The sync logic for DS:
1. Checks modified timestamps across all locations
2. Finds the newest file
3. If newest is a .dsv: strips last 122 bytes → .sav → pushes to Cloud and 3DS
4. If newest is a .sav: extracts 122-byte footer from existing OpenEmu .dsv → appends to .sav → overwrites OpenEmu .dsv
5. Syncs all locations to the newest state

### GBA/GBC Files (Simple Copy)
OpenEmu's GBA/GBC cores output raw `.sav` files natively, so sync is straightforward:
1. Check modified timestamps
2. Find newest file
3. Copy to other locations

## Features

- **Multiplatform**: macOS app + iOS app with shared codebase
- **Widget Support**: WidgetKit widgets for both platforms
- **Multi-system**: Configure separate paths for DS, GBA, and GBC
- **On-demand Sync**: No background daemon
- **Settings UI**: Configure all paths and FTP details

## Project Structure

```
SyncSaves/
├── Sources/
│   ├── SyncSaves/           # Main app (macOS + iOS)
│   │   ├── SyncSavesApp.swift
│   │   ├── ContentView.swift
│   │   └── SettingsView.swift
│   ├── SyncSavesCore/       # Shared core logic
│   │   ├── Models.swift
│   │   ├── SettingsManager.swift
│   │   └── SyncManager.swift
│   └── SyncSavesWidget/     # Widget extension
│       └── SyncSavesWidget.swift
├── Tests/
│   └── SyncSavesTests/
└── Package.swift
```

## Requirements

- macOS 14.0+ / iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

1. Open the project in Xcode
2. Add Widget Extension target
3. Set up App Groups for widget/main app communication
4. Build and run

## Configuration

In the app settings, configure for each system:

### All Systems
- Game name (used to construct filenames)
- OpenEmu save folder path
- Cloud save folder path (for Delta iOS)

### DS Only
- 3DS FTP connection details (host, port, credentials)

## Future Enhancements

- Real FTP implementation (libcurl or Network framework)
- App Groups for widget/main app communication
- iCloud integration for settings sync
- Multiple game support per system
- Sync history and conflict resolution
- Background sync via URLSession
- Watch app companion