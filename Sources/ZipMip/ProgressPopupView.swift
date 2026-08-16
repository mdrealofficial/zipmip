import SwiftUI
import ZipMipCore

public struct ProgressPopupView: View {
    @ObservedObject var manager: ProgressPopupManager

    public init(manager: ProgressPopupManager) {
        self.manager = manager
    }

    public var body: some View {
        let progress = manager.currentProgress ?? TaskProgress(title: "Compressing...", phase: .pending)
        let percent = progress.percentage
        let isDone = progress.phase == .completed

        VStack(spacing: 14) {
            // Header: Icon + Title + Percent Badge
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isDone ? Color.green.opacity(0.2) : Color.accentColor.opacity(0.15))
                        .frame(width: 38, height: 38)

                    Image(systemName: isDone ? "checkmark" : "archivebox.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isDone ? Color.green : Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(progress.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(isDone ? "Completed successfully" : progress.currentFileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(isDone ? "100%" : String(format: "%.0f%%", percent * 100))
                    .font(.title3.monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundStyle(isDone ? Color.green : Color.primary)
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isDone ? [.green, .mint] : [.accentColor, .teal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(percent)), height: 8)
                        .animation(.linear(duration: 0.2), value: percent)
                }
            }
            .frame(height: 8)

            // Footer: Speed & Details
            HStack {
                if !progress.formattedSpeed.isEmpty && !isDone {
                    Label(progress.formattedSpeed, systemImage: "bolt.fill")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else if !isDone {
                    Text("Processing archive...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Saved to folder")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }

                Spacer()

                if !isDone {
                    Button("Cancel") {
                        manager.cancelCurrentTask()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                }
            }
        }
        .padding(18)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        )
    }
}
