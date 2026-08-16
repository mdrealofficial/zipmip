import Foundation

/// Represents an entry (file or directory) inside an archive
public struct ArchiveItem: Identifiable, Sendable, Hashable, Codable {
    public var id: String { path }
    public let path: String
    public let isDirectory: Bool
    public let uncompressedSize: Int64
    public let compressedSize: Int64
    public let modifiedDate: Date?
    public let attributes: String?
    public let crc: String?
    public let isEncrypted: Bool
    public let method: String?

    public init(
        path: String,
        isDirectory: Bool,
        uncompressedSize: Int64 = 0,
        compressedSize: Int64 = 0,
        modifiedDate: Date? = nil,
        attributes: String? = nil,
        crc: String? = nil,
        isEncrypted: Bool = false,
        method: String? = nil
    ) {
        // Clean leading slash if any
        self.path = path.hasPrefix("/") ? String(path.dropFirst()) : path
        self.isDirectory = isDirectory
        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize
        self.modifiedDate = modifiedDate
        self.attributes = attributes
        self.crc = crc
        self.isEncrypted = isEncrypted
        self.method = method
    }

    public var name: String {
        let cleanPath = path.hasSuffix("/") ? String(path.dropLast()) : path
        return (cleanPath as NSString).lastPathComponent
    }

    public var parentPath: String {
        let cleanPath = path.hasSuffix("/") ? String(path.dropLast()) : path
        let parent = (cleanPath as NSString).deletingLastPathComponent
        return parent == "." || parent == "" ? "" : parent
    }

    public var fileExtension: String {
        guard !isDirectory else { return "" }
        return (name as NSString).pathExtension.lowercased()
    }

    public var compressionRatioPercentage: Double {
        guard uncompressedSize > 0 else { return 0 }
        let ratio = (1.0 - (Double(compressedSize) / Double(uncompressedSize))) * 100.0
        return max(0, min(100, ratio))
    }

    public var formattedUncompressedSize: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: uncompressedSize, countStyle: .file)
    }

    public var formattedCompressedSize: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
    }

    public var formattedDate: String {
        guard let modifiedDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modifiedDate)
    }
}
