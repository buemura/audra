import AppKit
import ScreenReaderCore
import SwiftUI

/// The floating player: what's being read on top, playback controls below.
struct PlayerView: View {
    static let size = CGSize(width: 240, height: 120)

    @ObservedObject var model: PlayerViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(model.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .allowsHitTesting(false)

                Spacer(minLength: 0)

                PlayerButton(symbol: "stop.fill", size: 11, help: "Stop") { model.stop() }
                    .disabled(!model.canStop)
            }

            HStack(spacing: 24) {
                PlayerButton(symbol: "backward.fill", size: 18, help: "Slower") { model.slower() }
                    .disabled(!model.canGoSlower)
                PlayerButton(
                    symbol: model.isPlaying ? "pause.fill" : "play.fill",
                    size: 26,
                    help: model.isPlaying ? "Pause" : "Play"
                ) {
                    Task { await model.playPause() }
                }
                PlayerButton(symbol: "forward.fill", size: 18, help: "Faster") { model.faster() }
                    .disabled(!model.canGoFaster)
            }
        }
        .padding(14)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(WindowDragArea())
        .background(Color(nsColor: .windowBackgroundColor), in: Self.card)
        .overlay(Self.card.strokeBorder(Color(nsColor: .separatorColor)))
        .clipShape(Self.card)
    }

    private static let card = RoundedRectangle(cornerRadius: 20, style: .continuous)
}

private struct PlayerButton: View {
    let symbol: String
    let size: CGFloat
    let help: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(isEnabled ? .primary : .tertiary)
                .frame(width: size + 16, height: size + 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
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
