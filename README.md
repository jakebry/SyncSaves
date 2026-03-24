# SyncSaves

SyncSaves is a zero-friction, native macOS and iOS utility designed to seamlessly synchronize Nintendo DS, Game Boy Advance (GBA), and Game Boy Color (GBC) save files across multiple emulation platforms.

It acts as a bridge between local emulators (like OpenEmu on macOS), cloud-synced mobile emulators (like Delta on iOS), and physical modded hardware (like a 3DS running TWiLight Menu++).

## Core Features

- **Zero-Friction Auto-Discovery**: SyncSaves automatically scans your configured emulator and cloud directories. It uses fuzzy-matching to detect and link your game save files across platforms without requiring manual filename entry.
- **Format Translation**: Automatically handles format discrepancies between emulators. For example, it seamlessly strips the 122-byte DeSmuME footer from OpenEmu `.dsv` files when pushing to the cloud, and reconstructs it when pulling back to the Mac.
- **Cross-Platform Syncing**: 
  - **macOS (OpenEmu)**: Watches local save directories.
  - **iOS (Delta)**: Syncs via your native iCloud or Dropbox folder.
  - **Nintendo 3DS**: Pushes and pulls save data directly to your modded 3DS over local FTP.
- **Native UI & Widgets**: Built entirely in Swift and SwiftUI. Includes a menu bar utility for quick access and WidgetKit support for monitoring sync status directly from your Notification Center or Home Screen.

## Installation

1. Clone the repository to your local machine.
2. Open `Package.swift` or the generated Xcode project in Xcode.
3. Build and run the macOS or iOS target.

## Initial Setup

Upon first launch, SyncSaves will guide you through a simple onboarding process:
1. Select your local OpenEmu battery saves directory.
2. Select your designated Cloud sync directory (e.g., a folder in iCloud Drive or Dropbox).
3. (Optional) Provide the local IP address of your modded 3DS if you intend to use the FTP sync feature.

Once configured, the app will automatically scan both directories, link matching save files, and present a unified dashboard. A single "Sync All" button will resolve timestamp differences and update all locations to the most recent save state.

## Architecture

- **SyncSavesCore**: The shared business logic module responsible for file scanning, fuzzy-matching, timestamp comparison, and byte-level file conversion.
- **macOS App**: The primary configuration dashboard and sync engine.
- **iOS App**: A companion app for monitoring sync status on the go.
- **WidgetKit Extension**: Glanceable sync status widgets for both macOS and iOS.

## Requirements

- macOS 14.0+ / iOS 17.0+
- Xcode 15.0+
- For 3DS Sync: A modded 3DS running FTPD or a similar background FTP server.

## License

This project is for personal use and educational purposes.
