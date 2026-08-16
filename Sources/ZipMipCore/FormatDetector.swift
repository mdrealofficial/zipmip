import Foundation

/// Detects archive formats using file magic bytes / signatures
public struct FormatDetector: Sendable {
    public static func detect(url: URL) -> ArchiveFormat {
        // First try reading header bytes
        if let fileHandle = try? FileHandle(forReadingFrom: url) {
            defer { try? fileHandle.close() }
            let headerData = (try? fileHandle.read(upToCount: 512)) ?? Data()
            if let format = detectFromBytes(headerData) {
                return format
            }
        }
        
        // Fallback to extension-based detection
        return ArchiveFormat.from(url: url)
    }

    public static func detectFromBytes(_ data: Data) -> ArchiveFormat? {
        guard data.count >= 2 else { return nil }

        // ZIP: PK\x03\x04 or PK\x05\x06 or PK\x07\x08
        if data.starts(with: [0x50, 0x4B, 0x03, 0x04]) ||
           data.starts(with: [0x50, 0x4B, 0x05, 0x06]) ||
           data.starts(with: [0x50, 0x4B, 0x07, 0x08]) {
            return .zip
        }

        // 7-Zip: 7z\xBC\xAF\x27\x1C
        if data.starts(with: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) {
            return .sevenZip
        }

        // RAR 5.0: Rar!\x1A\x07\x01\x00
        if data.starts(with: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]) {
            return .rar
        }

        // RAR 4.x / 1.5: Rar!\x1A\x07\x00
        if data.starts(with: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00]) {
            return .rar
        }

        // GZ: \x1F\x8B
        if data.starts(with: [0x1F, 0x8B]) {
            return .gz
        }

        // BZ2: BZh
        if data.starts(with: [0x42, 0x5A, 0x68]) {
            return .bz2
        }

        // XZ: \xFD7zXZ\x00
        if data.starts(with: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) {
            return .xz
        }

        // Zstandard: \x28\xB5\x2F\xFD
        if data.starts(with: [0x28, 0xB5, 0x2F, 0xFD]) {
            return .zst
        }

        // TAR: check for "ustar" at offset 257
        if data.count >= 262 {
            let ustarBytes = data.subdata(in: 257..<262)
            if ustarBytes == Data([0x75, 0x73, 0x74, 0x61, 0x72]) { // "ustar"
                return .tar
            }
        }

        // ISO 9660: check for "CD001" at offset 0x8001 / 32769 (if data large enough)
        // CAB: "MSCF"
        if data.starts(with: [0x4D, 0x53, 0x43, 0x46]) {
            return .cab
        }

        // WIM: "MSWIM\0\0\0"
        if data.starts(with: [0x4D, 0x53, 0x57, 0x49, 0x4D, 0x00, 0x00, 0x00]) {
            return .wim
        }

        return nil
    }
}
