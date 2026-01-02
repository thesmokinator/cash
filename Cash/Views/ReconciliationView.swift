//
//  ReconciliationView.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import SwiftUI
import SwiftData

struct ReconciliationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    let account: Account
    
    @State private var statementDate: Date = Date()
    @State private var statementBalance: String = ""
    @State private var selectedTransactionIDs: Set<UUID> = []
    @State private var showingConfirmation = false
    @State private var isLoading = true
    @State private var unreconcicledTransactions: [Transaction] = []
    
    private var statementBalanceDecimal: Decimal? {
        Decimal(string: statementBalance.replacingOccurrences(of: ",", with: "."))
    }
    
    private var clearedBalance: Decimal {
        var total = account.lastReconciledBalance ?? Decimal.zero
        
        for transaction in unreconcicledTransactions {
            guard selectedTransactionIDs.contains(transaction.id) else { continue }
            
            for entry in transaction.entries ?? [] {
                guard entry.account?.id == account.id else { continue }
                
                if account.accountClass.normalBalance == .debit {
                    total += entry.entryType == .debit ? entry.amount : -entry.amount
                } else {
                    total += entry.entryType == .credit ? entry.amount : -entry.amount
                }
            }
        }
        
        return total
    }
    
    private var difference: Decimal {
        guard let target = statementBalanceDecimal else { return Decimal.zero }
        return target - clearedBalance
    }
    
    private var isBalanced: Bool {
        statementBalanceDecimal != nil && difference == Decimal.zero
    }
    
    var body: some View {
        Group {
            if DeviceType.current.isCompact {
                // Modern iPhone layout
                NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Statement info card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Statement Information")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Date")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    DatePicker("", selection: $statementDate, displayedComponents: .date)
                                        .labelsHidden()
                                }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Ending balance")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 8) {
                                        TextField("0.00", text: $statementBalance)
                                            #if os(iOS)
                                            .keyboardType(.decimalPad)
                                            #endif
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                        Text(account.currency)
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.platformWindowBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        
                        // Balance summary card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Balance Summary")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            VStack(spacing: 12) {
                                BalanceRow(
                                    label: "Last reconciled",
                                    amount: account.lastReconciledBalance ?? Decimal.zero,
                                    currency: account.currency
                                )
                                
                                Divider()
                                
                                BalanceRow(
                                    label: "Cleared balance",
                                    amount: clearedBalance,
                                    currency: account.currency
                                )
                                
                                Divider()
                                
                                BalanceRow(
                                    label: "Statement balance",
                                    amount: statementBalanceDecimal ?? Decimal.zero,
                                    currency: account.currency
                                )
                                
                                Divider()
                                
                                HStack {
                                    Text("Difference")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(CurrencyFormatter.format(difference, currency: account.currency))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(difference == Decimal.zero ? .green : .red)
                                }
                            }
                        }
                        .padding()
                        .background(Color.platformWindowBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        
                        // Transactions section
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else if unreconcicledTransactions.isEmpty {
                            ContentUnavailableView {
                                Label("No transactions to reconcile", systemImage: "checkmark.circle")
                            } description: {
                                Text("All transactions have been reconciled")
                            }
                            .padding()
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("\(unreconcicledTransactions.count) unreconciled transactions")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if !selectedTransactionIDs.isEmpty {
                                        Button("Clear") {
                                            selectedTransactionIDs.removeAll()
                                        }
                                        .font(.subheadline)
                                    }
                                    Button(selectedTransactionIDs.count == unreconcicledTransactions.count ? "Deselect all" : "Select all") {
                                        if selectedTransactionIDs.count == unreconcicledTransactions.count {
                                            selectedTransactionIDs.removeAll()
                                        } else {
                                            selectedTransactionIDs = Set(unreconcicledTransactions.map { $0.id })
                                        }
                                    }
                                    .font(.subheadline)
                                }
                                
                                ForEach(unreconcicledTransactions) { transaction in
                                    ReconciliationTransactionRow(
                                        transaction: transaction,
                                        account: account,
                                        isSelected: selectedTransactionIDs.contains(transaction.id)
                                    ) {
                                        if selectedTransactionIDs.contains(transaction.id) {
                                            selectedTransactionIDs.remove(transaction.id)
                                        } else {
                                            selectedTransactionIDs.insert(transaction.id)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .background(Color.platformSecondaryBackground)
                .navigationTitle("Reconcile")
                .navigationBarTitleDisplayModeInline()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Reconcile") {
                            showingConfirmation = true
                        }
                        .disabled(!isBalanced || selectedTransactionIDs.isEmpty)
                        .fontWeight(.semibold)
                    }
                }
            }
        } else {
            // iPad layout (keep existing)
            iphoneLegacyLayout
        }
        }
        .task {
            await loadTransactions()
        }
        .confirmationDialog(
            "Confirm reconciliation",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reconcile \(selectedTransactionIDs.count) transactions") {
                performReconciliation()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will mark \(selectedTransactionIDs.count) transactions as reconciled. Reconciled transactions should not be modified.")
        }
    }
    
    private func loadTransactions() async {
        isLoading = true
        
        // Small delay to allow UI to render
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        _ = account.id
        let allEntries = account.entries ?? []
        
        // Get all transactions that have entries in this account and are not reconciled
        var transactionSet = Set<UUID>()
        var transactions: [Transaction] = []
        
        for entry in allEntries {
            guard let transaction = entry.transaction,
                  !transaction.isRecurring,
                  transaction.reconciliationStatus != .reconciled,
                  transaction.date <= statementDate,
                  !transactionSet.contains(transaction.id) else {
                continue
            }
            transactionSet.insert(transaction.id)
            transactions.append(transaction)
        }
        
        // Sort by date
        transactions.sort { $0.date < $1.date }
        
        // Pre-select cleared transactions
        let clearedIDs = transactions
            .filter { $0.reconciliationStatus == .cleared }
            .map { $0.id }
        
        await MainActor.run {
            unreconcicledTransactions = transactions
            selectedTransactionIDs = Set(clearedIDs)
            isLoading = false
        }
    }
    
    private func performReconciliation() {
        let now = Date()
        
        for transaction in unreconcicledTransactions {
            if selectedTransactionIDs.contains(transaction.id) {
                transaction.reconciliationStatus = .reconciled
                transaction.reconciledDate = now
            }
        }
        
        // Update account reconciliation info
        account.lastReconciledBalance = statementBalanceDecimal
        account.lastReconciledDate = statementDate
        
        try? modelContext.save()
        
        dismiss()
    }
    
    // MARK: - Legacy Layout for iPad/macOS
    
    private var iphoneLegacyLayout: some View {
        VStack(spacing: 0) {
            // Header with statement info (existing layout)
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reconcile: \(account.displayName)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(1)
                        if let lastDate = account.lastReconciledDate {
                            Text("Last reconciled: \(lastDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Statement date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $statementDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Statement ending balance")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("0.00", text: $statementBalance)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 150)
                            Text(account.currency)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                // Balance summary
                HStack(spacing: 32) {
                    BalanceSummaryItem(
                        label: "Last reconciled",
                        amount: account.lastReconciledBalance ?? Decimal.zero,
                        currency: account.currency
                    )
                    
                    BalanceSummaryItem(
                        label: "Cleared balance",
                        amount: clearedBalance,
                        currency: account.currency
                    )
                    
                    BalanceSummaryItem(
                        label: "Statement balance",
                        amount: statementBalanceDecimal ?? Decimal.zero,
                        currency: account.currency
                    )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Difference")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(difference, currency: account.currency))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(isBalanced ? .green : .red)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(.regularMaterial)
            
            Divider()
            
            // Transaction list
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if unreconcicledTransactions.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("No transactions to reconcile", systemImage: "checkmark.circle")
                } description: {
                    Text("All transactions have been reconciled")
                }
                Spacer()
            } else {
                List {
                    ForEach(unreconcicledTransactions) { transaction in
                        ReconciliationTransactionRow(
                            transaction: transaction,
                            account: account,
                            isSelected: selectedTransactionIDs.contains(transaction.id)
                        ) {
                            if selectedTransactionIDs.contains(transaction.id) {
                                selectedTransactionIDs.remove(transaction.id)
                            } else {
                                selectedTransactionIDs.insert(transaction.id)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                
                HStack(spacing: 8) {
                    Text("\(selectedTransactionIDs.count) of \(unreconcicledTransactions.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if !selectedTransactionIDs.isEmpty {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        
                        Button("Select all") {
                            selectedTransactionIDs = Set(unreconcicledTransactions.map { $0.id })
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        
                        Text("•")
                            .foregroundStyle(.tertiary)
                        
                        Button("Clear selection") {
                            selectedTransactionIDs.removeAll()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                    }
                }
            }
            
            Divider()
            
            // Footer with action buttons
            HStack {
                if isBalanced {
                    Label("Balanced!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)
                } else if statementBalanceDecimal != nil {
                    Label("Difference: \(CurrencyFormatter.format(difference, currency: account.currency))", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.headline)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Reconcile") {
                    showingConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isBalanced || selectedTransactionIDs.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(.regularMaterial)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            await loadTransactions()
        }
        .confirmationDialog(
            "Confirm reconciliation",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reconcile \(selectedTransactionIDs.count) transactions") {
                performReconciliation()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will mark \(selectedTransactionIDs.count) transactions as reconciled. Reconciled transactions should not be modified.")
        }
    }
}

// MARK: - Supporting Views

// New component for iPhone layout
struct BalanceRow: View {
    let label: String
    let amount: Decimal
    let currency: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(CurrencyFormatter.format(amount, currency: currency))
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Supporting Views

struct BalanceSummaryItem: View {
    let label: String
    let amount: Decimal
    let currency: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(label))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(CurrencyFormatter.format(amount, currency: currency))
                .font(.headline)
                .fontWeight(.medium)
        }
    }
}

struct ReconciliationTransactionRow: View {
    let transaction: Transaction
    let account: Account
    let isSelected: Bool
    let onToggle: () -> Void
    
    private var entryForAccount: Entry? {
        (transaction.entries ?? []).first { $0.account?.id == account.id }
    }
    
    private var amountForAccount: Decimal {
        guard let entry = entryForAccount else { return Decimal.zero }
        
        if account.accountClass.normalBalance == .debit {
            return entry.entryType == .debit ? entry.amount : -entry.amount
        } else {
            return entry.entryType == .credit ? entry.amount : -entry.amount
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.descriptionText.isEmpty ? "Transaction" : transaction.descriptionText)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if !transaction.reference.isEmpty {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(transaction.reference)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    ReconciliationStatusBadge(status: transaction.reconciliationStatus)
                }
            }
            
            Spacer()
            
            Text(CurrencyFormatter.format(amountForAccount, currency: account.currency))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(amountForAccount >= 0 ? Color.primary : Color.red)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

struct ReconciliationStatusBadge: View {
    let status: ReconciliationStatus
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: status.iconName)
            Text(status.shortName)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        switch status {
        case .notReconciled:
            return .secondary.opacity(0.2)
        case .cleared:
            return .blue.opacity(0.2)
        case .reconciled:
            return .green.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch status {
        case .notReconciled:
            return .secondary
        case .cleared:
            return .blue
        case .reconciled:
            return .green
        }
    }
}

// MARK: - Compact Badge for Transaction List

struct ReconciliationStatusIcon: View {
    let status: ReconciliationStatus
    
    var body: some View {
        Image(systemName: status.iconName)
            .font(.caption)
            .foregroundStyle(iconColor)
            .help(status.localizedName)
    }
    
    private var iconColor: Color {
        switch status {
        case .notReconciled:
            return .secondary.opacity(0.5)
        case .cleared:
            return .blue
        case .reconciled:
            return .green
        }
    }
}

#Preview {
    ReconciliationView(account: Account(
        name: "Checking Account",
        accountNumber: "1010",
        currency: "EUR",
        accountClass: .asset,
        accountType: .bank
    ))
    .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
    .environment(AppSettings.shared)
}
