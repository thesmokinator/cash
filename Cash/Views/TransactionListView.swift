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
    @Query(filter: #Predicate<Transaction> { $0.isRecurring == false }, sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showingAddTransaction = false
    @State private var transactionToEdit: Transaction?
    @State private var transactionToDelete: Transaction?
    @State private var dateFilter: TransactionDateFilter = .thisMonth
    @State private var searchText: String = ""
    
    var account: Account?
    
    private var filteredTransactions: [Transaction] {
        var result: [Transaction]
        
        // If searching, always use last 12 months
        if !searchText.isEmpty {
            let range = TransactionDateFilter.last12Months.dateRange
            result = transactions.filter { $0.date >= range.start && $0.date <= range.end }
            result = result.filter { $0.descriptionText.localizedCaseInsensitiveContains(searchText) }
        } else {
            let range = dateFilter.dateRange
            result = transactions.filter { $0.date >= range.start && $0.date <= range.end }
        }
        
        if let account {
            result = result.filter { transaction in
                (transaction.entries ?? []).contains { $0.account?.id == account.id }
            }
        }
        return result
    }
    
    private var groupedTransactions: [(String, [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            transaction.date.formatted(date: .long, time: .omitted)
        }
        return grouped.sorted { $0.value.first?.date ?? Date() > $1.value.first?.date ?? Date() }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TransactionFilterBar(
                dateFilter: $dateFilter,
                searchText: $searchText,
                onAddTransaction: { showingAddTransaction = true }
            )
            
            Group {
                if filteredTransactions.isEmpty {
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
                        ForEach(groupedTransactions, id: \.0) { dateString, dayTransactions in
                            Section(dateString) {
                                ForEach(dayTransactions) { transaction in
                                    TransactionRowView(transaction: transaction, highlightAccount: account)
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
        .id(settings.refreshID)
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
        withAnimation {
            modelContext.delete(transaction)
        }
    }
}

struct TransactionFilterBar: View {
    @Binding var dateFilter: TransactionDateFilter
    @Binding var searchText: String
    var showDateFilter: Bool = true
    var onAddTransaction: (() -> Void)?
    
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
            .background(Color(nsColor: .controlBackgroundColor))
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
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    var highlightAccount: Account? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            transactionIcon
                .font(.title2)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(transaction.descriptionText.isEmpty ? transactionSummary : transaction.descriptionText)
                        .font(.headline)
                    
                    if transaction.isRecurring {
                        RecurringIcon()
                    }
                }
                
                HStack(spacing: 4) {
                    Text(accountsSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatAmount(transaction.amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
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

#Preview {
    NavigationStack {
        TransactionListView()
    }
    .modelContainer(for: Account.self, inMemory: true)
    .environment(AppSettings.shared)
}
