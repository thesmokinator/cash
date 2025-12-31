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
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    @Query(filter: #Predicate<Transaction> { $0.isRecurring == true }, sort: \Transaction.date) private var scheduledTransactions: [Transaction]
    @State private var showingAddScheduled = false
    @State private var transactionToEdit: Transaction?
    @State private var transactionToDelete: Transaction?
    @State private var transactionToExecute: Transaction?
    @State private var searchText: String = ""
    @State private var dummyDateFilter: TransactionDateFilter = .thisMonth
    @State private var isLoading = true
    @State private var displayedTransactions: [Transaction] = []
    @State private var selectedDate: Date? = nil
    @State private var currentMonth: Date = Date()
    
    private var currency: String {
        CurrencyHelper.defaultCurrency(from: accounts)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar Section
            ScheduledCalendarView(
                scheduledTransactions: scheduledTransactions,
                selectedDate: $selectedDate,
                currentMonth: $currentMonth
            )
            .padding(.horizontal)
            .padding(.top, 8)
            .navigationTitle("Scheduled Transactions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddScheduled = true }) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            
            TransactionFilterBar(
                dateFilter: $dummyDateFilter,
                searchText: $searchText,
                showDateFilter: false
            )
            
            Divider()
                        
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                }
            } else if displayedTransactions.isEmpty {
                VStack {
                    ContentUnavailableView {
                        Label(emptyStateTitle, systemImage: emptyStateIcon)
                    } description: {
                        Text(emptyStateDescription)
                    }
                    Spacer()
                }
            } else {
                List {
                    if selectedDate != nil {
                        Button("Show all scheduled transactions") {
                            selectedDate = nil
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundStyle(.blue)
                        .listRowSeparator(.hidden)
                        .padding(.bottom, 8)
                    }
                    
                    ForEach(displayedTransactions) { transaction in
                        ScheduledTransactionRow(transaction: transaction, currency: currency)
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
        .task {
            await loadTransactions()
        }
        .onChange(of: searchText) { _, _ in
            Task { await loadTransactions() }
        }
        .onChange(of: scheduledTransactions) { _, _ in
            Task { await loadTransactions() }
        }
        .onChange(of: selectedDate) { _, _ in
            Task { await loadTransactions() }
        }
    }
    
    private var emptyStateTitle: String {
        if let date = selectedDate {
            return String(localized: "No transactions on \(date.formatted(date: .abbreviated, time: .omitted))")
        } else if scheduledTransactions.isEmpty {
            return String(localized: "No scheduled transactions")
        } else {
            return String(localized: "No results")
        }
    }
    
    private var emptyStateIcon: String {
        if selectedDate != nil {
            return "calendar"
        } else if scheduledTransactions.isEmpty {
            return "calendar.badge.clock"
        } else {
            return "magnifyingglass"
        }
    }
    
    private var emptyStateDescription: String {
        if selectedDate != nil {
            return String(localized: "No scheduled transactions are due on this date")
        } else if scheduledTransactions.isEmpty {
            return String(localized: "Add a recurring transaction to see it here")
        } else {
            return String(localized: "No transactions match your search")
        }
    }
    
    private func loadTransactions() async {
        isLoading = true
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let allTxns = scheduledTransactions
        let currentSearchText = searchText
        let filterDate = selectedDate
        
        var result: [Transaction]
        
        if let filterDate = filterDate {
            // Filter by selected date - check if transaction occurs on this date
            result = allTxns.filter { transaction in
                transactionOccursOnDate(transaction, date: filterDate)
            }
        } else if currentSearchText.isEmpty {
            result = allTxns
        } else {
            result = allTxns.filter { $0.descriptionText.localizedCaseInsensitiveContains(currentSearchText) }
        }
        
        // Also apply search filter if both date and search are set
        if filterDate != nil && !currentSearchText.isEmpty {
            result = result.filter { $0.descriptionText.localizedCaseInsensitiveContains(currentSearchText) }
        }
        
        await MainActor.run {
            displayedTransactions = result
            isLoading = false
        }
    }
    
    private func transactionOccursOnDate(_ transaction: Transaction, date: Date) -> Bool {
        guard let rule = transaction.recurrenceRule else { return false }
        
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        // Generate occurrences for the month and check if any match the target date
        let occurrences = generateOccurrences(for: rule, in: calendar.dateInterval(of: .month, for: date)!)
        
        return occurrences.contains { occurrence in
            calendar.isDate(occurrence, inSameDayAs: targetDay)
        }
    }
    
    private func generateOccurrences(for rule: RecurrenceRule, in interval: DateInterval) -> [Date] {
        var occurrences: [Date] = []
        var currentDate = rule.startDate
        let calendar = Calendar.current
        
        // Limit iterations for safety
        var iterations = 0
        let maxIterations = 366
        
        while currentDate <= interval.end && iterations < maxIterations {
            if let nextOccurrence = rule.calculateNextOccurrence(from: currentDate, includeDate: true) {
                if nextOccurrence >= interval.start && nextOccurrence <= interval.end {
                    occurrences.append(nextOccurrence)
                }
                
                if nextOccurrence > interval.end {
                    break
                }
                
                // Move to next occurrence (use nextOccurrence as base to handle weekend adjustments)
                switch rule.frequency {
                case .daily:
                    currentDate = calendar.date(byAdding: .day, value: rule.interval, to: nextOccurrence) ?? nextOccurrence
                case .weekly:
                    currentDate = calendar.date(byAdding: .weekOfYear, value: rule.interval, to: nextOccurrence) ?? nextOccurrence
                case .monthly:
                    currentDate = calendar.date(byAdding: .month, value: rule.interval, to: nextOccurrence) ?? nextOccurrence
                case .yearly:
                    currentDate = calendar.date(byAdding: .year, value: rule.interval, to: nextOccurrence) ?? nextOccurrence
                }
            } else {
                break
            }
            iterations += 1
        }
        
        return occurrences
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
        
        // Signal balance update for affected accounts
        let affectedAccountIDs = Set((newTransaction.entries ?? []).compactMap { $0.account?.id })
        BalanceUpdateSignal.send(for: affectedAccountIDs)
        
        transactionToExecute = nil
    }
}

// MARK: - Scheduled Calendar View

struct ScheduledCalendarView: View {
    let scheduledTransactions: [Transaction]
    @Binding var selectedDate: Date?
    @Binding var currentMonth: Date

    private let calendar = Calendar.current
    private let daysOfWeek = Calendar.current.shortWeekdaySymbols

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: currentMonth)!
    }

    private var daysInMonth: [Date] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!

        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }

    private var firstWeekdayOffset: Int {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let weekday = calendar.component(.weekday, from: startOfMonth)
        return weekday - 1
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }

    private var scheduledDates: Set<Date> {
        var dates = Set<Date>()

        for transaction in scheduledTransactions {
            guard let rule = transaction.recurrenceRule else { continue }

            // Generate occurrences for current month
            var currentDate = rule.startDate
            var iterations = 0
            let maxIterations = 366

            while currentDate <= monthInterval.end && iterations < maxIterations {
                if let nextOccurrence = rule.calculateNextOccurrence(from: currentDate, includeDate: true) {
                    if nextOccurrence >= monthInterval.start && nextOccurrence <= monthInterval.end {
                        dates.insert(calendar.startOfDay(for: nextOccurrence))
                    }

                    if nextOccurrence > monthInterval.end {
                        break
                    }

                    // Move to next occurrence
                    switch rule.frequency {
                    case .daily:
                        currentDate = calendar.date(byAdding: .day, value: rule.interval, to: nextOccurrence) ?? nextOccurrence
                    case .weekly:
                        currentDate = calendar.date(byAdding: .weekOfYear, value: rule.interval, to: nextOccurrence) ?? nextOccurrence
                    case .monthly:
                        currentDate = calendar.date(byAdding: .month, value: rule.interval, to: nextOccurrence) ?? nextOccurrence
                    case .yearly:
                        currentDate = calendar.date(byAdding: .year, value: rule.interval, to: nextOccurrence) ?? nextOccurrence
                    }
                } else {
                    break
                }
                iterations += 1
            }
        }

        return dates
    }

    var body: some View {
        VStack(spacing: CashSpacing.md) {
            // Month navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CashColors.primary)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .background(CashColors.primary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text(currentMonth.formatted(.dateTime.month(.wide)))
                        .font(CashTypography.title3)
                        .foregroundStyle(.primary)
                    Text(currentMonth.formatted(.dateTime.year()))
                        .font(CashTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: CashSpacing.sm) {
                    if !isCurrentMonth {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentMonth = Date()
                                selectedDate = nil
                            }
                        } label: {
                            Text("Today")
                                .font(CashTypography.caption)
                                .foregroundStyle(CashColors.primary)
                                .padding(.horizontal, CashSpacing.md)
                                .padding(.vertical, CashSpacing.xs)
                                .background(.ultraThinMaterial)
                                .background(CashColors.primary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CashColors.primary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .background(CashColors.primary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CashSpacing.sm)

            // Days of week header
            HStack(spacing: 2) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CashColors.primary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CashSpacing.sm)
                }
            }
            .background(.ultraThinMaterial)
            .background(CashColors.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: CashRadius.small))

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                // Empty cells for offset
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 40)
                }

                // Day cells
                ForEach(daysInMonth, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                        isToday: calendar.isDateInToday(date),
                        hasScheduled: scheduledDates.contains(calendar.startOfDay(for: date))
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedDate.map({ calendar.isDate($0, inSameDayAs: date) }) ?? false {
                                selectedDate = nil
                            } else {
                                selectedDate = date
                            }
                        }
                    }
                }
            }
        }
        .padding(CashSpacing.lg)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: CashRadius.large))
        .shadow(
            color: CashShadow.light.color,
            radius: CashShadow.light.radius,
            x: CashShadow.light.x,
            y: CashShadow.light.y
        )
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasScheduled: Bool
    let action: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday || isSelected ? .bold : .regular, design: .rounded))
                    .foregroundStyle(foregroundColor)

                // Indicator dot
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
                    .opacity(hasScheduled ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: CashRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CashRadius.small)
                    .stroke(borderColor, lineWidth: isToday && !isSelected ? 1.5 : 0)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var foregroundColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return CashColors.primary
        } else {
            return .primary
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return CashColors.primary
        } else {
            return Color.clear
        }
    }

    private var borderColor: Color {
        if isToday && !isSelected {
            return CashColors.primary
        }
        return .clear
    }

    private var dotColor: Color {
        if isSelected {
            return .white
        } else if hasScheduled {
            return CashColors.accent
        }
        return .clear
    }
}

struct ScheduledTransactionRow: View {
    @Environment(AppSettings.self) private var settings
    let transaction: Transaction
    let currency: String

    var body: some View {
        HStack(spacing: CashSpacing.md) {
            // Icon with glass background
            GlassIconCircle(
                icon: transactionIcon,
                color: transactionColor,
                size: 44
            )

            VStack(alignment: .leading, spacing: CashSpacing.xs) {
                HStack(spacing: CashSpacing.xs) {
                    Text(transaction.descriptionText.isEmpty ? TransactionHelper.summary(for: transaction) : transaction.descriptionText)
                        .font(CashTypography.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Image(systemName: "repeat")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CashColors.primary)
                        .padding(4)
                        .background(CashColors.primary.opacity(0.1))
                        .clipShape(Circle())
                }

                HStack(spacing: CashSpacing.sm) {
                    if let rule = transaction.recurrenceRule {
                        HStack(spacing: CashSpacing.xs) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 10))
                            Text(rule.localizedDescription)
                        }
                        .font(CashTypography.caption)
                        .foregroundStyle(.secondary)
                    }

                    if let nextDate = transaction.recurrenceRule?.nextOccurrence {
                        HStack(spacing: CashSpacing.xs) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .bold))
                            Text(nextDate.formatted(date: .abbreviated, time: .omitted))
                        }
                        .font(CashTypography.caption)
                        .foregroundStyle(CashColors.primary)
                        .padding(.horizontal, CashSpacing.sm)
                        .padding(.vertical, 2)
                        .background(CashColors.primary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                Text(TransactionHelper.accountsSummary(for: transaction))
                    .font(CashTypography.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            PrivacyAmountView(
                amount: CurrencyFormatter.format(transaction.amount, currency: currency),
                isPrivate: settings.privacyMode,
                font: CashTypography.amountSmall,
                fontWeight: .bold,
                color: .primary
            )
        }
        .padding(.vertical, CashSpacing.sm)
    }

    private var transactionIcon: String {
        // Determine icon based on transaction type
        if let entries = transaction.entries, !entries.isEmpty {
            let debitEntry = entries.first { $0.entryType == .debit }
            if let account = debitEntry?.account {
                return account.effectiveIconName
            }
        }
        return "arrow.left.arrow.right"
    }

    private var transactionColor: Color {
        // Determine color based on transaction type
        if let entries = transaction.entries, !entries.isEmpty {
            let debitEntry = entries.first { $0.entryType == .debit }
            if let account = debitEntry?.account {
                switch account.accountClass {
                case .expense: return CashColors.expense
                case .asset: return CashColors.transfer
                case .income: return CashColors.income
                default: return CashColors.primary
                }
            }
        }
        return CashColors.primary
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
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    
    @State private var descriptionText: String = ""
    @State private var amountText: String = ""
    @State private var recurrenceFrequency: RecurrenceFrequency = .monthly
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceDayOfMonth: Int = 1
    @State private var recurrenceDayOfWeek: Int = 2
    @State private var recurrenceWeekendAdjustment: WeekendAdjustment = .none
    @State private var recurrenceStartDate: Date = Date()
    @State private var recurrenceEndDate: Date? = nil
    
    private var currency: String {
        CurrencyHelper.defaultCurrency(from: accounts)
    }
    
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
        amountText = CurrencyFormatter.format(transaction.amount, currency: currency)
        
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
