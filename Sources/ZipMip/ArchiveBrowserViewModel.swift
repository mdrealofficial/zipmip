import Foundation
import SwiftUI
import ZipMipCore
import QuickLook

#if canImport(AppKit)
import AppKit
#endif

@MainActor
public final class ArchiveBrowserViewModel: ObservableObject {
    @Published public var currentArchiveURL: URL?
    @Published public var format: ArchiveFormat = .unknown
    @Published public var allItems: [ArchiveItem] = []
    @Published public var currentFolderPath: String = ""
    @Published public var searchQuery: String = ""
    @Published public var selectedItemIDs: Set<String> = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var isPasswordRequired: Bool = false
    @Published public var pendingPasswordAttempt: String = ""
    @Published public var activeTaskProgress: TaskProgress?

    // QuickLook support
    @Published public var quickLookURL: URL?

    public init(archiveURL: URL? = nil) {
        if let archiveURL {
            loadArchive(at: archiveURL)
        }
    }

    // MARK: - Filtered & Directory-scoped items

    public var displayedItems: [ArchiveItem] {
        var items: [ArchiveItem]

        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            // Show only direct children of currentFolderPath
            items = allItems.filter { item in
                if currentFolderPath.isEmpty {
                    return item.parentPath.isEmpty
                } else {
                    return item.parentPath == currentFolderPath
                }
            }
        } else {
            // Global search filter
            let query = searchQuery.lowercased()
            items = allItems.filter { $0.name.lowercased().contains(query) || $0.path.lowercased().contains(query) }
        }

        // Folders first, then sorted alphabetically by name
        return items.sorted {
            if $0.isDirectory != $1.isDirectory {
                return $0.isDirectory && !$1.isDirectory
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    public var breadcrumbs: [String] {
        guard !currentFolderPath.isEmpty else { return [] }
        return currentFolderPath.components(separatedBy: "/")
    }

    public var totalUncompressedSize: Int64 {
        allItems.reduce(0) { $0 + $1.uncompressedSize }
    }

    public var totalCompressedSize: Int64 {
        allItems.reduce(0) { $0 + $1.compressedSize }
    }

    public var overallCompressionRatio: Double {
        guard totalUncompressedSize > 0 else { return 0 }
        let ratio = (1.0 - (Double(totalCompressedSize) / Double(totalUncompressedSize))) * 100.0
        return max(0, min(100, ratio))
    }

    // MARK: - Navigation

    public func navigateTo(folderPath: String) {
        currentFolderPath = folderPath
        selectedItemIDs.removeAll()
    }

    public func navigateUp() {
        guard !currentFolderPath.isEmpty else { return }
        let parent = (currentFolderPath as NSString).deletingLastPathComponent
        currentFolderPath = (parent == "." || parent == "") ? "" : parent
        selectedItemIDs.removeAll()
    }

    public func navigateToBreadcrumb(index: Int) {
        let parts = breadcrumbs
        guard index < parts.count else { return }
        let target = parts[0...index].joined(separator: "/")
        currentFolderPath = target
        selectedItemIDs.removeAll()
    }

    // MARK: - Operations

    public func loadArchive(at url: URL, password: String? = nil) {
        currentArchiveURL = url
        format = FormatDetector.detect(url: url)
        isLoading = true
        errorMessage = nil
        isPasswordRequired = false

        Task {
            do {
                let items = try await ArchiveEngine.shared.listArchive(at: url, password: password)
                self.allItems = items
                self.isLoading = false
            } catch ArchiveError.passwordRequired, ArchiveError.incorrectPassword {
                self.isPasswordRequired = true
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    public func submitPassword(_ password: String) {
        guard let url = currentArchiveURL else { return }
        loadArchive(at: url, password: password)
    }

    public func extractAll(to destination: URL? = nil, config: ExtractionConfig? = nil) {
        guard let archiveURL = currentArchiveURL else { return }
        let targetDir = destination ?? archiveURL.deletingLastPathComponent()
        let effectiveConfig = config ?? ExtractionConfig(
            destinationFolder: targetDir,
            createSubfolder: true,
            revealInFinder: true
        )

        performOperation(title: "Extracting All") { progressCallback in
            try await ArchiveEngine.shared.extract(
                archiveURL: archiveURL,
                items: nil,
                config: effectiveConfig,
                progressHandler: progressCallback
            )
        }
    }

    public func extractSelected(to destination: URL) {
        guard let archiveURL = currentArchiveURL, !selectedItemIDs.isEmpty else { return }
        let selectedPaths = Array(selectedItemIDs)
        let config = ExtractionConfig(
            destinationFolder: destination,
            createSubfolder: false,
            revealInFinder: true
        )

        performOperation(title: "Extracting Selected") { progressCallback in
            try await ArchiveEngine.shared.extract(
                archiveURL: archiveURL,
                items: selectedPaths,
                config: config,
                progressHandler: progressCallback
            )
        }
    }

    public func testIntegrity() {
        guard let archiveURL = currentArchiveURL else { return }

        performOperation(title: "Verifying Archive Integrity") { progressCallback in
            let valid = try await ArchiveEngine.shared.testArchive(
                archiveURL: archiveURL,
                password: nil,
                progressHandler: progressCallback
            )
            if valid {
                // Verified successfully
            }
        }
    }

    public func previewItem(_ item: ArchiveItem) {
        guard !item.isDirectory, let archiveURL = currentArchiveURL else { return }
        
        Task {
            do {
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                
                let config = ExtractionConfig(destinationFolder: tempDir, overwriteMode: .overwrite, revealInFinder: false)
                try await ArchiveEngine.shared.extract(archiveURL: archiveURL, items: [item.path], config: config)
                
                let extractedFileURL = tempDir.appendingPathComponent(item.path)
                if FileManager.default.fileExists(atPath: extractedFileURL.path) {
                    self.quickLookURL = extractedFileURL
                }
            } catch {
                self.errorMessage = "Could not preview item: \(error.localizedDescription)"
            }
        }
    }

    private func performOperation(title: String, block: @escaping (@Sendable @escaping (TaskProgress) -> Void) async throws -> Void) {
        isLoading = true
        activeTaskProgress = TaskProgress(title: title, phase: .pending)

        Task {
            do {
                try await block { progress in
                    Task { @MainActor in
                        self.activeTaskProgress = progress
                    }
                }
                self.isLoading = false
                self.activeTaskProgress = nil
            } catch {
                self.isLoading = false
                self.activeTaskProgress = nil
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
