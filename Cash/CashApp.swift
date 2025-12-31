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
                    cloudManager.modelContext = container.mainContext
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
                CloudKitManager.shared.modelContext = container.mainContext
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
                .onAppear {
                    // Start iCloud sync monitoring
                    CloudKitManager.shared.startListeningForRemoteChanges()
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(settings)
    }
}
