import SwiftUI

enum AppColor {
    static let textPrimary = Color(hex: "#5D4E37")!
    static let textSecondary = Color(hex: "#5D4E37")!.opacity(0.7)
    static let textTertiary = Color(hex: "#5D4E37")!.opacity(0.6)
    static let textFaint = Color(hex: "#5D4E37")!.opacity(0.3)

    static let accentBlue = Color(hex: "#5BA8D9")!
    static let accentGreen = Color(hex: "#6BBF7B")!
    static let accentYellow = Color(hex: "#F1C40F")!
    static let linkBlue = Color(hex: "#0288D1")!

    static let background = Color(hex: "#FFF8E7")!
    static let endMarkerGreen = Color(hex: "#27AE60")!
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6 else { return nil }
        var rgbValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgbValue)
        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgbValue & 0x0000FF) / 255.0
        )
    }
}
