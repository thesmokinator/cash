//
//  FixedIncomeExpenseRatioReportView.swift
//  Cash
//
//  Created by Michele Broggi on 28/11/25.
//

import SwiftUI
import SwiftData

// MARK: - Stability Level

enum StabilityLevel {
    case excellent
    case good
    case adequate
    case atRisk
    case noData
    
    var localizedName: String {
        switch self {
        case .excellent:
            return String(localized: "Excellent")
        case .good:
            return String(localized: "Good")
        case .adequate:
            return String(localized: "Adequate")
        case .atRisk:
            return String(localized: "At Risk")
        case .noData:
            return String(localized: "No Data")
        }
    }
    
    var color: Color {
        switch self {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .adequate:
            return .orange
        case .atRisk:
            return .red
        case .noData:
            return .gray
        }
    }
    
    var iconName: String {
        switch self {
        case .excellent:
            return "checkmark.seal.fill"
        case .good:
            return "hand.thumbsup.fill"
        case .adequate:
            return "equal.circle.fill"
        case .atRisk:
            return "exclamationmark.triangle.fill"
        case .noData:
            return "questionmark.circle.fill"
        }
    }
}

// MARK: - Fixed Income vs Expense Ratio View

struct FixedIncomeExpenseRatioReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(filter: #Predicate<Transaction> { $0.isRecurring == true })
    private var recurringTransactions: [Transaction]
    
    private var fixedIncome: Decimal {
        var total: Decimal = 0
        for transaction in recurringTransactions {
            for entry in transaction.entries ?? [] {
                guard let account = entry.account,
                      account.accountClass == .income else { continue }
                // Income accounts: credits increase
                if entry.entryType == .credit {
                    total += entry.amount
                }
            }
        }
        return total
    }
    
    private var fixedExpenses: Decimal {
        var total: Decimal = 0
        for transaction in recurringTransactions {
            for entry in transaction.entries ?? [] {
                guard let account = entry.account,
                      account.accountClass == .expense else { continue }
                // Expense accounts: debits increase
                if entry.entryType == .debit {
                    total += entry.amount
                }
            }
        }
        return total
    }
    
    private var ratio: Double {
        guard fixedExpenses > 0 else { return 0 }
        return Double(truncating: (fixedIncome / fixedExpenses) as NSDecimalNumber)
    }
    
    private var surplus: Decimal {
        fixedIncome - fixedExpenses
    }
    
    private var stabilityLevel: StabilityLevel {
        if ratio >= 1.5 {
            return .excellent
        } else if ratio >= 1.2 {
            return .good
        } else if ratio >= 1.0 {
            return .adequate
        } else if ratio > 0 {
            return .atRisk
        } else {
            return .noData
        }
    }
    
    private var currency: String {
        if let firstTransaction = recurringTransactions.first,
           let entry = firstTransaction.entries?.first,
           let account = entry.account {
            return account.currency
        }
        return "EUR"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if recurringTransactions.isEmpty {
                    ContentUnavailableView {
                        Label("No recurring transactions", systemImage: "arrow.triangle.2.circlepath")
                    } description: {
                        Text("Add recurring transactions to analyze your financial stability")
                    }
                } else {
                    // Ratio indicator
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                                .frame(width: 180, height: 180)
                            
                            Circle()
                                .trim(from: 0, to: min(CGFloat(ratio) / 2.0, 1.0))
                                .stroke(stabilityLevel.color.gradient, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                                .frame(width: 180, height: 180)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.5), value: ratio)
                            
                            VStack(spacing: 4) {
                                Text(String(format: "%.2f", ratio))
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundStyle(stabilityLevel.color)
                                    .privacyBlur(settings.privacyMode)
                                
                                Text("ratio")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Stability badge
                        HStack(spacing: 8) {
                            Image(systemName: stabilityLevel.iconName)
                            Text(stabilityLevel.localizedName)
                        }
                        .font(.headline)
                        .foregroundStyle(stabilityLevel.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(stabilityLevel.color.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .padding(.top, 20)
                    
                    // Income vs Expenses comparison
                    VStack(spacing: 16) {
                        HStack(spacing: 20) {
                            // Fixed Income
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.green)
                                
                                Text("Fixed Income")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                PrivacyAmountView(
                                    amount: CurrencyFormatter.format(fixedIncome, currency: currency),
                                    isPrivate: settings.privacyMode,
                                    font: .title2,
                                    fontWeight: .semibold,
                                    color: .green
                                )
                                
                                Text("monthly")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            // Fixed Expenses
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.red)
                                
                                Text("Fixed Expenses")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                PrivacyAmountView(
                                    amount: CurrencyFormatter.format(fixedExpenses, currency: currency),
                                    isPrivate: settings.privacyMode,
                                    font: .title2,
                                    fontWeight: .semibold,
                                    color: .red
                                )
                                
                                Text("monthly")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Surplus/Deficit
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(surplus >= 0 ? "Monthly Surplus" : "Monthly Deficit")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                PrivacyAmountView(
                                    amount: CurrencyFormatter.format(abs(surplus), currency: currency),
                                    isPrivate: settings.privacyMode,
                                    font: .title3,
                                    fontWeight: .semibold,
                                    color: surplus >= 0 ? .green : .red
                                )
                            }
                            
                            Spacer()
                            
                            Image(systemName: surplus >= 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.title)
                                .foregroundStyle(surplus >= 0 ? .green : .red)
                        }
                        .padding()
                        .background(Color(surplus >= 0 ? .green : .red).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    
                    // Explanation
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Understanding the Ratio")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            RatioExplanationRow(
                                range: "≥ 1.50",
                                level: .excellent,
                                description: String(localized: "Excellent financial stability")
                            )
                            RatioExplanationRow(
                                range: "1.20 - 1.49",
                                level: .good,
                                description: String(localized: "Good stability with savings margin")
                            )
                            RatioExplanationRow(
                                range: "1.00 - 1.19",
                                level: .adequate,
                                description: String(localized: "Adequate, but limited flexibility")
                            )
                            RatioExplanationRow(
                                range: "< 1.00",
                                level: .atRisk,
                                description: String(localized: "At risk: expenses exceed income")
                            )
                        }
                    }
                    .padding()
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 20)
            }
        }
    }
}

// MARK: - Ratio Explanation Row

struct RatioExplanationRow: View {
    let range: String
    let level: StabilityLevel
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(range)
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(width: 80, alignment: .leading)
            
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    FixedIncomeExpenseRatioReportView()
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
        .environment(AppSettings.shared)
}
