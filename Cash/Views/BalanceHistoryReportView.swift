//
//  BalanceHistoryReportView.swift
//  Cash
//
//  Created by Michele Broggi on 28/11/25.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - History Period

enum HistoryPeriod: String, CaseIterable, Identifiable {
    case threeMonths = "threeMonths"
    case sixMonths = "sixMonths"
    case year = "year"
    case allTime = "allTime"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .threeMonths:
            return String(localized: "3 Months")
        case .sixMonths:
            return String(localized: "6 Months")
        case .year:
            return String(localized: "1 Year")
        case .allTime:
            return String(localized: "All Time")
        }
    }
    
    var startDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: Date())
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: Date())
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: Date())
        case .allTime:
            return nil
        }
    }
}

// MARK: - Balance Data Point

struct BalanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Decimal
    
    var balanceDouble: Double {
        NSDecimalNumber(decimal: balance).doubleValue
    }
}

// MARK: - Balance History Report View

struct BalanceHistoryReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    @Query(sort: \Transaction.date) private var allTransactions: [Transaction]
    
    @State private var selectedPeriod: HistoryPeriod = .sixMonths
    @State private var isLoading = true
    @State private var balanceHistory: [BalanceDataPoint] = []
    
    private var assetAccounts: [Account] {
        accounts.filter { $0.accountClass == .asset && $0.isActive && !$0.isSystem }
    }
    
    private var liabilityAccounts: [Account] {
        accounts.filter { $0.accountClass == .liability && $0.isActive && !$0.isSystem }
    }
    
    private var transactions: [Transaction] {
        allTransactions.filter { !$0.isRecurring }
    }
    
    private func netBalanceChange(for transaction: Transaction) -> Decimal {
        BalanceCalculator.netBalanceChange(for: transaction)
    }
    
    private var currentBalance: Decimal {
        balanceHistory.last?.balance ?? 0
    }
    
    private var minBalance: Decimal {
        balanceHistory.map { $0.balance }.min() ?? 0
    }
    
    private var maxBalance: Decimal {
        balanceHistory.map { $0.balance }.max() ?? 0
    }
    
    private var balanceChange: Decimal {
        guard let first = balanceHistory.first, let last = balanceHistory.last else { return 0 }
        return last.balance - first.balance
    }
    
    private var percentageChange: Double {
        guard let first = balanceHistory.first, first.balance != 0 else { return 0 }
        return Double(truncating: (balanceChange / abs(first.balance) * 100) as NSDecimalNumber)
    }
    
    private var currency: String {
        assetAccounts.first?.currency ?? liabilityAccounts.first?.currency ?? "EUR"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Period picker
            HStack {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    Picker(selection: $selectedPeriod) {
                        ForEach(HistoryPeriod.allCases) { period in
                            Text(period.localizedName).tag(period)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                } else {
                    Picker(selection: $selectedPeriod) {
                        ForEach(HistoryPeriod.allCases) { period in
                            Text(period.localizedName).tag(period)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 400)
                }

                Spacer()
            }
            .padding()
            .background(.bar)
            
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Spacer()
            } else if balanceHistory.isEmpty {
                VStack {
                    ContentUnavailableView {
                        Label("No balance history", systemImage: "chart.xyaxis.line")
                    } description: {
                        Text("Add transactions to see your balance history")
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Net Worth Over Time")
                                .font(.headline)
                            
                            Chart(balanceHistory) { point in
                                AreaMark(
                                    x: .value("Date", point.date),
                                    y: .value("Balance", point.balanceDouble)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Balance", point.balanceDouble)
                                )
                                .foregroundStyle(Color.blue)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let doubleValue = value.as(Double.self) {
                                            Text(formatAxisValue(doubleValue))
                                                .font(.caption2)
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
                            .frame(height: 250)
                            .privacyBlur(settings.privacyMode)
                        }
                        .padding()
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Stats
                        HStack(spacing: 16) {
                            // Current balance
                            StatCard(
                                title: String(localized: "Current Balance"),
                                value: CurrencyFormatter.format(currentBalance, currency: currency),
                                color: currentBalance >= 0 ? .blue : .red,
                                isPrivate: settings.privacyMode
                            )
                            
                            // Change
                            StatCard(
                                title: String(localized: "Change"),
                                value: "\(balanceChange >= 0 ? "+" : "")\(CurrencyFormatter.format(balanceChange, currency: currency))",
                                subtitle: String(format: "%+.1f%%", percentageChange),
                                color: balanceChange >= 0 ? .green : .red,
                                isPrivate: settings.privacyMode
                            )
                        }
                        .padding(.horizontal)
                        
                        HStack(spacing: 16) {
                            // Min balance
                            StatCard(
                                title: String(localized: "Minimum"),
                                value: CurrencyFormatter.format(minBalance, currency: currency),
                                color: .secondary,
                                isPrivate: settings.privacyMode
                            )
                            
                            // Max balance
                            StatCard(
                                title: String(localized: "Maximum"),
                                value: CurrencyFormatter.format(maxBalance, currency: currency),
                                color: .secondary,
                                isPrivate: settings.privacyMode
                            )
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedPeriod) { _, _ in
            Task { await loadData() }
        }
    }
    
    private func loadData() async {
        isLoading = true
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let txns = transactions
        guard !txns.isEmpty else {
            await MainActor.run {
                balanceHistory = []
                isLoading = false
            }
            return
        }
        
        let sortedTransactions = txns.sorted { $0.date < $1.date }
        let period = selectedPeriod
        
        let filteredTransactions: [Transaction]
        if let startDate = period.startDate {
            filteredTransactions = sortedTransactions.filter { $0.date >= startDate }
        } else {
            filteredTransactions = sortedTransactions
        }
        
        guard !filteredTransactions.isEmpty else {
            await MainActor.run {
                balanceHistory = []
                isLoading = false
            }
            return
        }
        
        var dataPoints: [BalanceDataPoint] = []
        var runningBalance: Decimal = 0
        
        if let startDate = period.startDate {
            for transaction in sortedTransactions where transaction.date < startDate {
                runningBalance += BalanceCalculator.netBalanceChange(for: transaction)
            }
            dataPoints.append(BalanceDataPoint(date: startDate, balance: runningBalance))
        }
        
        let calendar = Calendar.current
        var dailyBalances: [Date: Decimal] = [:]
        var currentBalance = runningBalance
        
        for transaction in filteredTransactions {
            currentBalance += BalanceCalculator.netBalanceChange(for: transaction)
            let dayStart = calendar.startOfDay(for: transaction.date)
            dailyBalances[dayStart] = currentBalance
        }
        
        let sortedDays = dailyBalances.keys.sorted()
        for day in sortedDays {
            if let balance = dailyBalances[day] {
                dataPoints.append(BalanceDataPoint(date: day, balance: balance))
            }
        }
        
        let today = calendar.startOfDay(for: Date())
        if dataPoints.last?.date != today {
            dataPoints.append(BalanceDataPoint(date: today, balance: currentBalance))
        }
        
        await MainActor.run {
            balanceHistory = dataPoints
            isLoading = false
        }
    }
    
    private func formatAxisValue(_ value: Double) -> String {
        ChartAxisFormatter.format(value)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let color: Color
    let isPrivate: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            PrivacyAmountView(
                amount: value,
                isPrivate: isPrivate,
                font: .title3,
                fontWeight: .semibold,
                color: color
            )
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(color)
                    .privacyBlur(isPrivate)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    BalanceHistoryReportView()
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
        .environment(AppSettings.shared)
}
