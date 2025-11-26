//
//  TransactionListView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showingAddTransaction = false
    @State private var transactionToEdit: Transaction?
    @State private var transactionToDelete: Transaction?
    
    var account: Account?
    
    private var filteredTransactions: [Transaction] {
        if let account {
            return transactions.filter { transaction in
                (transaction.entries ?? []).contains { $0.account?.id == account.id }
            }
        }
        return transactions
    }
    
    private var groupedTransactions: [(String, [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            transaction.date.formatted(date: .long, time: .omitted)
        }
        return grouped.sorted { $0.value.first?.date ?? Date() > $1.value.first?.date ?? Date() }
    }
    
    var body: some View {
        Group {
            if filteredTransactions.isEmpty {
                VStack {
                    ContentUnavailableView {
                        Label("No Transactions", systemImage: "arrow.left.arrow.right")
                    } description: {
                        Text("Add your first transaction to track your finances.")
                    } actions: {
                        Button("Add Transaction") {
                            showingAddTransaction = true
                        }
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
        .navigationTitle(account?.name ?? String(localized: "All Transactions"))
        .toolbar {
            if account == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddTransaction = true }) {
                        Label("Add Transaction", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(preselectedAccount: account)
        }
        .sheet(item: $transactionToEdit) { transaction in
            EditTransactionView(transaction: transaction)
        }
        .confirmationDialog(
            "Delete Transaction",
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

struct TransactionRowView: View {
    let transaction: Transaction
    var highlightAccount: Account? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            transactionIcon
                .font(.title2)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.descriptionText.isEmpty ? transactionSummary : transaction.descriptionText)
                    .font(.headline)
                
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
