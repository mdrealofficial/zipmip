import Foundation
#if canImport(FinderSync)
import FinderSync

/// FinderSync extension providing right-click contextual menus in macOS Finder
open class ZipMipFinderSyncExtension: FIFinderSync {
    public override init() {
        super.init()
        // Monitor all user mounted volumes and user directory
        let home = URL(fileURLWithPath: NSHomeDirectory())
        FIFinderSyncController.default().directoryURLs = [home]
    }

    // MARK: - Menu Provider

    open override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else { return nil }
        guard let selectedItems = FIFinderSyncController.default().selectedItemURLs(), !selectedItems.isEmpty else {
            return nil
        }

        let menu = NSMenu(title: "ZipMip")
        
        let allAreArchives = selectedItems.allSatisfy { url in
            let format = ArchiveFormat.from(url: url)
            return format != .unknown
        }

        if allAreArchives {
            // Archive Selected - Extraction options
            let extractHereItem = NSMenuItem(
                title: "⚡️ Extract Here",
                action: #selector(handleExtractHere(_:)),
                keyEquivalent: ""
            )
            extractHereItem.target = self
            menu.addItem(extractHereItem)

            if selectedItems.count == 1, let first = selectedItems.first {
                let name = first.deletingPathExtension().lastPathComponent
                let extractToFolderItem = NSMenuItem(
                    title: "📁 Extract to \"\(name)/\"",
                    action: #selector(handleExtractToFolder(_:)),
                    keyEquivalent: ""
                )
                extractToFolderItem.target = self
                menu.addItem(extractToFolderItem)
            }

            let extractPwdItem = NSMenuItem(
                title: "🔒 Extract with Password...",
                action: #selector(handleExtractWithPassword(_:)),
                keyEquivalent: ""
            )
            extractPwdItem.target = self
            menu.addItem(extractPwdItem)

            menu.addItem(NSMenuItem.separator())

            let openBrowserItem = NSMenuItem(
                title: "🔍 Open & Browse in ZipMip",
                action: #selector(handleOpenInZipMip(_:)),
                keyEquivalent: ""
            )
            openBrowserItem.target = self
            menu.addItem(openBrowserItem)
        } else {
            // Normal files/folders - Compression options
            let count = selectedItems.count
            let defaultName = count == 1 ? selectedItems[0].lastPathComponent : "Archive"

            let compressZipItem = NSMenuItem(
                title: "📦 Compress to \"\(defaultName).zip\"",
                action: #selector(handleCompressToZip(_:)),
                keyEquivalent: ""
            )
            compressZipItem.target = self
            menu.addItem(compressZipItem)

            let compress7zItem = NSMenuItem(
                title: "🗜️ Compress to \"\(defaultName).7z\" (Ultra)",
                action: #selector(handleCompressTo7z(_:)),
                keyEquivalent: ""
            )
            compress7zItem.target = self
            menu.addItem(compress7zItem)

            menu.addItem(NSMenuItem.separator())

            let compressOptionsItem = NSMenuItem(
                title: "⚙️ Compress with ZipMip...",
                action: #selector(handleCompressCustom(_:)),
                keyEquivalent: ""
            )
            compressOptionsItem.target = self
            menu.addItem(compressOptionsItem)
        }

        return menu
    }

    // MARK: - Actions

    @objc private func handleExtractHere(_ sender: Any?) {
        sendAction(.extractHere)
    }

    @objc private func handleExtractToFolder(_ sender: Any?) {
        sendAction(.extractToSubfolder)
    }

    @objc private func handleExtractWithPassword(_ sender: Any?) {
        sendAction(.extractWithPassword)
    }

    @objc private func handleOpenInZipMip(_ sender: Any?) {
        sendAction(.openInBrowser)
    }

    @objc private func handleCompressToZip(_ sender: Any?) {
        sendAction(.compressToZip)
    }

    @objc private func handleCompressTo7z(_ sender: Any?) {
        sendAction(.compressTo7z)
    }

    @objc private func handleCompressCustom(_ sender: Any?) {
        sendAction(.compressCustom)
    }

    private func sendAction(_ action: FinderSyncBridge.Action) {
        guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }
        let paths = items.map { $0.path }
        if let url = FinderSyncBridge.makeActionURL(action: action, targetPaths: paths) {
            NSWorkspace.shared.open(url)
        }
    }
}
#endif
