# ZipMip 🗜️
> **The Universal Archive Manager for macOS** built with modern **Swift 6 & SwiftUI**. Minimalist design, native Finder right-click integration, and full WinRAR / 7-Zip power features.

---

## 🌟 Key Features

- **🚀 Complete Format Support**:
  - **Extract**: `.zip`, `.rar` (RAR4 & RAR5), `.7z`, `.tar`, `.tar.gz` (`.tgz`), `.tar.bz2` (`.tbz2`), `.tar.xz` (`.txz`), `.tar.zst`, `.gz`, `.bz2`, `.xz`, `.zst`, `.iso`, `.dmg`, `.cab`, `.cpio`, `.wim`, `.arj`, `.lha`, and multi-part archives (`.001`, `.part1.rar`, `.z01`).
  - **Create / Compress**: `.zip`, `.7z`, `.tar`, `.tar.gz`, `.tar.bz2`, `.tar.xz`, and `.wim`.
- **⚡️ Finder Right-Click Integration**:
  - Right-click any archive in macOS Finder:
    - `⚡️ Extract Here`
    - `📁 Extract to "[Archive Name]/"`
    - `🔒 Extract with Password...`
    - `🔍 Open & Browse in ZipMip`
  - Right-click any file or folder:
    - `📦 Compress to "[Item].zip"`
    - `🗜️ Compress to "[Item].7z" (Ultra)`
    - `⚙️ Compress with ZipMip...`
- **🔒 AES-256 Encryption & Password Protection**:
  - Full support for encrypted ZIP and 7Z archives.
  - **Header Encryption (Encrypt File Names)**: Hide folder/file names until unlocked.
- **✂️ Multi-Volume Splitting**:
  - Split archives into chunks with presets (10MB, 100MB, 700MB CD, 4.7GB DVD, 4GB FAT32) or custom sizes (e.g. `250m`, `1.5g`).
- **🛡️ Archive Integrity & CRC Verification**:
  - Test archive validity and CRC-32 checksums without extracting to disk.
- **👁️ Native Spacebar QuickLook**:
  - Preview photos, PDFs, code, and videos directly from inside archives without manual extraction.
- **🎨 Minimalist macOS Design**:
  - Clean translucent toolbar, breadcrumb navigation, search filter, size metrics, and floating throughput HUD.

---

## 🏗️ Architecture

```
zipmip/
├── Sources/
│   ├── ZipMipCore/                # Core Archive Engine & Bridges
│   │   ├── ArchiveFormat.swift    # Supported formats & capabilities
│   │   ├── FormatDetector.swift   # Binary magic byte detection
│   │   ├── SevenZipRunner.swift   # 7zz & streaming process runner
│   │   ├── ArchiveEngine.swift    # Actor orchestrating all archive tasks
│   │   ├── CompressionConfig.swift# Levels, algorithms, splitting options
│   │   └── FinderSyncBridge.swift # FinderSync URL scheme & IPC
│   ├── ZipMipFinderSync/          # FinderSync right-click extension target
│   │   └── FinderSync.swift       # FIFinderSync context menu injection
│   └── ZipMip/                    # SwiftUI macOS Application
│       ├── ZipMipApp.swift        # App entry point, menu bar commands, URL router
│       ├── ArchiveBrowserView.swift # File browser, breadcrumbs, search, status bar
│       ├── CompressionSheetView.swift # WinRAR / 7-Zip compression inspector
│       ├── PasswordPromptSheet.swift # Decryption key modal
│       ├── ProgressHUDView.swift  # Floating throughput & progress pill
│       └── PreferencesView.swift  # Settings & defaults
├── Tests/                         # Comprehensive unit test suite
└── scripts/
    └── build_app.sh               # Standalone .app bundle builder
```

---

## 🚀 Building & Running

### 1. Run Unit Tests
```bash
swift test
```

### 2. Build Release App Bundle
```bash
./scripts/build_app.sh
```

### 3. Launch the Application
```bash
open build/ZipMip.app
```

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘ + O` | Open Archive file picker |
| `⌘ + N` | Create New Archive from folder |
| `⇧ + ⌘ + E` | Extract All |
| `⇧ + ⌘ + T` | Test Archive Integrity |
| `Spacebar` | QuickLook Preview selected file |
| `⌘ + F` | Search inside archive |
| `⌘ + ,` | Preferences / Settings |
