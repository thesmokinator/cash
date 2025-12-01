//
//  LoanDetailView.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import SwiftUI
import SwiftData

struct LoanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Bindable var loan: Loan
    
    @State private var showingAmortization = false
    @State private var showingScenarios = false
    @State private var showingEarlyRepayment = false
    @State private var showingUpdateRate = false
    @State private var showingRecordPayment = false
    @State private var newRateText: String = ""
    
    private var remainingBalance: Decimal {
        LoanCalculator.remainingBalance(
            principal: loan.principalAmount,
            annualRate: loan.currentInterestRate,
            totalPayments: loan.totalPayments,
            paymentsMade: loan.paymentsMade,
            frequency: loan.paymentFrequency
        )
    }
    
    private var interestPaidSoFar: Decimal {
        let totalPaid = loan.monthlyPayment * Decimal(loan.paymentsMade)
        let principalPaid = loan.principalAmount - remainingBalance
        return totalPaid - principalPaid
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: loan.loanType.iconName)
                                .font(.largeTitle)
                                .foregroundStyle(.tint)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loan.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                HStack(spacing: 8) {
                                    Text(loan.loanType.localizedName)
                                    Text("•")
                                        .foregroundStyle(.tertiary)
                                    Text(loan.interestRateType.localizedName)
                                    if loan.isExisting {
                                        Text("•")
                                            .foregroundStyle(.tertiary)
                                        Text("Tracking")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            CircularProgressView(progress: loan.progressPercentage / 100)
                                .frame(width: 60, height: 60)
                        }
                        
                        // Progress bar
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: loan.progressPercentage, total: 100)
                                .tint(Color.accentColor)
                            
                            HStack {
                                Text("\(loan.paymentsMade) payments made")
                                Spacer()
                                Text("\(loan.remainingPayments) remaining")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                    // Financial Summary
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        LoanStatCard(title: "Original Principal", value: loan.principalAmount, currency: loan.currency)
                        LoanStatCard(title: "Current Payment", value: loan.monthlyPayment, currency: loan.currency, isHighlighted: true)
                        LoanStatCard(title: "Interest Rate", value: loan.currentInterestRate, suffix: "%", isPercentage: true)
                        LoanStatCard(title: "Remaining Balance", value: remainingBalance, currency: loan.currency)
                        LoanStatCard(title: "Interest Paid", value: interestPaidSoFar, currency: loan.currency)
                        LoanStatCard(title: "Total Interest", value: loan.totalInterest, currency: loan.currency)
                    }
                    
                    // Dates
                    HStack(spacing: 16) {
                        DateCard(title: "Start Date", date: loan.startDate)
                        DateCard(title: "End Date", date: loan.endDate)
                        if let nextPayment = loan.nextPaymentDate {
                            DateCard(title: "Next Payment", date: nextPayment, isHighlighted: true)
                        }
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
                        Text("Actions")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ActionButton(title: "Record Payment", icon: "checkmark.circle", color: .green) {
                                recordPayment()
                            }
                            .disabled(loan.remainingPayments == 0)
                            
                            ActionButton(title: "Amortization", icon: "tablecells", color: .blue) {
                                showingAmortization = true
                            }
                            
                            ActionButton(title: "Rate Scenarios", icon: "chart.line.uptrend.xyaxis", color: .purple) {
                                showingScenarios = true
                            }
                            
                            ActionButton(title: "Early Repayment", icon: "arrow.uturn.backward", color: .orange) {
                                showingEarlyRepayment = true
                            }
                            .disabled(loan.remainingPayments == 0)
                            
                            if loan.interestRateType == .variable || loan.interestRateType == .mixed {
                                ActionButton(title: "Update Rate", icon: "percent", color: .teal) {
                                    newRateText = "\(loan.currentInterestRate)"
                                    showingUpdateRate = true
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Loan Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAmortization) {
                AmortizationScheduleView(
                    principal: loan.principalAmount,
                    annualRate: loan.currentInterestRate,
                    totalPayments: loan.totalPayments,
                    frequency: loan.paymentFrequency,
                    startDate: loan.startDate,
                    currency: loan.currency
                )
            }
            .sheet(isPresented: $showingScenarios) {
                LoanScenariosView(
                    principal: remainingBalance,
                    baseRate: loan.currentInterestRate,
                    totalPayments: loan.remainingPayments,
                    frequency: loan.paymentFrequency,
                    currency: loan.currency
                )
            }
            .sheet(isPresented: $showingEarlyRepayment) {
                EarlyRepaymentView(
                    remainingBalance: remainingBalance,
                    remainingPayments: loan.remainingPayments,
                    annualRate: loan.currentInterestRate,
                    frequency: loan.paymentFrequency,
                    currency: loan.currency
                )
            }
            .alert("Update Interest Rate", isPresented: $showingUpdateRate) {
                TextField("New Rate %", text: $newRateText)
                Button("Update") {
                    updateRate()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter the new interest rate. This will recalculate future payments.")
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private func recordPayment() {
        if loan.paymentsMade < loan.totalPayments {
            loan.paymentsMade += 1
        }
    }
    
    private func updateRate() {
        if let newRate = Decimal(string: newRateText.replacingOccurrences(of: ",", with: ".")) {
            loan.currentInterestRate = newRate
            // Recalculate payment for remaining balance
            let newPayment = LoanCalculator.calculatePayment(
                principal: remainingBalance,
                annualRate: newRate,
                totalPayments: loan.remainingPayments,
                frequency: loan.paymentFrequency
            )
            loan.monthlyPayment = newPayment
        }
    }
}

// MARK: - Supporting Views

struct LoanStatCard: View {
    @Environment(AppSettings.self) private var settings
    let title: LocalizedStringKey
    let value: Decimal
    var currency: String? = nil
    var suffix: String? = nil
    var isPercentage: Bool = false
    var isHighlighted: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if isPercentage {
                Text("\(value.formatted())\(suffix ?? "%")")
                    .font(.headline)
                    .fontWeight(.semibold)
            } else if let currency = currency {
                PrivacyAmountView(
                    amount: CurrencyFormatter.format(value, currency: currency),
                    isPrivate: settings.privacyMode,
                    font: .headline,
                    fontWeight: .semibold,
                    color: isHighlighted ? Color.accentColor : Color.primary
                )
            } else {
                Text(value.formatted())
                    .font(.headline)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct DateCard: View {
    let title: LocalizedStringKey
    let date: Date
    var isHighlighted: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(isHighlighted ? Color.accentColor : Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ActionButton: View {
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LoanDetailView(loan: Loan(
        name: "Home Mortgage",
        loanType: .mortgage,
        interestRateType: .fixed,
        principalAmount: 200000,
        currentInterestRate: 3.5,
        totalPayments: 240,
        monthlyPayment: 1160,
        startDate: Calendar.current.date(byAdding: .year, value: -2, to: Date())!,
        isExisting: true,
        paymentsMade: 24,
        currency: "EUR"
    ))
    .modelContainer(for: Loan.self, inMemory: true)
    .environment(AppSettings.shared)
}
