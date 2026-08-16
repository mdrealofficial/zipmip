import Foundation

/// Compression level matching 7-Zip & WinRAR standard levels
public enum CompressionLevel: Int, CaseIterable, Identifiable, Sendable, Codable {
    case store = 0
    case fastest = 1
    case fast = 3
    case normal = 5
    case maximum = 7
    case ultra = 9

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .store: return "Store (0 - No Compression)"
        case .fastest: return "Fastest (1)"
        case .fast: return "Fast (3)"
        case .normal: return "Normal (5 - Recommended)"
        case .maximum: return "Maximum (7)"
        case .ultra: return "Ultra (9 - Highest Ratio)"
        }
    }

    public var shortName: String {
        switch self {
        case .store: return "Store"
        case .fastest: return "Fastest"
        case .fast: return "Fast"
        case .normal: return "Normal"
        case .maximum: return "Maximum"
        case .ultra: return "Ultra"
        }
    }
}

/// Compression method / algorithm
public enum CompressionMethod: String, CaseIterable, Identifiable, Sendable, Codable {
    case lzma2 = "LZMA2"
    case lzma = "LZMA"
    case ppmd = "PPMd"
    case bzip2 = "BZip2"
    case deflate = "Deflate"
    case deflate64 = "Deflate64"
    case copy = "Copy"

    public var id: String { rawValue }
}

/// Volume split size preset
public enum VolumeSplitPreset: String, CaseIterable, Identifiable, Sendable, Codable {
    case none = "none"
    case mb10 = "10m"
    case mb100 = "100m"
    case cd700 = "700m"
    case fat32 = "4092m"
    case dvd4_7 = "4480m"
    case custom = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "No Splitting (Single File)"
        case .mb10: return "10 MB"
        case .mb100: return "100 MB"
        case .cd700: return "700 MB (CD)"
        case .fat32: return "4 GB (FAT32 Limit)"
        case .dvd4_7: return "4.7 GB (DVD)"
        case .custom: return "Custom Size..."
        }
    }
}

/// Configuration options for creating/compressing an archive
public struct CompressionConfig: Sendable, Codable {
    public var format: ArchiveFormat
    public var level: CompressionLevel
    public var method: CompressionMethod
    public var password: String?
    public var encryptHeaders: Bool // 7z only: hides file names
    public var splitSize: String?   // e.g. "100m", "1g", nil
    public var threadCount: Int     // 0 = auto
    public var excludePatterns: [String] // e.g. [".DS_Store", "__MACOSX"]
    public var solidArchive: Bool   // Solid block compression for 7z

    public init(
        format: ArchiveFormat = .zip,
        level: CompressionLevel = .normal,
        method: CompressionMethod = .lzma2,
        password: String? = nil,
        encryptHeaders: Bool = false,
        splitSize: String? = nil,
        threadCount: Int = 0,
        excludePatterns: [String] = [".DS_Store", "__MACOSX"],
        solidArchive: Bool = true
    ) {
        self.format = format
        self.level = level
        self.method = method
        self.password = (password?.isEmpty ?? true) ? nil : password
        self.encryptHeaders = encryptHeaders
        self.splitSize = (splitSize?.isEmpty ?? true) ? nil : splitSize
        self.threadCount = threadCount
        self.excludePatterns = excludePatterns
        self.solidArchive = solidArchive
    }
}

/// File conflict resolution rule during extraction
public enum OverwriteMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case ask = "ask"
    case overwrite = "overwrite"
    case skip = "skip"
    case rename = "rename"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ask: return "Ask for Confirmation"
        case .overwrite: return "Overwrite All Existing Files"
        case .skip: return "Skip Existing Files"
        case .rename: return "Auto-Rename Duplicates"
        }
    }
}

/// Configuration options for extracting an archive
public struct ExtractionConfig: Sendable, Codable {
    public var destinationFolder: URL
    public var password: String?
    public var overwriteMode: OverwriteMode
    public var createSubfolder: Bool
    public var deleteArchiveAfterExtraction: Bool
    public var revealInFinder: Bool

    public init(
        destinationFolder: URL,
        password: String? = nil,
        overwriteMode: OverwriteMode = .overwrite,
        createSubfolder: Bool = false,
        deleteArchiveAfterExtraction: Bool = false,
        revealInFinder: Bool = true
    ) {
        self.destinationFolder = destinationFolder
        self.password = (password?.isEmpty ?? true) ? nil : password
        self.overwriteMode = overwriteMode
        self.createSubfolder = createSubfolder
        self.deleteArchiveAfterExtraction = deleteArchiveAfterExtraction
        self.revealInFinder = revealInFinder
    }
}
