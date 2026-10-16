import AppKit
import AudraCore
import SwiftUI

/// The floating player: a header, the text being read with its progress, and playback controls.
struct PlayerView: View {
    /// The size the layout is designed at; other sizes scale it to fit.
    static let defaultSize = CGSize(width: 360, height: 222)
    static let minSize = CGSize(width: defaultSize.width * 0.6, height: defaultSize.height * 0.6)

    @ObservedObject var model: PlayerViewModel

    var body: some View {
        GeometryReader { proxy in
            // Scale everything by the tighter axis, then give the looser axis the leftover room
            // so the layout stretches there instead of leaving a gap.
            let fit = min(proxy.size.width / Self.defaultSize.width, proxy.size.height / Self.defaultSize.height)
            // The first layout pass can be zero-sized; scaling by zero would make the frame infinite.
            let scale = fit.isFinite && fit > 0 ? fit : 1
            content
                .frame(width: proxy.size.width / scale, height: proxy.size.height / scale)
                .scaleEffect(scale, anchor: .topLeading)
        }
        .overlay(alignment: .bottomTrailing) {
            ResizeGrip()
                .frame(width: 14, height: 14)
                .padding(5)
        }
        .background(WindowDragArea())
        .background(Palette.background)
        .background(VisualEffectBackground())
        .overlay(Self.card.strokeBorder(Palette.border))
        .clipShape(Self.card)
        .environment(\.colorScheme, .dark)
    }

    private var content: some View {
        VStack(spacing: 12) {
            header
                .allowsHitTesting(false)
            VStack(spacing: 14) {
                nowReading
                    .allowsHitTesting(false)
                controls
            }
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.hairline))
        }
        .padding(14)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: Self.logo)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .foregroundStyle(Palette.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text("Audra")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(model.voiceLabel ?? "Screen text, naturally spoken.")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let language = model.languageLabel {
                Label(language, systemImage: "globe")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Palette.control, in: Capsule())
            }
        }
    }

    private var nowReading: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
                    .frame(width: 30, height: 30)
                    .background(Palette.control, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(model.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .truncationMode(.tail)
                    // Shows two lines at the minimum size and more as the player grows.
                    .frame(maxWidth: .infinity, minHeight: 34, maxHeight: .infinity, alignment: .topLeading)
            }

            ProgressTrack(progress: model.progress)
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            PlayerButton(symbol: "stop.fill", help: "Stop") { model.stop() }
                .disabled(!model.canStop)

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                PlayerButton(symbol: "backward.fill", help: "Slower") { model.slower() }
                    .disabled(!model.canGoSlower)
                PlayPauseButton(isPlaying: model.isPlaying) {
                    Task { await model.playPause() }
                }
                PlayerButton(symbol: "forward.fill", help: "Faster") { model.faster() }
                    .disabled(!model.canGoFaster)
            }

            Spacer(minLength: 0)

            SpeedMenu(speed: $model.speed)
        }
    }

    private static let card = RoundedRectangle(cornerRadius: 22, style: .continuous)

    /// The Audra mark as a template image, so it takes the accent gradient.
    private static let logo: NSImage = {
        let image = Bundle.module.image(forResource: "MenuBarIcon") ?? NSImage()
        image.isTemplate = true
        return image
    }()
}

/// Colors shared by the player. The panel is always dark, like a media HUD.
private enum Palette {
    static let accent = LinearGradient(
        colors: [Color(red: 0.36, green: 0.42, blue: 1.0), Color(red: 0.55, green: 0.36, blue: 0.98)],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let glow = Color(red: 0.42, green: 0.40, blue: 1.0)
    static let background = Color(red: 0.07, green: 0.08, blue: 0.11).opacity(0.82)
    static let surface = Color.white.opacity(0.04)
    static let control = Color.white.opacity(0.07)
    static let hairline = Color.white.opacity(0.06)
    static let border = Color.white.opacity(0.12)
    static let secondaryText = Color.white.opacity(0.55)
}

private struct ProgressTrack: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let filled = proxy.size.width * progress
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: max(filled, progress > 0 ? 4 : 0))
                    .shadow(color: Palette.glow.opacity(0.6), radius: 4)
            }
            .animation(.easeOut(duration: 0.25), value: progress)
        }
        .frame(height: 4)
    }
}

private struct PlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 52, height: 52)
                .background(Palette.accent, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18)))
                .shadow(color: Palette.glow.opacity(0.55), radius: 10, y: 2)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .help(isPlaying ? "Pause" : "Play")
    }
}

private struct PlayerButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(isEnabled ? 0.9 : 0.25))
                .frame(width: 40, height: 36)
                .background(Palette.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .help(help)
    }
}

private struct SpeedMenu: View {
    @Binding var speed: SpeechSpeed

    var body: some View {
        Menu {
            Picker("Speed", selection: $speed) {
                ForEach(SpeechSpeed.allCases) { speed in
                    Text(speed.label).tag(speed)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 3) {
                Text(speed.label)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 52, height: 36)
            .background(Palette.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .help("Speed")
    }
}

/// Dims and shrinks a button slightly while it's pressed.
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Blurs whatever is behind the panel, under the tinted background.
private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// A corner handle that resizes the panel, keeping its top-left corner in place.
private struct ResizeGrip: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { GripView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class GripView: NSView {
        private var startMouse: NSPoint = .zero
        private var startFrame: NSRect = .zero

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .frameResize(position: .bottomRight, directions: .all))
        }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.white.withAlphaComponent(0.25).setStroke()
            // Two diagonal strokes across the bottom-right corner.
            for inset in [3.0, 7.0] {
                let path = NSBezierPath()
                path.move(to: NSPoint(x: inset, y: 1))
                path.line(to: NSPoint(x: bounds.maxX - 1, y: bounds.maxX - inset))
                path.lineWidth = 1.2
                path.lineCapStyle = .round
                path.stroke()
            }
        }

        override func mouseDown(with event: NSEvent) {
            startMouse = NSEvent.mouseLocation
            startFrame = window?.frame ?? .zero
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window else { return }
            let mouse = NSEvent.mouseLocation
            let minSize = window.contentMinSize
            let width = max(minSize.width, startFrame.width + mouse.x - startMouse.x)
            let height = max(minSize.height, startFrame.height - (mouse.y - startMouse.y))
            window.setFrame(
                NSRect(x: startFrame.minX, y: startFrame.maxY - height, width: width, height: height),
                display: true
            )
        }
    }
}

/// Lets the user drag the borderless panel by any spot that isn't a button.
private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
