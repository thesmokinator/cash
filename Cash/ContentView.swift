//
//  ContentView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query private var accounts: [Account]
    @State private var showingSettings = false
    @State private var showingWelcome = false
    
    private var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    }
    
    var body: some View {
        AccountListView()
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingSettings = true }) {
                        Label("Settings", systemImage: "gear")
                    }
                    .keyboardShortcut(",", modifiers: .command)
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingSettings = false
                                }
                            }
                        }
                }
                .frame(minWidth: 450, minHeight: 400)
                .environment(settings)
                .environment(\.locale, settings.language.locale)
            }
            .alert("Welcome to Cash", isPresented: $showingWelcome) {
                Button("Create Example Accounts") {
                    createDefaultAccounts()
                    markAsLaunched()
                }
                Button("Start Empty", role: .cancel) {
                    markAsLaunched()
                }
            } message: {
                Text("Cash helps you manage your personal finances using double-entry bookkeeping.\n\nEvery transaction has two sides: money comes from somewhere and goes somewhere else. For example, when you receive your salary, money enters your bank account (Asset) from your Salary (Income).\n\nWould you like to create a set of example accounts to get started?")
            }
            .task {
                if isFirstLaunch {
                    showingWelcome = true
                }
            }
    }
    
    private func createDefaultAccounts() {
        let defaultAccounts = ChartOfAccounts.createDefaultAccounts(currency: "EUR")
        for account in defaultAccounts {
            modelContext.insert(account)
        }
    }
    
    private func markAsLaunched() {
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Account.self, inMemory: true)
        .environment(AppSettings.shared)
}
