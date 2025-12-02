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
                    // Scenarios table
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
        .frame(minWidth: 750, minHeight: 450)
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
