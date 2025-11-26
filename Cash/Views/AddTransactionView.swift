//
//  AddTransactionView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData

/// Transaction type for user-friendly selection
enum SimpleTransactionType: String, CaseIterable, Identifiable {
    case expense = "expense"
    case income = "income"
    case transfer = "transfer"
    
    var id: String { rawValue }
    
    var localizedName: LocalizedStringKey {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .transfer: return "Transfer"
        }
    }
    
    var iconName: String {
        switch self {
        case .expense: return "arrow.up.circle.fill"
        case .income: return "arrow.down.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }
}

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    
    var preselectedAccount: Account?
    
    @State private var transactionType: SimpleTransactionType = .expense
    @State private var date: Date = Date()
    @State private var descriptionText: String = ""
    @State private var reference: String = ""
    @State private var amountText: String = ""
    
    @State private var selectedExpenseAccount: Account?
    @State private var selectedPaymentAccount: Account?
    @State private var selectedDepositAccount: Account?
    @State private var selectedIncomeAccount: Account?
    @State private var selectedFromAccount: Account?
    @State private var selectedToAccount: Account?
    
    @State private var showingValidationError = false
    @State private var validationMessage: LocalizedStringKey = ""
    
    private var assetAndLiabilityAccounts: [Account] {
        accounts.filter { ($0.accountClass == .asset || $0.accountClass == .liability) && $0.isActive }
    }
    
    private var expenseAccounts: [Account] {
        accounts.filter { $0.accountClass == .expense && $0.isActive }
    }
    
    private var incomeAccounts: [Account] {
        accounts.filter { $0.accountClass == .income && $0.isActive }
    }
    
    private var amount: Decimal {
        CurrencyFormatter.parse(amountText)
    }
    
    private var isValid: Bool {
        guard !amountText.isEmpty, amount > 0 else { return false }
        
        switch transactionType {
        case .expense:
            return selectedExpenseAccount != nil && selectedPaymentAccount != nil
        case .income:
            return selectedIncomeAccount != nil && selectedDepositAccount != nil
        case .transfer:
            return selectedFromAccount != nil && selectedToAccount != nil && selectedFromAccount?.id != selectedToAccount?.id
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction Type") {
                    Picker("Type", selection: $transactionType) {
                        ForEach(SimpleTransactionType.allCases) { type in
                            Label(type.localizedName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Description", text: $descriptionText)
                    TextField("Amount", text: $amountText)
                        .help("Enter the transaction amount")
                    TextField("Reference (optional)", text: $reference)
                }
                
                accountsSection
                
                Section {
                    journalPreview
                } header: {
                    Label("Journal Entry Preview", systemImage: "doc.text")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTransaction() }
                        .disabled(!isValid)
                }
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
            .onAppear { setupPreselectedAccount() }
            .id(settings.refreshID)
        }
        .frame(minWidth: 450, minHeight: 550)
    }
    
    @ViewBuilder
    private var accountsSection: some View {
        Section("Accounts") {
            switch transactionType {
            case .expense:
                AccountPicker(title: "Expense Category", accounts: expenseAccounts, selection: $selectedExpenseAccount)
                AccountPicker(title: "Pay From", accounts: assetAndLiabilityAccounts, selection: $selectedPaymentAccount)
            case .income:
                AccountPicker(title: "Income Category", accounts: incomeAccounts, selection: $selectedIncomeAccount)
                AccountPicker(title: "Deposit To", accounts: assetAndLiabilityAccounts, selection: $selectedDepositAccount)
            case .transfer:
                AccountPicker(title: "From Account", accounts: assetAndLiabilityAccounts, selection: $selectedFromAccount)
                AccountPicker(title: "To Account", accounts: assetAndLiabilityAccounts.filter { $0.id != selectedFromAccount?.id }, selection: $selectedToAccount)
            }
        }
    }
    
    @ViewBuilder
    private var journalPreview: some View {
        let (debitName, creditName) = previewAccounts
        JournalEntryPreview(
            debitAccountName: debitName,
            creditAccountName: creditName,
            amount: amount,
            currency: "EUR"
        )
    }
    
    private var previewAccounts: (String?, String?) {
        switch transactionType {
        case .expense:
            return (selectedExpenseAccount?.name, selectedPaymentAccount?.name)
        case .income:
            return (selectedDepositAccount?.name, selectedIncomeAccount?.name)
        case .transfer:
            return (selectedToAccount?.name, selectedFromAccount?.name)
        }
    }
    
    private func setupPreselectedAccount() {
        guard let account = preselectedAccount else { return }
        switch account.accountClass {
        case .asset, .liability:
            selectedPaymentAccount = account
            selectedDepositAccount = account
            selectedFromAccount = account
        case .expense:
            selectedExpenseAccount = account
        case .income:
            selectedIncomeAccount = account
        case .equity:
            break
        }
    }
    
    private func saveTransaction() {
        guard amount > 0 else {
            validationMessage = "Please enter a valid positive amount."
            showingValidationError = true
            return
        }
        
        let description = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch transactionType {
        case .expense:
            guard let expenseAccount = selectedExpenseAccount, let paymentAccount = selectedPaymentAccount else {
                showValidationError()
                return
            }
            _ = TransactionBuilder.createExpense(
                date: date,
                description: description.isEmpty ? expenseAccount.name : description,
                amount: amount,
                expenseAccount: expenseAccount,
                paymentAccount: paymentAccount,
                reference: reference,
                context: modelContext
            )
            
        case .income:
            guard let depositAccount = selectedDepositAccount, let incomeAccount = selectedIncomeAccount else {
                showValidationError()
                return
            }
            _ = TransactionBuilder.createIncome(
                date: date,
                description: description.isEmpty ? incomeAccount.name : description,
                amount: amount,
                depositAccount: depositAccount,
                incomeAccount: incomeAccount,
                reference: reference,
                context: modelContext
            )
            
        case .transfer:
            guard let fromAccount = selectedFromAccount, let toAccount = selectedToAccount else {
                showValidationError()
                return
            }
            _ = TransactionBuilder.createTransfer(
                date: date,
                description: description.isEmpty ? "Transfer" : description,
                amount: amount,
                fromAccount: fromAccount,
                toAccount: toAccount,
                reference: reference,
                context: modelContext
            )
        }
        
        dismiss()
    }
    
    private func showValidationError() {
        validationMessage = "Please select both accounts."
        showingValidationError = true
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(for: Account.self, inMemory: true)
        .environment(AppSettings.shared)
}
