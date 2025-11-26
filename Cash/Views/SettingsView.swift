//
//  SettingsView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData
import AppKit

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var showingFirstResetAlert = false
    @State private var showingSecondResetAlert = false
    
    var body: some View {
        @Bindable var settings = settings
        
        Form {
            Section {
                Picker("Theme", selection: $settings.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(theme.localizedName, systemImage: theme.iconName)
                            .tag(theme)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Label("Appearance", systemImage: "paintbrush.fill")
            } footer: {
                Text("Choose how Cash looks. System follows your macOS appearance settings.")
            }
            
            Section {
                Picker("Language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Label(language.localizedName, systemImage: language.iconName)
                            .tag(language)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Label("Language", systemImage: "globe")
            }
            
            Section {
                Button(role: .destructive) {
                    showingFirstResetAlert = true
                } label: {
                    Label("Reset All Data", systemImage: "trash.fill")
                }
            } header: {
                Label("Data", systemImage: "externaldrive.fill")
            } footer: {
                Text("This will delete all accounts and transactions and restart the app.")
            }
            
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("About", systemImage: "info.circle.fill")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .id(settings.refreshID)
        .alert("Reset All Data?", isPresented: $showingFirstResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                showingSecondResetAlert = true
            }
        } message: {
            Text("This will permanently delete all your accounts and transactions. This action cannot be undone.")
        }
        .alert("Are you absolutely sure?", isPresented: $showingSecondResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Everything", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("All data will be permanently deleted and the app will restart.")
        }
    }
    
    private func resetAllData() {
        // Delete all data
        do {
            try modelContext.delete(model: Entry.self)
            try modelContext.delete(model: Transaction.self)
            try modelContext.delete(model: Account.self)
            try modelContext.save()
        } catch {
            print("Error deleting data: \(error)")
        }
        
        // Reset first launch flag
        UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
        
        // Restart the app
        settings.restartApp()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppSettings.shared)
}
