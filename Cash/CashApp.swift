//
//  CashApp.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData

@main
struct CashApp: App {
    @State private var settings = AppSettings.shared
    @State private var menuAppState = AppState()
    
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
        }
        .modelContainer(sharedModelContainer)
        .environment(settings)
        
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
