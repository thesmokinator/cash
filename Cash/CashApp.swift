//
//  CashApp.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftData
import SwiftUI

// MARK: - Navigation State

@Observable
class NavigationState {
    var isViewingAccount: Bool = false
    var isViewingScheduled: Bool = false
    var currentAccount: Account? = nil
}

// MARK: - Notifications

extension Notification.Name {
    static let addNewAccount = Notification.Name("addNewAccount")
    static let addNewTransaction = Notification.Name("addNewTransaction")
    static let addNewScheduledTransaction = Notification.Name("addNewScheduledTransaction")
    static let importOFX = Notification.Name("importOFX")
    static let importJSON = Notification.Name("importJSON")
    static let exportData = Notification.Name("exportData")
}

@main
struct CashApp: App {
    @State private var settings = AppSettings.shared
    @State private var navigationState = NavigationState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Account.self,
            Transaction.self,
            Entry.self,
            Attachment.self,
            RecurrenceRule.self,
            AppConfiguration.self,
            Budget.self,
            Envelope.self,
            Loan.self,
        ])

        #if ENABLE_ICLOUD
            let cloudManager = CloudKitManager.shared

            // Try CloudKit if enabled and available
            if cloudManager.isEnabled && cloudManager.isAvailable {
                do {
                    let cloudConfig = ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: false,
                        cloudKitDatabase: .private(cloudManager.containerIdentifier)
                    )
                    let container = try ModelContainer(for: schema, configurations: [cloudConfig])
                    cloudManager.modelContainer = container
                    return container
                } catch {
                    // CloudKit failed, fall back to local storage
                    print(
                        "CloudKit initialization failed: \(error). Falling back to local storage.")
                }
            }
        #endif

        // Fall back to local storage
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)])
            #if ENABLE_ICLOUD
                CloudKitManager.shared.modelContainer = container
            #endif
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(navigationState)
                .environment(\.locale, settings.language.locale)
                .preferredColorScheme(settings.theme.colorScheme)
                .onAppear {
                    // Start iCloud sync monitoring
                    CloudKitManager.shared.startListeningForRemoteChanges()
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(settings)
        #if os(macOS)
            .defaultSize(width: 1200, height: 800)
            .commands {
                AppCommands()
            }
        #endif

        #if os(macOS)
            Settings {
                MacOSSettingsView()
                    .environment(settings)
                    .modelContainer(sharedModelContainer)
            }
        #endif
    }
}

// MARK: - macOS Menu Bar Commands

#if os(macOS)
    struct AppCommands: Commands {
        var body: some Commands {
            // Replace the New Item menu
            CommandGroup(replacing: .newItem) {
                Button("New Transaction") {
                    NotificationCenter.default.post(name: .addNewTransaction, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("New Account") {
                    NotificationCenter.default.post(name: .addNewAccount, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("Import OFX...") {
                    NotificationCenter.default.post(name: .importOFX, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command])

                Button("Export Data...") {
                    NotificationCenter.default.post(
                        name: .exportData,
                        object: nil,
                        userInfo: ["format": "cashBackup"]
                    )
                }
                .keyboardShortcut("e", modifiers: [.command])
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Link(
                    "Cash on GitHub",
                    destination: URL(string: "https://github.com/thesmokinator/cash")!)
                Link(
                    "Privacy Policy",
                    destination: URL(
                        string: "https://github.com/thesmokinator/cash/blob/main/PRIVACY.md")!)
            }
        }
    }
#endif
