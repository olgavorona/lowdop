import SwiftUI

/// A parental gate that presents a randomized math problem.
/// Required by Apple Kids Category guidelines (1.3) to guard
/// external links, IAP, and settings areas.
struct ParentalGateView: View {
    @EnvironmentObject var ttsService: TTSService

    enum Purpose {
        case paywall
        case settings
        case privacyPolicy
        case account

        var subtitle: String {
            switch self {
            case .paywall: return "You're about to open the Store"
            case .settings: return "You're about to open Settings"
            case .privacyPolicy: return "You're about to open Privacy Info"
            case .account: return "You're about to open Account"
            }
        }

        var icon: String {
            switch self {
            case .paywall: return "cart.fill"
            case .settings: return "gearshape.fill"
            case .privacyPolicy: return "hand.raised.fill"
            case .account: return "person.circle.fill"
            }
        }

    }

    let purpose: Purpose
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @State private var a: Int
    @State private var b: Int
    @State private var answer = ""
    @State private var showError = false

    init(purpose: Purpose = .settings, onSuccess: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.purpose = purpose
        self.onSuccess = onSuccess
        self.onCancel = onCancel
        let a = Int.random(in: 2...9)
        let b = Int.random(in: 2...9)
        _a = State(initialValue: a)
        _b = State(initialValue: b)
    }

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .phone {
                GeometryReader { geometry in
                    parentalGateContent(isCompact: true)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geometry.size.height, alignment: .center)
                        .padding(.horizontal, 24)
                }
            } else {
                ScrollView {
                    parentalGateContent(isCompact: false)
                        .padding()
                }
            }
        }
        .background(AppColor.background)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onAppear {
            ttsService.stop()
            _ = ttsService.playAudio("parental_gate.mp3")
        }
        .onDisappear {
            ttsService.stop()
        }
    }

    private func parentalGateContent(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 12 : 20) {
            if !isCompact {
                Spacer(minLength: 24)
            }

            Image(systemName: purpose.icon)
                .font(.system(size: isCompact ? 30 : 36))
                .foregroundColor(AppColor.textTertiary)

            Text("Grown-Up Check")
                .font(.system(size: isCompact ? 22 : 24, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)

            Text(purpose.subtitle)
                .font(.system(size: isCompact ? 15 : 16, weight: .medium, design: .rounded))
                .foregroundColor(AppColor.textSecondary)

            Text("Please ask a grown-up to answer this question:")
                .font(.system(size: isCompact ? 15 : 16, design: .rounded))
                .foregroundColor(AppColor.textTertiary)
                .multilineTextAlignment(.center)

            Text("What is \(a) + \(b)?")
                .font(.system(size: isCompact ? 28 : 32, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .padding(.top, isCompact ? 2 : 8)

            TextField("Answer", text: $answer)
                .keyboardType(.numberPad)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(width: 120, height: isCompact ? 50 : 56)
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
                    .background(AppColor.accentGreen)
                    .cornerRadius(14)
            }
            .padding(.horizontal, isCompact ? 16 : 40)

            Button(action: {
                ttsService.stop()
                onCancel()
            }) {
                Text("Go Back")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(AppColor.textTertiary)
                    .frame(minHeight: isCompact ? 44 : nil)
            }
            .padding(.bottom, isCompact ? 0 : 24)
        }
    }

    private func checkAnswer() {
        if let entered = Int(answer), entered == a + b {
            ttsService.stop()
            onSuccess()
        } else {
            showError = true
            // Randomize new problem on failure
            a = Int.random(in: 2...9)
            b = Int.random(in: 2...9)
            answer = ""
        }
    }
}
