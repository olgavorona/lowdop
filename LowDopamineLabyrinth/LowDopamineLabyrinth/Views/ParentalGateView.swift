import SwiftUI

/// A parental gate that presents a randomized math problem.
/// Required by Apple Kids Category guidelines (1.3) to guard
/// external links, IAP, and settings areas.
struct ParentalGateView: View {
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @State private var a: Int
    @State private var b: Int
    @State private var answer = ""
    @State private var showError = false

    init(onSuccess: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onSuccess = onSuccess
        self.onCancel = onCancel
        let a = Int.random(in: 12...29)
        let b = Int.random(in: 12...29)
        _a = State(initialValue: a)
        _b = State(initialValue: b)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Grown-Up Check")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#5D4E37") ?? .brown)

            Text("Please ask a grown-up to answer this question:")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("What is \(a) + \(b)?")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                .padding(.top, 8)

            TextField("Answer", text: $answer)
                .keyboardType(.numberPad)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(width: 120, height: 56)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

            if showError {
                Text("That's not right. Try again!")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.red)
            }

            Button(action: checkAnswer) {
                Text("Continue")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "#6BBF7B") ?? .green)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)

            Button(action: onCancel) {
                Text("Go Back")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(hex: "#FFF8E7") ?? Color(.systemBackground))
    }

    private func checkAnswer() {
        if let entered = Int(answer), entered == a + b {
            onSuccess()
        } else {
            showError = true
            // Randomize new problem on failure
            a = Int.random(in: 12...29)
            b = Int.random(in: 12...29)
            answer = ""
        }
    }
}
