import Cocoa
import FinderSync
import ZipMipCore

@objc(FinderSync)
public final class FinderSync: FIFinderSync {
    public override init() {
        super.init()
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let volumes = URL(fileURLWithPath: "/Volumes")
        FIFinderSyncController.default().directoryURLs = [home, volumes]
    }

    // MARK: - Contextual Menu

    public override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else { return nil }
        guard let items = FIFinderSyncController.default().selectedItemURLs(), !items.isEmpty else {
            return nil
        }

        let menu = NSMenu(title: "ZipMip")

        let allArchives = items.allSatisfy { url in
            ArchiveFormat.from(url: url) != .unknown
        }

        if allArchives {
            // Archive options
            let extractHere = NSMenuItem(
                title: "⚡️ Extract Here",
                action: #selector(onExtractHere),
                keyEquivalent: ""
            )
            extractHere.target = self
            menu.addItem(extractHere)

            if items.count == 1, let first = items.first {
                let name = first.deletingPathExtension().lastPathComponent
                let extractToFolder = NSMenuItem(
                    title: "📁 Extract to \"\(name)/\"",
                    action: #selector(onExtractToFolder),
                    keyEquivalent: ""
                )
                extractToFolder.target = self
                menu.addItem(extractToFolder)
            }

            let extractPwd = NSMenuItem(
                title: "🔒 Extract with Password...",
                action: #selector(onExtractWithPassword),
                keyEquivalent: ""
            )
            extractPwd.target = self
            menu.addItem(extractPwd)

            menu.addItem(NSMenuItem.separator())

            let openBrowser = NSMenuItem(
                title: "🔍 Open & Browse in ZipMip",
                action: #selector(onOpenInZipMip),
                keyEquivalent: ""
            )
            openBrowser.target = self
            menu.addItem(openBrowser)
        } else {
            // File & Folder Compression options
            let defaultName = items.count == 1 ? items[0].lastPathComponent : "Archive"

            let compressZip = NSMenuItem(
                title: "📦 Compress to \"\(defaultName).zip\"",
                action: #selector(onCompressToZip),
                keyEquivalent: ""
            )
            compressZip.target = self
            menu.addItem(compressZip)

            let compress7z = NSMenuItem(
                title: "🗜️ Compress to \"\(defaultName).7z\" (Ultra)",
                action: #selector(onCompressTo7z),
                keyEquivalent: ""
            )
            compress7z.target = self
            menu.addItem(compress7z)

            menu.addItem(NSMenuItem.separator())

            let compressCustom = NSMenuItem(
                title: "⚙️ Compress with ZipMip...",
                action: #selector(onCompressCustom),
                keyEquivalent: ""
            )
            compressCustom.target = self
            menu.addItem(compressCustom)
        }

        return menu
    }

    // MARK: - Actions

    @objc private func onExtractHere() {
        triggerAction(.extractHere)
    }

    @objc private func onExtractToFolder() {
        triggerAction(.extractToSubfolder)
    }

    @objc private func onExtractWithPassword() {
        triggerAction(.extractWithPassword)
    }

    @objc private func onOpenInZipMip() {
        triggerAction(.openInBrowser)
    }

    @objc private func onCompressToZip() {
        triggerAction(.compressToZip)
    }

    @objc private func onCompressTo7z() {
        triggerAction(.compressTo7z)
    }

    @objc private func onCompressCustom() {
        triggerAction(.compressCustom)
    }

    private func triggerAction(_ action: FinderSyncBridge.Action) {
        guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }
        let paths = items.map { $0.path }
        if let url = FinderSyncBridge.makeActionURL(action: action, targetPaths: paths) {
            NSWorkspace.shared.open(url)
        }
    }
}
