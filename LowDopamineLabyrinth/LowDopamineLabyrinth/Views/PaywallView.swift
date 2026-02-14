import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            StarShape(points: 5, innerRatio: 0.45)
                .fill(Color(hex: "#F1C40F") ?? .yellow)
                .frame(width: 50, height: 50)

            Text("Great job today!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#5D4E37") ?? .brown)

            Text("Come back tomorrow for a new labyrinth,\nor unlock all of them now.")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                ForEach(subscriptionManager.products, id: \.id) { product in
                    Button(action: {
                        Task {
                            isPurchasing = true
                            let success = await subscriptionManager.purchase(product)
                            isPurchasing = false
                            if success { dismiss() }
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(product.displayName)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text(product.displayPrice)
                                .font(.system(size: 14, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "#5BA8D9") ?? .blue)
                        .cornerRadius(16)
                    }
                    .disabled(isPurchasing)
                }

                if subscriptionManager.products.isEmpty {
                    Text("Subscriptions loading...")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Button("Restore Purchases") {
                    Task { await subscriptionManager.restorePurchases() }
                }
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top, 8)
            }
            .padding(.horizontal, 40)

            Button(action: { dismiss() }) {
                Text("Maybe Later")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(height: 44)
            .padding(.bottom, 24)
        }
        .background(Color(hex: "#FFF8E7") ?? Color(.systemBackground))
        .task {
            await subscriptionManager.loadProducts()
        }
    }
}
