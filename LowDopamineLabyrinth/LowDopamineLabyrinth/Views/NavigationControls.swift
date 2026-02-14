import SwiftUI

struct NavigationControls: View {
    let currentIndex: Int
    let total: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(currentIndex > 0 ? .white : .white.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
            }
            .disabled(currentIndex <= 0)

            Spacer()

            Button(action: onReset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Progress dots
            Text("\(currentIndex + 1) / \(total)")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(currentIndex < total - 1 ? .white : .white.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
            }
            .disabled(currentIndex >= total - 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
