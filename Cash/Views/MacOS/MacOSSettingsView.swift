//
//  MacOSSettingsView.swift
//  Cash
//
//  macOS Settings window with tabbed interface
//

#if os(macOS)
    import AppKit
    import SwiftData
    import SwiftUI
    import UniformTypeIdentifiers

    // MARK: - Main Settings View

    struct MacOSSettingsView: View {
        var body: some View {
            TabView {
                GeneralSettingsTab()
                    .tabItem {
                        Label("General", systemImage: "gearshape")
                    }

                DataSettingsTab()
                    .tabItem {
                        Label("Data", systemImage: "externaldrive")
                    }

                AboutSettingsTab()
                    .tabItem {
                        Label("About", systemImage: "info.circle")
                    }
            }
            .frame(width: 500, height: 400)
        }
    }

    // MARK: - General Settings Tab

    struct GeneralSettingsTab: View {
        @Environment(AppSettings.self) private var settings

        var body: some View {
            Form {
                // Language Section
                Section {
                    Picker(
                        "Language",
                        selection: Binding(
                            get: { settings.language },
                            set: { settings.language = $0 }
                        )
                    ) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.labelKey).tag(language)
                        }
                    }
                } header: {
                    Text("Language")
                }

                // Theme Section
                Section {
                    HStack(spacing: 16) {
                        ForEach(AppTheme.allCases) { theme in
                            ThemeOptionButton(
                                theme: theme,
                                isSelected: settings.theme == theme,
                                action: { settings.theme = theme }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Theme")
                }

                // Live ETF Quotes Section
                Section {
                    Toggle(
                        "Display real-time quotes for investment accounts",
                        isOn: Binding(
                            get: { settings.showLiveQuotes },
                            set: { settings.showLiveQuotes = $0 }
                        ))
                } header: {
                    Text("Live ETF Quotes")
                }

                // Privacy Mode Section
                Section {
                    Toggle(
                        "Hide sensitive balance information",
                        isOn: Binding(
                            get: { settings.privacyMode },
                            set: { settings.privacyMode = $0 }
                        ))
                } header: {
                    Text("Privacy Mode")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Theme Option Button

    struct ThemeOptionButton: View {
        let theme: AppTheme
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(backgroundColor)
                            .frame(width: 80, height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isSelected
                                            ? Color.accentColor : Color(nsColor: .separatorColor),
                                        lineWidth: isSelected ? 2 : 1)
                            )

                        // Mini preview
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(previewAccentColor)
                                .frame(width: 40, height: 6)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(previewSecondaryColor)
                                .frame(width: 50, height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(previewSecondaryColor)
                                .frame(width: 35, height: 4)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: theme.iconName)
                            .font(.caption)
                        Text(theme.labelKey)
                            .font(.caption)
                    }
                    .foregroundStyle(isSelected ? .primary : .secondary)
                }
            }
            .buttonStyle(.plain)
        }

        private var backgroundColor: Color {
            switch theme {
            case .system:
                return Color(nsColor: .windowBackgroundColor)
            case .light:
                return Color.white
            case .dark:
                return Color(white: 0.15)
            }
        }

        private var previewAccentColor: Color {
            switch theme {
            case .system:
                return .accentColor.opacity(0.8)
            case .light:
                return .blue.opacity(0.8)
            case .dark:
                return .blue.opacity(0.9)
            }
        }

        private var previewSecondaryColor: Color {
            switch theme {
            case .system:
                return .secondary.opacity(0.3)
            case .light:
                return .gray.opacity(0.3)
            case .dark:
                return .white.opacity(0.2)
            }
        }
    }

    // MARK: - Data Settings Tab

    struct DataSettingsTab: View {
        @Environment(\.modelContext) private var modelContext
        @Query private var accounts: [Account]
        @Query private var transactions: [Transaction]

        @State private var showingResetConfirmation = false
        @State private var showingImportConfirmation = false
        @State private var showingExportSuccess = false
        @State private var showingImportSuccess = false
        @State private var showingError = false
        @State private var errorMessage = ""
        @State private var importResult: (accountsCount: Int, transactionsCount: Int) = (0, 0)
        @State private var showingOFXImportWizard = false
        @State private var parsedOFXTransactions: [OFXTransaction] = []

        var body: some View {
            Form {
                // Backup Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export Data")
                            Text("Export your data in JSON format for backup")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Export...") {
                            exportData()
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import Data")
                            Text("Restore your data from a JSON backup")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Import...") {
                            showingImportConfirmation = true
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import OFX")
                            Text("Import transactions from your bank")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Import...") {
                            importOFX()
                        }
                    }
                } header: {
                    Text("Import & Export")
                }

                #if ENABLE_ICLOUD
                    // iCloud Sync Section
                    Section {
                        Toggle(
                            "Keep your data in sync across all your devices",
                            isOn: Binding(
                                get: { CloudKitManager.shared.isEnabled },
                                set: { CloudKitManager.shared.isEnabled = $0 }
                            ))
                    } header: {
                        Text("iCloud Sync")
                    }
                #endif

                // Danger Zone Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset All Data")
                                .foregroundStyle(.red)
                            Text("Permanently delete all accounts, transactions, and budgets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reset...", role: .destructive) {
                            showingResetConfirmation = true
                        }
                    }
                } header: {
                    Text("Danger Zone")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .confirmationDialog(
                "Reset All Data?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    resetAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "This will permanently delete all accounts, transactions, and budgets. This action cannot be undone."
                )
            }
            .alert(
                "Import data?",
                isPresented: $showingImportConfirmation
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Continue") {
                    importData()
                }
            } message: {
                Text(
                    "Importing will replace all existing data. Make sure to export your current data first if needed."
                )
            }
            .alert("Export successful", isPresented: $showingExportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your data has been exported successfully.")
            }
            .alert("Import successful", isPresented: $showingImportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(
                    "Imported \(importResult.accountsCount) accounts and \(importResult.transactionsCount) transactions."
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingOFXImportWizard) {
                OFXImportWizard(ofxTransactions: parsedOFXTransactions)
            }
        }

        // MARK: - Export

        private func exportData() {
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType(filenameExtension: "cashbackup") ?? .data]
            savePanel.nameFieldStringValue = DataExporter.generateFilename(for: .cashBackup)
            savePanel.title = "Export Cash Backup"
            savePanel.message = "Choose where to save your backup file"

            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    do {
                        let data = try DataExporter.exportCashBackup(
                            accounts: accounts, transactions: transactions)
                        try data.write(to: url)
                        showingExportSuccess = true
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }

        // MARK: - Import Data (JSON)

        private func importData() {
            let openPanel = NSOpenPanel()
            openPanel.allowedContentTypes = [
                UTType(filenameExtension: "cashbackup") ?? .data, .json,
            ]
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = false
            openPanel.title = "Import Cash Backup"
            openPanel.message = "Select a backup file to restore"

            openPanel.begin { response in
                if response == .OK, let url = openPanel.url {
                    do {
                        let data = try Data(contentsOf: url)

                        // Delete existing data first
                        deleteAllDataForImport()

                        // Import new data
                        let result = try DataExporter.importCashBackup(
                            from: data, into: modelContext)
                        importResult = result
                        showingImportSuccess = true
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }

        // MARK: - Import OFX

        private func importOFX() {
            let openPanel = NSOpenPanel()
            openPanel.allowedContentTypes = [
                UTType(filenameExtension: "ofx") ?? .data,
                UTType(filenameExtension: "qfx") ?? .data,
                .data,
            ]
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = false
            openPanel.title = "Import OFX File"
            openPanel.message = "Select an OFX or QFX file from your bank"

            openPanel.begin { response in
                if response == .OK, let url = openPanel.url {
                    do {
                        let data = try Data(contentsOf: url)
                        let transactions = try OFXParser.parse(data: data)
                        if transactions.isEmpty {
                            errorMessage = "No transactions found in the OFX file"
                            showingError = true
                            return
                        }

                        parsedOFXTransactions = transactions
                        showingOFXImportWizard = true
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }

        // MARK: - Delete All Data

        private func deleteAllDataForImport() {
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

        // MARK: - Reset All Data

        private func resetAllData() {
            do {
                try modelContext.delete(model: Transaction.self)
                try modelContext.delete(model: Account.self)
                try modelContext.delete(model: Budget.self)
                try modelContext.delete(model: Envelope.self)
                try modelContext.delete(model: Loan.self)
                try modelContext.save()
            } catch {
                print("Error resetting data: \(error)")
            }
        }
    }

    // MARK: - About Settings Tab

    struct AboutSettingsTab: View {
        var body: some View {
            VStack(spacing: 20) {
                Spacer()

                // App Icon
                if let iconImage = Bundle.main.iconImage {
                    iconImage
                        .resizable()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                // App Name and Version
                VStack(spacing: 4) {
                    Text("Cash")
                        .font(.title)
                        .fontWeight(.semibold)

                    Text(
                        "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                // Description
                Text(
                    "A personal finance management application inspired by Gnucash, built with SwiftUI and SwiftData."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

                // Links
                VStack(spacing: 12) {
                    Link(destination: URL(string: "https://github.com/thesmokinator/cash")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("Project website")
                        }
                        .font(.body)
                    }

                    Link(
                        destination: URL(
                            string: "https://github.com/thesmokinator/cash/blob/main/PRIVACY.md")!
                    ) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            Text("Privacy policy")
                        }
                        .font(.body)
                    }
                }

                Spacer()

                // Copyright
                Text("© 2025 Michele Broggi")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Preview

    #Preview {
        MacOSSettingsView()
            .environment(AppSettings.shared)
            .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
    }
#endif
