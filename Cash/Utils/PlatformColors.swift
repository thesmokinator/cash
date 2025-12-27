//
//  PlatformColors.swift
//  Cash
//
//  Cross-platform color definitions for macOS/iOS/iPadOS compatibility
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Platform Colors

extension Color {
    /// Background color for control elements (text fields, buttons, etc.)
    static var platformControlBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
    
    /// Main window/view background color
    static var platformWindowBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
    
    /// Separator color for dividers and borders
    static var platformSeparator: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }
    
    /// Text background color
    static var platformTextBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
    
    /// Secondary system background
    static var platformSecondaryBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
    
    /// Tertiary system background
    static var platformTertiaryBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor).opacity(0.8)
        #else
        Color(uiColor: .tertiarySystemBackground)
        #endif
    }
}
