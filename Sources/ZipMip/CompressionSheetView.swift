import SwiftUI
import ZipMipCore

public struct CompressionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    public let sourceURLs: [URL]
    public let onCompress: (URL, CompressionConfig) -> Void

    @State private var format: ArchiveFormat = .zip
    @State private var compressionLevel: CompressionLevel = .normal
    @State private var enablePassword: Bool = false
    @State private var passwordText: String = ""
    @State private var encryptHeaders: Bool = false
    @State private var splitPreset: VolumeSplitPreset = .none
    @State private var customSplitSizeText: String = "500m"
    @State private var excludeMacMetadata: Bool = true
    @State private var archiveName: String = ""
    @State private var destinationDirectory: URL?

    public init(sourceURLs: [URL], onCompress: @escaping (URL, CompressionConfig) -> Void) {
        self.sourceURLs = sourceURLs
        self.onCompress = onCompress

        let defaultName: String
        if let first = sourceURLs.first {
            defaultName = sourceURLs.count == 1 ? first.deletingPathExtension().lastPathComponent : "Archive"
            _destinationDirectory = State(initialValue: first.deletingLastPathComponent())
        } else {
            defaultName = "Archive"
            _destinationDirectory = State(initialValue: FileManager.default.homeDirectoryForCurrentUser)
        }
        _archiveName = State(initialValue: defaultName)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "archivebox.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Compress Items")
                        .font(.headline)
                    Text("\(sourceURLs.count) \(sourceURLs.count == 1 ? "item" : "items") selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(20)
            .background(.ultraThinMaterial)

            Divider()

            // Main Form
            Form {
                Section("Archive Output") {
                    TextField("Archive Name", text: $archiveName)
                        .textFieldStyle(.roundedBorder)

                    Picker("Format", selection: $format) {
                        Text("ZIP (.zip) - Universal").tag(ArchiveFormat.zip)
                        Text("7-Zip (.7z) - High Ratio").tag(ArchiveFormat.sevenZip)
                        Text("TAR (.tar)").tag(ArchiveFormat.tar)
                        Text("GZip Tarball (.tar.gz)").tag(ArchiveFormat.tarGz)
                        Text("BZip2 Tarball (.tar.bz2)").tag(ArchiveFormat.tarBz2)
                        Text("XZ Tarball (.tar.xz)").tag(ArchiveFormat.tarXz)
                    }

                    Picker("Compression Level", selection: $compressionLevel) {
                        ForEach(CompressionLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }

                Section("Security & Encryption (AES-256)") {
                    Toggle("Password Protect Archive", isOn: $enablePassword)
                        .disabled(!format.canEncrypt)

                    if enablePassword {
                        SecureField("Password", text: $passwordText)
                            .textFieldStyle(.roundedBorder)

                        if format.canEncryptHeader {
                            Toggle("Encrypt file names (Hides file list)", isOn: $encryptHeaders)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Multi-Volume Splitting") {
                    Picker("Split into Volumes", selection: $splitPreset) {
                        ForEach(VolumeSplitPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .disabled(!format.canSplit)

                    if splitPreset == .custom {
                        TextField("Custom Size (e.g. 50m, 100m, 1g)", text: $customSplitSizeText)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section("Advanced Options") {
                    Toggle("Exclude macOS metadata (.DS_Store, __MACOSX)", isOn: $excludeMacMetadata)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            // Footer actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Compress") {
                    startCompression()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(archiveName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
        .frame(width: 480, height: 520)
    }

    private func startCompression() {
        guard let destDir = destinationDirectory else { return }
        
        let ext = format.defaultExtension
        let finalFilename = "\(archiveName).\(ext)"
        let destinationURL = destDir.appendingPathComponent(finalFilename)

        let splitSize: String? = {
            switch splitPreset {
            case .none: return nil
            case .custom: return customSplitSizeText.trimmingCharacters(in: .whitespaces)
            default: return splitPreset.rawValue
            }
        }()

        var excludes: [String] = []
        if excludeMacMetadata {
            excludes.append(contentsOf: [".DS_Store", "__MACOSX", ".Spotlight-V100", ".Trashes"])
        }

        let config = CompressionConfig(
            format: format,
            level: compressionLevel,
            password: enablePassword ? passwordText : nil,
            encryptHeaders: encryptHeaders,
            splitSize: splitSize,
            excludePatterns: excludes
        )

        dismiss()
        onCompress(destinationURL, config)
    }
}
