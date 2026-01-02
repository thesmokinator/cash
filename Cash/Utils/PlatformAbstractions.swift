//
//  PlatformAbstractions.swift
//  Cash
//
//  Cross-platform abstractions for iOS/iPadOS/macOS compatibility
//

import SwiftUI

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor
#else
import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
#endif

// MARK: - Device Type Detection

enum DeviceType {
    case phone
    case tablet
    case desktop

    static var current: DeviceType {
        #if os(macOS)
        return .desktop
        #else
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return .phone
        case .pad:
            return .tablet
        default:
            return .phone
        }
        #endif
    }

    var isCompact: Bool {
        self == .phone
    }

    var isDesktop: Bool {
        self == .desktop
    }
}

// MARK: - Adaptive Color Helper

/// Creates colors that adapt to light/dark mode on all platforms
struct AdaptiveColor {
    let light: Color
    let dark: Color

    var color: Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(self.dark) : NSColor(self.light)
        })
        #else
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(self.dark)
                : UIColor(self.light)
        })
        #endif
    }

    init(light: Color, dark: Color) {
        self.light = light
        self.dark = dark
    }

    init(lightHex: String, darkHex: String) {
        self.light = Color(hex: lightHex)
        self.dark = Color(hex: darkHex)
    }

    init(lightRGB: (r: Double, g: Double, b: Double), darkRGB: (r: Double, g: Double, b: Double)) {
        self.light = Color(red: lightRGB.r, green: lightRGB.g, blue: lightRGB.b)
        self.dark = Color(red: darkRGB.r, green: darkRGB.g, blue: darkRGB.b)
    }
}

// MARK: - Platform Image Extensions

extension Image {
    /// Creates a SwiftUI Image from platform-specific image data
    init?(platformImageData data: Data) {
        #if os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        self.init(nsImage: nsImage)
        #else
        guard let uiImage = UIImage(data: data) else { return nil }
        self.init(uiImage: uiImage)
        #endif
    }

    /// Creates a SwiftUI Image from a platform-native image
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

// MARK: - Haptic Feedback Helper

struct HapticFeedback {
    static func light() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    static func medium() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }

    static func heavy() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        #endif
    }

    static func selection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }

    static func notification(_ type: NotificationType) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .success:
            generator.notificationOccurred(.success)
        case .warning:
            generator.notificationOccurred(.warning)
        case .error:
            generator.notificationOccurred(.error)
        }
        #endif
    }

    enum NotificationType {
        case success
        case warning
        case error
    }
}

// MARK: - Cross-Platform View Modifiers

extension View {
    /// Applies navigationBarTitleDisplayMode only on iOS (no-op on macOS)
    @ViewBuilder
    func navigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Applies insetGrouped list style only on iOS (sidebar on macOS)
    @ViewBuilder
    func listStyleInsetGrouped() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self.listStyle(.sidebar)
        #endif
    }

    /// Applies presentationDetents only on iOS (no-op on macOS)
    @ViewBuilder
    func presentationDetentsMedium() -> some View {
        #if os(iOS)
        self.presentationDetents([.medium])
        #else
        self
        #endif
    }

    /// Applies presentationDetents only on iOS (no-op on macOS)
    @ViewBuilder
    func presentationDetentsLarge() -> some View {
        #if os(iOS)
        self.presentationDetents([.large])
        #else
        self
        #endif
    }
}
