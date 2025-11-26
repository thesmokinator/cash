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
    @State private var amountText: String = ""
    @State private var attachments: [AttachmentData] = []
    
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
    
    private var currentCurrency: String {
        switch transactionType {
        case .expense:
            return selectedPaymentAccount?.currency ?? "EUR"
        case .income:
            return selectedDepositAccount?.currency ?? "EUR"
        case .transfer:
            return selectedFromAccount?.currency ?? "EUR"
        }
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
                    HStack {
                        Text(CurrencyList.symbol(forCode: currentCurrency))
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                    }
                }
                
                accountsSection
                
                Section("Description") {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 80)
                }
                
                Section("Attachments") {
                    AttachmentPickerView(attachments: $attachments)
                }
                
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
            currency: currentCurrency
        )
    }
    
    private var previewAccounts: (String?, String?) {
        switch transactionType {
        case .expense:
            return (selectedExpenseAccount?.displayName, selectedPaymentAccount?.displayName)
        case .income:
            return (selectedDepositAccount?.displayName, selectedIncomeAccount?.displayName)
        case .transfer:
            return (selectedToAccount?.displayName, selectedFromAccount?.displayName)
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
        var transaction: Transaction?
        
        switch transactionType {
        case .expense:
            guard let expenseAccount = selectedExpenseAccount, let paymentAccount = selectedPaymentAccount else {
                showValidationError()
                return
            }
            transaction = TransactionBuilder.createExpense(
                date: date,
                description: description.isEmpty ? expenseAccount.name : description,
                amount: amount,
                expenseAccount: expenseAccount,
                paymentAccount: paymentAccount,
                reference: "",
                context: modelContext
            )
            
        case .income:
            guard let depositAccount = selectedDepositAccount, let incomeAccount = selectedIncomeAccount else {
                showValidationError()
                return
            }
            transaction = TransactionBuilder.createIncome(
                date: date,
                description: description.isEmpty ? incomeAccount.name : description,
                amount: amount,
                depositAccount: depositAccount,
                incomeAccount: incomeAccount,
                reference: "",
                context: modelContext
            )
            
        case .transfer:
            guard let fromAccount = selectedFromAccount, let toAccount = selectedToAccount else {
                showValidationError()
                return
            }
            transaction = TransactionBuilder.createTransfer(
                date: date,
                description: description.isEmpty ? "Transfer" : description,
                amount: amount,
                fromAccount: fromAccount,
                toAccount: toAccount,
                reference: "",
                context: modelContext
            )
        }
        
        // Save attachments
        if let transaction = transaction {
            for attachmentData in attachments {
                let attachment = Attachment(
                    filename: attachmentData.filename,
                    mimeType: attachmentData.mimeType,
                    data: attachmentData.data
                )
                attachment.transaction = transaction
                modelContext.insert(attachment)
            }
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
