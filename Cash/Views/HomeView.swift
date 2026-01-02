//
//  HomeView.swift
//  Cash
//
//  Dashboard home view with Net Worth, quick stats, and recent transactions
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    @Query(filter: #Predicate<Transaction> { !$0.isRecurring }, sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @State private var selectedTransaction: Transaction?
    @State private var showingAllTransactions = false
    
    // iCloud sync state
    private var cloudManager = CloudKitManager.shared

    // MARK: - Computed Properties

    private var assetAccounts: [Account] {
        accounts.filter { $0.accountClass == .asset && $0.isActive && !$0.isSystem }
    }

    private var liabilityAccounts: [Account] {
        accounts.filter { $0.accountClass == .liability && $0.isActive && !$0.isSystem }
    }

    private var totalAssets: Decimal {
        assetAccounts.reduce(Decimal.zero) { $0 + $1.balance }
    }

    private var totalLiabilities: Decimal {
        liabilityAccounts.reduce(Decimal.zero) { $0 + $1.balance }
    }

    private var netWorth: Decimal {
        totalAssets - totalLiabilities
    }

    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(5))
    }

    private var thisMonthExpenses: Decimal {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        return transactions
            .filter { $0.date >= startOfMonth }
            .reduce(Decimal.zero) { total, transaction in
                let expenseAmount = (transaction.entries ?? [])
                    .filter { $0.account?.accountClass == .expense && $0.entryType == .debit }
                    .reduce(Decimal.zero) { $0 + $1.amount }
                return total + expenseAmount
            }
    }

    private var thisMonthIncome: Decimal {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        return transactions
            .filter { $0.date >= startOfMonth }
            .reduce(Decimal.zero) { total, transaction in
                let incomeAmount = (transaction.entries ?? [])
                    .filter { $0.account?.accountClass == .income && $0.entryType == .credit }
                    .reduce(Decimal.zero) { $0 + $1.amount }
                return total + incomeAmount
            }
    }

    private var currency: String {
        accounts.first(where: { $0.accountClass == .asset })?.currency ?? "EUR"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CashSpacing.xl) {
                    // Net Worth Card - clickable
                    NavigationLink {
                        NetWorthView()
                    } label: {
                        netWorthCard
                    }
                    .buttonStyle(.plain)

                    // Quick Stats
                    quickStatsSection

                    // Recent Transactions
                    recentTransactionsSection
                }
                .padding(CashSpacing.lg)
            }
            .cashBackground()
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: CashSpacing.md) {
                        // iCloud sync indicator
                        if cloudManager.shouldShowSyncIndicator && cloudManager.syncState.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(CashColors.primary)
                        }
                        
                        // Add transaction menu
                        Menu {
                            Button {
                                NotificationCenter.default.post(
                                    name: .addNewTransaction,
                                    object: nil,
                                    userInfo: ["transactionType": SimpleTransactionType.expense.rawValue]
                                )
                            } label: {
                                Label("New Expense", systemImage: "arrow.up.circle.fill")
                            }
                            
                            Button {
                                NotificationCenter.default.post(
                                    name: .addNewTransaction,
                                    object: nil,
                                    userInfo: ["transactionType": SimpleTransactionType.income.rawValue]
                                )
                            } label: {
                                Label("New Income", systemImage: "arrow.down.circle.fill")
                            }
                            
                            Button {
                                NotificationCenter.default.post(
                                    name: .addNewTransaction,
                                    object: nil,
                                    userInfo: ["transactionType": SimpleTransactionType.transfer.rawValue]
                                )
                            } label: {
                                Label("Transfer", systemImage: "arrow.left.arrow.right")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(CashColors.primary)
                        }
                        
                        // Privacy toggle
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.privacyMode.toggle()
                            }
                        } label: {
                            Image(systemName: settings.privacyMode ? "eye.slash.fill" : "eye.fill")
                                .foregroundStyle(CashColors.primary)
                        }
                    }
                }
            }
            .refreshable {
                // Pull to refresh - recalculate balances
                for account in accounts {
                    account.recalculateBalance()
                }
            }
            .sheet(item: $selectedTransaction) { transaction in
                NavigationStack {
                    EditTransactionView(transaction: transaction)
                }
            }
            .navigationDestination(isPresented: $showingAllTransactions) {
                AllTransactionsView()
            }
        }
    }

    // MARK: - Net Worth Card

    private var netWorthCard: some View {
        VStack(spacing: CashSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: CashSpacing.xs) {
                    Text("Net Worth")
                        .font(CashTypography.subheadline)
                        .foregroundColor(.secondary)

                    PrivacyAmountView(
                        amount: CurrencyFormatter.format(netWorth, currency: currency),
                        isPrivate: settings.privacyMode,
                        font: CashTypography.amountLarge,
                        fontWeight: .bold,
                        color: netWorth >= 0 ? CashColors.primary : CashColors.error
                    )
                }

                Spacer()

                // Trend indicator (placeholder)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32))
                    .foregroundColor(CashColors.primary.opacity(0.6))
            }

            GlassDivider()

            HStack(spacing: CashSpacing.xxl) {
                VStack(alignment: .leading, spacing: CashSpacing.xs) {
                    Text("Assets")
                        .font(CashTypography.caption)
                        .foregroundColor(.secondary)

                    PrivacyAmountView(
                        amount: CurrencyFormatter.format(totalAssets, currency: currency),
                        isPrivate: settings.privacyMode,
                        font: CashTypography.headline,
                        fontWeight: .semibold,
                        color: CashColors.success
                    )
                }

                VStack(alignment: .leading, spacing: CashSpacing.xs) {
                    Text("Liabilities")
                        .font(CashTypography.caption)
                        .foregroundColor(.secondary)

                    PrivacyAmountView(
                        amount: CurrencyFormatter.format(totalLiabilities, currency: currency),
                        isPrivate: settings.privacyMode,
                        font: CashTypography.headline,
                        fontWeight: .semibold,
                        color: CashColors.error
                    )
                }

                Spacer()
            }
        }
        .padding(CashSpacing.xl)
        .background(.ultraThinMaterial)
        .background(CashColors.glassBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: CashRadius.xlarge))
        .shadow(
            color: CashShadow.light.color,
            radius: CashShadow.light.radius,
            x: CashShadow.light.x,
            y: CashShadow.light.y
        )
    }

    // MARK: - Quick Stats Section

    private var quickStatsSection: some View {
        HStack(spacing: CashSpacing.md) {
            GlassMetricCard(
                title: "This Month",
                value: CurrencyFormatter.format(thisMonthExpenses, currency: currency),
                icon: "arrow.up.circle.fill",
                valueColor: CashColors.expense,
                iconColor: CashColors.expense,
                isPrivate: settings.privacyMode
            )

            GlassMetricCard(
                title: "Income",
                value: CurrencyFormatter.format(thisMonthIncome, currency: currency),
                icon: "arrow.down.circle.fill",
                valueColor: CashColors.income,
                iconColor: CashColors.income,
                isPrivate: settings.privacyMode
            )
        }
    }

    // MARK: - Recent Transactions Section

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: CashSpacing.md) {
            GlassSectionHeader(
                title: "Recent Transactions",
                action: {
                    showingAllTransactions = true
                },
                actionLabel: "See All"
            )

            if recentTransactions.isEmpty {
                GlassEmptyState(
                    icon: "list.bullet.rectangle",
                    title: "No Transactions",
                    description: "Add your first transaction to get started"
                )
                .frame(maxWidth: .infinity)
                .glassBackground()
            } else {
                GlassCard(padding: CashSpacing.md) {
                    VStack(spacing: 0) {
                        ForEach(Array(recentTransactions.enumerated()), id: \.element.id) { index, transaction in
                            Button {
                                selectedTransaction = transaction
                            } label: {
                                TransactionRowHome(
                                    transaction: transaction,
                                    currency: currency,
                                    isPrivate: settings.privacyMode
                                )
                            }
                            .buttonStyle(.plain)

                            if index < recentTransactions.count - 1 {
                                GlassDivider()
                                    .padding(.vertical, CashSpacing.sm)
                            }
                        }
                    }
                }
            }
        }
    }

}

// MARK: - Transaction Row for Home

struct TransactionRowHome: View {
    let transaction: Transaction
    let currency: String
    let isPrivate: Bool

    private var iconInfo: (iconName: String, color: Color) {
        TransactionHelper.iconInfo(for: transaction)
    }

    private var summary: String {
        TransactionHelper.summary(for: transaction)
    }

    private var amount: Decimal {
        transaction.amount
    }

    private var isExpense: Bool {
        (transaction.entries ?? []).contains { $0.account?.accountClass == .expense }
    }

    var body: some View {
        HStack(spacing: CashSpacing.md) {
            // Icon
            GlassIconCircle(
                icon: iconInfo.iconName,
                color: iconInfo.color,
                size: 40
            )

            // Description and date
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.descriptionText.isEmpty ? summary : transaction.descriptionText)
                    .font(CashTypography.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(CashTypography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amount
            PrivacyAmountView(
                amount: "\(isExpense ? "-" : "+")\(CurrencyFormatter.format(amount, currency: currency))",
                isPrivate: isPrivate,
                font: CashTypography.amountSmall,
                fontWeight: .semibold,
                color: isExpense ? CashColors.expense : CashColors.income
            )
        }
        .padding(.vertical, CashSpacing.sm)
    }
}

// MARK: - All Transactions View

struct AllTransactionsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    @State private var isInitialLoading = true
    @State private var isLoadingMore = false
    @State private var hasMoreData = true
    @State private var displayedTransactions: [Transaction] = []
    @State private var currentPage = 0
    @State private var detectedCurrency = "EUR"
    @State private var errorMessage: String?
    @State private var selectedTransaction: Transaction?

    private let pageSize = 50

    private var currency: String {
        detectedCurrency
    }

    private func fetchTransactions(page: Int) async throws -> [Transaction] {
        let offset = page * pageSize
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()

        let predicate = #Predicate<Transaction> { transaction in
            !transaction.isRecurring && transaction.date >= cutoffDate
        }

        var descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = offset

        return try modelContext.fetch(descriptor)
    }

    private func loadInitialTransactions() async {
        isInitialLoading = true
        currentPage = 0
        displayedTransactions = []
        hasMoreData = true
        errorMessage = nil

        do {
            let transactions = try await fetchTransactions(page: 0)

            await MainActor.run {
                displayedTransactions = transactions
                currentPage = 0
                hasMoreData = transactions.count == pageSize

                if let firstTransaction = transactions.first {
                    detectedCurrency = firstTransaction.entries?.first?.account?.currency ?? "EUR"
                }

                isInitialLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load transactions: \(error.localizedDescription)"
                displayedTransactions = []
                hasMoreData = false
                isInitialLoading = false
            }
        }
    }

    private func loadMoreTransactions() async {
        guard !isLoadingMore && !isInitialLoading && hasMoreData else { return }

        await MainActor.run {
            isLoadingMore = true
        }

        do {
            let nextPage = currentPage + 1
            let newTransactions = try await fetchTransactions(page: nextPage)

            await MainActor.run {
                displayedTransactions.append(contentsOf: newTransactions)
                currentPage = nextPage
                hasMoreData = newTransactions.count == pageSize
                isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load more transactions"
                hasMoreData = false
                isLoadingMore = false
            }
        }
    }

    var body: some View {
        Group {
            if isInitialLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading transactions...")
                        .font(CashTypography.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, CashSpacing.md)
                    Spacer()
                }
            } else if displayedTransactions.isEmpty {
                ContentUnavailableView {
                    Label("No Transactions", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("No transactions found in the last 90 days")
                }
            } else {
                List {
                    ForEach(displayedTransactions) { transaction in
                        Button {
                            selectedTransaction = transaction
                        } label: {
                            TransactionRowHome(
                                transaction: transaction,
                                currency: currency,
                                isPrivate: settings.privacyMode
                            )
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            // Trigger pagination when last item appears
                            if transaction.id == displayedTransactions.last?.id {
                                Task {
                                    await loadMoreTransactions()
                                }
                            }
                        }
                    }

                    // Bottom loading indicator
                    if isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                    }

                    // End of data indicator
                    if !hasMoreData && !displayedTransactions.isEmpty {
                        Text("All transactions loaded")
                            .font(CashTypography.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .listStyleInsetGrouped()
            }
        }
        .navigationTitle("Recent Transactions")
        .navigationBarTitleDisplayModeInline()
        .task {
            await loadInitialTransactions()
        }
        .refreshable {
            await loadInitialTransactions()
        }
        .sheet(item: $selectedTransaction) { transaction in
            NavigationStack {
                EditTransactionView(transaction: transaction)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
        .environment(AppSettings.shared)
}
