//
//  ExpenseByCategoryReportView.swift
//  Cash
//
//  Created by Michele Broggi on 28/11/25.
//

import SwiftUI
import SwiftData

// MARK: - Time Period

enum ReportPeriod: String, CaseIterable, Identifiable {
    case month = "month"
    case threeMonths = "threeMonths"
    case sixMonths = "sixMonths"
    case year = "year"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .month:
            return String(localized: "1 Month")
        case .threeMonths:
            return String(localized: "3 Months")
        case .sixMonths:
            return String(localized: "6 Months")
        case .year:
            return String(localized: "1 Year")
        }
    }
    
    var months: Int {
        switch self {
        case .month: return 1
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .year: return 12
        }
    }
    
    var startDate: Date {
        Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
    }
}

// MARK: - Sort Order

enum ExpenseSortOrder: String, CaseIterable, Identifiable {
    case alphabetical = "alphabetical"
    case highestFirst = "highestFirst"
    case lowestFirst = "lowestFirst"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .alphabetical:
            return String(localized: "Alphabetical")
        case .highestFirst:
            return String(localized: "Highest first")
        case .lowestFirst:
            return String(localized: "Lowest first")
        }
    }
    
    var iconName: String {
        switch self {
        case .alphabetical:
            return "textformat.abc"
        case .highestFirst:
            return "arrow.down.circle"
        case .lowestFirst:
            return "arrow.up.circle"
        }
    }
}

// MARK: - Category Expense Data

struct CategoryExpense: Identifiable {
    let id = UUID()
    let account: Account
    let total: Decimal
}

// MARK: - Expense by Category View

struct ExpenseByCategoryReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(filter: #Predicate<Account> { $0.accountClassRawValue == "expense" && $0.isActive == true && $0.isSystem == false })
    private var expenseAccounts: [Account]
    
    @State private var selectedPeriod: ReportPeriod = .month
    @State private var sortOrder: ExpenseSortOrder = .alphabetical
    
    private var categoryExpenses: [CategoryExpense] {
        let startDate = selectedPeriod.startDate
        let endDate = Date()
        
        var expenses: [CategoryExpense] = []
        
        for account in expenseAccounts {
            let entries = account.entries ?? []
            var total: Decimal = 0
            
            for entry in entries {
                guard let transaction = entry.transaction,
                      !transaction.isRecurring,
                      transaction.date >= startDate,
                      transaction.date <= endDate else {
                    continue
                }
                
                // For expenses: debits increase, credits decrease
                if entry.entryType == .debit {
                    total += entry.amount
                } else {
                    total -= entry.amount
                }
            }
            
            if total != 0 {
                expenses.append(CategoryExpense(account: account, total: total))
            }
        }
        
        // Sort based on selected order
        switch sortOrder {
        case .alphabetical:
            expenses.sort { $0.account.displayName.localizedCaseInsensitiveCompare($1.account.displayName) == .orderedAscending }
        case .highestFirst:
            expenses.sort { $0.total > $1.total }
        case .lowestFirst:
            expenses.sort { $0.total < $1.total }
        }
        
        return expenses
    }
    
    private var grandTotal: Decimal {
        categoryExpenses.reduce(Decimal.zero) { $0 + $1.total }
    }
    
    private var currency: String {
        expenseAccounts.first?.currency ?? "EUR"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            HStack {
                // Period picker
                Picker(selection: $selectedPeriod) {
                    ForEach(ReportPeriod.allCases) { period in
                        Text(period.localizedName).tag(period)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 400)
                
                Spacer()
                
                // Sort picker
                Menu {
                    ForEach(ExpenseSortOrder.allCases) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            Label(order.localizedName, systemImage: order.iconName)
                        }
                    }
                } label: {
                    Label(sortOrder.localizedName, systemImage: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 150)
            }
            .padding()
            .background(.bar)
            
            if categoryExpenses.isEmpty {
                ContentUnavailableView {
                    Label("No expenses", systemImage: "chart.bar.xaxis")
                } description: {
                    Text("No expenses recorded in this period")
                }
            } else {
                // Category list
                List {
                    ForEach(categoryExpenses) { expense in
                        CategoryExpenseRow(
                            expense: expense,
                            grandTotal: grandTotal,
                            currency: currency,
                            isPrivate: settings.privacyMode
                        )
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

// MARK: - Category Expense Row

struct CategoryExpenseRow: View {
    let expense: CategoryExpense
    let grandTotal: Decimal
    let currency: String
    let isPrivate: Bool
    
    private var percentage: Double {
        guard grandTotal > 0 else { return 0 }
        return Double(truncating: (expense.total / grandTotal * 100) as NSDecimalNumber)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: expense.account.accountType.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            // Category name
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.account.displayName)
                    .font(.body)
                
                // Percentage bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                        
                        Rectangle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 4)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
                .frame(height: 4)
            }
            
            Spacer()
            
            // Percentage
            Text(String(format: "%.1f%%", percentage))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            // Amount
            PrivacyAmountView(
                amount: CurrencyFormatter.format(expense.total, currency: currency),
                isPrivate: isPrivate,
                font: .body,
                fontWeight: .medium,
                color: .red
            )
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ExpenseByCategoryReportView()
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
        .environment(AppSettings.shared)
}
