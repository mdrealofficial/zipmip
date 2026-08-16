import Foundation

/// Progress state of an archive task
public struct TaskProgress: Sendable, Identifiable {
    public var id = UUID()
    
    public enum Phase: Sendable, Equatable {
        case pending
        case analyzing
        case processing(percentage: Double, currentFile: String, speedBytesPerSec: Double, bytesProcessed: Int64, totalBytes: Int64)
        case verifying
        case completed
        case failed(error: String)
        case cancelled
    }

    public var phase: Phase
    public var title: String
    public var totalItems: Int
    public var completedItems: Int
    public var startTime: Date?
    
    public init(title: String, phase: Phase = .pending, totalItems: Int = 0, completedItems: Int = 0) {
        self.title = title
        self.phase = phase
        self.totalItems = totalItems
        self.completedItems = completedItems
        self.startTime = Date()
    }

    public var percentage: Double {
        switch phase {
        case .pending:
            return 0.0
        case .analyzing:
            return 0.05
        case .processing(let percentage, _, _, _, _):
            return percentage
        case .verifying:
            return 0.95
        case .completed:
            return 1.0
        case .failed, .cancelled:
            return 0.0
        }
    }

    public var formattedSpeed: String {
        switch phase {
        case .processing(_, _, let speed, _, _):
            if speed <= 0 { return "" }
            let formatted = ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file)
            return "\(formatted)/s"
        default:
            return ""
        }
    }

    public var currentFileName: String {
        switch phase {
        case .processing(_, let currentFile, _, _, _):
            return currentFile
        case .analyzing:
            return "Analyzing archive..."
        case .verifying:
            return "Verifying integrity..."
        case .completed:
            return "Completed"
        case .failed(let err):
            return "Failed: \(err)"
        case .cancelled:
            return "Cancelled"
        case .pending:
            return "Starting..."
        }
    }
}
