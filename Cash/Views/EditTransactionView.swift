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
    
    // Recurrence settings
    @State private var isRecurring: Bool = false
    @State private var recurrenceFrequency: RecurrenceFrequency = .monthly
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceDayOfMonth: Int = 1
    @State private var recurrenceDayOfWeek: Int = 2
    @State private var recurrenceWeekendAdjustment: WeekendAdjustment = .none
    @State private var recurrenceEndDate: Date? = nil
    
    @State private var showingValidationError = false
    @State private var validationMessage: LocalizedStringKey = ""
    @State private var showingReconciledWarning = false
    
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
    
    private var isReconciled: Bool {
        transaction.reconciliationStatus == .reconciled
    }
    
    init(transaction: Transaction) {
        self.transaction = transaction
        _date = State(initialValue: transaction.date)
        _descriptionText = State(initialValue: transaction.descriptionText)
        _amountText = State(initialValue: "\(transaction.amount)")
        _selectedDebitAccount = State(initialValue: transaction.debitEntry?.account)
        _selectedCreditAccount = State(initialValue: transaction.creditEntry?.account)
        _isRecurring = State(initialValue: transaction.isRecurring)
        
        if let rule = transaction.recurrenceRule {
            _recurrenceFrequency = State(initialValue: rule.frequency)
            _recurrenceInterval = State(initialValue: rule.interval)
            _recurrenceDayOfMonth = State(initialValue: rule.dayOfMonth ?? 1)
            _recurrenceDayOfWeek = State(initialValue: rule.dayOfWeek ?? 2)
            _recurrenceWeekendAdjustment = State(initialValue: rule.weekendAdjustment)
            _recurrenceEndDate = State(initialValue: rule.endDate)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Warning banner for reconciled transactions
                if isReconciled {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reconciled transaction")
                                    .font(.headline)
                                Text("This transaction has been reconciled. Modifying it may cause discrepancies with your bank statement.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Recurrence") {
                    RecurrenceConfigView(
                        isRecurring: $isRecurring,
                        frequency: $recurrenceFrequency,
                        interval: $recurrenceInterval,
                        dayOfMonth: $recurrenceDayOfMonth,
                        dayOfWeek: $recurrenceDayOfWeek,
                        weekendAdjustment: $recurrenceWeekendAdjustment,
                        endDate: $recurrenceEndDate
                    )
                }
                
                Section("Details") {
                    if isRecurring {
                        DatePicker("Start date", selection: $date, displayedComponents: .date)
                    } else {
                        DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    }
                    HStack {
                        Text(CurrencyList.symbol(forCode: currentCurrency))
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                    }
                }
                
                Section("Debit account (receives value)") {
                    AccountPicker(title: "Debit", accounts: activeAccounts, selection: $selectedDebitAccount, showClass: true)
                }
                
                Section("Credit account (gives value)") {
                    AccountPicker(title: "Credit", accounts: activeAccounts.filter { $0.id != selectedDebitAccount?.id }, selection: $selectedCreditAccount, showClass: true)
                }
                
                Section("Description") {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 80)
                }
                
                Section("Attachments") {
                    ForEach(existingAttachments) { attachment in
                        ExistingAttachmentRow(attachment: attachment) {
                            attachmentsToDelete.insert(attachment.id)
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
                    Label("Journal entry preview", systemImage: "doc.text")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTransaction() }
                        .disabled(!isValid)
                }
            }
            .alert("Validation error", isPresented: $showingValidationError) {
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
        
        // Update recurrence
        transaction.isRecurring = isRecurring
        
        if isRecurring {
            if let existingRule = transaction.recurrenceRule {
                // Update existing rule
                existingRule.frequency = recurrenceFrequency
                existingRule.interval = recurrenceInterval
                existingRule.dayOfMonth = recurrenceDayOfMonth
                existingRule.dayOfWeek = recurrenceDayOfWeek
                existingRule.weekendAdjustment = recurrenceWeekendAdjustment
                existingRule.endDate = recurrenceEndDate
                existingRule.nextOccurrence = existingRule.calculateNextOccurrence(from: date, includeDate: true)
            } else {
                // Create new rule
                let rule = RecurrenceRule(
                    frequency: recurrenceFrequency,
                    interval: recurrenceInterval,
                    dayOfMonth: recurrenceDayOfMonth,
                    dayOfWeek: recurrenceDayOfWeek,
                    weekendAdjustment: recurrenceWeekendAdjustment,
                    startDate: date,
                    endDate: recurrenceEndDate
                )
                rule.nextOccurrence = rule.calculateNextOccurrence(from: date, includeDate: true)
                rule.transaction = transaction
                modelContext.insert(rule)
            }
        } else {
            // Remove recurrence rule if exists
            if let existingRule = transaction.recurrenceRule {
                modelContext.delete(existingRule)
            }
        }
        
        // Signal balance update for affected accounts
        let affectedAccountIDs = Set((transaction.entries ?? []).compactMap { $0.account?.id })
        BalanceUpdateSignal.send(for: affectedAccountIDs)
        
        dismiss()
    }
}

#Preview {
    @Previewable @State var transaction = Transaction(date: Date(), descriptionText: "Grocery shopping")
    EditTransactionView(transaction: transaction)
        .modelContainer(for: Account.self, inMemory: true)
        .environment(AppSettings.shared)
}
