//
//  EarlyRepaymentView.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import SwiftUI

struct EarlyRepaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    let remainingBalance: Decimal
    let remainingPayments: Int
    let annualRate: Decimal
    let frequency: PaymentFrequency
    let currency: String
    
    @State private var repaymentAmountText: String = ""
    @State private var penaltyPercentageText: String = "0"
    
    private var repaymentAmount: Decimal {
        Decimal(string: repaymentAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var penaltyPercentage: Decimal {
        Decimal(string: penaltyPercentageText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var currentPayment: Decimal {
        LoanCalculator.calculatePayment(
            principal: remainingBalance,
            annualRate: annualRate,
            totalPayments: remainingPayments,
            frequency: frequency
        )
    }
    
    private var calculation: (savedInterest: Decimal, penaltyAmount: Decimal, netSavings: Decimal, newRemainingPayments: Int) {
        guard repaymentAmount > 0 else {
            return (0, 0, 0, remainingPayments)
        }
        
        return LoanCalculator.calculateEarlyRepayment(
            remainingBalance: remainingBalance,
            remainingPayments: remainingPayments,
            annualRate: annualRate,
            frequency: frequency,
            earlyRepaymentAmount: repaymentAmount,
            penaltyPercentage: penaltyPercentage
        )
    }
    
    private var isFullRepayment: Bool {
        repaymentAmount >= remainingBalance
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Current Loan Status") {
                    HStack {
                        Text("Remaining Balance")
                            .foregroundStyle(.secondary)
                        Spacer()
                        PrivacyAmountView(
                            amount: CurrencyFormatter.format(remainingBalance, currency: currency),
                            isPrivate: settings.privacyMode,
                            font: .body,
                            fontWeight: .semibold
                        )
                    }
                    
                    HStack {
                        Text("Remaining Payments")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(remainingPayments)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Current Payment")
                            .foregroundStyle(.secondary)
                        Spacer()
                        PrivacyAmountView(
                            amount: CurrencyFormatter.format(currentPayment, currency: currency),
                            isPrivate: settings.privacyMode,
                            font: .body,
                            fontWeight: .semibold
                        )
                    }
                    
                    HStack {
                        Text("Interest Rate")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(annualRate.formatted())%")
                            .fontWeight(.semibold)
                    }
                }
                
                Section("Early Repayment") {
                    HStack {
                        Text(CurrencyList.symbol(forCode: currency))
                            .foregroundStyle(.secondary)
                        TextField("Repayment Amount", text: $repaymentAmountText)
                    }
                    
                    HStack {
                        TextField("Penalty", text: $penaltyPercentageText)
                        Text("% of repayment amount")
                            .foregroundStyle(.secondary)
                    }
                    
                    // Quick amount buttons
                    HStack(spacing: 8) {
                        Text("Quick:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ForEach([10, 25, 50, 100], id: \.self) { percent in
                            Button("\(percent)%") {
                                let amount = remainingBalance * Decimal(percent) / 100
                                repaymentAmountText = "\(amount.rounded(2))"
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                
                if repaymentAmount > 0 {
                    Section("Results") {
                        if isFullRepayment {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                Text("Full repayment")
                                    .font(.headline)
                            }
                        }
                        
                        ResultRow2(
                            label: "Interest Saved",
                            value: calculation.savedInterest,
                            currency: currency,
                            valueColor: .green
                        )
                        
                        if penaltyPercentage > 0 {
                            ResultRow2(
                                label: "Penalty Amount",
                                value: calculation.penaltyAmount,
                                currency: currency,
                                valueColor: .red
                            )
                        }
                        
                        ResultRow2(
                            label: "Net Savings",
                            value: calculation.netSavings,
                            currency: currency,
                            valueColor: calculation.netSavings >= 0 ? .green : .red,
                            isHighlighted: true
                        )
                        
                        if !isFullRepayment {
                            Divider()
                            
                            HStack {
                                Text("New Remaining Payments")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(calculation.newRemainingPayments)")
                                        .fontWeight(.semibold)
                                    Text("(\(remainingPayments - calculation.newRemainingPayments) fewer)")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                            
                            HStack {
                                Text("Time Saved")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                let monthsSaved = (remainingPayments - calculation.newRemainingPayments) * frequency.monthsBetweenPayments
                                let years = monthsSaved / 12
                                let months = monthsSaved % 12
                                if years > 0 {
                                    Text("\(years) years, \(months) months")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("\(months) months")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Summary", systemImage: "info.circle")
                                .font(.headline)
                            
                            if isFullRepayment {
                                Text("By paying \(CurrencyFormatter.format(repaymentAmount, currency: currency)) now, you will completely pay off this loan and save \(CurrencyFormatter.format(calculation.savedInterest, currency: currency)) in interest.")
                            } else {
                                Text("By paying \(CurrencyFormatter.format(repaymentAmount, currency: currency)) now, you will reduce your loan term by \(remainingPayments - calculation.newRemainingPayments) payments and save \(CurrencyFormatter.format(calculation.netSavings, currency: currency)) overall.")
                            }
                            
                            if penaltyPercentage > 0 {
                                Text("Note: A penalty of \(CurrencyFormatter.format(calculation.penaltyAmount, currency: currency)) (\(penaltyPercentage.formatted())%) has been deducted from your savings.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Early Repayment")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 550)
    }
}

// MARK: - Result Row

struct ResultRow2: View {
    @Environment(AppSettings.self) private var settings
    let label: LocalizedStringKey
    let value: Decimal
    let currency: String
    var valueColor: Color = .primary
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(isHighlighted ? .primary : .secondary)
            Spacer()
            PrivacyAmountView(
                amount: CurrencyFormatter.format(value, currency: currency),
                isPrivate: settings.privacyMode,
                font: isHighlighted ? .headline : .body,
                fontWeight: isHighlighted ? .bold : .semibold,
                color: valueColor
            )
        }
    }
}

#Preview {
    EarlyRepaymentView(
        remainingBalance: 180000,
        remainingPayments: 216,
        annualRate: 3.5,
        frequency: .monthly,
        currency: "EUR"
    )
    .environment(AppSettings.shared)
}
