//
//  LoanFullPayoffView.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import SwiftUI
import SwiftData

struct LoanFullPayoffView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    
    let loan: Loan
    let remainingBalance: Decimal
    let onPayoff: () -> Void
    
    @State private var penaltyPercentageText: String = "0"
    @State private var selectedPaymentAccount: Account?
    @State private var payoffDate: Date = Date()
    @State private var createTransaction: Bool = true
    @State private var showingConfirmation = false
    
    private var penaltyPercentage: Decimal {
        Decimal(string: penaltyPercentageText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var penaltyAmount: Decimal {
        remainingBalance * penaltyPercentage / 100
    }
    
    private var totalPayoffAmount: Decimal {
        remainingBalance + penaltyAmount
    }
    
    private var savedInterest: Decimal {
        guard loan.remainingPayments > 0 else { return 0 }
        let remainingInterest = LoanCalculator.calculateTotalInterest(
            principal: remainingBalance,
            annualRate: loan.currentInterestRate,
            totalPayments: loan.remainingPayments,
            frequency: loan.paymentFrequency,
            amortizationType: loan.amortizationType
        )
        return remainingInterest - penaltyAmount
    }
    
    private var bankAccounts: [Account] {
        accounts.filter { $0.accountClass == .asset }
    }
    
    private var expenseCategories: [Account] {
        accounts.filter { $0.accountClass == .expense }
    }
    
    private var canPayoff: Bool {
        !createTransaction || selectedPaymentAccount != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Loan Payoff")
                            .font(.headline)
                        Text("Pay off the entire remaining balance of your loan.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Payoff Summary") {
                    LabeledContent("Loan", value: loan.name)
                    LabeledContent("Remaining Balance") {
                        Text(CurrencyFormatter.format(remainingBalance, currency: loan.currency))
                            .fontWeight(.semibold)
                    }
                    LabeledContent("Remaining Payments", value: "\(loan.remainingPayments)")
                }
                
                Section("Early Termination Penalty") {
                    LabeledContent("Penalty") {
                        HStack(spacing: 4) {
                            TextField("", text: $penaltyPercentageText)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if penaltyAmount > 0 {
                        LabeledContent("Penalty Amount") {
                            Text(CurrencyFormatter.format(penaltyAmount, currency: loan.currency))
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    Text("Enter any early termination penalty percentage from your loan agreement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Total Payoff Amount") {
                    HStack {
                        Text("Total to Pay")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(CurrencyFormatter.format(totalPayoffAmount, currency: loan.currency))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                    }
                    
                    if savedInterest > 0 {
                        HStack {
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(.green)
                            Text("You save \(CurrencyFormatter.format(savedInterest, currency: loan.currency)) in interest!")
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                Section {
                    Toggle("Create payoff transaction", isOn: $createTransaction)
                    
                    if createTransaction {
                        DatePicker("Payoff Date", selection: $payoffDate, displayedComponents: .date)
                        
                        if bankAccounts.isEmpty {
                            Text("No bank/cash accounts available")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("From Account", selection: $selectedPaymentAccount) {
                                Text("Select account").tag(nil as Account?)
                                ForEach(bankAccounts) { account in
                                    HStack {
                                        Image(systemName: account.accountType.iconName)
                                        Text(account.displayName)
                                    }
                                    .tag(account as Account?)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Transaction")
                } footer: {
                    if createTransaction {
                        Text("A transaction will be created to record this payoff in your accounts.")
                    }
                }
                
                if loan.linkedRecurringTransactionId != nil {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("This will also remove all scheduled future payments for this loan.")
                                .font(.callout)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Payoff Loan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pay Off") {
                        showingConfirmation = true
                    }
                    .disabled(!canPayoff)
                }
            }
            .alert("Confirm Payoff", isPresented: $showingConfirmation) {
                Button("Pay Off", role: .destructive) {
                    executePayoff()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to pay off this loan for \(CurrencyFormatter.format(totalPayoffAmount, currency: loan.currency))? This action cannot be undone.")
            }
            .onAppear {
                selectedPaymentAccount = bankAccounts.first
            }
        }
        .frame(minWidth: 450, minHeight: 550)
    }
    
    private func executePayoff() {
        // Create payoff transaction if requested
        if createTransaction, let paymentAccount = selectedPaymentAccount {
            createPayoffTransaction(from: paymentAccount)
        }
        
        // Remove linked recurring transaction
        LoanTransactionService.unlinkTransaction(for: loan, deleteTransaction: true, modelContext: modelContext)
        
        // Mark loan as fully paid
        loan.paymentsMade = loan.totalPayments
        
        dismiss()
        onPayoff()
    }
    
    private func createPayoffTransaction(from paymentAccount: Account) {
        // Find or use a generic expense category for the payoff
        let expenseCategory = expenseCategories.first {
            $0.displayName.localizedCaseInsensitiveContains("loan") ||
            $0.displayName.localizedCaseInsensitiveContains("mortgage") ||
            $0.displayName.localizedCaseInsensitiveContains("mutuo") ||
            $0.displayName.localizedCaseInsensitiveContains("prestito")
        } ?? expenseCategories.first
        
        guard let category = expenseCategory else { return }
        
        // Create the payoff transaction
        let transaction = Transaction(
            date: payoffDate,
            descriptionText: String(localized: "Payoff: \(loan.name)"),
            reference: "PAYOFF-\(loan.id.uuidString.prefix(8))"
        )
        transaction.isRecurring = false
        transaction.linkedLoanId = loan.id
        
        // Debit from payment account
        let debitEntry = Entry(
            entryType: .debit,
            amount: totalPayoffAmount,
            account: paymentAccount
        )
        
        // Credit to expense category
        let creditEntry = Entry(
            entryType: .credit,
            amount: totalPayoffAmount,
            account: category
        )
        
        transaction.entries = [debitEntry, creditEntry]
        modelContext.insert(transaction)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Loan.self, Account.self, Transaction.self, configurations: config)
    
    let loan = Loan(
        name: "Test Mortgage",
        loanType: .mortgage,
        interestRateType: .fixed,
        principalAmount: 200000,
        currentInterestRate: 3.5,
        totalPayments: 240,
        monthlyPayment: 1160,
        startDate: Date()
    )
    container.mainContext.insert(loan)
    
    return LoanFullPayoffView(loan: loan, remainingBalance: 180000, onPayoff: {})
        .modelContainer(container)
        .environment(AppSettings.shared)
}
