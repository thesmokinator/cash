//
//  Account.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import Foundation
import SwiftData

// MARK: - Entry Type (Debit or Credit)

/// In double-entry bookkeeping, every entry is either a debit or credit
enum EntryType: String, Codable, CaseIterable, Identifiable {
    case debit = "debit"
    case credit = "credit"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .debit:
            return String(localized: "Debit")
        case .credit:
            return String(localized: "Credit")
        }
    }
    
    var shortName: String {
        switch self {
        case .debit:
            return String(localized: "Dr")
        case .credit:
            return String(localized: "Cr")
        }
    }
    
    var opposite: EntryType {
        self == .debit ? .credit : .debit
    }
}

// MARK: - Account Class (Double-Entry Bookkeeping)

/// The five fundamental account classes in double-entry bookkeeping.
/// These follow the accounting equation: Assets = Liabilities + Equity
/// with Income increasing Equity and Expenses decreasing Equity.
enum AccountClass: String, Codable, CaseIterable, Identifiable {
    case asset = "asset"
    case liability = "liability"
    case equity = "equity"
    case income = "income"
    case expense = "expense"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .asset:
            return String(localized: "Asset")
        case .liability:
            return String(localized: "Liability")
        case .equity:
            return String(localized: "Equity")
        case .income:
            return String(localized: "Income")
        case .expense:
            return String(localized: "Expense")
        }
    }
    
    var localizedPluralName: String {
        switch self {
        case .asset:
            return String(localized: "Assets")
        case .liability:
            return String(localized: "Liabilities")
        case .equity:
            return String(localized: "Equity")
        case .income:
            return String(localized: "Income")
        case .expense:
            return String(localized: "Expenses")
        }
    }
    
    var iconName: String {
        switch self {
        case .asset:
            return "building.columns.fill"
        case .liability:
            return "creditcard.fill"
        case .equity:
            return "chart.pie.fill"
        case .income:
            return "arrow.down.circle.fill"
        case .expense:
            return "arrow.up.circle.fill"
        }
    }
    
    /// In double-entry bookkeeping:
    /// - Assets and Expenses have normal DEBIT balances (debits increase, credits decrease)
    /// - Liabilities, Equity, and Income have normal CREDIT balances (credits increase, debits decrease)
    var normalBalance: EntryType {
        switch self {
        case .asset, .expense:
            return .debit
        case .liability, .equity, .income:
            return .credit
        }
    }
    
    /// Display order for the chart of accounts
    var displayOrder: Int {
        switch self {
        case .asset: return 0
        case .liability: return 1
        case .equity: return 2
        case .income: return 3
        case .expense: return 4
        }
    }
}

// MARK: - Account Type (Subtypes within each class)

/// Common account types for organizing accounts within each class
enum AccountType: String, Codable, CaseIterable, Identifiable {
    // Asset types
    case cash = "cash"
    case bank = "bank"
    case investment = "investment"
    case receivable = "receivable"
    case prepaidExpense = "prepaidExpense"
    
    // Liability types
    case creditCard = "creditCard"
    case loan = "loan"
    case payable = "payable"
    
    // Equity types
    case retainedEarnings = "retainedEarnings"
    case openingBalance = "openingBalance"
    
    // Income types
    case salary = "salary"
    case freelance = "freelance"
    case interestIncome = "interestIncome"
    case dividendIncome = "dividendIncome"
    case rentalIncome = "rentalIncome"
    case otherIncome = "otherIncome"
    
    // Expense types
    case food = "food"
    case transportation = "transportation"
    case utilities = "utilities"
    case housing = "housing"
    case healthcare = "healthcare"
    case entertainment = "entertainment"
    case shopping = "shopping"
    case education = "education"
    case travel = "travel"
    case insurance = "insurance"
    case personalCare = "personalCare"
    case subscriptions = "subscriptions"
    case otherExpense = "otherExpense"
    
    var id: String { rawValue }
    
    var localizedName: String {
        localizedName(bundle: .main)
    }
    
    func localizedName(bundle: Bundle) -> String {
        switch self {
        // Asset types
        case .cash: return String(localized: "Cash", bundle: bundle)
        case .bank: return String(localized: "Bank account", bundle: bundle)
        case .investment: return String(localized: "Investment", bundle: bundle)
        case .receivable: return String(localized: "Receivable", bundle: bundle)
        case .prepaidExpense: return String(localized: "Prepaid expense", bundle: bundle)
        // Liability types
        case .creditCard: return String(localized: "Credit card", bundle: bundle)
        case .loan: return String(localized: "Loan", bundle: bundle)
        case .payable: return String(localized: "Payable", bundle: bundle)
        // Equity types
        case .retainedEarnings: return String(localized: "Retained earnings", bundle: bundle)
        case .openingBalance: return String(localized: "Opening balance", bundle: bundle)
        // Income types
        case .salary: return String(localized: "Salary", bundle: bundle)
        case .freelance: return String(localized: "Freelance", bundle: bundle)
        case .interestIncome: return String(localized: "Interest income", bundle: bundle)
        case .dividendIncome: return String(localized: "Dividend income", bundle: bundle)
        case .rentalIncome: return String(localized: "Rental income", bundle: bundle)
        case .otherIncome: return String(localized: "Other income", bundle: bundle)
        // Expense types
        case .food: return String(localized: "Food & dining", bundle: bundle)
        case .transportation: return String(localized: "Transportation", bundle: bundle)
        case .utilities: return String(localized: "Utilities", bundle: bundle)
        case .housing: return String(localized: "Housing", bundle: bundle)
        case .healthcare: return String(localized: "Healthcare", bundle: bundle)
        case .entertainment: return String(localized: "Entertainment", bundle: bundle)
        case .shopping: return String(localized: "Shopping", bundle: bundle)
        case .education: return String(localized: "Education", bundle: bundle)
        case .travel: return String(localized: "Travel", bundle: bundle)
        case .insurance: return String(localized: "Insurance", bundle: bundle)
        case .personalCare: return String(localized: "Personal care", bundle: bundle)
        case .subscriptions: return String(localized: "Subscriptions", bundle: bundle)
        case .otherExpense: return String(localized: "Other expense", bundle: bundle)
        }
    }
    
    var iconName: String {
        switch self {
        // Asset types
        case .cash: return "banknote"
        case .bank: return "building.columns"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .receivable: return "arrow.down.doc"
        case .prepaidExpense: return "calendar.badge.clock"
        // Liability types
        case .creditCard: return "creditcard"
        case .loan: return "doc.text"
        case .payable: return "arrow.up.doc"
        // Equity types
        case .retainedEarnings: return "chart.pie"
        case .openingBalance: return "flag"
        // Income types
        case .salary: return "briefcase.fill"
        case .freelance: return "laptopcomputer"
        case .interestIncome: return "percent"
        case .dividendIncome: return "chart.bar.fill"
        case .rentalIncome: return "building.2.fill"
        case .otherIncome: return "ellipsis.circle.fill"
        // Expense types
        case .food: return "fork.knife"
        case .transportation: return "car.fill"
        case .utilities: return "bolt.fill"
        case .housing: return "house.fill"
        case .healthcare: return "cross.case.fill"
        case .entertainment: return "tv.fill"
        case .shopping: return "bag.fill"
        case .education: return "book.fill"
        case .travel: return "airplane"
        case .insurance: return "shield.fill"
        case .personalCare: return "person.fill"
        case .subscriptions: return "repeat"
        case .otherExpense: return "ellipsis.circle.fill"
        }
    }
    
    /// The account class this type belongs to
    var accountClass: AccountClass {
        switch self {
        case .cash, .bank, .investment, .receivable, .prepaidExpense:
            return .asset
        case .creditCard, .loan, .payable:
            return .liability
        case .retainedEarnings, .openingBalance:
            return .equity
        case .salary, .freelance, .interestIncome, .dividendIncome, .rentalIncome, .otherIncome:
            return .income
        case .food, .transportation, .utilities, .housing, .healthcare, .entertainment,
             .shopping, .education, .travel, .insurance, .personalCare, .subscriptions, .otherExpense:
            return .expense
        }
    }
    
    /// Get all account types for a specific class
    static func types(for accountClass: AccountClass) -> [AccountType] {
        allCases.filter { $0.accountClass == accountClass }
    }
}

// MARK: - Account Model

@Model
final class Account {
    var id: UUID
    var name: String
    var accountNumber: String
    var currency: String
    var accountClassRawValue: String
    var accountTypeRawValue: String
    var isActive: Bool
    var isSystem: Bool
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Entry.account)
    var entries: [Entry]? = []
    
    var accountClass: AccountClass {
        get { AccountClass(rawValue: accountClassRawValue) ?? .asset }
        set { accountClassRawValue = newValue.rawValue }
    }
    
    var accountType: AccountType {
        get { AccountType(rawValue: accountTypeRawValue) ?? .bank }
        set { accountTypeRawValue = newValue.rawValue }
    }
    
    /// Calculate the current balance based on all entries
    /// Following double-entry rules:
    /// - Assets/Expenses: Debits increase, Credits decrease
    /// - Liabilities/Equity/Income: Credits increase, Debits decrease
    /// Note: Recurring transactions (scheduled) are excluded from balance
    var balance: Decimal {
        let allEntries = entries ?? []
        var total: Decimal = 0
        
        for entry in allEntries {
            // Skip entries from recurring transactions (they are templates)
            if entry.transaction?.isRecurring == true {
                continue
            }
            
            if accountClass.normalBalance == .debit {
                // For assets and expenses: debits add, credits subtract
                total += entry.entryType == .debit ? entry.amount : -entry.amount
            } else {
                // For liabilities, equity, and income: credits add, debits subtract
                total += entry.entryType == .credit ? entry.amount : -entry.amount
            }
        }
        
        return total
    }
    
    /// Display-friendly balance with appropriate sign
    var displayBalance: Decimal {
        balance
    }
    
    /// Returns the display name - uses account name
    var displayName: String {
        name
    }
    
    init(
        name: String,
        accountNumber: String = "",
        currency: String = "EUR",
        accountClass: AccountClass,
        accountType: AccountType,
        isActive: Bool = true,
        isSystem: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.accountNumber = accountNumber
        self.currency = currency
        self.accountClassRawValue = accountClass.rawValue
        self.accountTypeRawValue = accountType.rawValue
        self.isActive = isActive
        self.isSystem = isSystem
        self.createdAt = Date()
    }
}

// MARK: - Default Chart of Accounts

struct ChartOfAccounts {
    /// Creates a default set of accounts for a new user
    /// Creates a default set of accounts with localized names
    static func createDefaultAccounts(currency: String = "EUR", bundle: Bundle = .main) -> [Account] {
        let defaultTypes: [AccountType] = [
            .openingBalance,
            .cash,
            .bank,
            .creditCard,
            .salary,
            .otherIncome,
            .food,
            .transportation,
            .utilities,
            .housing,
            .healthcare,
            .entertainment,
            .shopping,
            .subscriptions,
            .otherExpense,
        ]
        
        return defaultTypes.map { type in
            Account(
                name: type.localizedName(bundle: bundle),
                accountNumber: "",
                currency: currency,
                accountClass: type.accountClass,
                accountType: type,
                isSystem: type == .openingBalance
            )
        }
    }
}
