//
//  LoanScenariosView.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import SwiftUI

struct RateScenario: Identifiable {
    let id = UUID()
    let rateChange: Decimal
    let newRate: Decimal
    let payment: Decimal
    let totalInterest: Decimal
}

struct LoanScenariosView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    let principal: Decimal
    let baseRate: Decimal
    let totalPayments: Int
    let frequency: PaymentFrequency
    var amortizationType: AmortizationType = .french
    let currency: String
    
    @State private var scenarios: [RateScenario] = []
    @State private var customVariations: [Decimal] = [-1, -0.5, 0, 0.5, 1, 1.5, 2]
    @State private var isLoading = true
    
    private var basePayment: Decimal {
        LoanCalculator.calculatePayment(principal: principal, annualRate: baseRate, totalPayments: totalPayments, frequency: frequency, amortizationType: amortizationType)
    }
    
    private var baseTotalInterest: Decimal {
        LoanCalculator.calculateTotalInterest(principal: principal, annualRate: baseRate, totalPayments: totalPayments, frequency: frequency, amortizationType: amortizationType)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with base scenario
                VStack(spacing: 12) {
                    HStack {
                        Text("Rate Scenarios Analysis")
                            .font(.headline)
                        Spacer()
                    }
                    
                    HStack(spacing: 32) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Base Rate")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(baseRate.formatted())%")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Base Payment")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(basePayment, currency: currency),
                                isPrivate: settings.privacyMode,
                                font: .title2,
                                fontWeight: .bold
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Base Total Interest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(baseTotalInterest, currency: currency),
                                isPrivate: settings.privacyMode,
                                font: .title2,
                                fontWeight: .bold
                            )
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(.regularMaterial)
                
                Divider()
                
                if isLoading {
                    Spacer()
                    ProgressView("Calculating scenarios...")
                    Spacer()
                } else {
                    #if os(macOS)
                    // Scenarios table for macOS
                    Table(scenarios) { 
                        TableColumn("Change") { s in
                            HStack {
                                if s.rateChange > 0 {
                                    Image(systemName: "arrow.up")
                                        .foregroundStyle(.red)
                                } else if s.rateChange < 0 {
                                    Image(systemName: "arrow.down")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "minus")
                                        .foregroundStyle(.secondary)
                                }
                                Text(s.rateChange >= 0 ? "+\(s.rateChange.formatted())%" : "\(s.rateChange.formatted())%")
                                    .fontWeight(s.rateChange == 0 ? .bold : .regular)
                            }
                        }
                        .width(100)
                        
                        TableColumn("New Rate") { s in
                            Text("\(s.newRate.formatted())%")
                                .fontWeight(s.rateChange == 0 ? .bold : .regular)
                        }
                        .width(100)
                        
                        TableColumn("Payment") { s in
                            HStack {
                                PrivacyAmountView(
                                    amount: CurrencyFormatter.format(s.payment, currency: currency),
                                    isPrivate: settings.privacyMode,
                                    font: .body,
                                    fontWeight: s.rateChange == 0 ? .bold : .regular
                                )
                                
                                if s.rateChange != 0 {
                                    let diff = s.payment - basePayment
                                    Text("(\(diff >= 0 ? "+" : "")\(CurrencyFormatter.format(diff, currency: currency)))")
                                        .font(.caption)
                                        .foregroundStyle(diff > 0 ? .red : .green)
                                }
                            }
                        }
                        .width(180)
                        
                        TableColumn("Total Interest") { s in
                            HStack {
                                PrivacyAmountView(
                                    amount: CurrencyFormatter.format(s.totalInterest, currency: currency),
                                    isPrivate: settings.privacyMode,
                                    font: .body,
                                    fontWeight: s.rateChange == 0 ? .bold : .regular
                                )
                                
                                if s.rateChange != 0 {
                                    let diff = s.totalInterest - baseTotalInterest
                                    Text("(\(diff >= 0 ? "+" : "")\(CurrencyFormatter.format(diff, currency: currency)))")
                                        .font(.caption)
                                        .foregroundStyle(diff > 0 ? .red : .green)
                                }
                            }
                        }
                        .width(200)
                        
                        TableColumn("Monthly Diff") { s in
                            if s.rateChange != 0 {
                                let diff = s.payment - basePayment
                                Text("\(diff >= 0 ? "+" : "")\(CurrencyFormatter.format(diff, currency: currency))")
                                    .foregroundStyle(diff > 0 ? .red : .green)
                                    .fontWeight(.medium)
                            } else {
                                Text("-")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .width(120)
                    }
                    #else
                    // List for iOS
                    List(scenarios) { scenario in
                        RateScenarioRowView(
                            scenario: scenario,
                            basePayment: basePayment,
                            baseTotalInterest: baseTotalInterest,
                            currency: currency,
                            privacyMode: settings.privacyMode
                        )
                    }
                    .listStyle(.plain)
                    #endif
                }
            }
            .navigationTitle("Rate Scenarios")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await calculateScenarios()
            }
        }
        .adaptiveSheetFrame(minWidth: 750, minHeight: 450)
    }
    
    private func calculateScenarios() async {
        isLoading = true
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let result = LoanCalculator.simulateRateScenarios(
            principal: principal,
            baseRate: baseRate,
            totalPayments: totalPayments,
            frequency: frequency,
            amortizationType: amortizationType,
            variations: customVariations
        )
        
        await MainActor.run {
            scenarios = result.map { RateScenario(rateChange: $0.0, newRate: $0.1, payment: $0.2, totalInterest: $0.3) }
            isLoading = false
        }
    }
}

#Preview {
    LoanScenariosView(
        principal: 200000,
        baseRate: 3.5,
        totalPayments: 240,
        frequency: .monthly,
        currency: "EUR"
    )
    .environment(AppSettings.shared)
}

// MARK: - iOS Rate Scenario Row View

#if os(iOS)
struct RateScenarioRowView: View {
    let scenario: RateScenario
    let basePayment: Decimal
    let baseTotalInterest: Decimal
    let currency: String
    let privacyMode: Bool
    
    private var paymentDiff: Decimal {
        scenario.payment - basePayment
    }
    
    private var interestDiff: Decimal {
        scenario.totalInterest - baseTotalInterest
    }
    
    private var isBaseScenario: Bool {
        scenario.rateChange == 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: rate change indicator
            HStack {
                if scenario.rateChange > 0 {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.red)
                } else if scenario.rateChange < 0 {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.blue)
                }
                
                Text(scenario.rateChange >= 0 ? "+\(scenario.rateChange.formatted())%" : "\(scenario.rateChange.formatted())%")
                    .font(.headline)
                    .fontWeight(isBaseScenario ? .bold : .medium)
                
                if isBaseScenario {
                    Text("(Current)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("Rate: \(scenario.newRate.formatted())%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Payment and Interest details
            HStack(spacing: 16) {
                // Payment
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        PrivacyAmountView(
                            amount: CurrencyFormatter.format(scenario.payment, currency: currency),
                            isPrivate: privacyMode,
                            font: .subheadline,
                            fontWeight: .medium
                        )
                        if !isBaseScenario {
                            Text("(\(paymentDiff >= 0 ? "+" : "")\(CurrencyFormatter.format(paymentDiff, currency: currency)))")
                                .font(.caption)
                                .foregroundStyle(paymentDiff > 0 ? .red : .green)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Total Interest
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Interest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        PrivacyAmountView(
                            amount: CurrencyFormatter.format(scenario.totalInterest, currency: currency),
                            isPrivate: privacyMode,
                            font: .subheadline,
                            fontWeight: .medium
                        )
                        if !isBaseScenario {
                            Text("(\(interestDiff >= 0 ? "+" : "")\(CurrencyFormatter.format(interestDiff, currency: currency)))")
                                .font(.caption)
                                .foregroundStyle(interestDiff > 0 ? .red : .green)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
        .background(isBaseScenario ? Color.blue.opacity(0.05) : Color.clear)
    }
}
#endif
