//
//  YearOverYearReportView.swift
//  Cash
//
//  Created by Michele Broggi on 28/11/25.
//

import SwiftUI
import SwiftData

// MARK: - Comparison Period

enum ComparisonPeriod: String, CaseIterable, Identifiable {
    case month = "month"
    case threeMonths = "threeMonths"
    case sixMonths = "sixMonths"
    case year = "year"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .month:
            return String(localized: "1 Month")
        case .threeMonths:
            return String(localized: "3 Months")
        case .sixMonths:
            return String(localized: "6 Months")
        case .year:
            return String(localized: "1 Year")
        }
    }
    
    var months: Int {
        switch self {
        case .month: return 1
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .year: return 12
        }
    }
    
    // Current period dates
    var currentStartDate: Date {
        Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
    }
    
    var currentEndDate: Date {
        Date()
    }
    
    // Previous year same period dates
    var previousStartDate: Date {
        Calendar.current.date(byAdding: .year, value: -1, to: currentStartDate) ?? Date()
    }
    
    var previousEndDate: Date {
        Calendar.current.date(byAdding: .year, value: -1, to: currentEndDate) ?? Date()
    }
}

// MARK: - Category Comparison Data

struct CategoryComparison: Identifiable {
    let id = UUID()
    let account: Account
    let currentTotal: Decimal
    let previousTotal: Decimal
    
    var difference: Decimal {
        currentTotal - previousTotal
    }
    
    var percentageChange: Double {
        guard previousTotal != 0 else {
            return currentTotal > 0 ? 100 : 0
        }
        return Double(truncating: ((currentTotal - previousTotal) / abs(previousTotal) * 100) as NSDecimalNumber)
    }
    
    var hasIncreased: Bool {
        currentTotal > previousTotal
    }
    
    var hasDecreased: Bool {
        currentTotal < previousTotal
    }
}

// MARK: - Year Over Year Report View

struct YearOverYearReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(filter: #Predicate<Account> { $0.accountClassRawValue == "expense" && $0.isActive == true && $0.isSystem == false })
    private var expenseAccounts: [Account]
    
    @State private var selectedPeriod: ComparisonPeriod = .month
    @State private var isLoading = true
    @State private var categoryComparisons: [CategoryComparison] = []
    
    private var totalCurrentExpenses: Decimal {
        categoryComparisons.reduce(Decimal.zero) { $0 + $1.currentTotal }
    }
    
    private var totalPreviousExpenses: Decimal {
        categoryComparisons.reduce(Decimal.zero) { $0 + $1.previousTotal }
    }
    
    private var totalDifference: Decimal {
        totalCurrentExpenses - totalPreviousExpenses
    }
    
    private var totalPercentageChange: Double {
        guard totalPreviousExpenses != 0 else {
            return totalCurrentExpenses > 0 ? 100 : 0
        }
        return Double(truncating: ((totalCurrentExpenses - totalPreviousExpenses) / abs(totalPreviousExpenses) * 100) as NSDecimalNumber)
    }
    
    private var currency: String {
        expenseAccounts.first?.currency ?? "EUR"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Period picker
            HStack {
                Picker(selection: $selectedPeriod) {
                    ForEach(ComparisonPeriod.allCases) { period in
                        Text(period.localizedName).tag(period)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 400)
                
                Spacer()
            }
            .padding()
            .background(.bar)
            
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Spacer()
            } else if categoryComparisons.isEmpty {
                VStack {
                    ContentUnavailableView {
                        Label("No data to compare", systemImage: "calendar.badge.clock")
                    } description: {
                        Text("Not enough expense data for year-over-year comparison")
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Summary card
                        VStack(spacing: 16) {
                            Text("Total Expenses Variation")
                                .font(.headline)
                            
                            HStack(spacing: 30) {
                                // Previous period
                                VStack(spacing: 4) {
                                    Text("Previous Year")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    PrivacyAmountView(
                                        amount: CurrencyFormatter.format(totalPreviousExpenses, currency: currency),
                                        isPrivate: settings.privacyMode,
                                        font: .title3,
                                        fontWeight: .medium,
                                        color: .secondary
                                    )
                                }
                                
                                // Arrow
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                
                                // Current period
                                VStack(spacing: 4) {
                                    Text("Current")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    PrivacyAmountView(
                                        amount: CurrencyFormatter.format(totalCurrentExpenses, currency: currency),
                                        isPrivate: settings.privacyMode,
                                        font: .title3,
                                        fontWeight: .medium,
                                        color: .primary
                                    )
                                }
                            }
                            
                            // Variation badge
                            HStack(spacing: 8) {
                                Image(systemName: totalDifference > 0 ? "arrow.up.right" : totalDifference < 0 ? "arrow.down.right" : "equal")
                                
                                PrivacyAmountView(
                                    amount: "\(totalDifference >= 0 ? "+" : "")\(CurrencyFormatter.format(totalDifference, currency: currency))",
                                    isPrivate: settings.privacyMode,
                                    font: .headline,
                                    fontWeight: .semibold,
                                    color: totalDifference > 0 ? .red : totalDifference < 0 ? .green : .secondary
                                )
                                
                                Text("(\(String(format: "%+.1f%%", totalPercentageChange)))")
                                    .font(.subheadline)
                                    .foregroundStyle(totalDifference > 0 ? .red : totalDifference < 0 ? .green : .secondary)
                                    .privacyBlur(settings.privacyMode)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background((totalDifference > 0 ? Color.red : totalDifference < 0 ? Color.green : Color.gray).opacity(0.15))
                            .clipShape(Capsule())
                        }
                        .padding()
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Category breakdown
                        VStack(alignment: .leading, spacing: 12) {
                            Text("By Category")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(categoryComparisons) { comparison in
                                CategoryComparisonRow(
                                    comparison: comparison,
                                    currency: currency,
                                    isPrivate: settings.privacyMode
                                )
                            }
                        }
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
        
        let accounts = expenseAccounts
        let period = selectedPeriod
        var comparisons: [CategoryComparison] = []
        
        for account in accounts {
            let entries = account.entries ?? []
            var currentTotal: Decimal = 0
            var previousTotal: Decimal = 0
            
            for entry in entries {
                guard let transaction = entry.transaction,
                      !transaction.isRecurring else {
                    continue
                }
                
                let amount: Decimal
                if entry.entryType == .debit {
                    amount = entry.amount
                } else {
                    amount = -entry.amount
                }
                
                if transaction.date >= period.currentStartDate &&
                   transaction.date <= period.currentEndDate {
                    currentTotal += amount
                }
                
                if transaction.date >= period.previousStartDate &&
                   transaction.date <= period.previousEndDate {
                    previousTotal += amount
                }
            }
            
            if currentTotal != 0 || previousTotal != 0 {
                comparisons.append(CategoryComparison(
                    account: account,
                    currentTotal: currentTotal,
                    previousTotal: previousTotal
                ))
            }
        }
        
        comparisons.sort { abs($0.difference) > abs($1.difference) }
        
        await MainActor.run {
            categoryComparisons = comparisons
            isLoading = false
        }
    }
}

// MARK: - Category Comparison Row

struct CategoryComparisonRow: View {
    let comparison: CategoryComparison
    let currency: String
    let isPrivate: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: comparison.account.effectiveIconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            // Category name and previous value
            VStack(alignment: .leading, spacing: 2) {
                Text(comparison.account.displayName)
                    .font(.body)
                
                HStack(spacing: 4) {
                    Text(CurrencyFormatter.format(comparison.previousTotal, currency: currency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .privacyBlur(isPrivate)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Text(CurrencyFormatter.format(comparison.currentTotal, currency: currency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .privacyBlur(isPrivate)
                }
            }
            
            Spacer()
            
            // Variation
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: comparison.hasIncreased ? "arrow.up.right" : comparison.hasDecreased ? "arrow.down.right" : "equal")
                        .font(.caption)
                    
                    Text("\(comparison.difference >= 0 ? "+" : "")\(CurrencyFormatter.format(comparison.difference, currency: currency))")
                        .font(.body)
                        .fontWeight(.medium)
                        .privacyBlur(isPrivate)
                }
                .foregroundStyle(comparison.hasIncreased ? .red : comparison.hasDecreased ? .green : .secondary)
                
                Text(String(format: "%+.1f%%", comparison.percentageChange))
                    .font(.caption)
                    .foregroundStyle(comparison.hasIncreased ? .red : comparison.hasDecreased ? .green : .secondary)
                    .privacyBlur(isPrivate)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

#Preview {
    YearOverYearReportView()
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
        .environment(AppSettings.shared)
}
