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
    var isViewingScheduled: Bool = false
    var currentAccount: Account? = nil
}

// MARK: - Cmd+N Notifications

extension Notification.Name {
    static let addNewAccount = Notification.Name("addNewAccount")
    static let addNewTransaction = Notification.Name("addNewTransaction")
    static let addNewScheduledTransaction = Notification.Name("addNewScheduledTransaction")
    static let importOFX = Notification.Name("importOFX")
    static let showSettings = Notification.Name("showSettings")
}

@main
struct CashApp: App {
    @State private var settings = AppSettings.shared
    @State private var menuAppState = AppState()
    @State private var navigationState = NavigationState()
    @State private var showingSettingsSheet = false
    @Environment(\.openWindow) private var openWindow
    
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
                return try ModelContainer(for: schema, configurations: [cloudConfig])
            } catch {
                // CloudKit failed, fall back to local storage
                print("CloudKit initialization failed: \(error). Falling back to local storage.")
            }
        }
        #endif
        
        // Local storage (default)
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(navigationState)
                .sheet(isPresented: $showingSettingsSheet) {
                    SettingsView(appState: menuAppState, dismissSettings: { showingSettingsSheet = false })
                        .environment(settings)
                        .modelContainer(sharedModelContainer)
                }
                .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
                    showingSettingsSheet = true
                }
                .onAppear {
                    // Start iCloud sync monitoring
                    CloudKitManager.shared.startListeningForRemoteChanges()
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(settings)
        .commands {
            // Add Window menu with option to show main window
            CommandGroup(after: .windowList) {
                Button("Show Main Window") {
                    if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                        window.makeKeyAndOrderFront(nil)
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    } else {
                        openWindow(id: "main")
                    }
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            
            // Replace default New Window command with contextual actions
            CommandGroup(replacing: .newItem) {
                Button {
                    ensureMainWindowOpen()
                    if navigationState.isViewingAccount {
                        NotificationCenter.default.post(name: .addNewTransaction, object: nil)
                    } else if navigationState.isViewingScheduled {
                        NotificationCenter.default.post(name: .addNewScheduledTransaction, object: nil)
                    } else {
                        NotificationCenter.default.post(name: .addNewAccount, object: nil)
                    }
                } label: {
                    if navigationState.isViewingAccount {
                        Text("New transaction")
                    } else if navigationState.isViewingScheduled {
                        Text("New scheduled transaction")
                    } else {
                        Text("New account")
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            // Import menu
            CommandGroup(replacing: .importExport) {
                Button {
                    ensureMainWindowOpen()
                    NotificationCenter.default.post(name: .importOFX, object: nil)
                } label: {
                    Label("Import OFX...", systemImage: "doc.badge.arrow.up")
                }
            }
            
            // Settings menu item (replaces system Preferences)
            CommandGroup(replacing: .appSettings) {
                Button {
                    ensureMainWindowOpen()
                    showingSettingsSheet = true
                } label: {
                    Text("Settings...")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
    
    private func ensureMainWindowOpen() {
        if let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.identifier?.rawValue.contains("main") == true }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
