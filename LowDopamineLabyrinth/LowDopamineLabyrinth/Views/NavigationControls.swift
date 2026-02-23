import SwiftUI

struct NavigationControls: View {
    let currentIndex: Int
    let total: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onReset: () -> Void
    var onBack: (() -> Void)? = nil
    @Binding var ttsEnabled: Bool

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// iPhone landscape = compact, iPad = regular
    private var isCompact: Bool { verticalSizeClass == .compact }
    private var buttonSize: CGFloat { isCompact ? 28 : 48 }
    private var iconSize: CGFloat { isCompact ? 11 : 16 }
    private var chevronSize: CGFloat { isCompact ? 13 : 18 }
    private var counterSize: CGFloat { isCompact ? 11 : 15 }

    var body: some View {
        HStack(spacing: isCompact ? 6 : 12) {
            // Close (X) — left, circular
            if let onBack = onBack {
                Button(action: onBack) {
                    Image(systemName: "xmark")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Close")
            }

            Spacer()

            // Centered pill: prev | counter | next
            HStack(spacing: isCompact ? 10 : 16) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: chevronSize, weight: .semibold))
                        .foregroundColor(currentIndex > 0 ? .white : .white.opacity(0.3))
                }
                .disabled(currentIndex <= 0)
                .accessibilityLabel("Previous labyrinth")

                Text("\(currentIndex + 1) / \(total)")
                    .font(.system(size: counterSize, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: chevronSize, weight: .semibold))
                        .foregroundColor(currentIndex < total - 1 ? .white : .white.opacity(0.3))
                }
                .disabled(currentIndex >= total - 1)
                .accessibilityLabel("Next labyrinth")
            }
            .padding(.horizontal, isCompact ? 10 : 20)
            .padding(.vertical, isCompact ? 4 : 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            Spacer()

            // Sound toggle — circular
            Button(action: { ttsEnabled.toggle() }) {
                Image(systemName: ttsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityLabel(ttsEnabled ? "Mute sound" : "Enable sound")

            // Reset — circular
            Button(action: onReset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Reset drawing")
        }
        .padding(.horizontal, isCompact ? 6 : 12)
        .padding(.vertical, isCompact ? 2 : 8)
    }
}
