import Foundation

/// Supported archive formats with detailed capabilities
public enum ArchiveFormat: String, CaseIterable, Identifiable, Sendable, Codable {
    case zip = "zip"
    case sevenZip = "7z"
    case rar = "rar"
    case tar = "tar"
    case tarGz = "tar.gz"
    case tarBz2 = "tar.bz2"
    case tarXz = "tar.xz"
    case tarZst = "tar.zst"
    case gz = "gz"
    case bz2 = "bz2"
    case xz = "xz"
    case zst = "zst"
    case iso = "iso"
    case dmg = "dmg"
    case cab = "cab"
    case cpio = "cpio"
    case arj = "arj"
    case lha = "lha"
    case wim = "wim"
    case unknown = "unknown"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .zip: return "ZIP Archive"
        case .sevenZip: return "7-Zip Archive (.7z)"
        case .rar: return "RAR Archive"
        case .tar: return "TAR Archive"
        case .tarGz: return "GZip Tarball (.tar.gz / .tgz)"
        case .tarBz2: return "BZip2 Tarball (.tar.bz2 / .tbz2)"
        case .tarXz: return "XZ Tarball (.tar.xz / .txz)"
        case .tarZst: return "Zstandard Tarball (.tar.zst)"
        case .gz: return "GZip (.gz)"
        case .bz2: return "BZip2 (.bz2)"
        case .xz: return "XZ (.xz)"
        case .zst: return "Zstandard (.zst)"
        case .iso: return "ISO Disk Image"
        case .dmg: return "Apple Disk Image"
        case .cab: return "Microsoft Cabinet (.cab)"
        case .cpio: return "CPIO Archive"
        case .arj: return "ARJ Archive"
        case .lha: return "LHA / LZH Archive"
        case .wim: return "Windows Imaging Format (.wim)"
        case .unknown: return "Unknown Archive"
        }
    }

    public var defaultExtension: String {
        switch self {
        case .tarGz: return "tar.gz"
        case .tarBz2: return "tar.bz2"
        case .tarXz: return "tar.xz"
        case .tarZst: return "tar.zst"
        default: return rawValue
        }
    }

    public var extensions: [String] {
        switch self {
        case .zip: return ["zip", "cbz", "jar", "war", "ear", "ipa", "apk"]
        case .sevenZip: return ["7z", "cb7"]
        case .rar: return ["rar", "cbr", "r00", "r01", "part1.rar"]
        case .tar: return ["tar", "cbt"]
        case .tarGz: return ["tar.gz", "tgz", "taz"]
        case .tarBz2: return ["tar.bz2", "tbz2", "tbz"]
        case .tarXz: return ["tar.xz", "txz"]
        case .tarZst: return ["tar.zst", "tzst"]
        case .gz: return ["gz"]
        case .bz2: return ["bz2"]
        case .xz: return ["xz"]
        case .zst: return ["zst"]
        case .iso: return ["iso", "img"]
        case .dmg: return ["dmg"]
        case .cab: return ["cab"]
        case .cpio: return ["cpio"]
        case .arj: return ["arj"]
        case .lha: return ["lha", "lzh"]
        case .wim: return ["wim", "swm", "esd"]
        case .unknown: return []
        }
    }

    /// Whether ZipMip supports creating archives in this format
    public var canCompress: Bool {
        switch self {
        case .zip, .sevenZip, .tar, .tarGz, .tarBz2, .tarXz, .tarZst, .gz, .bz2, .xz, .zst:
            return true
        default:
            return false
        }
    }

    /// Whether password encryption is supported
    public var canEncrypt: Bool {
        switch self {
        case .zip, .sevenZip:
            return true
        default:
            return false
        }
    }

    /// Whether encrypting file list / headers is supported (hiding directory contents)
    public var canEncryptHeader: Bool {
        return self == .sevenZip
    }

    /// Whether multi-volume splitting is supported
    public var canSplit: Bool {
        switch self {
        case .sevenZip, .zip, .tar:
            return true
        default:
            return false
        }
    }

    /// Detect format from file URL / extension
    public static func from(url: URL) -> ArchiveFormat {
        let filename = url.lastPathComponent.lowercased()
        
        // Check double extensions first (.tar.gz, .tar.xz, etc.)
        for format in [ArchiveFormat.tarGz, .tarBz2, .tarXz, .tarZst] {
            for ext in format.extensions {
                if filename.hasSuffix("." + ext) {
                    return format
                }
            }
        }

        // Check single extensions
        let ext = url.pathExtension.lowercased()
        for format in ArchiveFormat.allCases {
            if format.extensions.contains(ext) {
                return format
            }
        }

        // Multi-part volume patterns (e.g., .7z.001, .zip.001, .z01)
        if filename.range(of: #"\.7z\.\d{3}$"#, options: .regularExpression) != nil {
            return .sevenZip
        }
        if filename.range(of: #"\.zip\.\d{3}$"#, options: .regularExpression) != nil ||
           filename.range(of: #"\.z\d{2}$"#, options: .regularExpression) != nil {
            return .zip
        }
        if filename.range(of: #"\.part\d+\.rar$"#, options: .regularExpression) != nil ||
           filename.range(of: #"\.r\d{2}$"#, options: .regularExpression) != nil {
            return .rar
        }

        return .unknown
    }
}
