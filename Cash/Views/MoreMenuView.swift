//
//  MoreMenuView.swift
//  Cash
//
//  Menu view for additional features: Loans, Reports, Scheduled, Settings
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

#if ENABLE_ICLOUD
import CloudKit
#endif

struct MoreMenuView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var appState = AppState()

    // Export/Import state
    @State private var showingExportFormatPicker = false
    @State private var showingImportConfirmation = false
    @State private var showingImportFilePicker = false
    @State private var showingExportSuccess = false
    @State private var showingImportSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var importResult: (accountsCount: Int, transactionsCount: Int) = (0, 0)
    @State private var exportData: Data?
    @State private var exportFilename = ""
    @State private var showingFileExporter = false

    // Reset state
    @State private var showingFirstResetAlert = false
    @State private var showingSecondResetAlert = false

    // Settings sheets
    @State private var showingThemeSheet = false
    @State private var showingLanguageSheet = false
    @State private var showingETFQuotesSheet = false
    @State private var showingICloudSheet = false

    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]

    var body: some View {
        NavigationStack {
            List {
                // Finance Tools Section
                Section {
                    NavigationLink {
                        LoansView()
                    } label: {
                        MoreMenuRow(
                            icon: "building.columns.fill",
                            title: "Loans & Mortgages",
                            subtitle: "Manage loans and amortization",
                            color: CashColors.primary
                        )
                    }

                    NavigationLink {
                        ScheduledTransactionsView()
                    } label: {
                        MoreMenuRow(
                            icon: "calendar.badge.clock",
                            title: "Scheduled",
                            subtitle: "Recurring and upcoming payments",
                            color: .orange
                        )
                    }
                } header: {
                    Text("Finance Tools")
                }

                // Analytics Section
                Section {
                    NavigationLink {
                        NetWorthView()
                    } label: {
                        MoreMenuRow(
                            icon: "chart.bar.fill",
                            title: "Net Worth",
                            subtitle: "Assets and liabilities overview",
                            color: CashColors.success
                        )
                    }

                    NavigationLink {
                        ReportsView()
                    } label: {
                        MoreMenuRow(
                            icon: "doc.text.fill",
                            title: "Reports",
                            subtitle: "Expense analysis and trends",
                            color: .purple
                        )
                    }

                    NavigationLink {
                        ForecastView()
                    } label: {
                        MoreMenuRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Forecast",
                            subtitle: "Project future balances",
                            color: .blue
                        )
                    }
                } header: {
                    Text("Analytics")
                }

                // Investments Section
                Section {
                    Button {
                        showingETFQuotesSheet = true
                    } label: {
                        MoreMenuRow(
                            icon: "chart.line.uptrend.xyaxis.circle.fill",
                            title: "Live ETF Quotes",
                            subtitle: settings.showLiveQuotes ? "Enabled" : "Disabled",
                            color: .teal
                        )
                    }
                } header: {
                    Text("Investments")
                }

                // Data Section
                Section {
                    
                    #if ENABLE_ICLOUD
                    Button {
                        showingICloudSheet = true
                    } label: {
                        MoreMenuRow(
                            icon: "icloud.fill",
                            title: "iCloud Sync",
                            subtitle: CloudKitManager.shared.isEnabled ? "Enabled" : "Disabled",
                            color: .blue
                        )
                    }
                    #endif
                    
                    Button {
                        NotificationCenter.default.post(name: .importOFX, object: nil)
                    } label: {
                        MoreMenuRow(
                            icon: "square.and.arrow.down.fill",
                            title: "Import OFX",
                            subtitle: "Import from OFX/QFX files",
                            color: .cyan
                        )
                    }

                    Button {
                        showingExportFormatPicker = true
                    } label: {
                        MoreMenuRow(
                            icon: "square.and.arrow.up.fill",
                            title: "Export Data",
                            subtitle: "JSON backup or OFX format",
                            color: .green
                        )
                    }

                    Button {
                        showingImportConfirmation = true
                    } label: {
                        MoreMenuRow(
                            icon: "arrow.down.doc.fill",
                            title: "Restore Backup",
                            subtitle: "Import from JSON backup",
                            color: .indigo
                        )
                    }

                    Button {
                        showingFirstResetAlert = true
                    } label: {
                        MoreMenuRow(
                            icon: "trash.fill",
                            title: "Reset All Data",
                            subtitle: "Delete all accounts and transactions",
                            color: .red
                        )
                    }
                } header: {
                    Text("Data")
                }

                // Settings Section
                Section {
                    Button {
                        showingThemeSheet = true
                    } label: {
                        MoreMenuRow(
                            icon: "paintbrush.fill",
                            title: "Theme",
                            subtitle: settings.theme.labelKey,
                            color: .purple
                        )
                    }

                    Button {
                        showingLanguageSheet = true
                    } label: {
                        MoreMenuRow(
                            icon: "globe",
                            title: "Language",
                            subtitle: settings.language.labelKey,
                            color: .orange
                        )
                    }
                } header: {
                    Text("Settings")
                }

                // About Section
                Section {
                    VStack(spacing: CashSpacing.lg) {
                        if let icon = Bundle.main.icon {
                            Image(uiImage: icon)
                                .resizable()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: CashRadius.large))
                        }

                        VStack(spacing: CashSpacing.xs) {
                            Text("Cash")
                                .font(CashTypography.title2)
                                .foregroundStyle(.primary)

                            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                                .font(CashTypography.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("A personal finance management application inspired by Gnucash, built with SwiftUI and SwiftData.")
                            .font(CashTypography.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        VStack(spacing: CashSpacing.sm) {
                            Link(destination: URL(string: "https://github.com/thesmokinator/cash")!) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("Project website")
                                }
                                .font(CashTypography.subheadline)
                                .foregroundStyle(CashColors.primary)
                            }

                            Link(destination: URL(string: "https://github.com/thesmokinator/cash/blob/main/PRIVACY.md")!) {
                                HStack {
                                    Image(systemName: "hand.raised.fill")
                                    Text("Privacy policy")
                                }
                                .font(CashTypography.subheadline)
                                .foregroundStyle(CashColors.primary)
                            }
                        }

                        Text("© 2025 Michele Broggi")
                            .font(CashTypography.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CashSpacing.lg)
                } header: {
                    Text("About")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More")
            .sheet(isPresented: $showingExportFormatPicker) {
                ExportFormatPickerView { format in
                    exportData(format: format)
                }
            }
            .sheet(isPresented: $showingThemeSheet) {
                ThemeSettingsSheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingLanguageSheet) {
                LanguageSettingsSheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingETFQuotesSheet) {
                ETFQuotesSettingsSheet()
                    .presentationDetents([.medium])
            }
            #if ENABLE_ICLOUD
            .sheet(isPresented: $showingICloudSheet) {
                ICloudSyncSettingsSheet()
                    .presentationDetents([.medium])
            }
            #endif
            .overlay {
                if appState.isLoading {
                    LoadingOverlayView(message: appState.loadingMessage)
                }
            }
            // Reset alerts
            .alert(String(localized: "Reset all data?"), isPresented: $showingFirstResetAlert) {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Continue"), role: .destructive) {
                    showingSecondResetAlert = true
                }
            } message: {
                Text("This will permanently delete all your accounts and transactions. This action cannot be undone.")
            }
            .alert(String(localized: "Are you absolutely sure?"), isPresented: $showingSecondResetAlert) {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Delete everything"), role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("All data will be permanently deleted.")
            }
            // Import alerts
            .alert(String(localized: "Import data?"), isPresented: $showingImportConfirmation) {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Continue")) {
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
            // Success/Error alerts
            .alert(String(localized: "Export successful"), isPresented: $showingExportSuccess) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text("Your data has been exported successfully.")
            }
            .alert(String(localized: "Import successful"), isPresented: $showingImportSuccess) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text("Imported \(importResult.accountsCount) accounts and \(importResult.transactionsCount) transactions.")
            }
            .alert(String(localized: "Error"), isPresented: $showingError) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .fileExporter(
                isPresented: $showingFileExporter,
                document: ExportDocument(data: exportData ?? Data()),
                contentType: .data,
                defaultFilename: exportFilename
            ) { result in
                switch result {
                case .success:
                    showingExportSuccess = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
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

            self.exportData = data
            self.exportFilename = filename
            self.showingFileExporter = true
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
        appState.isLoading = true
        appState.loadingMessage = String(localized: "Erasing data...")

        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)

            Task.detached(priority: .background) {
                await deleteAllData()

                await MainActor.run {
                    do {
                        try modelContext.save()
                    } catch {
                        print("Error saving after delete: \(error)")
                    }

                    appState.isLoading = false
                }
            }
        }
    }
}

// MARK: - More Menu Row

struct MoreMenuRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let color: Color

    var body: some View {
        HStack(spacing: CashSpacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: CashRadius.small))

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CashTypography.body)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(CashTypography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, CashSpacing.xs)
    }
}

// MARK: - Theme Settings Sheet

struct ThemeSettingsSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            settings.theme = theme
                        } label: {
                            HStack(spacing: CashSpacing.md) {
                                Image(systemName: theme.iconName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(themeColor(for: theme))
                                    .clipShape(RoundedRectangle(cornerRadius: CashRadius.small))

                                Text(theme.labelKey)
                                    .font(CashTypography.body)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if settings.theme == theme {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(CashColors.primary)
                                }
                            }
                            .padding(.vertical, CashSpacing.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Choose your preferred color scheme")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func themeColor(for theme: AppTheme) -> Color {
        switch theme {
        case .system: return .gray
        case .light: return .orange
        case .dark: return .indigo
        }
    }
}

// MARK: - Language Settings Sheet

struct LanguageSettingsSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private let languagesOrder: [AppLanguage] = [
        .system, .english, .italian, .spanish, .french, .german
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(languagesOrder) { language in
                        Button {
                            settings.language = language
                        } label: {
                            HStack(spacing: CashSpacing.md) {
                                Image(systemName: language.iconName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(languageColor(for: language))
                                    .clipShape(RoundedRectangle(cornerRadius: CashRadius.small))

                                Text(language.labelKey)
                                    .font(CashTypography.body)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if settings.language == language {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(CashColors.primary)
                                }
                            }
                            .padding(.vertical, CashSpacing.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Select your preferred language")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func languageColor(for language: AppLanguage) -> Color {
        switch language {
        case .system: return .gray
        case .english: return .blue
        case .italian: return .green
        case .spanish: return .red
        case .french: return .indigo
        case .german: return .orange
        }
    }
}

// MARK: - ETF Quotes Settings Sheet

struct ETFQuotesSettingsSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: CashSpacing.xl) {
                VStack(spacing: CashSpacing.md) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.teal)

                    Text("Live ETF Quotes")
                        .font(CashTypography.title2)

                    Text("Display real-time price quotes for investment accounts with an ISIN code. This setting syncs across your devices via iCloud.")
                        .font(CashTypography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, CashSpacing.lg)
                }
                .padding(.top, CashSpacing.xl)

                Toggle("Show live ETF quotes", isOn: Binding(
                    get: { settings.showLiveQuotes },
                    set: { settings.showLiveQuotes = $0 }
                ))
                .font(CashTypography.body)
                .padding(.horizontal, CashSpacing.xl)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#if ENABLE_ICLOUD
// MARK: - iCloud Sync Settings Sheet

struct ICloudSyncSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cloudManager = CloudKitManager.shared

    private var hasICloudAccount: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: CashSpacing.xl) {
                VStack(spacing: CashSpacing.md) {
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    Text("iCloud Sync")
                        .font(CashTypography.title2)

                    if hasICloudAccount {
                        Text("Sync your data across all your devices")
                            .font(CashTypography.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Sign in to iCloud in Settings to enable sync")
                            .font(CashTypography.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, CashSpacing.xl)

                VStack(spacing: CashSpacing.md) {
                    Toggle("Enable iCloud sync", isOn: Binding(
                        get: { cloudManager.isEnabled },
                        set: { newValue in
                            cloudManager.isEnabled = newValue
                        }
                    ))
                    .disabled(!cloudManager.isAvailable)
                    .font(CashTypography.body)
                    
                    Text("Changes will take effect when you restart the app")
                        .font(CashTypography.caption)
                        .foregroundStyle(.secondary)

                    if cloudManager.isEnabled {
                        HStack {
                            Text("Status")
                                .foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: CashSpacing.xs) {
                                Circle()
                                    .fill(cloudManager.accountStatus == .available ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                                Text(cloudManager.accountStatusDescription)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(CashTypography.subheadline)

                        HStack {
                            Text("Storage used")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if cloudManager.isLoadingStorage {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text(cloudManager.formattedStorageUsed)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(CashTypography.subheadline)
                    }
                }
                .padding(.horizontal, CashSpacing.xl)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await cloudManager.checkAccountStatus()
                    await cloudManager.fetchStorageUsed()
                }
            }
        }
    }
}
#endif

// MARK: - Export Format Picker View

struct ExportFormatPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ExportFormat) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(
                        String(
                            localized:
                                "Choose the format for exporting your financial data. JSON is recommended for full backup and restore, while OFX is the standard bank format for importing into other applications."
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Section(String(localized: "Available formats")) {
                    ForEach(ExportFormat.allCases) { format in
                        Button {
                            dismiss()
                            onSelect(format)
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            format == .cashBackup
                                                ? Color.blue.opacity(0.1) : Color.green.opacity(0.1)
                                        )
                                        .frame(width: 48, height: 48)

                                    Image(systemName: format.iconName)
                                        .font(.title2)
                                        .foregroundStyle(format == .cashBackup ? .blue : .green)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(format.localizedName)
                                        .font(.headline)

                                    Text(format.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                }
            }
            .navigationTitle(String(localized: "Export data"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Export Document

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Bundle Extension for App Icon

extension Bundle {
    var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let lastIcon = iconFiles.last
        {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

// MARK: - Preview

#Preview {
    MoreMenuView()
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
        .environment(AppSettings.shared)
}
