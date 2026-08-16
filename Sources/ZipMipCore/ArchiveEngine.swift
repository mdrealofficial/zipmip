import Foundation

/// Central coordinator for all archive listing, extraction, compression, and verification operations
public actor ArchiveEngine {
    public static let shared = ArchiveEngine()

    private let runner = SevenZipRunner.shared

    private init() {}

    /// Detects format and lists contents of the given archive
    public func listArchive(at url: URL, password: String? = nil) async throws -> [ArchiveItem] {
        return try await runner.listContents(archiveURL: url, password: password)
    }

    /// Extract archive with custom configuration and live progress updates
    public func extract(
        archiveURL: URL,
        items: [String]? = nil,
        config: ExtractionConfig,
        progressHandler: (@Sendable (TaskProgress) -> Void)? = nil
    ) async throws {
        try await runner.extract(
            archiveURL: archiveURL,
            items: items,
            config: config,
            progressHandler: progressHandler
        )
    }

    /// Compress multiple files/folders into a target archive
    public func compress(
        sources: [URL],
        destination: URL,
        config: CompressionConfig,
        progressHandler: (@Sendable (TaskProgress) -> Void)? = nil
    ) async throws {
        try await runner.compress(
            sources: sources,
            destinationURL: destination,
            config: config,
            progressHandler: progressHandler
        )
    }

    /// Test archive integrity
    public func testArchive(
        archiveURL: URL,
        password: String? = nil,
        progressHandler: (@Sendable (TaskProgress) -> Void)? = nil
    ) async throws -> Bool {
        return try await runner.testIntegrity(
            archiveURL: archiveURL,
            password: password,
            progressHandler: progressHandler
        )
    }

    /// Delete files inside an archive
    public func delete(archiveURL: URL, itemPaths: [String]) async throws {
        try await runner.deleteItems(archiveURL: archiveURL, itemPaths: itemPaths)
    }

    /// Quick extract helper for Finder right-click "Extract Here"
    public func extractHere(archiveURL: URL) async throws {
        let parentDir = archiveURL.deletingLastPathComponent()
        let config = ExtractionConfig(
            destinationFolder: parentDir,
            createSubfolder: true,
            revealInFinder: true
        )
        try await extract(archiveURL: archiveURL, config: config)
    }

    /// Quick compress helper for Finder right-click "Compress to ZIP"
    public func compressToZip(sources: [URL]) async throws {
        guard let first = sources.first else { return }
        let parentDir = first.deletingLastPathComponent()
        let baseName = sources.count == 1 ? first.deletingPathExtension().lastPathComponent : "Archive"
        let destURL = parentDir.appendingPathComponent("\(baseName).zip")

        let config = CompressionConfig(format: .zip, level: .normal)
        try await compress(sources: sources, destination: destURL, config: config)
    }

    /// Quick compress helper for Finder right-click "Compress to 7Z"
    public func compressTo7z(sources: [URL]) async throws {
        guard let first = sources.first else { return }
        let parentDir = first.deletingLastPathComponent()
        let baseName = sources.count == 1 ? first.deletingPathExtension().lastPathComponent : "Archive"
        let destURL = parentDir.appendingPathComponent("\(baseName).7z")

        let config = CompressionConfig(format: .sevenZip, level: .ultra)
        try await compress(sources: sources, destination: destURL, config: config)
    }
}
