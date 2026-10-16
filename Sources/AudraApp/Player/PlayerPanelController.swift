import AppKit
import Combine
import AudraCore
import SwiftUI

/// Owns the floating player window: an always-on-top panel that never activates the app,
/// so clicking it leaves the other app (and its text selection) frontmost.
@MainActor
final class PlayerPanelController {
    private static let autosaveName = "PlayerPanel"
    private static let hideDelay: Duration = .seconds(3)
    private static let fadeDuration: TimeInterval = 0.2
    private static let screenInset: CGFloat = 24

    private let panel: NSPanel
    private var visibilitySubscription: AnyCancellable?
    private var hideTask: Task<Void, Never>?
    /// False once a fade-out starts, so a fade-out finishing after a new show() doesn't hide the panel.
    private var isShown = false

    init(viewModel: PlayerViewModel) {
        // .nonactivatingPanel keeps clicks from activating the app, so the source app and its
        // selection stay frontmost; borderless also keeps the panel from becoming key.
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: PlayerView.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = FirstMouseHostingView(rootView: PlayerView(model: viewModel))

        // The saved frame may be from an older layout size or a monitor that's no longer attached.
        if panel.setFrameUsingName(Self.autosaveName) {
            panel.setContentSize(PlayerView.size)
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) {
                placeAtBottomRight()
            }
        } else {
            placeAtBottomRight()
        }
        panel.setFrameAutosaveName(Self.autosaveName)

        visibilitySubscription = viewModel.$shouldBeVisible.sink { [weak self] visible in
            if visible { self?.show() } else { self?.scheduleHide() }
        }
    }

    private func placeAtBottomRight() {
        guard let visible = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(
            x: visible.maxX - PlayerView.size.width - Self.screenInset,
            y: visible.minY + Self.screenInset
        ))
    }

    private func show() {
        hideTask?.cancel()
        hideTask = nil
        guard !isShown else { return }
        isShown = true
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = 1
        }
    }

    private func scheduleHide() {
        guard isShown else { return }
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.hideDelay)
            guard !Task.isCancelled else { return }
            self?.fadeOut()
        }
    }

    private func fadeOut() {
        isShown = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, !self.isShown else { return }
                self.panel.orderOut(nil)
            }
        })
    }
}

/// Makes the first click on an inactive panel press the button instead of only focusing the window.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
