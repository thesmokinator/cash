//
//  BudgetView.swift
//  Cash
//
//  Created by Michele Broggi on 28/11/25.
//

import SwiftUI
import SwiftData

// MARK: - Budget View

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Budget.startDate, order: .reverse) private var budgets: [Budget]
    
    @State private var showingCreateBudget = false
    @State private var budgetForEnvelope: Budget?
    @State private var budgetForTransfer: Budget?
    @State private var envelopeForEdit: Envelope?
    @State private var envelopeToDelete: Envelope?
    @State private var searchText: String = ""
    
    private var activeBudget: Budget? {
        budgets.first { $0.isCurrentPeriod && $0.isActive }
    }
    
    private var currency: String {
        // Safely get currency, avoiding access to potentially invalidated objects
        guard let budget = activeBudget,
              let envelopes = budget.envelopes,
              let envelope = envelopes.first,
              let category = envelope.category else {
            return "EUR"
        }
        return category.currency
    }
    
    private func filteredEnvelopes(from envelopes: [Envelope]) -> [Envelope] {
        let sorted = envelopes.sorted(by: { $0.sortOrder < $1.sortOrder })
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let budget = activeBudget {
                // Budget Header - sempre in alto
                BudgetHeaderView(
                    budget: budget,
                    currency: currency,
                    isPrivate: settings.privacyMode
                )
                
                Divider()
                
                // Filter bar with search and add button - mostra solo se ci sono envelopes
                if let envelopes = budget.envelopes, !envelopes.isEmpty {
                    TransactionFilterBar(
                        dateFilter: .constant(.thisMonth),
                        searchText: $searchText,
                        showDateFilter: false,
                        onAddTransaction: {
                            budgetForEnvelope = budget
                        }
                    )
                    .padding(.vertical, 8)
                }
                
                // Envelopes List
                if let envelopes = budget.envelopes, !envelopes.isEmpty {
                    let filtered = filteredEnvelopes(from: envelopes)
                    if filtered.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        List {
                            ForEach(filtered) { envelope in
                                EnvelopeRowView(
                                    envelope: envelope,
                                    currency: currency,
                                    isPrivate: settings.privacyMode
                                )
                                .listRowSeparator(.hidden)
                                .contextMenu {
                                    Button {
                                        envelopeForEdit = envelope
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive) {
                                        envelopeToDelete = envelope
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onDelete { indexSet in
                                let envelope = filtered[indexSet.first!]
                                envelopeToDelete = envelope
                            }
                        }
                        .listStyle(.inset)
                    }
                    
                    // Bottom toolbar for transfer
                    if envelopes.count >= 2 {
                        HStack {
                            Spacer()
                            Button {
                                budgetForTransfer = budget
                            } label: {
                                Label("Transfer", systemImage: "arrow.left.arrow.right")
                            }
                        }
                        .padding()
                        .background(.bar)
                    }
                } else {
                    VStack {
                        Spacer()
                        ContentUnavailableView {
                            Label("No envelopes", systemImage: "envelope")
                        } description: {
                            Text("Add envelopes to start budgeting")
                        } actions: {
                            Button {
                                budgetForEnvelope = budget
                            } label: {
                                Text("Add Envelope")
                            }
                        }
                        Spacer()
                    }
                }
                
            } else {
                // No active budget
                ContentUnavailableView {
                    Label("No active budget", systemImage: "envelope.badge.shield.half.filled")
                } description: {
                    Text("Create a budget to start tracking your spending by category")
                } actions: {
                    Button {
                        showingCreateBudget = true
                    } label: {
                        Text("Create Budget")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Budget")
        .toolbar {
            if activeBudget != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingCreateBudget = true
                        } label: {
                            Label("New Budget", systemImage: "plus")
                        }
                        
                        if !budgets.isEmpty {
                            Divider()
                            
                            Menu("Previous Budgets") {
                                ForEach(budgets.prefix(5)) { budget in
                                    Button {
                                        // View historical budget
                                    } label: {
                                        Text(budget.displayName)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateBudget) {
            CreateBudgetView()
        }
        .sheet(item: $budgetForEnvelope) { budget in
            AddEnvelopeView(budget: budget)
        }
        .sheet(item: $budgetForTransfer) { budget in
            TransferBetweenEnvelopesView(budget: budget)
        }
        .sheet(item: $envelopeForEdit) { envelope in
            EditEnvelopeView(envelope: envelope)
        }
        .alert("Delete Envelope", isPresented: .init(
            get: { envelopeToDelete != nil },
            set: { if !$0 { envelopeToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                envelopeToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let envelope = envelopeToDelete {
                    modelContext.delete(envelope)
                    envelopeToDelete = nil
                }
            }
        } message: {
            if let envelope = envelopeToDelete {
                Text("Are you sure you want to delete \"\(envelope.displayName)\"?")
            }
        }
    }
}

// MARK: - Budget Header View

struct BudgetHeaderView: View {
    let budget: Budget
    let currency: String
    let isPrivate: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Period info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(budget.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(periodDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Period type badge
                HStack(spacing: 4) {
                    Image(systemName: budget.periodType.iconName)
                    Text(budget.periodType.localizedName)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(Capsule())
            }
            
            // Progress bar
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Rectangle()
                            .fill(progressColor.gradient)
                            .frame(width: min(geometry.size.width * CGFloat(budget.percentageUsed / 100), geometry.size.width), height: 12)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .frame(height: 12)
                
                HStack {
                    PrivacyAmountView(
                        amount: "\(String(localized: "Spent")): \(CurrencyFormatter.format(budget.totalSpent, currency: currency))",
                        isPrivate: isPrivate,
                        font: .caption,
                        fontWeight: .medium,
                        color: .secondary
                    )
                    
                    Spacer()
                    
                    PrivacyAmountView(
                        amount: "\(String(localized: "Budget")): \(CurrencyFormatter.format(budget.totalBudgeted, currency: currency))",
                        isPrivate: isPrivate,
                        font: .caption,
                        fontWeight: .medium,
                        color: .secondary
                    )
                }
            }
            
            // Summary cards
            HStack(spacing: 12) {
                BudgetSummaryCard(
                    title: String(localized: "Available"),
                    amount: budget.totalAvailable,
                    currency: currency,
                    color: budget.totalAvailable >= 0 ? .green : .red,
                    isPrivate: isPrivate
                )
                
                BudgetSummaryCard(
                    title: String(localized: "Used"),
                    amount: nil,
                    percentage: budget.percentageUsed,
                    currency: currency,
                    color: progressColor,
                    isPrivate: isPrivate
                )
            }
        }
        .padding()
        .background(.bar)
    }
    
    private var periodDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: budget.startDate)) - \(formatter.string(from: budget.endDate))"
    }
    
    private var progressColor: Color {
        let percentage = budget.percentageUsed
        if percentage >= 100 {
            return .red
        } else if percentage >= 80 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Budget Summary Card

struct BudgetSummaryCard: View {
    let title: String
    var amount: Decimal? = nil
    var percentage: Double? = nil
    let currency: String
    let color: Color
    let isPrivate: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let amount = amount {
                PrivacyAmountView(
                    amount: CurrencyFormatter.format(amount, currency: currency),
                    isPrivate: isPrivate,
                    font: .title3,
                    fontWeight: .semibold,
                    color: color
                )
            } else if let percentage = percentage {
                Text(String(format: "%.0f%%", percentage))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .privacyBlur(isPrivate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Envelope Row View

struct EnvelopeRowView: View {
    let envelope: Envelope
    let currency: String
    let isPrivate: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: envelope.iconName)
                    .foregroundStyle(statusColor)
                    .frame(width: 24)
                
                // Name and progress
                VStack(alignment: .leading, spacing: 4) {
                    Text(envelope.displayName)
                        .font(.body)
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                            
                            Rectangle()
                                .fill(statusColor.gradient)
                                .frame(width: geometry.size.width * CGFloat(min(envelope.percentageUsed, 100) / 100), height: 6)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    .frame(height: 6)
                }
                
                Spacer()
                
                // Amounts
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(CurrencyFormatter.format(envelope.spentAmount, currency: currency))
                            .privacyBlur(isPrivate)
                        Text("/")
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(envelope.effectiveBudget, currency: currency))
                            .privacyBlur(isPrivate)
                    }
                    .font(.callout)
                    
                    HStack(spacing: 4) {
                        Text(String(localized: "Available:"))
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(envelope.availableAmount, currency: currency))
                            .foregroundStyle(envelope.availableAmount >= 0 ? .green : .red)
                            .privacyBlur(isPrivate)
                    }
                    .font(.caption)
                }
                
                // Warning indicator
                if envelope.isOverBudget {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            
            // Rollover indicator
            if envelope.rolloverAmount > 0 {
                HStack {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.caption2)
                    Text("Includes \(CurrencyFormatter.format(envelope.rolloverAmount, currency: currency)) rollover")
                        .font(.caption2)
                        .privacyBlur(isPrivate)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 36)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var statusColor: Color {
        switch envelope.statusColor {
        case .healthy:
            return .green
        case .warning:
            return .orange
        case .exceeded:
            return .red
        }
    }
}

// MARK: - Create Budget View

struct CreateBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var periodType: BudgetPeriodType = .monthly
    @State private var rolloverEnabled = false
    @State private var startDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Period Type", selection: $periodType) {
                        ForEach(BudgetPeriodType.allCases) { type in
                            Label(type.localizedName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                } header: {
                    Text("Budget Period")
                } footer: {
                    Text("End Date: \(formattedEndDate)")
                }
                
                Section {
                    Toggle("Enable Rollover", isOn: $rolloverEnabled)
                } header: {
                    Text("Options")
                } footer: {
                    Text("When enabled, unused budget from envelopes will carry over to the next period.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createBudget()
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private var formattedEndDate: String {
        let endDate = Budget.calculateEndDate(from: startDate, periodType: periodType)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: endDate)
    }
    
    private func createBudget() {
        let budget = Budget(
            startDate: startDate,
            periodType: periodType,
            rolloverEnabled: rolloverEnabled
        )
        modelContext.insert(budget)
    }
}

// MARK: - Add Envelope View

struct AddEnvelopeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var allAccounts: [Account]
    
    let budget: Budget
    
    @State private var selectedCategory: Account?
    @State private var customName = ""
    @State private var budgetedAmount: Decimal = 0
    @State private var amountString = ""
    
    private var budgetableCategories: [Account] {
        allAccounts.filter { 
            $0.accountClass == .expense && 
            $0.isActive && 
            !$0.isSystem && 
            $0.includedInBudget 
        }
    }
    
    private var existingCategoryIds: Set<UUID> {
        Set((budget.envelopes ?? []).compactMap { $0.category?.id })
    }
    
    private var availableCategories: [Account] {
        budgetableCategories.filter { !existingCategoryIds.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if availableCategories.isEmpty {
                        Text("No categories available. Enable 'Include in Budget' for expense categories in account settings.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Category", selection: $selectedCategory) {
                            Text("Select a category").tag(nil as Account?)
                            ForEach(availableCategories) { category in
                                Label(category.displayName, systemImage: category.accountType.iconName)
                                    .tag(category as Account?)
                            }
                        }
                    }
                    
                    TextField("Custom Name (optional)", text: $customName)
                } header: {
                    Text("Category")
                }
                
                Section {
                    TextField("Amount", text: $amountString)
                        .onChange(of: amountString) { _, newValue in
                            if let decimal = Decimal(string: newValue.replacingOccurrences(of: ",", with: ".")) {
                                budgetedAmount = decimal
                            }
                        }
                } header: {
                    Text("Budgeted Amount")
                }
                
                if let category = selectedCategory {
                    Section {
                        let avgSpending = calculateAverageSpending(for: category)
                        HStack {
                            Text("Avg. last 3 months:")
                            Spacer()
                            Text(CurrencyFormatter.format(avgSpending, currency: category.currency))
                                .foregroundStyle(.secondary)
                        }
                        
                        Button("Use Average") {
                            budgetedAmount = avgSpending
                            amountString = "\(avgSpending)"
                        }
                        .disabled(avgSpending == 0)
                    } header: {
                        Text("Suggestion")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Envelope")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addEnvelope()
                        dismiss()
                    }
                    .disabled(selectedCategory == nil || budgetedAmount <= 0)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 350)
    }
    
    private func calculateAverageSpending(for category: Account) -> Decimal {
        let calendar = Calendar.current
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        
        let entries = category.entries ?? []
        var total: Decimal = 0
        
        for entry in entries {
            guard let transaction = entry.transaction,
                  !transaction.isRecurring,
                  transaction.date >= threeMonthsAgo else {
                continue
            }
            
            if entry.entryType == .debit {
                total += entry.amount
            } else {
                total -= entry.amount
            }
        }
        
        // Divide by 3 for monthly average
        return max(total / 3, 0)
    }
    
    private func addEnvelope() {
        let envelope = Envelope(
            name: customName,
            budgetedAmount: budgetedAmount,
            category: selectedCategory,
            sortOrder: (budget.envelopes?.count ?? 0)
        )
        envelope.budget = budget
        modelContext.insert(envelope)
    }
}

// MARK: - Edit Envelope View

struct EditEnvelopeView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var envelope: Envelope
    
    @State private var customName: String = ""
    @State private var budgetedAmount: Decimal = 0
    @State private var amountString: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let category = envelope.category {
                        HStack {
                            Label(category.displayName, systemImage: category.accountType.iconName)
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                    }
                    
                    TextField("Custom Name (optional)", text: $customName)
                } header: {
                    Text("Category")
                }
                
                Section {
                    TextField("Amount", text: $amountString)
                        .onChange(of: amountString) { _, newValue in
                            if let decimal = Decimal(string: newValue.replacingOccurrences(of: ",", with: ".")) {
                                budgetedAmount = decimal
                            }
                        }
                } header: {
                    Text("Budgeted Amount")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Envelope")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(budgetedAmount <= 0)
                }
            }
            .onAppear {
                customName = envelope.name
                budgetedAmount = envelope.budgetedAmount
                amountString = "\(envelope.budgetedAmount)"
            }
        }
        .frame(minWidth: 400, minHeight: 250)
    }
    
    private func saveChanges() {
        envelope.name = customName
        envelope.budgetedAmount = budgetedAmount
    }
}

// MARK: - Transfer Between Envelopes View

struct TransferBetweenEnvelopesView: View {
    @Environment(\.dismiss) private var dismiss
    
    let budget: Budget
    
    @State private var fromEnvelope: Envelope?
    @State private var toEnvelope: Envelope?
    @State private var amount: Decimal = 0
    @State private var amountString = ""
    
    private var envelopes: [Envelope] {
        (budget.envelopes ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
    }
    
    private var isValid: Bool {
        guard let from = fromEnvelope,
              let to = toEnvelope,
              from.id != to.id,
              amount > 0,
              from.availableAmount >= amount else {
            return false
        }
        return true
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("From", selection: $fromEnvelope) {
                        Text("Select envelope").tag(nil as Envelope?)
                        ForEach(envelopes) { envelope in
                            Text(envelope.displayName)
                                .tag(envelope as Envelope?)
                        }
                    }
                    
                    Picker("To", selection: $toEnvelope) {
                        Text("Select envelope").tag(nil as Envelope?)
                        ForEach(envelopes.filter { $0.id != fromEnvelope?.id }) { envelope in
                            Text(envelope.displayName)
                                .tag(envelope as Envelope?)
                        }
                    }
                } header: {
                    Text("Envelopes")
                }
                
                Section {
                    TextField("Amount", text: $amountString)
                        .onChange(of: amountString) { _, newValue in
                            if let decimal = Decimal(string: newValue.replacingOccurrences(of: ",", with: ".")) {
                                amount = decimal
                            }
                        }
                } header: {
                    Text("Amount")
                } footer: {
                    if let from = fromEnvelope {
                        Text("Available: \(CurrencyFormatter.format(from.availableAmount, currency: "EUR"))")
                    }
                }
                
                if !isValid && amount > 0 {
                    if let from = fromEnvelope, amount > from.availableAmount {
                        Section {
                            Label("Insufficient funds in source envelope", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Transfer Funds")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Transfer") {
                        executeTransfer()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func executeTransfer() {
        guard let from = fromEnvelope,
              let to = toEnvelope else { return }
        
        let transfer = EnvelopeTransfer(fromEnvelope: from, toEnvelope: to, amount: amount)
        transfer.execute()
    }
}

#Preview {
    BudgetView()
        .modelContainer(for: [Account.self, Transaction.self, Budget.self, Envelope.self], inMemory: true)
        .environment(AppSettings.shared)
}
