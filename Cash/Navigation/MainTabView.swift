//
//  MainTabView.swift
//  Cash
//
//  Main navigation container with Tab Bar (iPhone) and Sidebar (iPad)
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - App State

@Observable
class AppState {
    var isLoading = false
    var loadingMessage = ""
}

// MARK: - Main Tab Enum (iPhone)

enum MainTab: Int, CaseIterable, Identifiable {
    case home = 0
    case accounts = 1
    case add = 2
    case budget = 3
    case more = 4

    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .home: return "Home"
        case .accounts: return "Accounts"
        case .add: return "Add"
        case .budget: return "Budget"
        case .more: return "More"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .accounts: return "creditcard"
        case .add: return "plus.circle.fill"
        case .budget: return "chart.pie"
        case .more: return "ellipsis.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .accounts: return "creditcard.fill"
        case .add: return "plus.circle.fill"
        case .budget: return "chart.pie.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - iPad Sidebar Item Enum

enum iPadSidebarItem: String, CaseIterable, Identifiable, Hashable {
    // Overview
    case home
    case accounts
    case budget
    // Finance Tools
    case loans
    case scheduled
    // Analytics
    case reports
    case netWorth
    case forecast

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .home: return "Home"
        case .accounts: return "Accounts"
        case .budget: return "Budget"
        case .loans: return "Loans & Mortgages"
        case .scheduled: return "Scheduled"
        case .reports: return "Reports"
        case .netWorth: return "Net Worth"
        case .forecast: return "Forecast"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .accounts: return "creditcard.fill"
        case .budget: return "chart.pie.fill"
        case .loans: return "building.columns.fill"
        case .scheduled: return "calendar.badge.clock"
        case .reports: return "doc.text.fill"
        case .netWorth: return "chart.bar.fill"
        case .forecast: return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AppSettings.self) private var settings
    @Environment(NavigationState.self) private var navigationState

    // Data queries for export
    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]

    @State private var selectedTab: MainTab = .home
    @State private var showingAddTransaction = false
    @State private var addTransactionType: SimpleTransactionType = .expense

    // iPad sidebar state
    @State private var selectedSidebarItem: iPadSidebarItem? = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // iPad settings sheets
    @State private var showingThemeSheet = false
    @State private var showingLanguageSheet = false
    @State private var showingETFQuotesSheet = false
    @State private var showingICloudSheet = false
    @State private var showingExportFormatPicker = false

    // Export state
    @State private var exportDataContent: Data?
    @State private var exportFilename = ""
    @State private var showingFileExporter = false
    @State private var showingExportSuccess = false
    @State private var showingExportError = false
    @State private var exportErrorMessage = ""

    // OFX Import state
    @State private var showingOFXImportPicker = false
    @State private var showingOFXImportWizard = false
    @State private var parsedOFXTransactions: [OFXTransaction] = []
    @State private var showingOFXError = false
    @State private var ofxErrorMessage = ""

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                // iPhone: Tab Bar navigation
                iPhoneTabView
            } else {
                // iPad: Sidebar navigation
                iPadSidebarView
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionSheet(transactionType: addTransactionType)
        }
        .sheet(isPresented: $showingOFXImportWizard) {
            OFXImportWizard(ofxTransactions: parsedOFXTransactions)
        }
        .fileImporter(
            isPresented: $showingOFXImportPicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            handleOFXImport(result: result)
        }
        .alert("Error", isPresented: $showingOFXError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ofxErrorMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewTransaction)) { notification in
            if let type = notification.userInfo?["transactionType"] as? String,
               let transactionType = SimpleTransactionType(rawValue: type) {
                addTransactionType = transactionType
            } else {
                addTransactionType = .expense
            }
            showingAddTransaction = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .importOFX)) { _ in
            showingOFXImportPicker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportData)) { notification in
            if let formatRaw = notification.userInfo?["format"] as? String,
               let format = ExportFormat(rawValue: formatRaw) {
                performExport(format: format)
            }
        }
        .fileExporter(
            isPresented: $showingFileExporter,
            document: ExportDocument(data: exportDataContent ?? Data()),
            contentType: .data,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                showingExportSuccess = true
            case .failure(let error):
                exportErrorMessage = error.localizedDescription
                showingExportError = true
            }
        }
        .alert(String(localized: "Export successful"), isPresented: $showingExportSuccess) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text("Your data has been exported successfully.")
        }
        .alert(String(localized: "Export error"), isPresented: $showingExportError) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
    }

    // MARK: - Export Handler

    private func performExport(format: ExportFormat) {
        do {
            let data: Data

            switch format {
            case .cashBackup:
                data = try DataExporter.exportCashBackup(accounts: accounts, transactions: transactions)
            case .ofx:
                data = try DataExporter.exportOFX(accounts: accounts, transactions: transactions)
            }

            let filename = DataExporter.generateFilename(for: format)

            self.exportDataContent = data
            self.exportFilename = filename
            self.showingFileExporter = true
        } catch {
            exportErrorMessage = error.localizedDescription
            showingExportError = true
        }
    }

    // MARK: - OFX Import Handler

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

    // MARK: - iPhone Tab View

    private var iPhoneTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: selectedTab == .home ? "house.fill" : "house")
                }
                .tag(MainTab.home)

            AccountsTabView()
                .tabItem {
                    Label("Accounts", systemImage: selectedTab == .accounts ? "creditcard.fill" : "creditcard")
                }
                .tag(MainTab.accounts)

            NavigationStack {
                BudgetView()
            }
            .tabItem {
                Label("Budget", systemImage: selectedTab == .budget ? "chart.pie.fill" : "chart.pie")
            }
            .tag(MainTab.budget)

            NavigationStack {
                MoreMenuView()
            }
            .tabItem {
                Label("More", systemImage: selectedTab == .more ? "ellipsis.circle.fill" : "ellipsis.circle")
            }
            .tag(MainTab.more)
        }
        .tint(CashColors.primary)
    }

    // MARK: - iPad Sidebar View

    private var iPadSidebarView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            iPadSidebar
        } detail: {
            iPadDetailView
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
        .sheet(isPresented: $showingExportFormatPicker) {
            iPadExportFormatPicker
        }
    }

    private var iPadSidebar: some View {
        List(selection: $selectedSidebarItem) {
            // Overview Section
            Section("Overview") {
                ForEach([iPadSidebarItem.home, .accounts, .budget]) { item in
                    NavigationLink(value: item) {
                        Label(item.title, systemImage: item.icon)
                    }
                }
            }

            // Finance Tools Section
            Section("Finance Tools") {
                ForEach([iPadSidebarItem.loans, .scheduled]) { item in
                    NavigationLink(value: item) {
                        Label(item.title, systemImage: item.icon)
                    }
                }
            }

            // Analytics Section
            Section("Analytics") {
                ForEach([iPadSidebarItem.reports, .netWorth, .forecast]) { item in
                    NavigationLink(value: item) {
                        Label(item.title, systemImage: item.icon)
                    }
                }
            }

            // Investments Section
            Section("Investments") {
                Button {
                    showingETFQuotesSheet = true
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Live ETF Quotes")
                            Text(settings.showLiveQuotes ? "Enabled" : "Disabled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    }
                }
            }

            // Data Section
            Section("Data") {
                #if ENABLE_ICLOUD
                Button {
                    showingICloudSheet = true
                } label: {
                    Label("iCloud Sync", systemImage: "icloud.fill")
                }
                #endif

                Button {
                    NotificationCenter.default.post(name: .importOFX, object: nil)
                } label: {
                    Label("Import OFX", systemImage: "square.and.arrow.down.fill")
                }

                Button {
                    showingExportFormatPicker = true
                } label: {
                    Label("Export Data", systemImage: "square.and.arrow.up.fill")
                }
            }

            // Settings Section
            Section("Settings") {
                Button {
                    showingThemeSheet = true
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Theme")
                            Text(settings.theme.labelKey)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "paintbrush.fill")
                    }
                }

                Button {
                    showingLanguageSheet = true
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Language")
                            Text(settings.language.labelKey)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "globe")
                    }
                }
            }

            // About Section
            Section("About") {
                VStack(spacing: CashSpacing.md) {
                    if let icon = Bundle.main.icon {
                        Image(uiImage: icon)
                            .resizable()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: CashRadius.medium))
                    }

                    VStack(spacing: CashSpacing.xs) {
                        Text("Cash")
                            .font(CashTypography.headline)

                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                            .font(CashTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CashSpacing.sm)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var iPadDetailView: some View {
        switch selectedSidebarItem {
        case .home, .none:
            HomeView()
        case .accounts:
            AccountsTabView()
        case .budget:
            NavigationStack {
                BudgetView()
            }
        case .loans:
            NavigationStack {
                LoansView()
            }
        case .scheduled:
            NavigationStack {
                ScheduledTransactionsView()
            }
        case .reports:
            NavigationStack {
                ReportsView()
            }
        case .netWorth:
            NavigationStack {
                NetWorthView()
            }
        case .forecast:
            NavigationStack {
                ForecastView()
            }
        }
    }

    private var iPadExportFormatPicker: some View {
        ExportFormatPickerView { format in
            // Export handled by MoreMenuView's export logic
            NotificationCenter.default.post(
                name: .exportData,
                object: nil,
                userInfo: ["format": format.rawValue]
            )
        }
    }
}

// MARK: - Add Transaction Sheet

struct AddTransactionSheet: View {
    var transactionType: SimpleTransactionType = .expense

    var body: some View {
        NavigationStack {
            AddTransactionView(initialTransactionType: transactionType)
        }
    }
}

// MARK: - Accounts Tab View (Simple list for iPhone)

struct AccountsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]

    @State private var showingAddAccount = false
    @State private var showingAddTransaction = false

    private var hasAccounts: Bool {
        !accounts.filter { $0.isActive && !$0.isSystem }.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if accounts.isEmpty || !hasAccounts {
                    GlassEmptyState(
                        icon: "building.columns",
                        title: "No Accounts",
                        description: "Create your first account to get started."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(AccountClass.allCases.sorted(by: { $0.displayOrder < $1.displayOrder })) { accountClass in
                            let classAccounts = accounts
                                .filter { $0.accountClass == accountClass && $0.isActive && !$0.isSystem }
                                .sorted { a, b in
                                    if a.accountType.localizedName != b.accountType.localizedName {
                                        return a.accountType.localizedName
                                            .localizedCaseInsensitiveCompare(b.accountType.localizedName) == .orderedAscending
                                    }
                                    return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
                                }

                            if !classAccounts.isEmpty {
                                Section(accountClass.localizedPluralName) {
                                    ForEach(classAccounts) { account in
                                        NavigationLink {
                                            AccountDetailView(
                                                account: account,
                                                showingAddTransaction: $showingAddTransaction
                                            )
                                        } label: {
                                            AccountRowViewSimple(account: account)
                                        }
                                    }
                                    .onDelete { indexSet in
                                        deleteAccounts(from: classAccounts, at: indexSet)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView()
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }
        }
        .id(settings.refreshID)
    }

    private func deleteAccounts(from filteredAccounts: [Account], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let account = filteredAccounts[index]
                if !account.isSystem {
                    modelContext.delete(account)
                }
            }
        }
    }
}

// MARK: - Simple Account Row

struct AccountRowViewSimple: View {
    @Environment(AppSettings.self) private var settings
    let account: Account

    var body: some View {
        HStack(spacing: CashSpacing.md) {
            GlassIconCircle(
                icon: account.effectiveIconName,
                color: iconColor,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(account.displayName)
                        .font(CashTypography.body)
                    if account.isSystem {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(account.accountType.localizedName)
                    .font(CashTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            PrivacyAmountView(
                amount: CurrencyFormatter.format(account.balance, currency: account.currency),
                isPrivate: settings.privacyMode,
                font: CashTypography.subheadline,
                fontWeight: .semibold,
                color: balanceColor
            )
        }
        .padding(.vertical, CashSpacing.xs)
    }

    private var iconColor: Color {
        switch account.accountClass {
        case .asset: return CashColors.success
        case .liability: return CashColors.error
        case .income: return CashColors.income
        case .expense: return CashColors.expense
        case .equity: return CashColors.primary
        }
    }

    private var balanceColor: Color {
        if account.balance == 0 { return .secondary }
        switch account.accountClass {
        case .asset: return account.balance >= 0 ? .primary : CashColors.error
        case .liability: return .primary
        case .income: return CashColors.success
        case .expense: return CashColors.error
        case .equity: return .primary
        }
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

// MARK: - Preview

#Preview {
    MainTabView()
        .modelContainer(for: [Account.self, Transaction.self, AppConfiguration.self], inMemory: true)
        .environment(AppSettings.shared)
        .environment(NavigationState())
}
