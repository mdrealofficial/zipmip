import SwiftUI
import ZipMipCore

public struct ProgressHUDView: View {
    public let progress: TaskProgress

    public init(progress: TaskProgress) {
        self.progress = progress
    }

    public var body: some View {
        HStack(spacing: 12) {
            ProgressView(value: progress.percentage, total: 1.0)
                .progressViewStyle(.circular)
                .scaleEffect(0.8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(progress.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()

                    Text(String(format: "%.0f%%", progress.percentage * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(progress.currentFileName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Spacer()

                    if !progress.formattedSpeed.isEmpty {
                        Text(progress.formattedSpeed)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
}
