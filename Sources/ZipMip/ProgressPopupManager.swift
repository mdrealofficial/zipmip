import Foundation
import SwiftUI
import AppKit
import ZipMipCore

@MainActor
public final class ProgressPopupManager: ObservableObject {
    public static let shared = ProgressPopupManager()

    @Published public var currentProgress: TaskProgress?
    @Published public var isVisible: Bool = false

    private var window: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?
    private var activeTask: Task<Void, Never>?

    public init() {}

    public func show(title: String) {
        dismissWorkItem?.cancel()
        currentProgress = TaskProgress(title: title, phase: .pending)
        isVisible = true

        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 140),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.contentView = NSHostingView(rootView: ProgressPopupView(manager: self))
            self.window = panel
        }

        window?.center()
        window?.orderFrontRegardless()
    }

    public func update(progress: TaskProgress) {
        currentProgress = progress

        if progress.phase == .completed {
            #if canImport(AppKit)
            NSSound(named: "Glass")?.play()
            #endif

            dismissWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.hide()
            }
            dismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
        } else if case .failed = progress.phase {
            dismissWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.hide()
            }
            dismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
        }
    }

    public func hide() {
        window?.orderOut(nil)
        isVisible = false
        currentProgress = nil
    }

    public func cancelCurrentTask() {
        activeTask?.cancel()
        hide()
    }

    /// Helper to run an async archive task with the progress popup automatically showing and updating
    public func runWithProgress(title: String, operation: @escaping (@Sendable @escaping (TaskProgress) -> Void) async throws -> Void) {
        show(title: title)

        activeTask = Task {
            do {
                try await operation { progress in
                    Task { @MainActor in
                        self.update(progress: progress)
                    }
                }
            } catch {
                Task { @MainActor in
                    self.update(progress: TaskProgress(title: title, phase: .failed(error: error.localizedDescription)))
                }
            }
        }
    }
}
