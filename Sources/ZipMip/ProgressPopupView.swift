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

        VStack(spacing: 12) {
            // Header: Icon + Title + Percent Badge
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isDone ? Color.green.opacity(0.2) : Color.accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: isDone ? "checkmark" : "archivebox.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isDone ? Color.green : Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(progress.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    Text(isDone ? "Completed successfully" : progress.currentFileName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(isDone ? "100%" : String(format: "%.0f%%", percent * 100))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(isDone ? Color.green : Color.primary)
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isDone ? [.green, .mint] : [.accentColor, .teal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * CGFloat(percent)), height: 6)
                        .animation(.linear(duration: 0.15), value: percent)
                }
            }
            .frame(height: 6)

            // Footer: Speed & Details
            HStack {
                if !progress.formattedSpeed.isEmpty && !isDone {
                    Label(progress.formattedSpeed, systemImage: "bolt.fill")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if !isDone {
                    Text("Processing archive...")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Saved to folder")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)
                }

                Spacer()

                if !isDone {
                    Button("Cancel") {
                        manager.cancelCurrentTask()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                }
            }
        }
        .padding(16)
        .frame(width: 360, height: 115)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
