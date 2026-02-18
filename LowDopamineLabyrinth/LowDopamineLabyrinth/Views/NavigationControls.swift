import SwiftUI

struct NavigationControls: View {
    let currentIndex: Int
    let total: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onReset: () -> Void
    var onBack: (() -> Void)? = nil
    @Binding var ttsEnabled: Bool

    var body: some View {
        HStack {
            // Close (X) — left, circular
            if let onBack = onBack {
                Button(action: onBack) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }

            Spacer()

            // Centered pill: prev | counter | next
            HStack(spacing: 16) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(currentIndex > 0 ? .white : .white.opacity(0.3))
                }
                .disabled(currentIndex <= 0)

                Text("\(currentIndex + 1) / \(total)")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(currentIndex < total - 1 ? .white : .white.opacity(0.3))
                }
                .disabled(currentIndex >= total - 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            Spacer()

            // Sound toggle — circular
            Button(action: { ttsEnabled.toggle() }) {
                Image(systemName: ttsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            // Reset — circular
            Button(action: onReset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
