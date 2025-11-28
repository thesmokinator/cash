//
//  AppSettings.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import Foundation
import SwiftUI
import AppKit

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var labelKey: LocalizedStringKey {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case italian = "it"
    
    var id: String { rawValue }
    
    var labelKey: LocalizedStringKey {
        switch self {
        case .system:
            return "System"
        case .english:
            return "English"
        case .italian:
            return "Italiano"
        }
    }
    
    var iconName: String {
        switch self {
        case .system:
            return "globe"
        case .english:
            return "flag.fill"
        case .italian:
            return "flag.fill"
        }
    }
}

@Observable
final class AppSettings {
    static let shared = AppSettings()
    
    private let themeKey = "appTheme"
    private let languageKey = "appLanguage"
    
    var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
            applyTheme()
        }
    }
    
    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: languageKey)
            applyLanguage()
            needsRestart = true
        }
    }
    
    var needsRestart: Bool = false
    
    // Used to force UI refresh when settings change
    var refreshID = UUID()
    
    private init() {
        if let themeRaw = UserDefaults.standard.string(forKey: themeKey),
           let savedTheme = AppTheme(rawValue: themeRaw) {
            self.theme = savedTheme
        } else {
            self.theme = .system
        }
        
        if let langRaw = UserDefaults.standard.string(forKey: languageKey),
           let savedLang = AppLanguage(rawValue: langRaw) {
            self.language = savedLang
        } else {
            self.language = .system
        }
        
        // Apply theme and language on init
        applyTheme()
        applyLanguage()
    }
    
    private func applyTheme() {
        DispatchQueue.main.async {
            switch self.theme {
            case .system:
                NSApp.appearance = nil
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
    
    private func applyLanguage() {
        switch language {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        case .italian:
            UserDefaults.standard.set(["it"], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
    
    func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        
        NSApp.terminate(nil)
    }
}
