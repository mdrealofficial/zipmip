import XCTest
@testable import ZipMipCore

final class ZipMipTests: XCTestCase {
    
    func testFormatDetectionFromExtensions() {
        XCTAssertEqual(ArchiveFormat.from(url: URL(fileURLWithPath: "photo.zip")), .zip)
        XCTAssertEqual(ArchiveFormat.from(url: URL(fileURLWithPath: "backup.7z")), .sevenZip)
        XCTAssertEqual(ArchiveFormat.from(url: URL(fileURLWithPath: "archive.rar")), .rar)
        XCTAssertEqual(ArchiveFormat.from(url: URL(fileURLWithPath: "package.tar.gz")), .tarGz)
        XCTAssertEqual(ArchiveFormat.from(url: URL(fileURLWithPath: "bundle.tgz")), .tarGz)
        XCTAssertEqual(ArchiveFormat.from(url: URL(fileURLWithPath: "system.tar.xz")), .tarXz)
        XCTAssertEqual(ArchiveFormat.from(url: URL(fileURLWithPath: "disk.iso")), .iso)
        XCTAssertEqual(ArchiveFormat.from(url: URL(fileURLWithPath: "split.7z.001")), .sevenZip)
        XCTAssertEqual(ArchiveFormat.from(url: URL(fileURLWithPath: "multi.part1.rar")), .rar)
    }

    func testFormatMagicByteDetection() {
        // Zip magic bytes: PK\x03\x04
        let zipBytes = Data([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00])
        XCTAssertEqual(FormatDetector.detectFromBytes(zipBytes), .zip)

        // 7z magic bytes: 7z\xBC\xAF\x27\x1C
        let sevenZipBytes = Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])
        XCTAssertEqual(FormatDetector.detectFromBytes(sevenZipBytes), .sevenZip)

        // RAR 5 magic bytes: Rar!\x1A\x07\x01\x00
        let rar5Bytes = Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00])
        XCTAssertEqual(FormatDetector.detectFromBytes(rar5Bytes), .rar)

        // GZ magic bytes: \x1F\x8B
        let gzBytes = Data([0x1F, 0x8B, 0x08, 0x00])
        XCTAssertEqual(FormatDetector.detectFromBytes(gzBytes), .gz)
    }

    func testArchiveItemCalculations() {
        let item = ArchiveItem(
            path: "Documents/Subfolder/report.pdf",
            isDirectory: false,
            uncompressedSize: 10_000,
            compressedSize: 3_000,
            modifiedDate: Date(),
            crc: "ABCD1234",
            isEncrypted: false
        )

        XCTAssertEqual(item.name, "report.pdf")
        XCTAssertEqual(item.parentPath, "Documents/Subfolder")
        XCTAssertEqual(item.fileExtension, "pdf")
        XCTAssertEqual(item.compressionRatioPercentage, 70.0, accuracy: 0.1)
    }

    func testFinderSyncBridgeURLParsing() {
        let samplePaths = ["/Users/test/archive.zip", "/Users/test/data.rar"]
        let url = FinderSyncBridge.makeActionURL(action: .extractHere, targetPaths: samplePaths)
        XCTAssertNotNil(url)

        let parsed = FinderSyncBridge.parseAction(from: url!)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.action, .extractHere)
        XCTAssertEqual(parsed?.paths.count, 2)
        XCTAssertEqual(parsed?.paths[0].path, "/Users/test/archive.zip")
    }

    func testCompressionAndExtractionRoundtrip() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ZipMipTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. Create a dummy file
        let sourceFile = tempDir.appendingPathComponent("hello.txt")
        let testContent = "Hello ZipMip Universal Archive Engine for macOS! " + String(repeating: "Test data 12345 ", count: 100)
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)

        // 2. Compress to .zip
        let zipArchive = tempDir.appendingPathComponent("test_archive.zip")
        let zipConfig = CompressionConfig(format: .zip, level: .ultra)
        try await ArchiveEngine.shared.compress(sources: [sourceFile], destination: zipArchive, config: zipConfig)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipArchive.path))

        // 3. List entries in zip
        let items = try await ArchiveEngine.shared.listArchive(at: zipArchive)
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.contains(where: { $0.name == "hello.txt" }))

        // 4. Test integrity
        let valid = try await ArchiveEngine.shared.testArchive(archiveURL: zipArchive)
        XCTAssertTrue(valid)

        // 5. Extract to new folder
        let extractDir = tempDir.appendingPathComponent("Extracted")
        let extractConfig = ExtractionConfig(destinationFolder: extractDir, revealInFinder: false)
        try await ArchiveEngine.shared.extract(archiveURL: zipArchive, config: extractConfig)

        let extractedFile = extractDir.appendingPathComponent("hello.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path))

        let extractedContent = try String(contentsOf: extractedFile, encoding: .utf8)
        XCTAssertEqual(extractedContent, testContent)
    }

    func testPasswordEncrypted7zArchive() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ZipMipPasswordTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceFile = tempDir.appendingPathComponent("secret.txt")
        try "Top Secret Message 1234".write(to: sourceFile, atomically: true, encoding: .utf8)

        // Compress with password and header encryption
        let encrypted7z = tempDir.appendingPathComponent("secret.7z")
        let config = CompressionConfig(
            format: .sevenZip,
            level: .normal,
            password: "MySecurePassword123!",
            encryptHeaders: true
        )
        try await ArchiveEngine.shared.compress(sources: [sourceFile], destination: encrypted7z, config: config)
        XCTAssertTrue(FileManager.default.fileExists(atPath: encrypted7z.path))

        // Listing with correct password
        let items = try await ArchiveEngine.shared.listArchive(at: encrypted7z, password: "MySecurePassword123!")
        XCTAssertTrue(items.contains(where: { $0.name == "secret.txt" }))

        // Extract with correct password
        let outDir = tempDir.appendingPathComponent("SecretOut")
        let extractConfig = ExtractionConfig(
            destinationFolder: outDir,
            password: "MySecurePassword123!",
            revealInFinder: false
        )
        try await ArchiveEngine.shared.extract(archiveURL: encrypted7z, config: extractConfig)
        let extractedSecret = outDir.appendingPathComponent("secret.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedSecret.path))
    }

    func testTarGzAndNestedDirectories() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ZipMipTarTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create folder structure: root/docs/readme.txt & root/images/icon.png
        let docsDir = tempDir.appendingPathComponent("docs")
        let imagesDir = tempDir.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        let readme = docsDir.appendingPathComponent("readme.md")
        try "# Readme Documentation".write(to: readme, atomically: true, encoding: .utf8)

        let icon = imagesDir.appendingPathComponent("icon.txt")
        try "icon asset".write(to: icon, atomically: true, encoding: .utf8)

        // Compress to .tar.gz
        let tarGzArchive = tempDir.appendingPathComponent("bundle.tar.gz")
        let config = CompressionConfig(format: .tarGz, level: .fast)
        try await ArchiveEngine.shared.compress(sources: [docsDir, imagesDir], destination: tarGzArchive, config: config)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tarGzArchive.path))

        // List contents
        let items = try await ArchiveEngine.shared.listArchive(at: tarGzArchive)
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.contains(where: { $0.name == "readme.md" }))
        XCTAssertTrue(items.contains(where: { $0.name == "icon.txt" }))
    }

    func testMultiVolumeSplitting() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ZipMipSplitTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a 2MB file to split into 500k chunks
        let largeFile = tempDir.appendingPathComponent("payload.bin")
        let chunkData = Data(repeating: 0xAB, count: 1024 * 1024 * 2) // 2MB
        try chunkData.write(to: largeFile)

        let splitArchive = tempDir.appendingPathComponent("split_archive.7z")
        let config = CompressionConfig(
            format: .sevenZip,
            level: .store,
            splitSize: "500k"
        )

        try await ArchiveEngine.shared.compress(sources: [largeFile], destination: splitArchive, config: config)

        // Verify that split parts were created (.7z.001, .7z.002, etc.)
        let part1 = tempDir.appendingPathComponent("split_archive.7z.001")
        let part2 = tempDir.appendingPathComponent("split_archive.7z.002")
        XCTAssertTrue(FileManager.default.fileExists(atPath: part1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: part2.path))

        // Test extracting the split archive by referencing the first volume
        let extractDir = tempDir.appendingPathComponent("SplitExtracted")
        let extractConfig = ExtractionConfig(destinationFolder: extractDir, revealInFinder: false)
        try await ArchiveEngine.shared.extract(archiveURL: part1, config: extractConfig)

        let extractedPayload = extractDir.appendingPathComponent("payload.bin")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedPayload.path))
        let extractedData = try Data(contentsOf: extractedPayload)
        XCTAssertEqual(extractedData.count, chunkData.count)
    }
}
