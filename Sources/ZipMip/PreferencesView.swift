import SwiftUI
import ZipMipCore
#if canImport(AppKit)
import AppKit
#endif

public struct PreferencesView: View {
    @AppStorage("defaultCompressionFormat") private var defaultFormat: String = ArchiveFormat.zip.rawValue
    @AppStorage("defaultCompressionLevel") private var defaultLevel: Int = CompressionLevel.normal.rawValue
    @AppStorage("defaultOverwriteMode") private var defaultOverwrite: String = OverwriteMode.overwrite.rawValue
    @AppStorage("autoCreateSubfolder") private var autoSubfolder: Bool = true
    @AppStorage("deleteArchiveAfterExtraction") private var deleteAfterExtract: Bool = false
    @AppStorage("revealInFinderAfterExtraction") private var revealInFinder: Bool = true
    @AppStorage("enableFinderSyncMenu") private var enableFinderMenu: Bool = true

    public init() {}

    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            compressionTab
                .tabItem {
                    Label("Compression", systemImage: "archivebox")
                }

            extractionTab
                .tabItem {
                    Label("Extraction", systemImage: "arrow.down.doc")
                }

            finderIntegrationTab
                .tabItem {
                    Label("Finder Integration", systemImage: "macwindow")
                }
        }
        .padding(20)
        .frame(width: 480, height: 340)
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Reveal extracted items in Finder", isOn: $revealInFinder)
                Toggle("Move archive to Trash after successful extraction", isOn: $deleteAfterExtract)
            }
        }
        .formStyle(.grouped)
    }

    private var compressionTab: some View {
        Form {
            Section("Default Archive Settings") {
                Picker("Default Format", selection: $defaultFormat) {
                    Text("ZIP (.zip)").tag(ArchiveFormat.zip.rawValue)
                    Text("7-Zip (.7z)").tag(ArchiveFormat.sevenZip.rawValue)
                    Text("TAR (.tar)").tag(ArchiveFormat.tar.rawValue)
                    Text("GZip (.tar.gz)").tag(ArchiveFormat.tarGz.rawValue)
                }

                Picker("Default Compression Level", selection: $defaultLevel) {
                    ForEach(CompressionLevel.allCases) { level in
                        Text(level.displayName).tag(level.rawValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var extractionTab: some View {
        Form {
            Section("Extraction Behavior") {
                Picker("File Conflicts", selection: $defaultOverwrite) {
                    ForEach(OverwriteMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }

                Toggle("Automatically create enclosing subfolder", isOn: $autoSubfolder)
            }
        }
        .formStyle(.grouped)
    }

    private var finderIntegrationTab: some View {
        Form {
            Section("Context Menu (Right-Click)") {
                Toggle("Show ZipMip options in Finder context menu", isOn: $enableFinderMenu)

                Text("Enables 'Extract Here', 'Extract to Folder', and 'Compress to ZIP/7z' when right-clicking files in macOS Finder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Open macOS Extensions Settings...") {
                    #if canImport(AppKit)
                    if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                        NSWorkspace.shared.open(url)
                    }
                    #endif
                }
                .padding(.top, 4)
            }
        }
        .formStyle(.grouped)
    }
}
