import Foundation

/// Errors that can occur during archive operations
public enum ArchiveError: LocalizedError, Sendable {
    case binaryNotFound
    case fileNotFound(String)
    case passwordRequired
    case incorrectPassword
    case corruptedArchive(String)
    case unsupportedFormat(String)
    case destinationNotWritable(String)
    case executionFailed(String, exitCode: Int32)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Archive engine binary (7zz) could not be located on the system."
        case .fileNotFound(let path):
            return "Archive or file not found at: \(path)"
        case .passwordRequired:
            return "This archive is encrypted. Please enter the password."
        case .incorrectPassword:
            return "The password entered is incorrect."
        case .corruptedArchive(let details):
            return "The archive appears to be corrupted or damaged: \(details)"
        case .unsupportedFormat(let format):
            return "Unsupported archive format: \(format)"
        case .destinationNotWritable(let path):
            return "Cannot write to destination folder: \(path)"
        case .executionFailed(let reason, let code):
            return "Archive operation failed (Exit code \(code)): \(reason)"
        case .cancelled:
            return "Operation was cancelled by user."
        }
    }
}
