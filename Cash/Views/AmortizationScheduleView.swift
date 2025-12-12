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
    var amortizationType: AmortizationType = .french
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
                // Header with summary
                VStack(spacing: 12) {
                    HStack {
                        Text("Amortization Schedule")
                            .font(.headline)
                        Spacer()
                    }
                    
                    HStack(spacing: 32) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Principal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(principal, currency: currency),
                                isPrivate: settings.privacyMode,
                                font: .title2,
                                fontWeight: .bold
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Interest Rate")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(annualRate.formatted())%")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total Interest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(totalInterestPaid, currency: currency),
                                isPrivate: settings.privacyMode,
                                font: .title2,
                                fontWeight: .bold
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total Amount")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(principal + totalInterestPaid, currency: currency),
                                isPrivate: settings.privacyMode,
                                font: .title2,
                                fontWeight: .bold
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Method")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(amortizationType.shortName)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(.regularMaterial)
                
                Divider()
                
                if isLoading {
                    Spacer()
                    ProgressView("Calculating...")
                    Spacer()
                } else {
                    #if os(macOS)
                    // Table for macOS
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
                    #else
                    // List for iOS
                    List(schedule) { entry in
                        AmortizationRowView(entry: entry, currency: currency, privacyMode: settings.privacyMode)
                    }
                    .listStyle(.plain)
                    #endif
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
        .adaptiveSheetFrame(minWidth: 700, minHeight: 500)
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
            amortizationType: amortizationType,
            startDate: startDate,
            startingPayment: startingPayment
        )
        
        await MainActor.run {
            schedule = result
            isLoading = false
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

// MARK: - iOS Amortization Row View

#if os(iOS)
struct AmortizationRowView: View {
    let entry: AmortizationEntry
    let currency: String
    let privacyMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: number and date
            HStack {
                Text("#\(entry.paymentNumber)")
                    .font(.headline)
                    .monospacedDigit()
                Spacer()
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Payment details grid
            HStack(spacing: 16) {
                // Payment
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PrivacyAmountView(
                        amount: CurrencyFormatter.format(entry.payment, currency: currency),
                        isPrivate: privacyMode,
                        font: .subheadline,
                        fontWeight: .medium
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Principal
                VStack(alignment: .leading, spacing: 2) {
                    Text("Principal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PrivacyAmountView(
                        amount: CurrencyFormatter.format(entry.principal, currency: currency),
                        isPrivate: privacyMode,
                        font: .subheadline,
                        fontWeight: .medium,
                        color: .green
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Interest
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PrivacyAmountView(
                        amount: CurrencyFormatter.format(entry.interest, currency: currency),
                        isPrivate: privacyMode,
                        font: .subheadline,
                        fontWeight: .medium,
                        color: .orange
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Balance row
            HStack {
                Text("Remaining Balance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                PrivacyAmountView(
                    amount: CurrencyFormatter.format(entry.remainingBalance, currency: currency),
                    isPrivate: privacyMode,
                    font: .subheadline,
                    fontWeight: .semibold
                )
            }
        }
        .padding(.vertical, 4)
    }
}
#endif
