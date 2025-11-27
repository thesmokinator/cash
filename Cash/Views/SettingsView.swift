//
//  SettingsView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    let appState: AppState
    let dismissSettings: () -> Void
    
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
                Label("Export / Import", systemImage: "arrow.up.arrow.down.circle.fill")
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
                Label("Data", systemImage: "externaldrive.fill")
            } footer: {
                Text("This will delete all accounts and transactions.")
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
            allowedContentTypes: [.json],
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
    
    // MARK: - Export
    
    private func exportData(format: ExportFormat) {
        do {
            let data: Data
            
            switch format {
            case .json:
                data = try DataExporter.exportJSON(accounts: accounts, transactions: transactions)
            case .ofx:
                data = try DataExporter.exportOFX(accounts: accounts, transactions: transactions)
            }
            
            let filename = DataExporter.generateFilename(for: format)
            
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [format.utType]
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
                            let result = try DataExporter.importJSON(from: data, into: modelContext)
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
        
        // Note: We don't delete AppConfiguration - we update it instead
    }
    
    // MARK: - Reset
    
    private func resetAllData() {
        // Close settings sheet immediately (for sheet presentation)
        dismissSettings()
        
        // Show loading overlay
        appState.isLoading = true
        appState.loadingMessage = String(localized: "Erasing data...")
        
        Task {
            // Small delay to let sheet dismiss
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            await MainActor.run {
                // Delete all data (except AppConfiguration)
                deleteAllData()
                
                // Mark that setup is needed again
                AppConfiguration.markSetupNeeded(in: modelContext)
                
                do {
                    try modelContext.save()
                } catch {
                    print("Error saving after delete: \(error)")
                }
                
                // Hide loading
                appState.isLoading = false
                
                // Close Settings window (macOS menu)
                NSApp.keyWindow?.close()
                
                // Notify to show welcome sheet via NotificationCenter
                AppState.requestShowWelcome()
            }
        }
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
                            Text(format == .json ? "Full backup" : "Bank format")
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
    NavigationStack {
        SettingsView(appState: AppState(), dismissSettings: {})
    }
    .environment(AppSettings.shared)
}
