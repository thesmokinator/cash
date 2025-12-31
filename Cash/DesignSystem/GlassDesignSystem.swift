//
//  GlassDesignSystem.swift
//  Cash
//
//  Design System for Glassmorphism UI with Teal/Green palette
//

import SwiftUI

// MARK: - Color Palette

struct CashColors {
    // Primary Teal Palette
    static let primary = Color(hex: "#00897B")          // Teal 600 - Main brand color
    static let primaryLight = Color(hex: "#4DB6AC")     // Teal 300 - Highlights
    static let primaryDark = Color(hex: "#00695C")      // Teal 800 - Dark accents
    static let accent = Color(hex: "#26A69A")           // Teal 400 - Secondary accent

    // Semantic Colors
    static let success = Color(hex: "#4CAF50")          // Green 500 - Positive values
    static let warning = Color(hex: "#FF9800")          // Orange 500 - Warnings
    static let error = Color(hex: "#F44336")            // Red 500 - Negative values, errors

    // Income/Expense Colors
    static let income = Color(hex: "#00C853")           // Green A700 - Income
    static let expense = Color(hex: "#FF5252")          // Red A200 - Expenses
    static let transfer = Color(hex: "#448AFF")         // Blue A200 - Transfers

    // Adaptive Glass Colors (for dark mode support)
    static let glassBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.15, alpha: 1.0)
            : UIColor(white: 1.0, alpha: 1.0)
    })

    static let glassBackgroundSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.2, alpha: 1.0)
            : UIColor(white: 1.0, alpha: 1.0)
    })

    // Background Gradients
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "#E0F2F1"), Color(hex: "#B2DFDB")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGradientDark = LinearGradient(
        colors: [Color(hex: "#004D40"), Color(hex: "#00695C")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Card Gradients
    static let cardGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.7),
            Color.white.opacity(0.4)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradientDark = LinearGradient(
        colors: [
            Color.white.opacity(0.15),
            Color.white.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Tab Bar
    static let tabBarBackground = Color(hex: "#00897B").opacity(0.95)
    static let tabBarSelected = Color.white
    static let tabBarUnselected = Color.white.opacity(0.6)
}

// MARK: - Typography

struct CashTypography {
    // Headers
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)

    // Body
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let callout = Font.system(size: 16, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)

    // Caption
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)

    // Numbers
    static let amount = Font.system(size: 24, weight: .bold, design: .rounded)
    static let amountLarge = Font.system(size: 36, weight: .bold, design: .rounded)
    static let amountSmall = Font.system(size: 17, weight: .semibold, design: .rounded)
}

// MARK: - Spacing

struct CashSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Corner Radius

struct CashRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xlarge: CGFloat = 20
    static let pill: CGFloat = 100
}

// MARK: - Shadows

struct CashShadow {
    static let light = Shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    static let medium = Shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    static let heavy = Shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 8)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Color Extension

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
            (a, r, g, b) = (255, 0, 0, 0)
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

// MARK: - Glass Effect Modifiers

extension View {
    /// Applies a glassmorphism background effect
    func glassBackground(
        cornerRadius: CGFloat = CashRadius.large,
        opacity: Double = 0.7
    ) -> some View {
        self
            .background(.ultraThinMaterial)
            .background(CashColors.glassBackground.opacity(opacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: CashShadow.light.color,
                radius: CashShadow.light.radius,
                x: CashShadow.light.x,
                y: CashShadow.light.y
            )
    }

    /// Applies a colored glassmorphism background
    func tintedGlassBackground(
        color: Color = CashColors.primary,
        cornerRadius: CGFloat = CashRadius.large,
        opacity: Double = 0.15
    ) -> some View {
        self
            .background(.ultraThinMaterial)
            .background(color.opacity(opacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: CashShadow.light.color,
                radius: CashShadow.light.radius,
                x: CashShadow.light.x,
                y: CashShadow.light.y
            )
    }

    /// Applies gradient background for main screens (adapts to dark mode)
    func cashBackground() -> some View {
        self.modifier(AdaptiveBackgroundModifier())
    }

    /// Applies the standard glass card style
    func glassCard() -> some View {
        self
            .padding(CashSpacing.lg)
            .glassBackground()
    }
}

// MARK: - Adaptive Background Modifier

struct AdaptiveBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if colorScheme == .dark {
                        Color(.systemBackground)
                    } else {
                        CashColors.backgroundGradient
                    }
                }
                .ignoresSafeArea()
            )
    }
}

// MARK: - Button Styles

struct GlassPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CashTypography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, CashSpacing.xl)
            .padding(.vertical, CashSpacing.md)
            .background(
                LinearGradient(
                    colors: [CashColors.primary, CashColors.primaryDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: CashRadius.medium))
            .shadow(
                color: CashColors.primary.opacity(0.4),
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GlassSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CashTypography.headline)
            .foregroundColor(CashColors.primary)
            .padding(.horizontal, CashSpacing.xl)
            .padding(.vertical, CashSpacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CashRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CashRadius.medium)
                    .stroke(CashColors.primary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassPrimaryButtonStyle {
    static var glassPrimary: GlassPrimaryButtonStyle { GlassPrimaryButtonStyle() }
}

extension ButtonStyle where Self == GlassSecondaryButtonStyle {
    static var glassSecondary: GlassSecondaryButtonStyle { GlassSecondaryButtonStyle() }
}
