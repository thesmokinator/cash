//
//  AppSettings.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#endif

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
    case spanish = "es"
    case french = "fr"
    case german = "de"
    
    var id: String { rawValue }
    
    var labelKey: LocalizedStringKey {
        switch self {
        case .system:
            return "System"
        case .english:
            return "English"
        case .italian:
            return "Italiano"
        case .spanish:
            return "Español"
        case .french:
            return "Français"
        case .german:
            return "Deutsch"
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
        case .spanish:
            return "flag.fill"
        case .french:
            return "flag.fill"
        case .german:
            return "flag.fill"
        }
    }
}

@Observable
final class AppSettings {
    static let shared = AppSettings()
    
    private let themeKey = "appTheme"
    private let languageKey = "appLanguage"
    private let privacyModeKey = "privacyMode"
    private let showLiveQuotesKey = "showLiveQuotes"
    
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
    
    var privacyMode: Bool {
        didSet {
            UserDefaults.standard.set(privacyMode, forKey: privacyModeKey)
            syncToCloud()
        }
    }
    
    var showLiveQuotes: Bool {
        didSet {
            UserDefaults.standard.set(showLiveQuotes, forKey: showLiveQuotesKey)
            syncToCloud()
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
        
        self.privacyMode = UserDefaults.standard.bool(forKey: privacyModeKey)
        self.showLiveQuotes = UserDefaults.standard.bool(forKey: showLiveQuotesKey)
        
        // Apply theme and language on init
        applyTheme()
        applyLanguage()
        
        // Setup iCloud sync
        setupCloudSync()
    }
    
    // MARK: - iCloud Sync
    
    private func setupCloudSync() {
        // Listen for changes from other devices
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudChange(notification)
        }
        
        // Sync initial values from cloud
        NSUbiquitousKeyValueStore.default.synchronize()
        syncFromCloud()
    }
    
    private func syncToCloud() {
        let store = NSUbiquitousKeyValueStore.default
        store.set(privacyMode, forKey: privacyModeKey)
        store.set(showLiveQuotes, forKey: showLiveQuotesKey)
        store.synchronize()
    }
    
    private func syncFromCloud() {
        let store = NSUbiquitousKeyValueStore.default
        
        // Only sync if cloud has a value (to preserve local defaults)
        if store.object(forKey: privacyModeKey) != nil {
            let cloudPrivacyMode = store.bool(forKey: privacyModeKey)
            if cloudPrivacyMode != privacyMode {
                privacyMode = cloudPrivacyMode
                UserDefaults.standard.set(privacyMode, forKey: privacyModeKey)
            }
        }
        
        if store.object(forKey: showLiveQuotesKey) != nil {
            let cloudShowLiveQuotes = store.bool(forKey: showLiveQuotesKey)
            if cloudShowLiveQuotes != showLiveQuotes {
                showLiveQuotes = cloudShowLiveQuotes
                UserDefaults.standard.set(showLiveQuotes, forKey: showLiveQuotesKey)
            }
        }
    }
    
    private func handleCloudChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }
        
        // Only sync on server change or initial sync
        if reason == NSUbiquitousKeyValueStoreServerChange ||
           reason == NSUbiquitousKeyValueStoreInitialSyncChange {
            syncFromCloud()
            refreshID = UUID() // Trigger UI refresh
        }
    }
    
    private func applyTheme() {
        #if os(macOS)
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
        #endif
        // On iOS/iPadOS, the theme is controlled by the system or via overrideUserInterfaceStyle
    }
    
    private func applyLanguage() {
        switch language {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        case .italian:
            UserDefaults.standard.set(["it"], forKey: "AppleLanguages")
        case .spanish:
            UserDefaults.standard.set(["es"], forKey: "AppleLanguages")
        case .french:
            UserDefaults.standard.set(["fr"], forKey: "AppleLanguages")
        case .german:
            UserDefaults.standard.set(["de"], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
    
    func restartApp() {
        #if os(macOS)
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        
        NSApp.terminate(nil)
        #else
        // On iOS/iPadOS, apps cannot programmatically restart
        // Show a message to the user to manually restart the app
        #endif
    }
}
