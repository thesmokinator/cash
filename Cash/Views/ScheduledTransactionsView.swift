//
//  ScheduledTransactionsView.swift
//  Cash
//
//  Created by Michele Broggi on 27/11/25.
//

import SwiftUI
import SwiftData

struct ScheduledTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(filter: #Predicate<Transaction> { $0.isRecurring == true }, sort: \Transaction.date) private var scheduledTransactions: [Transaction]
    @State private var showingAddScheduled = false
    @State private var transactionToEdit: Transaction?
    @State private var transactionToDelete: Transaction?
    @State private var transactionToExecute: Transaction?
    @State private var searchText: String = ""
    @State private var dummyDateFilter: TransactionDateFilter = .thisMonth
    
    private var filteredTransactions: [Transaction] {
        if searchText.isEmpty {
            return scheduledTransactions
        }
        return scheduledTransactions.filter { $0.descriptionText.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TransactionFilterBar(
                dateFilter: $dummyDateFilter,
                searchText: $searchText,
                showDateFilter: false,
                onAddTransaction: { showingAddScheduled = true }
            )
                        
            if filteredTransactions.isEmpty {
                VStack {
                    ContentUnavailableView {
                        Label(scheduledTransactions.isEmpty ? "No scheduled transactions" : "No results", systemImage: scheduledTransactions.isEmpty ? "calendar.badge.clock" : "magnifyingglass")
                    } description: {
                        Text(scheduledTransactions.isEmpty ? "Add a recurring transaction to see it here" : "No transactions match your search")
                    }
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredTransactions) { transaction in
                        ScheduledTransactionRow(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                transactionToEdit = transaction
                            }
                            .contextMenu {
                                Button {
                                    transactionToExecute = transaction
                                } label: {
                                    Label("Execute now", systemImage: "play.fill")
                                }
                                
                                Button {
                                    transactionToEdit = transaction
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    transactionToExecute = transaction
                                } label: {
                                    Label("Execute", systemImage: "play.fill")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Scheduled")
        .sheet(isPresented: $showingAddScheduled) {
            AddScheduledTransactionView()
        }
        .sheet(item: $transactionToEdit) { transaction in
            EditScheduledTransactionView(transaction: transaction)
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewScheduledTransaction)) { _ in
            showingAddScheduled = true
        }
        .confirmationDialog(
            "Execute transaction",
            isPresented: Binding(
                get: { transactionToExecute != nil },
                set: { if !$0 { transactionToExecute = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Execute") {
                if let transaction = transactionToExecute {
                    executeTransaction(transaction)
                }
            }
            Button("Cancel", role: .cancel) {
                transactionToExecute = nil
            }
        } message: {
            Text("This will create an actual transaction and update your balances.")
        }
        .confirmationDialog(
            "Delete scheduled transaction",
            isPresented: Binding(
                get: { transactionToDelete != nil },
                set: { if !$0 { transactionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let transaction = transactionToDelete {
                    modelContext.delete(transaction)
                }
            }
            Button("Cancel", role: .cancel) {
                transactionToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this scheduled transaction?")
        }
        .id(settings.refreshID)
    }
    
    private func executeTransaction(_ template: Transaction) {
        // Create a new real transaction from the template
        let newTransaction = Transaction(
            date: Date(),
            descriptionText: template.descriptionText,
            reference: template.reference,
            isRecurring: false
        )
        
        modelContext.insert(newTransaction)
        
        // Copy entries
        for entry in template.entries ?? [] {
            let newEntry = Entry(
                entryType: entry.entryType,
                amount: entry.amount,
                account: entry.account
            )
            modelContext.insert(newEntry)
            newEntry.transaction = newTransaction
        }
        
        // Update next occurrence
        if let rule = template.recurrenceRule {
            rule.nextOccurrence = rule.calculateNextOccurrence(from: Date())
        }
        
        transactionToExecute = nil
    }
}

struct ScheduledTransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            transactionIcon
                .font(.title2)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(transaction.descriptionText.isEmpty ? transactionSummary : transaction.descriptionText)
                        .font(.headline)
                    
                    RecurringIcon()
                }
                
                HStack(spacing: 8) {
                    if let rule = transaction.recurrenceRule {
                        Text(rule.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let nextDate = transaction.recurrenceRule?.nextOccurrence {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Next: \(nextDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                
                Text(accountsSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(formatAmount(transaction.amount))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
    
    private var transactionIcon: some View {
        let entries = transaction.entries ?? []
        let hasExpense = entries.contains { $0.account?.accountClass == .expense }
        let hasIncome = entries.contains { $0.account?.accountClass == .income }
        
        let iconName: String
        let color: Color
        
        if hasExpense {
            iconName = entries.first { $0.account?.accountClass == .expense }?.account?.accountType.iconName ?? "arrow.up.circle.fill"
            color = .red
        } else if hasIncome {
            iconName = entries.first { $0.account?.accountClass == .income }?.account?.accountType.iconName ?? "arrow.down.circle.fill"
            color = .green
        } else {
            iconName = "arrow.left.arrow.right.circle.fill"
            color = .blue
        }
        
        return Image(systemName: iconName)
            .foregroundColor(color)
    }
    
    private var transactionSummary: String {
        let entries = transaction.entries ?? []
        let expenseAccount = entries.first { $0.account?.accountClass == .expense }?.account
        let incomeAccount = entries.first { $0.account?.accountClass == .income }?.account
        
        if let expense = expenseAccount {
            return expense.name
        } else if let income = incomeAccount {
            return income.name
        } else {
            return String(localized: "Transfer")
        }
    }
    
    private var accountsSummary: String {
        let entries = transaction.entries ?? []
        let debitAccount = entries.first { $0.entryType == .debit }?.account
        let creditAccount = entries.first { $0.entryType == .credit }?.account
        
        if let debit = debitAccount, let credit = creditAccount {
            return "\(credit.name) → \(debit.name)"
        }
        return ""
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

// MARK: - Add Scheduled Transaction View

struct AddScheduledTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    
    @State private var transactionType: SimpleTransactionType = .expense
    @State private var descriptionText: String = ""
    @State private var amountText: String = ""
    
    // Recurrence settings
    @State private var recurrenceFrequency: RecurrenceFrequency = .monthly
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceDayOfMonth: Int = 1
    @State private var recurrenceDayOfWeek: Int = 2
    @State private var recurrenceWeekendAdjustment: WeekendAdjustment = .none
    @State private var recurrenceStartDate: Date = Date()
    @State private var recurrenceEndDate: Date? = nil
    
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
                Section("Transaction type") {
                    Picker("Type", selection: $transactionType) {
                        ForEach(SimpleTransactionType.allCases) { type in
                            Label(type.localizedName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Recurrence") {
                    RecurrenceConfigView(
                        isRecurring: .constant(true),
                        frequency: $recurrenceFrequency,
                        interval: $recurrenceInterval,
                        dayOfMonth: $recurrenceDayOfMonth,
                        dayOfWeek: $recurrenceDayOfWeek,
                        weekendAdjustment: $recurrenceWeekendAdjustment,
                        endDate: $recurrenceEndDate,
                        showToggle: false
                    )
                    
                    DatePicker("Start date", selection: $recurrenceStartDate, displayedComponents: .date)
                }
                
                Section("Details") {
                    HStack {
                        Text(CurrencyList.symbol(forCode: currentCurrency))
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                    }
                }
                
                accountsSection
                
                Section("Description") {
                    TextField("Description", text: $descriptionText)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New scheduled transaction")
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
    
    @ViewBuilder
    private var accountsSection: some View {
        Section("Accounts") {
            switch transactionType {
            case .expense:
                AccountPicker(title: "Expense category", accounts: expenseAccounts, selection: $selectedExpenseAccount)
                AccountPicker(title: "Pay from", accounts: assetAndLiabilityAccounts, selection: $selectedPaymentAccount)
            case .income:
                AccountPicker(title: "Income category", accounts: incomeAccounts, selection: $selectedIncomeAccount)
                AccountPicker(title: "Deposit to", accounts: assetAndLiabilityAccounts, selection: $selectedDepositAccount)
            case .transfer:
                AccountPicker(title: "From account", accounts: assetAndLiabilityAccounts, selection: $selectedFromAccount)
                AccountPicker(title: "To account", accounts: assetAndLiabilityAccounts.filter { $0.id != selectedFromAccount?.id }, selection: $selectedToAccount)
            }
        }
    }
    
    private func saveTransaction() {
        guard amount > 0 else {
            validationMessage = "Please enter a valid positive amount."
            showingValidationError = true
            return
        }
        
        let description = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create template transaction
        let transaction = Transaction(
            date: recurrenceStartDate,
            descriptionText: description,
            reference: "",
            isRecurring: true
        )
        
        modelContext.insert(transaction)
        
        // Create entries based on type
        switch transactionType {
        case .expense:
            guard let expenseAccount = selectedExpenseAccount, let paymentAccount = selectedPaymentAccount else { return }
            let debitEntry = Entry(entryType: .debit, amount: amount, account: expenseAccount)
            let creditEntry = Entry(entryType: .credit, amount: amount, account: paymentAccount)
            modelContext.insert(debitEntry)
            modelContext.insert(creditEntry)
            debitEntry.transaction = transaction
            creditEntry.transaction = transaction
            if description.isEmpty {
                transaction.descriptionText = expenseAccount.name
            }
            
        case .income:
            guard let depositAccount = selectedDepositAccount, let incomeAccount = selectedIncomeAccount else { return }
            let debitEntry = Entry(entryType: .debit, amount: amount, account: depositAccount)
            let creditEntry = Entry(entryType: .credit, amount: amount, account: incomeAccount)
            modelContext.insert(debitEntry)
            modelContext.insert(creditEntry)
            debitEntry.transaction = transaction
            creditEntry.transaction = transaction
            if description.isEmpty {
                transaction.descriptionText = incomeAccount.name
            }
            
        case .transfer:
            guard let fromAccount = selectedFromAccount, let toAccount = selectedToAccount else { return }
            let debitEntry = Entry(entryType: .debit, amount: amount, account: toAccount)
            let creditEntry = Entry(entryType: .credit, amount: amount, account: fromAccount)
            modelContext.insert(debitEntry)
            modelContext.insert(creditEntry)
            debitEntry.transaction = transaction
            creditEntry.transaction = transaction
            if description.isEmpty {
                transaction.descriptionText = String(localized: "Transfer")
            }
        }
        
        // Create recurrence rule
        let rule = RecurrenceRule(
            frequency: recurrenceFrequency,
            interval: recurrenceInterval,
            dayOfMonth: recurrenceDayOfMonth,
            dayOfWeek: recurrenceDayOfWeek,
            weekendAdjustment: recurrenceWeekendAdjustment,
            startDate: recurrenceStartDate,
            endDate: recurrenceEndDate
        )
        rule.nextOccurrence = rule.calculateNextOccurrence(from: recurrenceStartDate, includeDate: true)
        rule.transaction = transaction
        modelContext.insert(rule)
        
        dismiss()
    }
}

// MARK: - Edit Scheduled Transaction View

struct EditScheduledTransactionView: View {
    @Bindable var transaction: Transaction
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var descriptionText: String = ""
    @State private var amountText: String = ""
    @State private var recurrenceFrequency: RecurrenceFrequency = .monthly
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceDayOfMonth: Int = 1
    @State private var recurrenceDayOfWeek: Int = 2
    @State private var recurrenceWeekendAdjustment: WeekendAdjustment = .none
    @State private var recurrenceStartDate: Date = Date()
    @State private var recurrenceEndDate: Date? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Description", text: $descriptionText)
                    TextField("Amount", text: $amountText)
                }
                
                Section("Recurrence") {
                    RecurrenceConfigView(
                        isRecurring: .constant(true),
                        frequency: $recurrenceFrequency,
                        interval: $recurrenceInterval,
                        dayOfMonth: $recurrenceDayOfMonth,
                        dayOfWeek: $recurrenceDayOfWeek,
                        weekendAdjustment: $recurrenceWeekendAdjustment,
                        endDate: $recurrenceEndDate,
                        showToggle: false
                    )
                    
                    DatePicker("Start date", selection: $recurrenceStartDate, displayedComponents: .date)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit scheduled transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                }
            }
            .onAppear { loadTransaction() }
            .id(settings.refreshID)
        }
        .frame(minWidth: 400, minHeight: 400)
    }
    
    private func loadTransaction() {
        descriptionText = transaction.descriptionText
        amountText = CurrencyFormatter.format(transaction.amount)
        
        if let rule = transaction.recurrenceRule {
            recurrenceFrequency = rule.frequency
            recurrenceInterval = rule.interval
            recurrenceDayOfMonth = rule.dayOfMonth ?? 1
            recurrenceDayOfWeek = rule.dayOfWeek ?? 2
            recurrenceWeekendAdjustment = rule.weekendAdjustment
            recurrenceStartDate = rule.startDate
            recurrenceEndDate = rule.endDate
        }
    }
    
    private func saveChanges() {
        transaction.descriptionText = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newAmount = CurrencyFormatter.parse(amountText)
        if newAmount > 0 {
            for entry in transaction.entries ?? [] {
                entry.amount = newAmount
            }
        }
        
        if let rule = transaction.recurrenceRule {
            rule.frequency = recurrenceFrequency
            rule.interval = recurrenceInterval
            rule.dayOfMonth = recurrenceDayOfMonth
            rule.dayOfWeek = recurrenceDayOfWeek
            rule.weekendAdjustment = recurrenceWeekendAdjustment
            rule.startDate = recurrenceStartDate
            rule.endDate = recurrenceEndDate
            rule.nextOccurrence = rule.calculateNextOccurrence(from: recurrenceStartDate, includeDate: true)
        }
        
        dismiss()
    }
}

#Preview {
    ScheduledTransactionsView()
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
        .environment(AppSettings.shared)
}
