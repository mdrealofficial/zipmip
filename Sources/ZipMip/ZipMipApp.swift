import SwiftUI
import ZipMipCore

#if canImport(AppKit)
import AppKit

final class ZipMipAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.servicesProvider = ZipMipServicesProvider.shared
        NSUpdateDynamicServices()
    }
}

final class ZipMipServicesProvider: NSObject, @unchecked Sendable {
    static let shared = ZipMipServicesProvider()

    @objc func compressToZipService(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = extractURLs(from: pboard)
        guard !urls.isEmpty else { return }
        Task {
            try? await ArchiveEngine.shared.compressToZip(sources: urls)
        }
    }

    @objc func compressTo7zService(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = extractURLs(from: pboard)
        guard !urls.isEmpty else { return }
        Task {
            try? await ArchiveEngine.shared.compressTo7z(sources: urls)
        }
    }

    @objc func extractHereService(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = extractURLs(from: pboard)
        guard let first = urls.first else { return }
        Task {
            try? await ArchiveEngine.shared.extractHere(archiveURL: first)
        }
    }

    private func extractURLs(from pboard: NSPasteboard) -> [URL] {
        guard let items = pboard.pasteboardItems else { return [] }
        var result: [URL] = []
        for item in items {
            if let string = item.string(forType: .fileURL), let url = URL(string: string) {
                result.append(url)
            } else if let string = item.string(forType: .string) {
                let url = URL(fileURLWithPath: string)
                if FileManager.default.fileExists(atPath: url.path) {
                    result.append(url)
                }
            }
        }
        return result
    }
}
#endif

@main
public struct ZipMipApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(ZipMipAppDelegate.self) private var appDelegate
    #endif

    @StateObject private var viewModel = ArchiveBrowserViewModel()
    @State private var showingCompressSheet = false
    @State private var compressSources: [URL] = []

    public init() {}

    public var body: some Scene {
        WindowGroup {
            ArchiveBrowserView(viewModel: viewModel)
                .frame(minWidth: 700, minHeight: 480)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDroppedProviders(providers)
                }
                .sheet(isPresented: $showingCompressSheet) {
                    CompressionSheetView(sourceURLs: compressSources) { dest, config in
                        Task {
                            try? await ArchiveEngine.shared.compress(
                                sources: compressSources,
                                destination: dest,
                                config: config
                            )
                        }
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            // File Menu Commands
            CommandGroup(replacing: .newItem) {
                Button("Open Archive...") {
                    openArchiveFilePicker()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("New Archive from Folder...") {
                    compressFolderPicker()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .importExport) {
                Button("Extract All...") {
                    viewModel.extractAll()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(viewModel.allItems.isEmpty)

                Button("Test Archive Integrity") {
                    viewModel.testIntegrity()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(viewModel.allItems.isEmpty)
            }
        }

        #if os(macOS)
        Settings {
            PreferencesView()
        }
        #endif
    }

    // MARK: - Handlers

    private func handleIncomingURL(_ url: URL) {
        if url.isFileURL {
            let format = ArchiveFormat.from(url: url)
            if format != .unknown {
                viewModel.loadArchive(at: url)
            }
        } else if let parsed = FinderSyncBridge.parseAction(from: url) {
            Task {
                switch parsed.action {
                case .extractHere:
                    if let first = parsed.paths.first {
                        try? await ArchiveEngine.shared.extractHere(archiveURL: first)
                    }
                case .extractToSubfolder:
                    if let first = parsed.paths.first {
                        let config = ExtractionConfig(
                            destinationFolder: first.deletingLastPathComponent(),
                            createSubfolder: true,
                            revealInFinder: true
                        )
                        try? await ArchiveEngine.shared.extract(archiveURL: first, config: config)
                    }
                case .extractWithPassword, .openInBrowser:
                    if let first = parsed.paths.first {
                        viewModel.loadArchive(at: first)
                    }
                case .compressToZip:
                    try? await ArchiveEngine.shared.compressToZip(sources: parsed.paths)
                case .compressTo7z:
                    try? await ArchiveEngine.shared.compressTo7z(sources: parsed.paths)
                case .compressCustom:
                    compressSources = parsed.paths
                    showingCompressSheet = true
                }
            }
        }
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                Task { @MainActor in
                    let format = ArchiveFormat.from(url: url)
                    if format != .unknown {
                        self.viewModel.loadArchive(at: url)
                    } else {
                        self.compressSources = [url]
                        self.showingCompressSheet = true
                    }
                }
            }
        }
        return true
    }

    private func openArchiveFilePicker() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.loadArchive(at: url)
        }
        #endif
    }

    private func compressFolderPicker() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Choose Items to Compress"
        if panel.runModal() == .OK {
            compressSources = panel.urls
            showingCompressSheet = true
        }
        #endif
    }
}
