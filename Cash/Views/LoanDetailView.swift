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
    @State private var showingFullPayoff = false
    @State private var showingDeleteConfirmation = false
    @State private var newRateText: String = ""
    
    private var remainingBalance: Decimal {
        LoanCalculator.remainingBalance(
            principal: loan.principalAmount,
            annualRate: loan.currentInterestRate,
            totalPayments: loan.totalPayments,
            paymentsMade: loan.paymentsMade,
            frequency: loan.paymentFrequency,
            amortizationType: loan.amortizationType
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
                    
                    // Financial Summary - List style
                    VStack(spacing: 0) {
                        LoanInfoRow(title: "Original Principal", value: CurrencyFormatter.format(loan.principalAmount, currency: loan.currency))
                        Divider()
                        LoanInfoRow(title: "Current Payment", value: CurrencyFormatter.format(loan.monthlyPayment, currency: loan.currency), isHighlighted: true)
                        Divider()
                        LoanInfoRow(title: "Interest Rate", value: "\(loan.currentInterestRate.formatted())%")
                        Divider()
                        LoanInfoRow(title: "Remaining Balance", value: CurrencyFormatter.format(remainingBalance, currency: loan.currency))
                        Divider()
                        LoanInfoRow(title: "Interest Paid", value: CurrencyFormatter.format(interestPaidSoFar, currency: loan.currency))
                        Divider()
                        LoanInfoRow(title: "Total Interest", value: CurrencyFormatter.format(loan.totalInterest, currency: loan.currency))
                        Divider()
                        LoanInfoRow(title: "Start Date", value: loan.startDate.formatted(date: .abbreviated, time: .omitted))
                        Divider()
                        LoanInfoRow(title: "End Date", value: loan.endDate.formatted(date: .abbreviated, time: .omitted))
                        if let nextPayment = loan.nextPaymentDate {
                            Divider()
                            LoanInfoRow(title: "Next Payment", value: nextPayment.formatted(date: .abbreviated, time: .omitted), isHighlighted: true)
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                    // Actions
                    VStack(spacing: 12) {
                        Text("Actions")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 8) {
                            ActionButton(title: "Amortization Schedule", icon: "tablecells", color: .blue) {
                                showingAmortization = true
                            }
                            
                            ActionButton(title: "Rate Scenarios", icon: "chart.line.uptrend.xyaxis", color: .purple) {
                                showingScenarios = true
                            }
                            
                            ActionButton(title: "Early Repayment", icon: "arrow.uturn.backward", color: .orange) {
                                showingEarlyRepayment = true
                            }
                            .disabled(loan.remainingPayments == 0)
                            
                            ActionButton(title: "Full Payoff", icon: "checkmark.seal.fill", color: .red) {
                                showingFullPayoff = true
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
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .sheet(isPresented: $showingAmortization) {
                AmortizationScheduleView(
                    principal: loan.principalAmount,
                    annualRate: loan.currentInterestRate,
                    totalPayments: loan.totalPayments,
                    frequency: loan.paymentFrequency,
                    amortizationType: loan.amortizationType,
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
                    amortizationType: loan.amortizationType,
                    currency: loan.currency
                )
            }
            .sheet(isPresented: $showingEarlyRepayment) {
                EarlyRepaymentView(
                    remainingBalance: remainingBalance,
                    remainingPayments: loan.remainingPayments,
                    annualRate: loan.currentInterestRate,
                    frequency: loan.paymentFrequency,
                    amortizationType: loan.amortizationType,
                    currency: loan.currency
                )
            }
            .sheet(isPresented: $showingFullPayoff) {
                LoanFullPayoffView(
                    loan: loan,
                    remainingBalance: remainingBalance,
                    onPayoff: {
                        dismiss()
                    }
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
            .alert(
                "Delete Loan",
                isPresented: $showingDeleteConfirmation
            ) {
                Button("Delete", role: .destructive) {
                    deleteLoan()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if loan.linkedRecurringTransactionId != nil {
                    Text("This loan has linked recurring transactions. Deleting will also remove all scheduled future payments. This action cannot be undone.")
                } else {
                    Text("Are you sure you want to delete this loan? This action cannot be undone.")
                }
            }
        }
    }
    
    private func deleteLoan() {
        // Delete linked recurring transaction if exists
        LoanTransactionService.unlinkTransaction(for: loan, deleteTransaction: true, modelContext: modelContext)
        
        // Delete the loan
        modelContext.delete(loan)
        dismiss()
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

struct LoanInfoRow: View {
    @Environment(AppSettings.self) private var settings
    let title: LocalizedStringKey
    let value: String
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            if settings.privacyMode {
                Text("••••")
                    .fontWeight(.medium)
                    .foregroundStyle(isHighlighted ? Color.accentColor : .primary)
            } else {
                Text(value)
                    .fontWeight(.medium)
                    .foregroundStyle(isHighlighted ? Color.accentColor : .primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
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
