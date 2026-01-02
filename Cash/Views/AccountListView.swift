//
//  AccountListView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftData
import SwiftUI

enum SidebarSelection: Hashable {
    case patrimony
    case forecast
    case budget
    case loans
    case reports
    case scheduled
    case account(Account)
}

struct AccountListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(NavigationState.self) private var navigationState
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    @Query(filter: #Predicate<Transaction> { $0.isRecurring == true }) private
        var scheduledTransactions: [Transaction]
    @State private var showingAddAccount = false
    @State private var showingAddTransaction = false
    @State private var selection: SidebarSelection? =
        DeviceType.current.isCompact ? nil : .patrimony

    private var hasAccounts: Bool {
        !accounts.filter { $0.isActive && !$0.isSystem }.isEmpty
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                if accounts.isEmpty {
                    ContentUnavailableView {
                        Label("No accounts", systemImage: "building.columns")
                    } description: {
                        Text("Create your first account to get started.")
                    }
                } else {
                    if hasAccounts {
                        Section {
                            Label("Net Worth", systemImage: "chart.pie.fill")
                                .tag(SidebarSelection.patrimony)
                                .accessibilityIdentifier("netWorthItem")

                            Label("Forecast", systemImage: "chart.line.uptrend.xyaxis")
                                .tag(SidebarSelection.forecast)
                                .accessibilityIdentifier("forecastItem")

                            Label("Budget", systemImage: "envelope.fill")
                                .tag(SidebarSelection.budget)
                                .accessibilityIdentifier("budgetItem")

                            Label("Loans & Mortgages", systemImage: "house.fill")
                                .tag(SidebarSelection.loans)
                                .accessibilityIdentifier("loansItem")

                            Label("Reports", systemImage: "chart.bar.fill")
                                .tag(SidebarSelection.reports)
                                .accessibilityIdentifier("reportsItem")
                        }
                    }

                    ForEach(AccountClass.allCases.sorted(by: { $0.displayOrder < $1.displayOrder }))
                    { accountClass in
                        let classAccounts =
                            accounts
                            .filter {
                                $0.accountClass == accountClass && $0.isActive && !$0.isSystem
                            }

                        if !classAccounts.isEmpty {
                            Section(accountClass.localizedPluralName) {
                                // Add Scheduled as first item in Expenses section
                                if accountClass == .expense {
                                    HStack {
                                        Label("Scheduled", systemImage: "calendar.badge.clock")
                                        Spacer()
                                        if !scheduledTransactions.isEmpty {
                                            Text("\(scheduledTransactions.count)")
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(.quaternary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .tag(SidebarSelection.scheduled)
                                    .accessibilityIdentifier("scheduledItem")
                                }

                                // Show all accounts flat, sorted by type then name
                                let sortedAccounts = classAccounts.sorted { a, b in
                                    if a.accountType.localizedName != b.accountType.localizedName {
                                        return a.accountType.localizedName
                                            .localizedCaseInsensitiveCompare(
                                                b.accountType.localizedName) == .orderedAscending
                                    }
                                    return a.displayName.localizedCaseInsensitiveCompare(
                                        b.displayName) == .orderedAscending
                                }

                                ForEach(sortedAccounts) { account in
                                    AccountRowView(account: account)
                                        .tag(SidebarSelection.account(account))
                                }
                                .onDelete { indexSet in
                                    deleteAccounts(from: sortedAccounts, at: indexSet)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(String(localized: "Cash"))
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button(action: { showingAddAccount = true }) {
                            Label("Add account", systemImage: "plus")
                        }
                        Button(action: { showingAddTransaction = true }) {
                            Label(String(localized: "Add transaction"), systemImage: "plus.circle")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            settings.privacyMode.toggle()
                        }
                    } label: {
                        Label(
                            settings.privacyMode ? "Show amounts" : "Hide amounts",
                            systemImage: settings.privacyMode ? "eye.slash.fill" : "eye.fill"
                        )
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                SidebarSyncStatusBox()
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView()
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }
            .id(settings.refreshID)
        } detail: {
            Group {
                if !hasAccounts {
                    // No accounts configured - show empty state
                    ContentUnavailableView {
                        Label("No accounts", systemImage: "building.columns")
                    } description: {
                        Text("Create your first account to get started.")
                    } actions: {
                        Button(action: { showingAddAccount = true }) {
                            Text("Add Account")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    switch selection {
                    case .patrimony:
                        NetWorthView()
                    case .forecast:
                        ForecastView()
                    case .budget:
                        BudgetView()
                    case .loans:
                        LoansView()
                    case .reports:
                        ReportsView()
                    case .scheduled:
                        ScheduledTransactionsView()
                    case .account(let account):
                        AccountDetailView(
                            account: account, showingAddTransaction: $showingAddTransaction)
                    case nil:
                        ContentUnavailableView {
                            Label("Select an account", systemImage: "building.columns")
                        } description: {
                            Text("Choose an account from the sidebar to view details")
                        }
                    }
                }
            }
        }
        .onChange(of: selection) { _, newValue in
            switch newValue {
            case .account(let account):
                navigationState.isViewingAccount = true
                navigationState.isViewingScheduled = false
                navigationState.currentAccount = account
            case .scheduled:
                navigationState.isViewingAccount = false
                navigationState.isViewingScheduled = true
                navigationState.currentAccount = nil
            default:
                navigationState.isViewingAccount = false
                navigationState.isViewingScheduled = false
                navigationState.currentAccount = nil
            }
        }
        .onChange(of: accounts) { _, newAccounts in
            // Handle account deletion - check if selected account still exists
            if case .account(let selectedAccount) = selection {
                let accountExists = newAccounts.contains { $0.id == selectedAccount.id }
                if !accountExists {
                    // Account was deleted - navigate appropriately
                    let activeAccounts = newAccounts.filter { $0.isActive && !$0.isSystem }
                    if activeAccounts.isEmpty {
                        // No accounts left - show empty state
                        selection = nil
                    } else {
                        // Other accounts exist - go to Net Worth
                        selection = .patrimony
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewAccount)) { _ in
            showingAddAccount = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewTransaction)) { _ in
            if navigationState.isViewingAccount {
                showingAddTransaction = true
            }
        }
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

// MARK: - Account Row View

struct AccountRowView: View {
    @Environment(AppSettings.self) private var settings
    let account: Account
    @State private var isCalculating = false

    var body: some View {
        HStack {
            Image(systemName: account.effectiveIconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(account.displayName)
                        .font(.headline)
                    if account.isSystem {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if isCalculating {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 20, height: 20)
            } else {
                PrivacyAmountView(
                    amount: account.cachedFormattedBalance,
                    isPrivate: settings.privacyMode,
                    font: .subheadline,
                    fontWeight: .medium,
                    color: balanceColor
                )
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            // Lazy load balance calculation when row becomes visible
            if !account.balanceCalculated {
                calculateBalanceAsync()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountBalancesNeedUpdate)) {
            notification in
            // Recalculate balance if this account is affected
            let accountIDs = notification.userInfo?["accountIDs"] as? Set<UUID>
            if accountIDs == nil || accountIDs!.contains(account.id) {
                calculateBalanceAsync()
            }
        }
    }

    private func calculateBalanceAsync() {
        isCalculating = true
        // Capture values needed for background work
        let accountId = account.id
        let balance = account.balance
        let currency = account.currency

        Task.detached(priority: .userInitiated) {
            // Do formatting work on background thread
            let formattedBalance = CurrencyFormatter.format(balance, currency: currency)

            // Update UI on main thread
            await MainActor.run {
                // Verify we're still working with the same account
                if self.account.id == accountId {
                    self.account.cachedBalance = balance
                    self.account.cachedFormattedBalance = formattedBalance
                    self.account.balanceCalculated = true
                }
                self.isCalculating = false
            }
        }
    }

    private var balanceColor: Color {
        let balance = account.cachedBalance
        if balance == 0 {
            return .secondary
        }
        switch account.accountClass {
        case .asset:
            return balance >= 0 ? .primary : .red
        case .liability:
            return .primary
        case .income:
            return .green
        case .expense:
            return .red
        case .equity:
            return .primary
        }
    }
}

#Preview {
    AccountListView()
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
        .environment(AppSettings.shared)
        .environment(NavigationState())
}
