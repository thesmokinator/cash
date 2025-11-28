//
//  ContentView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

// MARK: - App Notifications

extension Notification.Name {
    static let showWelcomeSheet = Notification.Name("showWelcomeSheet")
}

// MARK: - App State

@Observable
class AppState {
    var isLoading = false
    var loadingMessage = ""
    var showWelcomeSheet = false
    
    // Post notification to show welcome sheet globally
    static func requestShowWelcome() {
        NotificationCenter.default.post(name: .showWelcomeSheet, object: nil)
    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @State private var appState = AppState()
    @State private var showingSettings = false
    @State private var hasCheckedSetup = false
    @State private var showingOFXImportPicker = false
    @State private var showingOFXImportWizard = false
    @State private var parsedOFXTransactions: [OFXTransaction] = []
    @State private var showingOFXError = false
    @State private var ofxErrorMessage = ""
    
    var body: some View {
        AccountListView()
            .sheet(isPresented: $showingSettings) {
                SettingsView(appState: appState, dismissSettings: { showingSettings = false })
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingSettings = false
                            }
                        }
                    }
                .environment(settings)
            }
            .sheet(isPresented: $appState.showWelcomeSheet) {
                WelcomeSheet(appState: appState)
                    .environment(settings)
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showingOFXImportWizard) {
                OFXImportWizard(ofxTransactions: parsedOFXTransactions)
                    .environment(settings)
            }
            .fileImporter(
                isPresented: $showingOFXImportPicker,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                handleOFXImport(result: result)
            }
            .alert("Error", isPresented: $showingOFXError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(ofxErrorMessage)
            }
            .overlay {
                if appState.isLoading {
                    LoadingOverlayView(message: appState.loadingMessage)
                }
            }
            .environment(appState)
            .task {
                // Check setup status from database only once
                if !hasCheckedSetup {
                    hasCheckedSetup = true
                    if AppConfiguration.isSetupNeeded(in: modelContext) {
                        appState.showWelcomeSheet = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showWelcomeSheet)) { _ in
                // Small delay to ensure any windows are closed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    appState.showWelcomeSheet = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .importOFX)) { _ in
                showingOFXImportPicker = true
            }
    }
    
    private func handleOFXImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                ofxErrorMessage = String(localized: "Cannot access the selected file")
                showingOFXError = true
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                let transactions = try OFXParser.parse(data: data)
                parsedOFXTransactions = transactions
                showingOFXImportWizard = true
            } catch {
                ofxErrorMessage = error.localizedDescription
                showingOFXError = true
            }
            
        case .failure(let error):
            ofxErrorMessage = error.localizedDescription
            showingOFXError = true
        }
    }
}

// MARK: - Welcome Sheet

struct WelcomeSheet: View {
    let appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @State private var showingImportPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "building.columns.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            
            // Title
            VStack(spacing: 8) {
                Text("Welcome to Cash")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Track your personal finances with double-entry bookkeeping")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Options
            VStack(spacing: 16) {
                WelcomeOptionButton(
                    title: "Start fresh",
                    subtitle: "Create a new empty account structure",
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    startFresh()
                }
                
                WelcomeOptionButton(
                    title: "Use Demo Data",
                    subtitle: "Set up example accounts to explore the app",
                    icon: "sparkles",
                    color: .orange
                ) {
                    setupDemoAccounts()
                }
                
                WelcomeOptionButton(
                    title: "Import Backup",
                    subtitle: "Restore from a previous JSON export",
                    icon: "square.and.arrow.down.fill",
                    color: .green
                ) {
                    showingImportPicker = true
                }
                
                WelcomeOptionButton(
                    title: "Quit",
                    subtitle: "Exit the application",
                    icon: "xmark.circle.fill",
                    color: .red
                ) {
                    exit(0)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(40)
        .frame(width: 450, height: 560)
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Import Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func startFresh() {
        AppConfiguration.markSetupCompleted(in: modelContext)
        appState.showWelcomeSheet = false
    }
    
    private func setupDemoAccounts() {
        let defaultAccounts = ChartOfAccounts.createDefaultAccounts(currency: "EUR")
        for account in defaultAccounts {
            modelContext.insert(account)
        }
        AppConfiguration.markSetupCompleted(in: modelContext)
        appState.showWelcomeSheet = false
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access the selected file"
                showingError = true
                return
            }
            
            appState.isLoading = true
            appState.loadingMessage = String(localized: "Importing data...")
            
            Task.detached(priority: .userInitiated) {
                do {
                    let data = try Data(contentsOf: url)
                    url.stopAccessingSecurityScopedResource()
                    
                    await MainActor.run {
                        do {
                            _ = try DataExporter.importCashBackup(from: data, into: modelContext)
                            AppConfiguration.markSetupCompleted(in: modelContext)
                            appState.isLoading = false
                            appState.showWelcomeSheet = false
                        } catch {
                            appState.isLoading = false
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                    }
                } catch {
                    url.stopAccessingSecurityScopedResource()
                    await MainActor.run {
                        appState.isLoading = false
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Welcome Option Button

struct WelcomeOptionButton: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlayView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)
                
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(30)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
        .environment(AppSettings.shared)
        .environment(NavigationState())
}
