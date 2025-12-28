//
//  ForecastView.swift
//  Cash
//
//  Created by Michele Broggi on 27/11/25.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Forecast Period

enum ForecastPeriod: String, CaseIterable, Identifiable {
    case nextWeek = "nextWeek"
    case next15Days = "next15Days"
    case nextMonth = "nextMonth"
    case next3Months = "next3Months"
    case next6Months = "next6Months"
    case next12Months = "next12Months"
    
    var id: String { rawValue }
    
    var localizedName: LocalizedStringKey {
        switch self {
        case .nextWeek: return "Next week"
        case .next15Days: return "Next 15 days"
        case .nextMonth: return "Next month"
        case .next3Months: return "Next 3 months"
        case .next6Months: return "Next 6 months"
        case .next12Months: return "Next 12 months"
        }
    }
    
    var endDate: Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .nextWeek:
            return calendar.date(byAdding: .day, value: 7, to: now) ?? now
        case .next15Days:
            return calendar.date(byAdding: .day, value: 15, to: now) ?? now
        case .nextMonth:
            return calendar.date(byAdding: .month, value: 1, to: now) ?? now
        case .next3Months:
            return calendar.date(byAdding: .month, value: 3, to: now) ?? now
        case .next6Months:
            return calendar.date(byAdding: .month, value: 6, to: now) ?? now
        case .next12Months:
            return calendar.date(byAdding: .month, value: 12, to: now) ?? now
        }
    }
}

// MARK: - Projected Transaction

struct ProjectedTransaction: Identifiable {
    let id = UUID()
    let date: Date
    let description: String
    let amount: Decimal
    let isExpense: Bool
    let sourceTransaction: Transaction?
}

// MARK: - Balance Point (for chart)

struct BalancePoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Decimal
    
    var balanceDouble: Double {
        NSDecimalNumber(decimal: balance).doubleValue
    }
}

// MARK: - Forecast View

struct ForecastView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    @Query(filter: #Predicate<Transaction> { $0.isRecurring == true }) private var recurringTransactions: [Transaction]
    
    @State private var selectedPeriod: ForecastPeriod = .nextMonth
    @State private var isCalculating = false
    @State private var projectedTransactions: [ProjectedTransaction] = []
    @State private var balanceHistory: [BalancePoint] = []
    
    private var assetAccounts: [Account] {
        accounts.filter { $0.accountClass == .asset && $0.isActive && !$0.isSystem }
    }
    
    private var liabilityAccounts: [Account] {
        accounts.filter { $0.accountClass == .liability && $0.isActive && !$0.isSystem }
    }
    
    private var currentBalance: Decimal {
        let totalAssets = assetAccounts.reduce(Decimal.zero) { $0 + $1.balance }
        let totalLiabilities = liabilityAccounts.reduce(Decimal.zero) { $0 + $1.balance }
        return totalAssets - totalLiabilities
    }
    
    private var projectedEndBalance: Decimal {
        balanceHistory.last?.balance ?? currentBalance
    }
    
    private var totalProjectedIncome: Decimal {
        projectedTransactions.filter { !$0.isExpense }.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    private var totalProjectedExpenses: Decimal {
        projectedTransactions.filter { $0.isExpense }.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    private var currency: String {
        CurrencyHelper.defaultCurrency(from: accounts)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Period Selector
                #if os(iOS)
                HStack {
                    Spacer()
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(ForecastPeriod.allCases) { period in
                            Text(period.localizedName).tag(period)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isCalculating)
                    .accessibilityIdentifier("forecastPeriodSelector")
                    .onChange(of: selectedPeriod) { _, newPeriod in
                        calculateForecast(for: newPeriod)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                #else
                Picker(selection: $selectedPeriod) {
                    ForEach(ForecastPeriod.allCases) { period in
                        Text(period.localizedName).tag(period)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal)
                .disabled(isCalculating)
                .accessibilityIdentifier("forecastPeriodSelector")
                .onChange(of: selectedPeriod) { _, newPeriod in
                    calculateForecast(for: newPeriod)
                }
                #endif
                
                if isCalculating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(.circular)
                        Text("Calculating forecast...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 400)
                } else {
                
                // Balance Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Balance Forecast")
                        .font(.headline)
                    
                    if balanceHistory.count > 1 {
                        Chart(balanceHistory) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Balance", point.balanceDouble)
                            )
                            .foregroundStyle(Color.blue.gradient)
                            
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Balance", point.balanceDouble)
                            )
                            .foregroundStyle(Color.blue.opacity(0.1).gradient)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text(formatCurrencyCompact(Decimal(doubleValue)))
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .frame(height: 200)
                        .privacyBlur(settings.privacyMode)
                    } else {
                        ContentUnavailableView {
                            Label("No forecast data", systemImage: "chart.line.uptrend.xyaxis")
                        } description: {
                            Text("Add recurring transactions to see balance projections.")
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Summary Cards
                HStack(spacing: 16) {
                    ForecastSummaryCard(
                        title: "Current Balance",
                        amount: currentBalance,
                        color: currentBalance >= 0 ? .blue : .red,
                        icon: "banknote",
                        currency: currency,
                        privacyMode: settings.privacyMode
                    )
                    
                    ForecastSummaryCard(
                        title: "Projected Balance",
                        amount: projectedEndBalance,
                        color: projectedEndBalance >= 0 ? .green : .red,
                        icon: "chart.line.uptrend.xyaxis",
                        currency: currency,
                        privacyMode: settings.privacyMode
                    )
                }
                
                HStack(spacing: 16) {
                    ForecastSummaryCard(
                        title: "Projected Income",
                        amount: totalProjectedIncome,
                        color: .green,
                        icon: "arrow.down.circle.fill",
                        currency: currency,
                        privacyMode: settings.privacyMode
                    )
                    
                    ForecastSummaryCard(
                        title: "Projected Expenses",
                        amount: totalProjectedExpenses,
                        color: .red,
                        icon: "arrow.up.circle.fill",
                        currency: currency,
                        privacyMode: settings.privacyMode
                    )
                }
                
                // Projected Transactions List
                if !projectedTransactions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming Transactions")
                            .font(.headline)
                        
                        ForEach(projectedTransactions.prefix(20)) { transaction in
                            ProjectedTransactionRow(transaction: transaction, currency: currency, privacyMode: settings.privacyMode)
                        }
                        
                        if projectedTransactions.count > 20 {
                            Text("And \(projectedTransactions.count - 20) more transactions...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                } // end else !isCalculating
            }
            .padding()
        }
        .navigationTitle("Forecast")
        .id(settings.refreshID)
        .task {
            calculateForecast(for: selectedPeriod)
        }
    }
    
    // MARK: - Calculate Forecast (Async)
    
    private func calculateForecast(for period: ForecastPeriod) {
        isCalculating = true
        
        // Capture necessary data for background computation
        let transactions = recurringTransactions
        let balance = currentBalance
        let endDate = period.endDate
        
        Task.detached(priority: .userInitiated) {
            let projected = await generateProjectedTransactionsAsync(
                recurringTransactions: transactions,
                until: endDate
            )
            let history = await generateBalanceHistoryAsync(
                transactions: projected,
                startingBalance: balance
            )
            
            await MainActor.run {
                projectedTransactions = projected
                balanceHistory = history
                isCalculating = false
            }
        }
    }
    
    // MARK: - Generate Projected Transactions (Async)
    
    private func generateProjectedTransactionsAsync(
        recurringTransactions: [Transaction],
        until endDate: Date
    ) async -> [ProjectedTransaction] {
        var projections: [ProjectedTransaction] = []
        let startDate = Date()
        
        for transaction in recurringTransactions {
            guard let rule = transaction.recurrenceRule, rule.isActive else { continue }
            
            // Determine if expense or income
            let entries = transaction.entries ?? []
            let isExpense = entries.contains { $0.account?.accountClass == .expense }
            
            // Generate all occurrences until end date
            var currentDate = rule.nextOccurrence ?? startDate
            var iterationCount = 0
            let maxIterations = 500 // Safety limit
            
            while currentDate <= endDate && iterationCount < maxIterations {
                iterationCount += 1
                
                if currentDate > startDate {
                    let projected = ProjectedTransaction(
                        date: currentDate,
                        description: transaction.descriptionText,
                        amount: transaction.amount,
                        isExpense: isExpense,
                        sourceTransaction: transaction
                    )
                    projections.append(projected)
                }
                
                // Calculate next occurrence
                if let nextDate = rule.calculateNextOccurrence(from: currentDate), nextDate > currentDate {
                    currentDate = nextDate
                } else {
                    break
                }
            }
        }
        
        return projections.sorted { $0.date < $1.date }
    }
    
    // MARK: - Generate Balance History (Async)
    
    private func generateBalanceHistoryAsync(
        transactions: [ProjectedTransaction],
        startingBalance: Decimal
    ) async -> [BalancePoint] {
        var points: [BalancePoint] = []
        var runningBalance = startingBalance
        
        // Start point (today)
        points.append(BalancePoint(date: Date(), balance: runningBalance))
        
        // Group transactions by date
        let grouped = Dictionary(grouping: transactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
        
        // Sort dates
        let sortedDates = grouped.keys.sorted()
        
        for date in sortedDates {
            if let dayTransactions = grouped[date] {
                for transaction in dayTransactions {
                    if transaction.isExpense {
                        runningBalance -= transaction.amount
                    } else {
                        runningBalance += transaction.amount
                    }
                }
                points.append(BalancePoint(date: date, balance: runningBalance))
            }
        }
        
        return points
    }
    
    private func formatCurrencyCompact(_ amount: Decimal) -> String {
        CurrencyFormatter.formatCompact(amount, currency: currency)
    }
}

// MARK: - Forecast Summary Card

struct ForecastSummaryCard: View {
    let title: LocalizedStringKey
    let amount: Decimal
    let color: Color
    let icon: String
    let currency: String
    var privacyMode: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            
            PrivacyAmountView(
                amount: CurrencyFormatter.format(amount, currency: currency),
                isPrivate: privacyMode,
                font: .title3,
                fontWeight: .semibold,
                color: amount < 0 ? .red : .primary
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Projected Transaction Row

struct ProjectedTransactionRow: View {
    let transaction: ProjectedTransaction
    let currency: String
    var privacyMode: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.isExpense ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(transaction.isExpense ? .red : .green)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            PrivacyAmountView(
                amount: formatAmount(transaction.amount, isExpense: transaction.isExpense),
                isPrivate: privacyMode,
                font: .subheadline,
                fontWeight: .medium,
                color: transaction.isExpense ? .red : .green
            )
        }
        .padding(.vertical, 4)
    }
    
    private func formatAmount(_ amount: Decimal, isExpense: Bool) -> String {
        let formatted = CurrencyFormatter.format(amount, currency: currency)
        return isExpense ? "-\(formatted)" : "+\(formatted)"
    }
}

#Preview {
    NavigationStack {
        ForecastView()
    }
    .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
    .environment(AppSettings.shared)
}
