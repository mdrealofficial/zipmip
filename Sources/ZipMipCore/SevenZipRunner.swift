import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Thread-safe buffer for capturing streaming process output and progress tracking
private final class ProcessStreamBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var output: String = ""
    private var error: String = ""
    private var lastProgressUpdate: Date = Date.distantPast

    func appendOutput(_ string: String) {
        lock.lock()
        defer { lock.unlock() }
        output += string
    }

    func appendError(_ string: String) {
        lock.lock()
        defer { lock.unlock() }
        error += string
    }

    func getOutput() -> String {
        lock.lock()
        defer { lock.unlock() }
        return output
    }

    func getError() -> String {
        lock.lock()
        defer { lock.unlock() }
        return error
    }

    func shouldEmitProgress(interval: TimeInterval = 0.05) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        if now.timeIntervalSince(lastProgressUpdate) > interval {
            lastProgressUpdate = now
            return true
        }
        return false
    }
}

/// High-performance backend engine that interfaces with 7-Zip (7zz)
public final class SevenZipRunner: Sendable {
    public static let shared = SevenZipRunner()

    private init() {}

    /// Locates the 7zz binary on macOS
    public func locateBinary() -> URL? {
        let fileManager = FileManager.default

        // 1. Check inside App Bundle Frameworks / Resources / bin
        if let resourceURL = Bundle.main.resourceURL {
            let bundleBinary = resourceURL.appendingPathComponent("bin/7zz")
            if fileManager.isExecutableFile(atPath: bundleBinary.path) {
                return bundleBinary
            }
        }

        // 2. Check standard Homebrew paths (Apple Silicon & Intel)
        let homebrewArm = URL(fileURLWithPath: "/opt/homebrew/bin/7zz")
        if fileManager.isExecutableFile(atPath: homebrewArm.path) {
            return homebrewArm
        }

        let homebrewIntel = URL(fileURLWithPath: "/usr/local/bin/7zz")
        if fileManager.isExecutableFile(atPath: homebrewIntel.path) {
            return homebrewIntel
        }

        // 3. Search in system PATH
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.components(separatedBy: ":") {
                let candidate = URL(fileURLWithPath: dir).appendingPathComponent("7zz")
                if fileManager.isExecutableFile(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return nil
    }

    /// List all entries inside an archive
    public func listContents(archiveURL: URL, password: String? = nil) async throws -> [ArchiveItem] {
        guard let binaryURL = locateBinary() else {
            throw ArchiveError.binaryNotFound
        }

        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw ArchiveError.fileNotFound(archiveURL.path)
        }

        let format = ArchiveFormat.from(url: archiveURL)
        if format == .tarGz || format == .tarBz2 || format == .tarXz || format == .tarZst || format == .tar {
            // Use native tar for deep inspection of tarball files
            if let tarItems = try? await listTarballContents(archiveURL: archiveURL), !tarItems.isEmpty {
                return tarItems
            }
        }

        var arguments = ["l", "-slt", "-ba"]
        if let password = password, !password.isEmpty {
            arguments.append("-p\(password)")
        } else {
            arguments.append("-p-") // Don't prompt interactively
        }
        arguments.append(archiveURL.path)

        let output = try await runProcess(executable: binaryURL, arguments: arguments)
        let items = parseSltOutput(output)

        // If it's a tarball and contains just a single .tar entry, expand it
        if items.count == 1, let first = items.first, first.name.hasSuffix(".tar") {
            if let tarItems = try? await listTarballContents(archiveURL: archiveURL), !tarItems.isEmpty {
                return tarItems
            }
        }

        return items
    }

    /// Native macOS tar reader for tarballs (.tar, .tar.gz, .tar.bz2, .tar.xz)
    private func listTarballContents(archiveURL: URL) async throws -> [ArchiveItem] {
        let tarURL = URL(fileURLWithPath: "/usr/bin/tar")
        guard FileManager.default.isExecutableFile(atPath: tarURL.path) else { return [] }

        let output = try await runProcess(executable: tarURL, arguments: ["-tvf", archiveURL.path])
        return parseTarOutput(output)
    }

    /// Extract archive to destination folder
    public func extract(
        archiveURL: URL,
        items: [String]? = nil,
        config: ExtractionConfig,
        progressHandler: (@Sendable (TaskProgress) -> Void)? = nil
    ) async throws {
        guard let binaryURL = locateBinary() else {
            throw ArchiveError.binaryNotFound
        }

        let fileManager = FileManager.default
        var destination = config.destinationFolder

        if config.createSubfolder {
            let folderName = archiveURL.deletingPathExtension().lastPathComponent
            destination = destination.appendingPathComponent(folderName, isDirectory: true)
        }

        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        var arguments = ["x", "-bsp1"]

        switch config.overwriteMode {
        case .overwrite:
            arguments.append("-y") // assume Yes on all queries
        case .skip:
            arguments.append("-aos") // skip existing files
        case .rename:
            arguments.append("-aou") // auto rename existing
        case .ask:
            arguments.append("-y")
        }

        if let password = config.password, !password.isEmpty {
            arguments.append("-p\(password)")
        } else {
            arguments.append("-p-")
        }

        arguments.append("-o\(destination.path)")
        arguments.append(archiveURL.path)

        if let items = items, !items.isEmpty {
            arguments.append(contentsOf: items)
        }

        progressHandler?(TaskProgress(title: "Extracting \(archiveURL.lastPathComponent)", phase: .analyzing))

        _ = try await runStreamingProcess(
            executable: binaryURL,
            arguments: arguments,
            progressHandler: progressHandler
        )

        if config.deleteArchiveAfterExtraction {
            try? fileManager.trashItem(at: archiveURL, resultingItemURL: nil)
        }

        if config.revealInFinder {
            Task { @MainActor in
                #if canImport(AppKit)
                NSWorkspace.shared.activateFileViewerSelecting([destination])
                #endif
            }
        }
    }

    /// Compress source files/folders into a new archive
    public func compress(
        sources: [URL],
        destinationURL: URL,
        config: CompressionConfig,
        progressHandler: (@Sendable (TaskProgress) -> Void)? = nil
    ) async throws {
        guard let binaryURL = locateBinary() else {
            throw ArchiveError.binaryNotFound
        }

        guard !sources.isEmpty else {
            throw ArchiveError.fileNotFound("No source files provided for compression")
        }

        // Check if this is a compound tarball format (.tar.gz, .tar.bz2, .tar.xz)
        if config.format == .tarGz || config.format == .tarBz2 || config.format == .tarXz {
            let tempTarURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tar")
            defer { try? FileManager.default.removeItem(at: tempTarURL) }

            // Step 1: Create TAR
            let tarConfig = CompressionConfig(format: .tar, level: .store, excludePatterns: config.excludePatterns)
            try await compress(sources: sources, destinationURL: tempTarURL, config: tarConfig, progressHandler: progressHandler)

            // Step 2: Compress TAR with GZip / BZip2 / XZ
            var subFormat = "gzip"
            if config.format == .tarBz2 { subFormat = "bzip2" }
            if config.format == .tarXz { subFormat = "xz" }

            var subArgs = ["a", "-t\(subFormat)", "-bsp1", "-mx=\(config.level.rawValue)"]
            subArgs.append(destinationURL.path)
            subArgs.append(tempTarURL.path)

            _ = try await runStreamingProcess(
                executable: binaryURL,
                arguments: subArgs,
                progressHandler: progressHandler
            )
            return
        }

        // Standard Single-Step Compression (7z, zip, tar, wim)
        var typeFlag = "zip"
        switch config.format {
        case .sevenZip:
            typeFlag = "7z"
        case .zip:
            typeFlag = "zip"
        case .tar:
            typeFlag = "tar"
        case .gz:
            typeFlag = "gzip"
        case .bz2:
            typeFlag = "bzip2"
        case .xz:
            typeFlag = "xz"
        case .wim:
            typeFlag = "wim"
        default:
            typeFlag = "7z"
        }

        var arguments = ["a", "-t\(typeFlag)", "-bsp1", "-mx=\(config.level.rawValue)"]

        // Multi-threading
        if config.threadCount > 0 {
            arguments.append("-mmt=\(config.threadCount)")
        }

        // Password & Header encryption
        if let password = config.password, !password.isEmpty {
            arguments.append("-p\(password)")
            if config.format == .sevenZip && config.encryptHeaders {
                arguments.append("-mhe=on")
            }
        }

        // Multi-volume split
        if let split = config.splitSize, !split.isEmpty && split != "none" {
            arguments.append("-v\(split)")
        }

        // Exclude system files (.DS_Store, __MACOSX)
        for pattern in config.excludePatterns {
            arguments.append("-xr!\(pattern)")
        }

        // Solid archive
        if config.format == .sevenZip {
            arguments.append(config.solidArchive ? "-ms=on" : "-ms=off")
        }

        // Destination and sources
        arguments.append(destinationURL.path)
        for source in sources {
            arguments.append(source.path)
        }

        progressHandler?(TaskProgress(title: "Compressing to \(destinationURL.lastPathComponent)", phase: .analyzing))

        _ = try await runStreamingProcess(
            executable: binaryURL,
            arguments: arguments,
            progressHandler: progressHandler
        )
    }

    /// Test archive integrity
    public func testIntegrity(
        archiveURL: URL,
        password: String? = nil,
        progressHandler: (@Sendable (TaskProgress) -> Void)? = nil
    ) async throws -> Bool {
        guard let binaryURL = locateBinary() else {
            throw ArchiveError.binaryNotFound
        }

        var arguments = ["t", "-bsp1"]
        if let password = password, !password.isEmpty {
            arguments.append("-p\(password)")
        } else {
            arguments.append("-p-")
        }
        arguments.append(archiveURL.path)

        progressHandler?(TaskProgress(title: "Testing \(archiveURL.lastPathComponent)", phase: .analyzing))

        _ = try await runStreamingProcess(
            executable: binaryURL,
            arguments: arguments,
            progressHandler: progressHandler
        )

        return true
    }

    /// Delete specific items inside an archive
    public func deleteItems(archiveURL: URL, itemPaths: [String]) async throws {
        guard let binaryURL = locateBinary() else {
            throw ArchiveError.binaryNotFound
        }

        var arguments = ["d", archiveURL.path]
        arguments.append(contentsOf: itemPaths)

        _ = try await runProcess(executable: binaryURL, arguments: arguments)
    }

    // MARK: - Process Execution Helpers

    private func runProcess(executable: URL, arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments

            let pipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errPipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errOutput = String(data: errData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    if errOutput.localizedCaseInsensitiveContains("wrong password") ||
                       output.localizedCaseInsensitiveContains("wrong password") {
                        continuation.resume(throwing: ArchiveError.incorrectPassword)
                    } else if errOutput.localizedCaseInsensitiveContains("password") ||
                              output.localizedCaseInsensitiveContains("enter password") {
                        continuation.resume(throwing: ArchiveError.passwordRequired)
                    } else {
                        continuation.resume(throwing: ArchiveError.executionFailed(errOutput.isEmpty ? output : errOutput, exitCode: process.terminationStatus))
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func runStreamingProcess(
        executable: URL,
        arguments: [String],
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> String {
        let buffer = ProcessStreamBuffer()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments

            let pipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errPipe

            pipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty else { return }
                if let str = String(data: data, encoding: .utf8) {
                    buffer.appendOutput(str)
                    
                    // Parse progress line (e.g., "  45% 120 / 300 files")
                    let (percent, currentFile) = self.parseProgressLine(str)
                    if let percent = percent {
                        if buffer.shouldEmitProgress() {
                            let progress = TaskProgress(
                                title: "Processing...",
                                phase: .processing(
                                    percentage: percent,
                                    currentFile: currentFile ?? "",
                                    speedBytesPerSec: 0,
                                    bytesProcessed: 0,
                                    totalBytes: 0
                                )
                            )
                            progressHandler?(progress)
                        }
                    }
                }
            }

            errPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty else { return }
                if let str = String(data: data, encoding: .utf8) {
                    buffer.appendError(str)
                }
            }

            do {
                try process.run()
                process.waitUntilExit()

                pipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil

                let accumulatedOutput = buffer.getOutput()
                let accumulatedError = buffer.getError()

                if process.terminationStatus == 0 {
                    progressHandler?(TaskProgress(title: "Complete", phase: .completed))
                    continuation.resume(returning: accumulatedOutput)
                } else {
                    if accumulatedError.localizedCaseInsensitiveContains("wrong password") ||
                       accumulatedOutput.localizedCaseInsensitiveContains("wrong password") {
                        continuation.resume(throwing: ArchiveError.incorrectPassword)
                    } else if accumulatedError.localizedCaseInsensitiveContains("password") ||
                              accumulatedOutput.localizedCaseInsensitiveContains("enter password") {
                        continuation.resume(throwing: ArchiveError.passwordRequired)
                    } else {
                        continuation.resume(throwing: ArchiveError.executionFailed(accumulatedError.isEmpty ? accumulatedOutput : accumulatedError, exitCode: process.terminationStatus))
                    }
                }
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Output Parsers

    private func parseProgressLine(_ text: String) -> (Double?, String?) {
        // Look for percentage patterns: " 42%" or "99%"
        let regex = try? NSRegularExpression(pattern: #"(\d+)\s*%"#)
        if let match = regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range(at: 1), in: text), let val = Double(text[range]) {
                let percent = min(1.0, max(0.0, val / 100.0))
                return (percent, nil)
            }
        }
        return (nil, nil)
    }

    private func parseSltOutput(_ output: String) -> [ArchiveItem] {
        var items: [ArchiveItem] = []
        let blocks = output.components(separatedBy: "\n\n")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for block in blocks {
            var path = ""
            var isFolder = false
            var size: Int64 = 0
            var packedSize: Int64 = 0
            var date: Date? = nil
            var attributes = ""
            var crc = ""
            var encrypted = false
            var method = ""

            let lines = block.components(separatedBy: .newlines)
            for line in lines {
                guard let separatorIndex = line.firstIndex(of: "=") else { continue }
                let key = line[..<separatorIndex].trimmingCharacters(in: .whitespaces)
                let value = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespaces)

                switch key {
                case "Path":
                    path = value
                case "Folder":
                    isFolder = (value == "+" || value == "1")
                case "Size":
                    size = Int64(value) ?? 0
                case "Packed Size":
                    packedSize = Int64(value) ?? 0
                case "Modified":
                    date = dateFormatter.date(from: value)
                case "Attributes":
                    attributes = value
                    if attributes.contains("D") { isFolder = true }
                case "CRC":
                    crc = value
                case "Encrypted":
                    encrypted = (value == "+" || value == "1")
                case "Method":
                    method = value
                default:
                    break
                }
            }

            if !path.isEmpty {
                let item = ArchiveItem(
                    path: path,
                    isDirectory: isFolder,
                    uncompressedSize: size,
                    compressedSize: packedSize,
                    modifiedDate: date,
                    attributes: attributes,
                    crc: crc,
                    isEncrypted: encrypted,
                    method: method
                )
                items.append(item)
            }
        }

        return items
    }

    private func parseTarOutput(_ output: String) -> [ArchiveItem] {
        var items: [ArchiveItem] = []
        let lines = output.components(separatedBy: .newlines)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d HH:mm"

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format example:
            // drwxr-xr-x  0 user staff       0 Aug 16 09:31 docs/
            // -rw-r--r--  0 user staff      22 Aug 16 09:31 docs/readme.md
            let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard tokens.count >= 6 else { continue }

            let permissions = tokens[0]
            let isDirectory = permissions.hasPrefix("d") || trimmed.hasSuffix("/")
            let size = Int64(tokens[4]) ?? 0

            // The path starts from token index 5 or later after date
            // Usually tokens: [perms, links, owner, group, size, month, day, time/year, path...]
            let path: String
            if tokens.count >= 9 {
                path = tokens[8...].joined(separator: " ")
            } else if tokens.count >= 6 {
                path = tokens.last ?? ""
            } else {
                continue
            }

            let cleanPath = path.hasSuffix("/") ? String(path.dropLast()) : path
            guard !cleanPath.isEmpty else { continue }

            items.append(ArchiveItem(
                path: cleanPath,
                isDirectory: isDirectory,
                uncompressedSize: size,
                compressedSize: size / 2, // approximation for tarball inner item
                modifiedDate: nil,
                attributes: permissions,
                crc: nil,
                isEncrypted: false,
                method: "tar"
            ))
        }

        return items
    }
}
