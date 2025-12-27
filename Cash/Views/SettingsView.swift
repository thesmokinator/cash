//
//  SettingsView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData

#if os(macOS)
import AppKit
#endif

import UniformTypeIdentifiers

#if ENABLE_ICLOUD
import CloudKit
#endif

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "general"
    case data = "data"
    case about = "about"
    
    var id: String { rawValue }
    
    var labelKey: LocalizedStringKey {
        switch self {
        case .general:
            return "General"
        case .data:
            return "Data"
        case .about:
            return "About"
        }
    }
    
    var iconName: String {
        switch self {
        case .general:
            return "gearshape.fill"
        case .data:
            return "externaldrive.fill"
        case .about:
            return "info.circle.fill"
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    let appState: AppState
    let dismissSettings: () -> Void
    
    @State private var selectedTab: SettingsTab = .general
    @State private var showingFirstResetAlert = false
    @State private var showingSecondResetAlert = false
    @State private var showingExportFormatPicker = false
    @State private var showingImportConfirmation = false
    @State private var showingImportFilePicker = false
    @State private var showingExportSuccess = false
    @State private var showingImportSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var importResult: (accountsCount: Int, transactionsCount: Int) = (0, 0)
    
    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Bar with icons
                tabBar
                
                Divider()
                
                // Content
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismissSettings()
                    }
                }
            }
        }
        .frame(width: 580, height: 520)
        .id(settings.refreshID)
        .overlay {
            if appState.isLoading {
                LoadingOverlayView(message: appState.loadingMessage)
            }
        }
        .alert("Reset all data?", isPresented: $showingFirstResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                showingSecondResetAlert = true
            }
        } message: {
            Text("This will permanently delete all your accounts and transactions. This action cannot be undone.")
        }
        .alert("Are you absolutely sure?", isPresented: $showingSecondResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete everything", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("All data will be permanently deleted.")
        }
        .sheet(isPresented: $showingExportFormatPicker) {
            ExportFormatPickerView { format in
                exportData(format: format)
            }
        }
        .alert("Import data?", isPresented: $showingImportConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                showingImportFilePicker = true
            }
        } message: {
            Text("Importing will replace all existing data. Make sure to export your current data first if needed.")
        }
        .fileImporter(
            isPresented: $showingImportFilePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Export successful", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your data has been exported successfully.")
        }
        .alert("Import successful", isPresented: $showingImportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Imported \(importResult.accountsCount) accounts and \(importResult.transactionsCount) transactions.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.platformWindowBackground)
    }
    
    private func tabButton(for tab: SettingsTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 24))
                    .frame(height: 28)
                Text(tab.labelKey)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    private var tabContent: some View {
        Form {
            switch selectedTab {
            case .general:
                GeneralSettingsTabContent()
            case .data:
                DataSettingsTabContent(
                    showingExportFormatPicker: $showingExportFormatPicker,
                    showingImportConfirmation: $showingImportConfirmation,
                    showingFirstResetAlert: $showingFirstResetAlert
                )
            case .about:
                AboutSettingsTabContent()
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - Export
    
    private func exportData(format: ExportFormat) {
        do {
            let data: Data
            
            switch format {
            case .cashBackup:
                data = try DataExporter.exportCashBackup(accounts: accounts, transactions: transactions)
            case .ofx:
                data = try DataExporter.exportOFX(accounts: accounts, transactions: transactions)
            }
            
            let filename = DataExporter.generateFilename(for: format)
            
            #if os(macOS)
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = filename
            savePanel.canCreateDirectories = true
            
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    do {
                        try data.write(to: url)
                        showingExportSuccess = true
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
            #else
            // iOS export not implemented yet
            errorMessage = "Export is not available on iOS yet"
            showingError = true
            #endif
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    // MARK: - Import
    
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
                        // Delete existing data first
                        deleteAllData()
                        
                        do {
                            let result = try DataExporter.importCashBackup(from: data, into: modelContext)
                            
                            importResult = result
                            appState.isLoading = false
                            showingImportSuccess = true
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
    
    private func deleteAllData() {
        let attachments = (try? modelContext.fetch(FetchDescriptor<Attachment>())) ?? []
        for attachment in attachments { modelContext.delete(attachment) }
        
        let rules = (try? modelContext.fetch(FetchDescriptor<RecurrenceRule>())) ?? []
        for rule in rules { modelContext.delete(rule) }
        
        let entries = (try? modelContext.fetch(FetchDescriptor<Entry>())) ?? []
        for entry in entries { modelContext.delete(entry) }
        
        let txns = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        for txn in txns { modelContext.delete(txn) }
        
        let accts = (try? modelContext.fetch(FetchDescriptor<Account>())) ?? []
        for acct in accts { modelContext.delete(acct) }
        
        let budgets = (try? modelContext.fetch(FetchDescriptor<Budget>())) ?? []
        for budget in budgets { modelContext.delete(budget) }
        
        let loans = (try? modelContext.fetch(FetchDescriptor<Loan>())) ?? []
        for loan in loans { modelContext.delete(loan) }
    }
    
    // MARK: - Reset
    
    private func resetAllData() {
        dismissSettings()
        
        appState.isLoading = true
        appState.loadingMessage = String(localized: "Erasing data...")
        
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            await MainActor.run {
                deleteAllData()
                AppConfiguration.markSetupNeeded(in: modelContext)
                
                do {
                    try modelContext.save()
                } catch {
                    print("Error saving after delete: \(error)")
                }
                
                appState.isLoading = false
                AppState.requestShowWelcome()
            }
        }
    }
}

// MARK: - General Settings Tab Content

struct GeneralSettingsTabContent: View {
    @Environment(AppSettings.self) private var settings
    @State private var showingRestartAlert = false
    
    var body: some View {
        @Bindable var settings = settings
        
        Section("Appearance") {
            Picker("Theme", selection: $settings.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.labelKey).tag(theme)
                }
            }
            .pickerStyle(.menu)
            
            Picker("Language", selection: $settings.language) {
                let languagesOrder: [AppLanguage] = [.system, .english, .italian, .spanish, .french, .german]
                ForEach(languagesOrder) { language in
                    Text(language.labelKey).tag(language)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: settings.language) {
                if settings.needsRestart {
                    showingRestartAlert = true
                }
            }
        }
        
        Section {
            Toggle("Show live ETF quotes", isOn: $settings.showLiveQuotes)
        } header: {
            Text("Investments")
        } footer: {
            Text("When enabled, displays real-time price quotes for investment accounts with an ISIN code. This setting syncs across your devices via iCloud.")
        }
        .alert("Restart required", isPresented: $showingRestartAlert) {
            Button("Later") {
                settings.needsRestart = false
            }
            Button("Restart now") {
                settings.needsRestart = false
                AppSettings.shared.restartApp()
            }
        } message: {
            Text("The app needs to restart to apply language changes.")
        }
    }
}

// MARK: - Data Settings Tab Content

struct DataSettingsTabContent: View {
    @Binding var showingExportFormatPicker: Bool
    @Binding var showingImportConfirmation: Bool
    @Binding var showingFirstResetAlert: Bool
    
    #if ENABLE_ICLOUD
    @State private var cloudManager = CloudKitManager.shared
    @State private var showingRestartAlert = false
    
    private var hasICloudAccount: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
    #endif
    
    var body: some View {
        #if ENABLE_ICLOUD
        // iCloud Sync Section
        Section {
            Toggle("Enable iCloud sync", isOn: Binding(
                get: { cloudManager.isEnabled },
                set: { newValue in
                    cloudManager.isEnabled = newValue
                    if cloudManager.needsRestart {
                        showingRestartAlert = true
                    }
                }
            ))
            .disabled(!cloudManager.isAvailable)
            
            if cloudManager.isEnabled {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(cloudManager.accountStatus == .available ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(cloudManager.accountStatusDescription)
                            .foregroundStyle(.secondary)
                    }
                }
                
                LabeledContent("Storage used") {
                    if cloudManager.isLoadingStorage {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text(cloudManager.formattedStorageUsed)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("iCloud Sync")
        } footer: {
            if !hasICloudAccount {
                Text("Sign in to iCloud in System Settings to enable sync.")
            } else {
                Text("Sync your data across all your devices.")
            }
        }
        .onAppear {
            Task {
                await cloudManager.checkAccountStatus()
                await cloudManager.fetchStorageUsed()
            }
        }
        .alert("Restart required", isPresented: $showingRestartAlert) {
            Button("Later") {
                cloudManager.needsRestart = false
            }
            Button("Restart now") {
                cloudManager.needsRestart = false
                AppSettings.shared.restartApp()
            }
        } message: {
            Text("The app needs to restart to apply iCloud changes.")
        }
        #endif
        
        Section {
            Button {
                showingExportFormatPicker = true
            } label: {
                Label("Export data", systemImage: "square.and.arrow.up")
            }
            
            Button {
                showingImportConfirmation = true
            } label: {
                Label("Import data", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Export / Import")
        } footer: {
            Text("Export your data as JSON (full backup) or OFX (standard bank format). Import will replace all existing data.")
        }
        
        Section {
            Button(role: .destructive) {
                showingFirstResetAlert = true
            } label: {
                Label("Reset all data", systemImage: "trash.fill")
            }
        } header: {
            Text("Danger zone")
        } footer: {
            Text("This will delete all accounts and transactions.")
        }
    }
}

// MARK: - About Settings Tab Content

struct AboutSettingsTabContent: View {
    @State private var showingLicense = false
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    var body: some View {
        Section {
            VStack(spacing: 16) {
                Image("AppIcon")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                VStack(spacing: 4) {
                    Text("Cash")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Version \(appVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text("A personal finance management application inspired by Gnucash, built with SwiftUI and SwiftData.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    showingLicense = true
                } label: {
                    Text("© 2025 Michele Broggi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        
        Section {
            Link(destination: URL(string: "https://github.com/thesmokinator/cash")!) {
                Label("Project website", systemImage: "link")
            }
            
            Link(destination: URL(string: "https://github.com/thesmokinator/cash/blob/main/PRIVACY.md")!) {
                Label("Privacy policy", systemImage: "hand.raised.fill")
            }
        } header: {
            Text("Links")
        }
        .sheet(isPresented: $showingLicense) {
            LicenseView()
        }
    }
}

// MARK: - License View

struct LicenseView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var licenseText: String {
        guard let url = Bundle.main.url(forResource: "LICENSE", withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return "License file not found"
        }
        return content
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("MIT License")
                .font(.headline)
            
            ScrollView {
                Text(licenseText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(width: 450, height: 350)
    }
}

// MARK: - Export Format Picker

struct ExportFormatPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ExportFormat) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Choose export format")
                .font(.headline)
            
            Text("JSON is recommended for full backup and restore. OFX is the standard bank format for importing into other apps.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                ForEach(ExportFormat.allCases) { format in
                    Button {
                        dismiss()
                        onSelect(format)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: format.iconName)
                                .font(.largeTitle)
                            Text(format.localizedName)
                                .font(.headline)
                            Text(format == .cashBackup ? "Full backup" : "Bank format")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 120, height: 100)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
        }
        .padding(30)
        .frame(width: 340)
    }
}

#Preview {
    SettingsView(appState: AppState(), dismissSettings: {})
        .environment(AppSettings.shared)
}
