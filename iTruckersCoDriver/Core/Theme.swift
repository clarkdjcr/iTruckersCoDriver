//
//  Theme.swift
//  iTruckersCoDriver
//
//  Created by Antigravity on 5/19/26.
//

import SwiftUI

struct Theme {
    static let primary = Color(hex: "007AFF")
    static let primaryGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "007AFF"), Color(hex: "00C6FF")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let background = Color(hex: "0A0A0C")
    static let cardBackground = Color(hex: "1C1C1E")
    static let cardBackgroundGlass = Color.white.opacity(0.05)
    
    static let accent = Color(hex: "FF3B30") // Danger/Alert
    static let warning = Color(hex: "FF9500") // Warning
    static let success = Color(hex: "34C759") // Compliant
    
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    
    struct Typography {
        static func title(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .bold, design: .rounded) }
        static func body(_ size: CGFloat = 16) -> Font { .system(size: size, weight: .regular, design: .default) }
        static func caption(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium, design: .default) }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}
