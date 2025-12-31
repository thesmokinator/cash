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

                    // Quick Actions
                    quickActionsSection

                    // Recent Transactions
                    recentTransactionsSection
                }
                .padding(CashSpacing.lg)
            }
            .cashBackground()
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
        .background(
            LinearGradient(
                colors: [CashColors.primary.opacity(0.15), CashColors.primaryLight.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: CashRadius.xlarge))
        .shadow(
            color: CashShadow.medium.color,
            radius: CashShadow.medium.radius,
            x: CashShadow.medium.x,
            y: CashShadow.medium.y
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

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: CashSpacing.md) {
            Text("Quick Actions")
                .font(CashTypography.headline)
                .padding(.horizontal, CashSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CashSpacing.md) {
                    QuickActionCard(
                        icon: "arrow.up.circle.fill",
                        title: "Expense",
                        color: CashColors.expense
                    ) {
                        NotificationCenter.default.post(name: .addNewTransaction, object: nil)
                    }

                    QuickActionCard(
                        icon: "arrow.down.circle.fill",
                        title: "Income",
                        color: CashColors.income
                    ) {
                        NotificationCenter.default.post(name: .addNewTransaction, object: nil)
                    }

                    QuickActionCard(
                        icon: "arrow.left.arrow.right",
                        title: "Transfer",
                        color: CashColors.transfer
                    ) {
                        NotificationCenter.default.post(name: .addNewTransaction, object: nil)
                    }

                    QuickActionCard(
                        icon: "doc.text",
                        title: "Import",
                        color: CashColors.primary
                    ) {
                        NotificationCenter.default.post(name: .importOFX, object: nil)
                    }
                }
                .padding(.horizontal, CashSpacing.lg)
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

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: LocalizedStringKey
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: CashSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)

                Text(title)
                    .font(CashTypography.caption)
                    .foregroundColor(.primary)
            }
            .frame(width: 80, height: 80)
            .background(.ultraThinMaterial)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CashRadius.large))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - All Transactions View

struct AllTransactionsView: View {
    @Environment(AppSettings.self) private var settings
    @Query(filter: #Predicate<Transaction> { !$0.isRecurring }, sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @State private var selectedTransaction: Transaction?

    private var last90DaysTransactions: [Transaction] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        return allTransactions.filter { $0.date >= cutoffDate }
    }

    private var currency: String {
        last90DaysTransactions.first?.entries?.first?.account?.currency ?? "EUR"
    }

    var body: some View {
        List {
            ForEach(last90DaysTransactions) { transaction in
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
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Recent Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedTransaction) { transaction in
            NavigationStack {
                EditTransactionView(transaction: transaction)
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
