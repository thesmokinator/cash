//
//  AmortizationScheduleView.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import SwiftUI

struct AmortizationScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    let principal: Decimal
    let annualRate: Decimal
    let totalPayments: Int
    let frequency: PaymentFrequency
    let startDate: Date
    let currency: String
    var startingPayment: Int = 1
    
    @State private var schedule: [AmortizationEntry] = []
    @State private var isLoading = true
    
    private var totalInterestPaid: Decimal {
        schedule.reduce(Decimal.zero) { $0 + $1.interest }
    }
    
    private var totalPrincipalPaid: Decimal {
        schedule.reduce(Decimal.zero) { $0 + $1.principal }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary header
                HStack(spacing: 32) {
                    SummaryItem(label: "Principal", value: principal, currency: currency)
                    SummaryItem(label: "Interest Rate", value: annualRate, suffix: "%", isPercentage: true)
                    SummaryItem(label: "Total Interest", value: totalInterestPaid, currency: currency)
                    SummaryItem(label: "Total Amount", value: principal + totalInterestPaid, currency: currency)
                }
                .padding()
                .background(.regularMaterial)
                
                Divider()
                
                if isLoading {
                    Spacer()
                    ProgressView("Calculating...")
                    Spacer()
                } else {
                    // Table
                    Table(schedule) {
                        TableColumn("#") { entry in
                            Text("\(entry.paymentNumber)")
                                .monospacedDigit()
                        }
                        .width(40)
                        
                        TableColumn("Date") { entry in
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        }
                        .width(100)
                        
                        TableColumn("Payment") { entry in
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(entry.payment, currency: currency),
                                isPrivate: settings.privacyMode,
                                font: .body,
                                fontWeight: .regular
                            )
                        }
                        .width(100)
                        
                        TableColumn("Principal") { entry in
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(entry.principal, currency: currency),
                                isPrivate: settings.privacyMode,
                                font: .body,
                                fontWeight: .regular,
                                color: .green
                            )
                        }
                        .width(100)
                        
                        TableColumn("Interest") { entry in
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(entry.interest, currency: currency),
                                isPrivate: settings.privacyMode,
                                font: .body,
                                fontWeight: .regular,
                                color: .orange
                            )
                        }
                        .width(100)
                        
                        TableColumn("Balance") { entry in
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(entry.remainingBalance, currency: currency),
                                isPrivate: settings.privacyMode,
                                font: .body,
                                fontWeight: .medium
                            )
                        }
                        .width(120)
                    }
                }
            }
            .navigationTitle("Amortization Schedule")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await generateSchedule()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
    
    private func generateSchedule() async {
        isLoading = true
        
        // Small delay to show loading
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let result = LoanCalculator.generateAmortizationSchedule(
            principal: principal,
            annualRate: annualRate,
            totalPayments: totalPayments,
            frequency: frequency,
            startDate: startDate,
            startingPayment: startingPayment
        )
        
        await MainActor.run {
            schedule = result
            isLoading = false
        }
    }
}

// MARK: - Summary Item

struct SummaryItem: View {
    @Environment(AppSettings.self) private var settings
    let label: LocalizedStringKey
    let value: Decimal
    var currency: String? = nil
    var suffix: String? = nil
    var isPercentage: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if isPercentage {
                Text("\(value.formatted())%")
                    .font(.headline)
                    .fontWeight(.semibold)
            } else if let currency = currency {
                PrivacyAmountView(
                    amount: CurrencyFormatter.format(value, currency: currency),
                    isPrivate: settings.privacyMode,
                    font: .headline,
                    fontWeight: .semibold
                )
            } else {
                Text(value.formatted())
                    .font(.headline)
                    .fontWeight(.semibold)
            }
        }
    }
}

#Preview {
    AmortizationScheduleView(
        principal: 200000,
        annualRate: 3.5,
        totalPayments: 240,
        frequency: .monthly,
        startDate: Date(),
        currency: "EUR"
    )
    .environment(AppSettings.shared)
}
