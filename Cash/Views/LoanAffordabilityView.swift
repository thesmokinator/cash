//
//  LoanAffordabilityView.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import SwiftUI
import SwiftData

struct LoanAffordabilityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    let proposedPayment: Decimal
    let currency: String
    
    @State private var analysis: LoanAffordabilityAnalysis?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let analysis = analysis {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with affordability level
                    AffordabilityHeaderView(analysis: analysis)
                    
                    Divider()
                    
                    // Budget breakdown
                    BudgetBreakdownView(analysis: analysis, currency: currency, isPrivate: settings.privacyMode)
                    
                    Divider()
                    
                    // Debt-to-income gauge
                    DebtToIncomeGaugeView(analysis: analysis)
                    
                    // Data quality notice
                    if !analysis.hasEnoughData {
                        DataQualityNoticeView(analysis: analysis)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ContentUnavailableView(
                    "Unable to Analyze",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Could not calculate budget impact")
                )
            }
        }
        .onAppear {
            loadAnalysis()
        }
        .onChange(of: proposedPayment) { _, _ in
            loadAnalysis()
        }
    }
    
    private func loadAnalysis() {
        isLoading = true
        
        // Perform analysis on background
        Task {
            let result = AffordabilityCalculator.analyze(
                proposedPayment: proposedPayment,
                modelContext: modelContext
            )
            
            await MainActor.run {
                self.analysis = result
                self.isLoading = false
            }
        }
    }
}

// MARK: - Affordability Header

struct AffordabilityHeaderView: View {
    let analysis: LoanAffordabilityAnalysis
    
    private var levelColor: Color {
        switch analysis.affordabilityLevel.color {
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: analysis.affordabilityLevel.iconName)
                .font(.title)
                .foregroundStyle(levelColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Budget Impact Analysis")
                    .font(.headline)
                
                Text(analysis.affordabilityLevel.localizedName)
                    .font(.subheadline)
                    .foregroundStyle(levelColor)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        
        Text(analysis.affordabilityLevel.description)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Budget Breakdown

struct BudgetBreakdownView: View {
    @Environment(AppSettings.self) private var settings
    let analysis: LoanAffordabilityAnalysis
    let currency: String
    let isPrivate: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Income row
            BudgetRow(
                label: String(localized: "Average Monthly Income"),
                sublabel: analysis.dataQualityDescription,
                amount: analysis.averageMonthlyIncome,
                currency: currency,
                isPrivate: isPrivate,
                style: .income
            )
            
            // Expenses row
            BudgetRow(
                label: String(localized: "Average Monthly Expenses"),
                amount: analysis.averageMonthlyExpenses,
                currency: currency,
                isPrivate: isPrivate,
                style: .expense
            )
            
            Divider()
                .padding(.vertical, 4)
            
            // Current surplus
            BudgetRow(
                label: String(localized: "Current Monthly Surplus"),
                amount: analysis.currentMonthlySurplus,
                currency: currency,
                isPrivate: isPrivate,
                style: analysis.currentMonthlySurplus >= 0 ? .positive : .negative
            )
            
            // New loan payment
            BudgetRow(
                label: String(localized: "New Loan Payment"),
                amount: analysis.proposedLoanPayment,
                currency: currency,
                isPrivate: isPrivate,
                style: .expense,
                isHighlighted: true
            )
            
            // Scheduled recurring (if any)
            if analysis.scheduledRecurringExpenses > 0 {
                BudgetRow(
                    label: String(localized: "Other Scheduled Expenses"),
                    amount: analysis.scheduledRecurringExpenses,
                    currency: currency,
                    isPrivate: isPrivate,
                    style: .expense
                )
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Final surplus
            BudgetRow(
                label: String(localized: "Surplus After Loan"),
                amount: analysis.surplusAfterLoan,
                currency: currency,
                isPrivate: isPrivate,
                style: analysis.surplusAfterLoan >= 0 ? .positive : .negative,
                isHighlighted: true
            )
        }
    }
}

// MARK: - Budget Row

enum BudgetRowStyle {
    case income, expense, positive, negative, neutral
    
    var color: Color {
        switch self {
        case .income, .positive:
            return .green
        case .expense, .negative:
            return .red
        case .neutral:
            return .primary
        }
    }
    
    var prefix: String {
        switch self {
        case .income, .positive:
            return ""
        case .expense, .negative:
            return "−"
        case .neutral:
            return ""
        }
    }
}

struct BudgetRow: View {
    let label: String
    var sublabel: String? = nil
    let amount: Decimal
    let currency: String
    let isPrivate: Bool
    var style: BudgetRowStyle = .neutral
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(isHighlighted ? .body.weight(.semibold) : .body)
                    .foregroundStyle(isHighlighted ? .primary : .secondary)
                
                if let sublabel = sublabel {
                    Text(sublabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            if isPrivate {
                Text("••••")
                    .font(isHighlighted ? .body.weight(.bold) : .body)
                    .foregroundStyle(style.color)
            } else {
                Text("\(style.prefix)\(CurrencyFormatter.format(abs(amount), currency: currency))")
                    .font(isHighlighted ? .body.weight(.bold) : .body)
                    .foregroundStyle(style.color)
            }
        }
    }
}

// MARK: - Debt-to-Income Gauge

struct DebtToIncomeGaugeView: View {
    let analysis: LoanAffordabilityAnalysis
    
    private var gaugeColor: Color {
        switch analysis.debtToIncomeRatio {
        case ..<20:
            return .green
        case 20..<28:
            return .blue
        case 28..<36:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Debt-to-Income Ratio")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(String(format: "%.1f%%", analysis.debtToIncomeRatio))
                    .font(.headline)
                    .foregroundStyle(gaugeColor)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Threshold markers
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: geometry.size.width * 0.20)
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: geometry.size.width * 0.08)
                        Rectangle()
                            .fill(Color.orange.opacity(0.3))
                            .frame(width: geometry.size.width * 0.08)
                        Rectangle()
                            .fill(Color.red.opacity(0.3))
                    }
                    .frame(height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    // Current value indicator
                    let ratio = min(analysis.debtToIncomeRatio / 50, 1.0)
                    Circle()
                        .fill(gaugeColor)
                        .frame(width: 12, height: 12)
                        .offset(x: geometry.size.width * CGFloat(ratio) - 6)
                }
            }
            .frame(height: 12)
            
            // Legend
            HStack(spacing: 16) {
                GaugeLegendItem(label: "<20%", description: String(localized: "Ideal"), color: .green)
                GaugeLegendItem(label: "20-28%", description: String(localized: "OK"), color: .blue)
                GaugeLegendItem(label: "28-36%", description: String(localized: "Limit"), color: .orange)
                GaugeLegendItem(label: ">36%", description: String(localized: "Risk"), color: .red)
            }
            .font(.caption2)
        }
        .padding(.top, 8)
    }
}

struct GaugeLegendItem: View {
    let label: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Data Quality Notice

struct DataQualityNoticeView: View {
    let analysis: LoanAffordabilityAnalysis
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.orange)
            
            Text("Limited historical data. Add more transactions for a more accurate analysis.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    LoanAffordabilityView(
        proposedPayment: 650,
        currency: "EUR"
    )
    .frame(width: 450)
    .padding()
    .modelContainer(for: [Transaction.self, Account.self], inMemory: true)
    .environment(AppSettings.shared)
}
