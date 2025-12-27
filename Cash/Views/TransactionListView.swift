//
//  TransactionListView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData

enum TransactionDateFilter: String, CaseIterable, Identifiable {
    case today = "today"
    case thisWeek = "thisWeek"
    case last15Days = "last15Days"
    case thisMonth = "thisMonth"
    case lastMonth = "lastMonth"
    case last3Months = "last3Months"
    case last6Months = "last6Months"
    case last12Months = "last12Months"
    
    var id: String { rawValue }
    
    var localizedName: LocalizedStringKey {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This week"
        case .last15Days: return "Last 15 days"
        case .thisMonth: return "This month"
        case .lastMonth: return "Last month"
        case .last3Months: return "Last 3 months"
        case .last6Months: return "Last 6 months"
        case .last12Months: return "Last 12 months"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        switch self {
        case .today:
            return (startOfToday, now)
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
            return (startOfWeek, now)
        case .last15Days:
            let start = calendar.date(byAdding: .day, value: -14, to: startOfToday) ?? startOfToday
            return (start, now)
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
            return (startOfMonth, now)
        case .lastMonth:
            let startOfThisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? startOfToday
            let endOfLastMonth = calendar.date(byAdding: .second, value: -1, to: startOfThisMonth) ?? startOfToday
            return (startOfLastMonth, endOfLastMonth)
        case .last3Months:
            let start = calendar.date(byAdding: .month, value: -3, to: startOfToday) ?? startOfToday
            return (start, now)
        case .last6Months:
            let start = calendar.date(byAdding: .month, value: -6, to: startOfToday) ?? startOfToday
            return (start, now)
        case .last12Months:
            let start = calendar.date(byAdding: .month, value: -12, to: startOfToday) ?? startOfToday
            return (start, now)
        }
    }
}

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    @Query(filter: #Predicate<Transaction> { $0.isRecurring == false }, sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showingAddTransaction = false
    @State private var showingAddInvestmentTransaction = false
    @State private var showingReconciliation = false
    @State private var transactionToEdit: Transaction?
    @State private var transactionToDelete: Transaction?
    @State private var dateFilter: TransactionDateFilter = .thisMonth
    @State private var searchText: String = ""
    @State private var isLoading = true
    @State private var displayedTransactions: [(String, [Transaction])] = []
    
    var account: Account?
    
    private var currency: String {
        account?.currency ?? CurrencyHelper.defaultCurrency(from: accounts)
    }
    
    private var canReconcile: Bool {
        guard let account = account else { return false }
        return (account.accountClass == .asset || account.accountClass == .liability) && account.accountType != .investment
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TransactionFilterBar(
                dateFilter: $dateFilter,
                searchText: $searchText,
                onAddTransaction: {
                    if account?.accountType == .investment {
                        showingAddInvestmentTransaction = true
                    } else {
                        showingAddTransaction = true
                    }
                },
                onReconcile: canReconcile ? { showingReconciliation = true } : nil,
                showReconcile: canReconcile
            )
            
            Group {
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
                            Label("No transactions", systemImage: "arrow.left.arrow.right")
                        } description: {
                            Text("No transactions found for the selected period")
                        }
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(displayedTransactions, id: \.0) { dateString, dayTransactions in
                            Section(dateString) {
                                ForEach(dayTransactions) { transaction in
                                    TransactionRowView(transaction: transaction, highlightAccount: account, currency: currency)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            transactionToEdit = transaction
                                        }
                                        .contextMenu {
                                            Button {
                                                transactionToEdit = transaction
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            
                                            // Reconciliation status menu
                                            if !transaction.isRecurring {
                                                Divider()
                                                
                                                Menu {
                                                    Button {
                                                        transaction.reconciliationStatus = .notReconciled
                                                        transaction.reconciledDate = nil
                                                    } label: {
                                                        Label("Not reconciled", systemImage: ReconciliationStatus.notReconciled.iconName)
                                                    }
                                                    
                                                    Button {
                                                        transaction.reconciliationStatus = .cleared
                                                        transaction.reconciledDate = nil
                                                    } label: {
                                                        Label("Cleared", systemImage: ReconciliationStatus.cleared.iconName)
                                                    }
                                                    
                                                    Button {
                                                        transaction.reconciliationStatus = .reconciled
                                                        transaction.reconciledDate = Date()
                                                    } label: {
                                                        Label("Reconciled", systemImage: ReconciliationStatus.reconciled.iconName)
                                                    }
                                                } label: {
                                                    Label("Reconciliation status", systemImage: "checkmark.shield")
                                                }
                                            }
                                            
                                            Divider()
                                            
                                            Button(role: .destructive) {
                                                transactionToDelete = transaction
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                                .onDelete { indexSet in
                                    deleteTransactions(from: dayTransactions, at: indexSet)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(account?.name ?? String(localized: "All transactions"))
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(preselectedAccount: account)
        }
        .sheet(isPresented: $showingAddInvestmentTransaction) {
            if let account = account {
                AddInvestmentTransactionView(preselectedInvestmentAccount: account)
            }
        }
        .sheet(isPresented: $showingReconciliation) {
            if let account = account {
                ReconciliationView(account: account)
            }
        }
        .sheet(item: $transactionToEdit) { transaction in
            EditTransactionView(transaction: transaction)
        }
        .confirmationDialog(
            "Delete transaction",
            isPresented: Binding(
                get: { transactionToDelete != nil },
                set: { if !$0 { transactionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let transaction = transactionToDelete {
                    deleteTransaction(transaction)
                }
            }
            Button("Cancel", role: .cancel) {
                transactionToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this transaction?")
        }
        .task {
            await loadTransactions()
        }
        .onChange(of: dateFilter) { _, _ in
            Task { await loadTransactions() }
        }
        .onChange(of: searchText) { _, _ in
            Task { await loadTransactions() }
        }
        .onChange(of: transactions) { _, _ in
            Task { await loadTransactions() }
        }
        .onChange(of: account) { _, _ in
            Task { await loadTransactions() }
        }
        .id(settings.refreshID)
    }
    
    private func loadTransactions() async {
        isLoading = true
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let allTxns = transactions
        let currentAccount = account
        let currentSearchText = searchText
        let currentDateFilter = dateFilter
        
        var result: [Transaction]
        
        if !currentSearchText.isEmpty {
            let range = TransactionDateFilter.last12Months.dateRange
            result = allTxns.filter { $0.date >= range.start && $0.date <= range.end }
            result = result.filter { $0.descriptionText.localizedCaseInsensitiveContains(currentSearchText) }
        } else {
            let range = currentDateFilter.dateRange
            result = allTxns.filter { $0.date >= range.start && $0.date <= range.end }
        }
        
        if let acc = currentAccount {
            result = result.filter { transaction in
                (transaction.entries ?? []).contains { $0.account?.id == acc.id }
            }
        }
        
        let grouped = Dictionary(grouping: result) { transaction in
            transaction.date.formatted(date: .long, time: .omitted)
        }
        let sortedGroups = grouped.sorted { $0.value.first?.date ?? Date() > $1.value.first?.date ?? Date() }
        
        await MainActor.run {
            displayedTransactions = sortedGroups
            isLoading = false
        }
    }
    
    private func deleteTransactions(from dayTransactions: [Transaction], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let transaction = dayTransactions[index]
                deleteTransaction(transaction)
            }
        }
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        // Collect affected account IDs before deletion
        let affectedAccountIDs = Set((transaction.entries ?? []).compactMap { $0.account?.id })
        
        withAnimation {
            modelContext.delete(transaction)
        }
        
        // Signal balance update for affected accounts
        if !affectedAccountIDs.isEmpty {
            BalanceUpdateSignal.send(for: affectedAccountIDs)
        }
    }
}

struct TransactionFilterBar: View {
    @Binding var dateFilter: TransactionDateFilter
    @Binding var searchText: String
    var showDateFilter: Bool = true
    var onAddTransaction: (() -> Void)?
    var onReconcile: (() -> Void)?
    var showReconcile: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.platformControlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            if showDateFilter {
                Picker("Period", selection: $dateFilter) {
                    ForEach(TransactionDateFilter.allCases) { filter in
                        Text(filter.localizedName).tag(filter)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            
            if let onAdd = onAddTransaction {
                Button(action: onAdd) {
                    Label("Add", systemImage: "plus")
                }
            }
            
            if showReconcile, let onReconcileAction = onReconcile {
                Button(action: onReconcileAction) {
                    Label("Reconcile", systemImage: "checkmark.shield")
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.platformWindowBackground)
    }
}

struct TransactionRowView: View {
    @Environment(AppSettings.self) private var settings
    let transaction: Transaction
    var highlightAccount: Account? = nil
    let currency: String
    
    var body: some View {
        HStack(spacing: 12) {
            TransactionIconView(transaction: transaction)
                .font(.title2)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(transaction.descriptionText.isEmpty ? TransactionHelper.summary(for: transaction) : transaction.descriptionText)
                        .font(.headline)
                    
                    if transaction.isRecurring {
                        RecurringIcon()
                    }
                    
                    // Reconciliation status icon
                    if !transaction.isRecurring {
                        ReconciliationStatusIcon(status: transaction.reconciliationStatus)
                    }
                }
                
                HStack(spacing: 4) {
                    Text(TransactionHelper.accountsSummary(for: transaction))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                PrivacyAmountView(
                    amount: CurrencyFormatter.format(transaction.amount, currency: currency),
                    isPrivate: settings.privacyMode,
                    font: .subheadline,
                    fontWeight: .semibold
                )
                
                if let highlight = highlightAccount {
                    if let entry = (transaction.entries ?? []).first(where: { $0.account?.id == highlight.id }) {
                        Text(entry.entryType.shortName)
                            .font(.caption2)
                            .foregroundStyle(entry.entryType == .debit ? .blue : .green)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        TransactionListView()
    }
    .modelContainer(for: Account.self, inMemory: true)
    .environment(AppSettings.shared)
}
