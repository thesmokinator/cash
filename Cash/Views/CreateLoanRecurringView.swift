//
//  CreateLoanRecurringView.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import SwiftUI
import SwiftData

struct CreateLoanRecurringView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    
    let loan: Loan
    let onComplete: () -> Void
    let onSkip: () -> Void
    
    @State private var selectedPaymentAccount: Account?
    @State private var selectedExpenseCategory: Account?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var bankAccounts: [Account] {
        accounts.filter { $0.accountClass == .asset }
    }
    
    private var expenseCategories: [Account] {
        accounts.filter { $0.accountClass == .expense }
    }
    
    private var canCreate: Bool {
        selectedPaymentAccount != nil && selectedExpenseCategory != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Loan saved successfully!")
                            .font(.headline)
                        Text("Would you like to create a recurring transaction to track your payments?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Loan Summary") {
                    LabeledContent("Name", value: loan.name)
                    LabeledContent("Payment", value: CurrencyFormatter.format(loan.monthlyPayment, currency: loan.currency))
                    LabeledContent("Frequency", value: loan.paymentFrequency.localizedName)
                    if let nextDate = loan.nextPaymentDate {
                        LabeledContent("Next Payment", value: nextDate.formatted(date: .abbreviated, time: .omitted))
                    }
                    LabeledContent("Remaining Payments", value: "\(loan.remainingPayments)")
                }
                
                Section("Payment Account") {
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
                
                Section("Expense Category") {
                    if expenseCategories.isEmpty {
                        Text("No expense categories available")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Category", selection: $selectedExpenseCategory) {
                            Text("Select category").tag(nil as Account?)
                            ForEach(expenseCategories) { account in
                                HStack {
                                    Image(systemName: account.accountType.iconName)
                                    Text(account.displayName)
                                }
                                .tag(account as Account?)
                            }
                        }
                    }
                }
                
                Section {
                    Text("This will create a recurring transaction that appears in your scheduled transactions. The payment will be automatically suggested on each due date.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create Recurring Payment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        onSkip()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createRecurringTransaction()
                    }
                    .disabled(!canCreate)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Pre-select first available accounts
                if selectedPaymentAccount == nil {
                    selectedPaymentAccount = bankAccounts.first
                }
                if selectedExpenseCategory == nil {
                    // Try to find a loan/mortgage category
                    selectedExpenseCategory = expenseCategories.first { 
                        $0.displayName.localizedCaseInsensitiveContains("loan") ||
                        $0.displayName.localizedCaseInsensitiveContains("mortgage") ||
                        $0.displayName.localizedCaseInsensitiveContains("mutuo") ||
                        $0.displayName.localizedCaseInsensitiveContains("prestito")
                    } ?? expenseCategories.first
                }
            }
        }
        .frame(minWidth: 450, minHeight: 500)
    }
    
    private func createRecurringTransaction() {
        guard let paymentAccount = selectedPaymentAccount,
              let expenseCategory = selectedExpenseCategory else {
            errorMessage = "Please select both a payment account and expense category."
            showingError = true
            return
        }
        
        let transaction = LoanTransactionService.createRecurringTransaction(
            for: loan,
            paymentAccount: paymentAccount,
            expenseCategory: expenseCategory,
            modelContext: modelContext
        )
        
        if transaction != nil {
            onComplete()
        } else {
            errorMessage = "Failed to create recurring transaction. Please try again."
            showingError = true
        }
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
    
    return CreateLoanRecurringView(loan: loan, onComplete: {}, onSkip: {})
        .modelContainer(container)
        .environment(AppSettings.shared)
}
