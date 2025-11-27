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
        VStack(spacing: 0) {
            // Tab Bar
            tabBar
            
            Divider()
            
            // Content
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 500, height: 400)
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
        .background(Color(nsColor: .windowBackgroundColor))
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
        switch selectedTab {
        case .general:
            GeneralSettingsTab()
        case .data:
            DataSettingsTab(
                showingExportFormatPicker: $showingExportFormatPicker,
                showingImportConfirmation: $showingImportConfirmation,
                showingFirstResetAlert: $showingFirstResetAlert
            )
        case .about:
            AboutSettingsTab()
        }
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
                NSApp.keyWindow?.close()
                AppState.requestShowWelcome()
            }
        }
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {
    @Environment(AppSettings.self) private var settings
    
    var body: some View {
        @Bindable var settings = settings
        
        Form {
            Picker("Theme", selection: $settings.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.labelKey).tag(theme)
                }
            }
            .pickerStyle(.menu)
            
            Picker("Language", selection: $settings.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.labelKey).tag(language)
                }
            }
            .pickerStyle(.menu)
        }
        .formStyle(.grouped)
    }
}

// MARK: - Data Settings Tab

struct DataSettingsTab: View {
    @Binding var showingExportFormatPicker: Bool
    @Binding var showingImportConfirmation: Bool
    @Binding var showingFirstResetAlert: Bool
    
    var body: some View {
        Form {
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
        .formStyle(.grouped)
    }
}

// MARK: - About Settings Tab

struct AboutSettingsTab: View {
    @State private var showingLicense = false
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            
            Text("Cash")
                .font(.title)
                .fontWeight(.semibold)
            
            VStack(spacing: 2) {
                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("Build \(buildNumber)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Text("A simplified macOS financial management application inspired by Gnucash, built with SwiftUI and SwiftData.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Spacer()
            
            Button {
                showingLicense = true
            } label: {
                Text("© 2025 Michele Broggi")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
