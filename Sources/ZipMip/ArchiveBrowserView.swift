import SwiftUI
import ZipMipCore
import QuickLook

public struct ArchiveBrowserView: View {
    @ObservedObject var viewModel: ArchiveBrowserViewModel
    @State private var showingCompressSheet = false
    @State private var showingSettings = false
    @State private var selectedItemForPreview: ArchiveItem?

    public init(viewModel: ArchiveBrowserViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Breadcrumb Navigation Bar
            breadcrumbBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)

            Divider()

            // MARK: - Content Table
            if viewModel.isLoading && viewModel.allItems.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Reading archive contents...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.allItems.isEmpty {
                emptyStateView
            } else {
                tableContentView
            }

            Divider()

            // MARK: - Status Bar
            statusBar
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
        }
        // Floating Progress HUD
        .overlay(alignment: .bottomTrailing) {
            if let progress = viewModel.activeTaskProgress {
                ProgressHUDView(progress: progress)
                    .padding(20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Password Prompt Sheet
        .sheet(isPresented: $viewModel.isPasswordRequired) {
            PasswordPromptSheet { password in
                viewModel.submitPassword(password)
            }
        }
        // Toolbar
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    viewModel.navigateUp()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(viewModel.currentFolderPath.isEmpty)
                .help("Go to Parent Folder")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.extractAll()
                } label: {
                    Label("Extract All", systemImage: "arrow.down.doc")
                }
                .disabled(viewModel.allItems.isEmpty)
                .help("Extract all files to folder")

                Button {
                    if let first = viewModel.displayedItems.first(where: { viewModel.selectedItemIDs.contains($0.id) }) {
                        viewModel.previewItem(first)
                    }
                } label: {
                    Label("Preview", systemImage: "eye")
                }
                .disabled(viewModel.selectedItemIDs.isEmpty)
                .help("QuickLook Preview (Spacebar)")

                Button {
                    viewModel.testIntegrity()
                } label: {
                    Label("Test", systemImage: "checkmark.shield")
                }
                .disabled(viewModel.allItems.isEmpty)
                .help("Test archive integrity")

                Menu {
                    Button("Extract Selected...") {
                        selectDestinationAndExtractSelected()
                    }
                    .disabled(viewModel.selectedItemIDs.isEmpty)

                    Divider()

                    Button("View Archive Info...") {
                        // Info sheet
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .searchable(text: $viewModel.searchQuery, placement: .toolbar, prompt: "Search files in archive")
        .quickLookPreview($viewModel.quickLookURL)
    }

    // MARK: - Breadcrumb View

    private var breadcrumbBar: some View {
        HStack(spacing: 6) {
            Button {
                viewModel.navigateTo(folderPath: "")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(.tint)
                    Text(viewModel.currentArchiveURL?.lastPathComponent ?? "Archive")
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.plain)

            ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.offset) { index, segment in
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Button {
                    viewModel.navigateToBreadcrumb(index: index)
                } label: {
                    Text(segment)
                        .foregroundStyle(index == viewModel.breadcrumbs.count - 1 ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if let format = viewModel.format as ArchiveFormat?, format != .unknown {
                Text(format.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }
        }
        .font(.subheadline)
    }

    // MARK: - Table View

    private var tableContentView: some View {
        Table(viewModel.displayedItems, selection: $viewModel.selectedItemIDs) {
            TableColumn("Name") { item in
                HStack(spacing: 8) {
                    Image(systemName: item.isDirectory ? "folder.fill" : fileIcon(for: item.fileExtension))
                        .foregroundStyle(item.isDirectory ? Color.accentColor : .secondary)
                        .frame(width: 18)

                    Text(item.name)
                        .lineLimit(1)

                    if item.isEncrypted {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if item.isDirectory {
                        viewModel.navigateTo(folderPath: item.path)
                    } else {
                        viewModel.previewItem(item)
                    }
                }
            }
            .width(min: 200, ideal: 300)

            TableColumn("Original Size") { item in
                Text(item.formattedUncompressedSize)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(ideal: 100)

            TableColumn("Packed Size") { item in
                Text(item.formattedCompressedSize)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(ideal: 100)

            TableColumn("Ratio") { item in
                if !item.isDirectory && item.uncompressedSize > 0 {
                    HStack(spacing: 6) {
                        ProgressView(value: item.compressionRatioPercentage, total: 100)
                            .progressViewStyle(.linear)
                            .frame(width: 50)
                        Text(String(format: "%.0f%%", item.compressionRatioPercentage))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("--")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .width(ideal: 110)

            TableColumn("Date Modified") { item in
                Text(item.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .width(ideal: 140)

            TableColumn("CRC-32") { item in
                Text(item.crc ?? "--")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .width(ideal: 80)
        }
        .contextMenu(forSelectionType: String.self) { selectedIDs in
            Button("Extract Selected...") {
                selectDestinationAndExtractSelected()
            }
            Button("QuickLook Preview") {
                if let firstID = selectedIDs.first,
                   let item = viewModel.allItems.first(where: { $0.id == firstID }) {
                    viewModel.previewItem(item)
                }
            }
            Divider()
            Button("Copy File Name") {
                #if canImport(AppKit)
                if let firstID = selectedIDs.first,
                   let item = viewModel.allItems.first(where: { $0.id == firstID }) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.name, forType: .string)
                }
                #endif
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Text("\(viewModel.displayedItems.count) items")
                .foregroundStyle(.secondary)

            if !viewModel.selectedItemIDs.isEmpty {
                Text("•")
                    .foregroundStyle(.tertiary)
                Text("\(viewModel.selectedItemIDs.count) selected")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.totalUncompressedSize > 0 {
                HStack(spacing: 8) {
                    Text("\(ByteCountFormatter.string(fromByteCount: viewModel.totalUncompressedSize, countStyle: .file))")
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(ByteCountFormatter.string(fromByteCount: viewModel.totalCompressedSize, countStyle: .file))")
                        .foregroundStyle(.primary)
                    Text(String(format: "(%.1f%% saved)", viewModel.overallCompressionRatio))
                        .foregroundStyle(.green)
                        .fontWeight(.medium)
                }
                .font(.caption.monospacedDigit())
            }
        }
        .font(.caption)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)

            Text("No Archive Open")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Drag and drop any ZIP, RAR, 7Z, TAR, or GZ archive here, or open from the menu.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button("Open Archive...") {
                openArchiveDialog()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Helpers

    private func fileIcon(for ext: String) -> String {
        switch ext {
        case "png", "jpg", "jpeg", "webp", "gif", "svg", "heic":
            return "photo.fill"
        case "mp4", "mov", "mkv", "avi", "webm":
            return "film.fill"
        case "mp3", "m4a", "wav", "flac", "aac":
            return "music.note"
        case "pdf":
            return "doc.richtext.fill"
        case "txt", "md", "json", "xml", "csv", "yaml", "yml":
            return "doc.text.fill"
        case "swift", "py", "js", "ts", "cpp", "c", "h", "html", "css", "go", "rs":
            return "chevron.left.forwardslash.chevron.right"
        case "zip", "rar", "7z", "tar", "gz", "xz", "bz2":
            return "archivebox.fill"
        default:
            return "doc.fill"
        }
    }

    private func selectDestinationAndExtractSelected() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Extract Here"
        if panel.runModal() == .OK, let target = panel.url {
            viewModel.extractSelected(to: target)
        }
        #endif
    }

    private func openArchiveDialog() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Archive"
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.loadArchive(at: url)
        }
        #endif
    }
}
