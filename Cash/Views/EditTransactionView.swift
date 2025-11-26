//
//  EditTransactionView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Bindable var transaction: Transaction
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    
    @State private var date: Date = Date()
    @State private var descriptionText: String = ""
    @State private var reference: String = ""
    @State private var amountText: String = ""
    @State private var selectedDebitAccount: Account?
    @State private var selectedCreditAccount: Account?
    
    @State private var showingValidationError = false
    @State private var validationMessage: LocalizedStringKey = ""
    
    private var activeAccounts: [Account] {
        accounts.filter { $0.isActive }
    }
    
    private var amount: Decimal {
        CurrencyFormatter.parse(amountText)
    }
    
    private var isValid: Bool {
        guard !amountText.isEmpty, amount > 0 else { return false }
        guard selectedDebitAccount != nil && selectedCreditAccount != nil else { return false }
        guard selectedDebitAccount?.id != selectedCreditAccount?.id else { return false }
        return true
    }
    
    init(transaction: Transaction) {
        self.transaction = transaction
        _date = State(initialValue: transaction.date)
        _descriptionText = State(initialValue: transaction.descriptionText)
        _reference = State(initialValue: transaction.reference)
        _amountText = State(initialValue: "\(transaction.amount)")
        _selectedDebitAccount = State(initialValue: transaction.debitEntry?.account)
        _selectedCreditAccount = State(initialValue: transaction.creditEntry?.account)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Description", text: $descriptionText)
                    TextField("Amount", text: $amountText)
                    TextField("Reference (optional)", text: $reference)
                }
                
                Section("Debit Account (receives value)") {
                    AccountPicker(title: "Debit", accounts: activeAccounts, selection: $selectedDebitAccount, showClass: true)
                }
                
                Section("Credit Account (gives value)") {
                    AccountPicker(title: "Credit", accounts: activeAccounts.filter { $0.id != selectedDebitAccount?.id }, selection: $selectedCreditAccount, showClass: true)
                }
                
                Section {
                    JournalEntryPreview(
                        debitAccountName: selectedDebitAccount?.name,
                        creditAccountName: selectedCreditAccount?.name,
                        amount: amount,
                        currency: "EUR"
                    )
                } header: {
                    Label("Journal Entry Preview", systemImage: "doc.text")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Transaction")
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
            .id(settings.refreshID)
        }
        .frame(minWidth: 450, minHeight: 500)
    }
    
    private func saveTransaction() {
        guard amount > 0 else {
            validationMessage = "Please enter a valid positive amount."
            showingValidationError = true
            return
        }
        
        guard let debitAccount = selectedDebitAccount, let creditAccount = selectedCreditAccount else {
            validationMessage = "Please select both accounts."
            showingValidationError = true
            return
        }
        
        transaction.date = date
        transaction.descriptionText = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        transaction.reference = reference
        
        if let debitEntry = transaction.debitEntry {
            debitEntry.amount = amount
            debitEntry.account = debitAccount
        }
        
        if let creditEntry = transaction.creditEntry {
            creditEntry.amount = amount
            creditEntry.account = creditAccount
        }
        
        dismiss()
    }
}

#Preview {
    @Previewable @State var transaction = Transaction(date: Date(), descriptionText: "Grocery shopping")
    EditTransactionView(transaction: transaction)
        .modelContainer(for: Account.self, inMemory: true)
        .environment(AppSettings.shared)
}
