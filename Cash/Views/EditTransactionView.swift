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
    @State private var amountText: String = ""
    @State private var selectedDebitAccount: Account?
    @State private var selectedCreditAccount: Account?
    @State private var newAttachments: [AttachmentData] = []
    @State private var attachmentsToDelete: Set<UUID> = []
    
    @State private var showingValidationError = false
    @State private var validationMessage: LocalizedStringKey = ""
    
    private var activeAccounts: [Account] {
        accounts.filter { $0.isActive }
    }
    
    private var amount: Decimal {
        CurrencyFormatter.parse(amountText)
    }
    
    private var currentCurrency: String {
        selectedDebitAccount?.currency ?? selectedCreditAccount?.currency ?? "EUR"
    }
    
    private var isValid: Bool {
        guard !amountText.isEmpty, amount > 0 else { return false }
        guard selectedDebitAccount != nil && selectedCreditAccount != nil else { return false }
        guard selectedDebitAccount?.id != selectedCreditAccount?.id else { return false }
        return true
    }
    
    private var existingAttachments: [Attachment] {
        (transaction.attachments ?? []).filter { !attachmentsToDelete.contains($0.id) }
    }
    
    init(transaction: Transaction) {
        self.transaction = transaction
        _date = State(initialValue: transaction.date)
        _descriptionText = State(initialValue: transaction.descriptionText)
        _amountText = State(initialValue: "\(transaction.amount)")
        _selectedDebitAccount = State(initialValue: transaction.debitEntry?.account)
        _selectedCreditAccount = State(initialValue: transaction.creditEntry?.account)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    HStack {
                        Text(CurrencyList.symbol(forCode: currentCurrency))
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                    }
                }
                
                Section("Debit Account (receives value)") {
                    AccountPicker(title: "Debit", accounts: activeAccounts, selection: $selectedDebitAccount, showClass: true)
                }
                
                Section("Credit Account (gives value)") {
                    AccountPicker(title: "Credit", accounts: activeAccounts.filter { $0.id != selectedDebitAccount?.id }, selection: $selectedCreditAccount, showClass: true)
                }
                
                Section("Description") {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 80)
                }
                
                Section("Attachments") {
                    if !existingAttachments.isEmpty || !newAttachments.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(existingAttachments) { attachment in
                                    ExistingAttachmentView(attachment: attachment) {
                                        attachmentsToDelete.insert(attachment.id)
                                    }
                                }
                                ForEach(newAttachments) { attachment in
                                    AttachmentThumbnail(attachment: attachment, onTap: {}, onDelete: {
                                        newAttachments.removeAll { $0.id == attachment.id }
                                    })
                                }
                            }
                        }
                    }
                    AttachmentPickerView(attachments: $newAttachments)
                }
                
                Section {
                    JournalEntryPreview(
                        debitAccountName: selectedDebitAccount?.displayName,
                        creditAccountName: selectedCreditAccount?.displayName,
                        amount: amount,
                        currency: currentCurrency
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
        
        if let debitEntry = transaction.debitEntry {
            debitEntry.amount = amount
            debitEntry.account = debitAccount
        }
        
        if let creditEntry = transaction.creditEntry {
            creditEntry.amount = amount
            creditEntry.account = creditAccount
        }
        
        // Delete removed attachments
        for attachmentId in attachmentsToDelete {
            if let attachment = (transaction.attachments ?? []).first(where: { $0.id == attachmentId }) {
                modelContext.delete(attachment)
            }
        }
        
        // Add new attachments
        for attachmentData in newAttachments {
            let attachment = Attachment(
                filename: attachmentData.filename,
                mimeType: attachmentData.mimeType,
                data: attachmentData.data
            )
            attachment.transaction = transaction
            modelContext.insert(attachment)
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
