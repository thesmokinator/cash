//
//  CashApp.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData

// MARK: - Navigation State

@Observable
class NavigationState {
    var isViewingAccount: Bool = false
    var currentAccount: Account? = nil
}

// MARK: - Cmd+N Notifications

extension Notification.Name {
    static let addNewAccount = Notification.Name("addNewAccount")
    static let addNewTransaction = Notification.Name("addNewTransaction")
    static let importOFX = Notification.Name("importOFX")
}

@main
struct CashApp: App {
    @State private var settings = AppSettings.shared
    @State private var menuAppState = AppState()
    @State private var navigationState = NavigationState()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Account.self,
            Transaction.self,
            Entry.self,
            Attachment.self,
            RecurrenceRule.self,
            AppConfiguration.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, settings.language.locale)
                .environment(navigationState)
        }
        .modelContainer(sharedModelContainer)
        .environment(settings)
        .commands {
            // Replace default New Window command with contextual actions
            CommandGroup(replacing: .newItem) {
                Button {
                    if navigationState.isViewingAccount {
                        NotificationCenter.default.post(name: .addNewTransaction, object: nil)
                    } else {
                        NotificationCenter.default.post(name: .addNewAccount, object: nil)
                    }
                } label: {
                    Text(navigationState.isViewingAccount ? "New transaction" : "New account")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            // Import menu
            CommandGroup(replacing: .importExport) {
                Button {
                    NotificationCenter.default.post(name: .importOFX, object: nil)
                } label: {
                    Label("Import OFX...", systemImage: "doc.badge.arrow.up")
                }
            }
        }
        
        Settings {
            SettingsView(appState: menuAppState, dismissSettings: {})
                .environment(settings)
                .environment(\.locale, settings.language.locale)
                .modelContainer(sharedModelContainer)
                .overlay {
                    if menuAppState.isLoading {
                        LoadingOverlayView(message: menuAppState.loadingMessage)
                    }
                }
                .sheet(isPresented: $menuAppState.showWelcomeSheet) {
                    WelcomeSheet(appState: menuAppState)
                        .modelContainer(sharedModelContainer)
                        .interactiveDismissDisabled()
                }
        }
    }
}
