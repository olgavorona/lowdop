import SwiftUI

struct NavigationControls: View {
    let currentIndex: Int
    let total: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onReset: () -> Void
    var onBack: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            // Back to grid button
            if let onBack = onBack {
                Button(action: onBack) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                }
            }

            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(currentIndex > 0 ? .white : .white.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
            }
            .disabled(currentIndex <= 0)

            Spacer()

            Button(action: onReset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
            }

            Spacer()

            Text("\(currentIndex + 1) / \(total)")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(currentIndex < total - 1 ? .white : .white.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
            }
            .disabled(currentIndex >= total - 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
