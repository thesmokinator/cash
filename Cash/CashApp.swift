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
    static let showSubscription = Notification.Name("showSubscription")
    static let showSubscriptionTab = Notification.Name("showSubscriptionTab")
    static let showSettings = Notification.Name("showSettings")
}

@main
struct CashApp: App {
    @State private var settings = AppSettings.shared
    @State private var menuAppState = AppState()
    @State private var navigationState = NavigationState()
    @State private var showingSubscriptionSheet = false
    @State private var showingSettingsSheet = false
    
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
        WindowGroup {
            ContentView()
                .environment(navigationState)
                .sheet(isPresented: $showingSettingsSheet) {
                    SettingsView(appState: menuAppState, dismissSettings: { showingSettingsSheet = false })
                        .environment(settings)
                        .modelContainer(sharedModelContainer)
                }
                .sheet(isPresented: $showingSubscriptionSheet) {
                    SubscriptionSheetView()
                }
                .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
                    showingSettingsSheet = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .showSubscriptionTab)) { _ in
                    showingSettingsSheet = true
                    // The SettingsView will handle switching to the subscription tab
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(settings)
        .commands {
            // Replace default New Window command with contextual actions
            CommandGroup(replacing: .newItem) {
                Button {
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
                    NotificationCenter.default.post(name: .importOFX, object: nil)
                } label: {
                    Label("Import OFX...", systemImage: "doc.badge.arrow.up")
                }
            }
            
            // Settings menu item (replaces system Preferences)
            CommandGroup(replacing: .appSettings) {
                Button {
                    showingSettingsSheet = true
                } label: {
                    Text("Settings...")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            // Subscription menu item in App menu
            CommandGroup(after: .appInfo) {
                Button {
                    showingSubscriptionSheet = true
                } label: {
                    Label("Subscription...", systemImage: "crown.fill")
                }
            }
        }
    }
}

// MARK: - Subscription Sheet View

struct SubscriptionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("Subscription")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            
            Divider()
            
            // Content
            SubscriptionSettingsTab()
        }
        .frame(width: 500, height: 450)
    }
}
