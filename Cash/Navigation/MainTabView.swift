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

// MARK: - Main Tab Enum

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

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AppSettings.self) private var settings
    @Environment(NavigationState.self) private var navigationState

    @State private var selectedTab: MainTab = .home
    @State private var showingAddTransaction = false

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
            AddTransactionSheet()
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
        .onReceive(NotificationCenter.default.publisher(for: .addNewTransaction)) { _ in
            showingAddTransaction = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .importOFX)) { _ in
            showingOFXImportPicker = true
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
        NavigationSplitView {
            iPadSidebar
        } detail: {
            iPadDetailView
        }
    }

    private var iPadSidebar: some View {
        List {
            Section("Overview") {
                sidebarButton(for: .home, label: "Home", icon: "house.fill")
                sidebarButton(for: .accounts, label: "Accounts", icon: "creditcard.fill")
                sidebarButton(for: .budget, label: "Budget", icon: "chart.pie.fill")
            }

            Section("Tools") {
                NavigationLink {
                    LoansView()
                } label: {
                    Label("Loans & Mortgages", systemImage: "building.columns.fill")
                }

                NavigationLink {
                    ForecastView()
                } label: {
                    Label("Forecast", systemImage: "chart.line.uptrend.xyaxis")
                }

                NavigationLink {
                    ScheduledTransactionsView()
                } label: {
                    Label("Scheduled", systemImage: "calendar.badge.clock")
                }

                NavigationLink {
                    ReportsView()
                } label: {
                    Label("Reports", systemImage: "chart.bar.fill")
                }
            }
        }
        .navigationTitle("Cash")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTransaction = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(CashColors.primary)
                }
            }
        }
    }

    private func sidebarButton(for tab: MainTab, label: String, icon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Label(label, systemImage: icon)
        }
        .listRowBackground(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    @ViewBuilder
    private var iPadDetailView: some View {
        switch selectedTab {
        case .home:
            HomeView()
        case .accounts:
            AccountsTabView()
        case .budget:
            BudgetView()
        case .add:
            HomeView() // Fallback
        case .more:
            MoreMenuView()
        }
    }
}

// MARK: - Add Transaction Sheet

struct AddTransactionSheet: View {
    var body: some View {
        NavigationStack {
            AddTransactionView()
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
