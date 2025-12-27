//
//  Transaction.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import Foundation
import SwiftData

// MARK: - Reconciliation Status

/// Status of transaction reconciliation with bank statements
enum ReconciliationStatus: String, Codable, CaseIterable, Identifiable {
    case notReconciled = "n"  // Not yet verified
    case cleared = "c"        // Verified/cleared but not formally reconciled
    case reconciled = "r"     // Formally reconciled with bank statement
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .notReconciled:
            return String(localized: "Not reconciled")
        case .cleared:
            return String(localized: "Cleared")
        case .reconciled:
            return String(localized: "Reconciled")
        }
    }
    
    var iconName: String {
        switch self {
        case .notReconciled:
            return "circle"
        case .cleared:
            return "checkmark.circle"
        case .reconciled:
            return "lock.circle.fill"
        }
    }
    
    var shortName: String {
        switch self {
        case .notReconciled:
            return "n"
        case .cleared:
            return "c"
        case .reconciled:
            return "R"
        }
    }
}

// MARK: - Entry Model

/// A single debit or credit entry within a transaction.
/// Every transaction must have at least one debit entry and one credit entry
/// that balance to zero.
@Model
final class Entry {
    var id: UUID = UUID()
    var entryTypeRawValue: String = EntryType.debit.rawValue
    var amount: Decimal = 0
    
    var account: Account?
    var transaction: Transaction?
    
    var entryType: EntryType {
        get { EntryType(rawValue: entryTypeRawValue) ?? .debit }
        set { entryTypeRawValue = newValue.rawValue }
    }
    
    init(
        entryType: EntryType,
        amount: Decimal,
        account: Account? = nil
    ) {
        self.id = UUID()
        self.entryTypeRawValue = entryType.rawValue
        self.amount = amount
        self.account = account
    }
}

// MARK: - Transaction Model

/// A double-entry transaction consisting of balanced debit and credit entries.
/// The fundamental rule: Total Debits = Total Credits
@Model
final class Transaction {
    var id: UUID = UUID()
    var date: Date = Date()
    var descriptionText: String = ""
    var reference: String = ""
    var createdAt: Date = Date()
    var isRecurring: Bool = false
    var reconciliationStatusRawValue: String = ReconciliationStatus.notReconciled.rawValue
    var reconciledDate: Date?
    var linkedLoanId: UUID?
    
    // MARK: - Investment Properties
    
    /// Type of investment transaction (buy, sell, dividend, split)
    var investmentTypeRawValue: String?
    
    /// Number of shares involved in the transaction
    var shares: Decimal?
    
    /// Price per share at time of transaction
    var pricePerShare: Decimal?
    
    /// Transaction fees (broker fees, commissions)
    var fees: Decimal?
    
    /// The investment transaction type
    var investmentType: InvestmentTransactionType? {
        get {
            guard let rawValue = investmentTypeRawValue else { return nil }
            return InvestmentTransactionType(rawValue: rawValue)
        }
        set { investmentTypeRawValue = newValue?.rawValue }
    }
    
    /// Whether this is an investment transaction
    var isInvestmentTransaction: Bool {
        investmentType != nil
    }
    
    /// Total transaction value (shares * price + fees)
    var investmentTotalValue: Decimal? {
        guard let shares = shares, let price = pricePerShare else { return nil }
        let baseValue = shares * price
        return baseValue + (fees ?? 0)
    }
    
    @Relationship(deleteRule: .cascade, inverse: \Entry.transaction)
    var entries: [Entry]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \Attachment.transaction)
    var attachments: [Attachment]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \RecurrenceRule.transaction)
    var recurrenceRule: RecurrenceRule?
    
    var reconciliationStatus: ReconciliationStatus {
        get { ReconciliationStatus(rawValue: reconciliationStatusRawValue) ?? .notReconciled }
        set { reconciliationStatusRawValue = newValue.rawValue }
    }
    
    /// Total amount of debit entries
    var totalDebits: Decimal {
        (entries ?? [])
            .filter { $0.entryType == .debit }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    /// Total amount of credit entries
    var totalCredits: Decimal {
        (entries ?? [])
            .filter { $0.entryType == .credit }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    /// Check if the transaction is balanced (debits = credits)
    var isBalanced: Bool {
        totalDebits == totalCredits
    }
    
    /// The transaction amount (sum of debits, which should equal sum of credits)
    var amount: Decimal {
        totalDebits
    }
    
    /// Get the debit entry (for simple two-entry transactions)
    var debitEntry: Entry? {
        (entries ?? []).first { $0.entryType == .debit }
    }
    
    /// Get the credit entry (for simple two-entry transactions)
    var creditEntry: Entry? {
        (entries ?? []).first { $0.entryType == .credit }
    }
    
    /// Get all debit entries
    var debitEntries: [Entry] {
        (entries ?? []).filter { $0.entryType == .debit }
    }
    
    /// Get all credit entries
    var creditEntries: [Entry] {
        (entries ?? []).filter { $0.entryType == .credit }
    }
    
    init(
        date: Date = Date(),
        descriptionText: String = "",
        reference: String = "",
        isRecurring: Bool = false
    ) {
        self.id = UUID()
        self.date = date
        self.descriptionText = descriptionText
        self.reference = reference
        self.createdAt = Date()
        self.isRecurring = isRecurring
        self.reconciliationStatusRawValue = ReconciliationStatus.notReconciled.rawValue
        self.reconciledDate = nil
    }
    
    /// Add a balanced pair of entries (debit and credit)
    func addEntryPair(
        debitAccount: Account,
        creditAccount: Account,
        amount: Decimal
    ) {
        let debitEntry = Entry(entryType: .debit, amount: amount, account: debitAccount)
        let creditEntry = Entry(entryType: .credit, amount: amount, account: creditAccount)
        
        debitEntry.transaction = self
        creditEntry.transaction = self
        
        if entries == nil {
            entries = []
        }
        entries?.append(debitEntry)
        entries?.append(creditEntry)
    }
}

// MARK: - Transaction Builder

/// Helper for creating balanced transactions
struct TransactionBuilder {
    
    /// Create a simple expense transaction
    /// Debits the expense account, credits the asset/liability account
    static func createExpense(
        date: Date = Date(),
        description: String,
        amount: Decimal,
        expenseAccount: Account,
        paymentAccount: Account,
        reference: String = "",
        context: ModelContext
    ) -> Transaction {
        let transaction = Transaction(
            date: date,
            descriptionText: description,
            reference: reference
        )
        
        let debitEntry = Entry(entryType: .debit, amount: amount, account: expenseAccount)
        let creditEntry = Entry(entryType: .credit, amount: amount, account: paymentAccount)
        
        context.insert(transaction)
        context.insert(debitEntry)
        context.insert(creditEntry)
        
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction
        
        return transaction
    }
    
    /// Create a simple income transaction
    /// Debits the asset account, credits the income account
    static func createIncome(
        date: Date = Date(),
        description: String,
        amount: Decimal,
        depositAccount: Account,
        incomeAccount: Account,
        reference: String = "",
        context: ModelContext
    ) -> Transaction {
        let transaction = Transaction(
            date: date,
            descriptionText: description,
            reference: reference
        )
        
        let debitEntry = Entry(entryType: .debit, amount: amount, account: depositAccount)
        let creditEntry = Entry(entryType: .credit, amount: amount, account: incomeAccount)
        
        context.insert(transaction)
        context.insert(debitEntry)
        context.insert(creditEntry)
        
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction
        
        return transaction
    }
    
    /// Create a transfer between two asset/liability accounts
    /// Debits the destination, credits the source
    static func createTransfer(
        date: Date = Date(),
        description: String,
        amount: Decimal,
        fromAccount: Account,
        toAccount: Account,
        reference: String = "",
        context: ModelContext
    ) -> Transaction {
        let transaction = Transaction(
            date: date,
            descriptionText: description,
            reference: reference
        )
        
        let debitEntry = Entry(entryType: .debit, amount: amount, account: toAccount)
        let creditEntry = Entry(entryType: .credit, amount: amount, account: fromAccount)
        
        context.insert(transaction)
        context.insert(debitEntry)
        context.insert(creditEntry)
        
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction
        
        return transaction
    }
    
    /// Create an opening balance transaction
    /// Used to set initial balances for accounts
    static func createOpeningBalance(
        date: Date = Date(),
        account: Account,
        amount: Decimal,
        openingBalanceEquityAccount: Account,
        context: ModelContext
    ) -> Transaction {
        let transaction = Transaction(
            date: date,
            descriptionText: String(localized: "Opening balance"),
            reference: ""
        )
        
        let debitEntry: Entry
        let creditEntry: Entry
        
        // For assets: debit the asset, credit opening balance equity
        // For liabilities: debit opening balance equity, credit the liability
        if account.accountClass.normalBalance == .debit {
            debitEntry = Entry(entryType: .debit, amount: amount, account: account)
            creditEntry = Entry(entryType: .credit, amount: amount, account: openingBalanceEquityAccount)
        } else {
            debitEntry = Entry(entryType: .debit, amount: amount, account: openingBalanceEquityAccount)
            creditEntry = Entry(entryType: .credit, amount: amount, account: account)
        }
        
        context.insert(transaction)
        context.insert(debitEntry)
        context.insert(creditEntry)
        
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction
        
        return transaction
    }
    
    // MARK: - Investment Transactions
    
    /// Create an investment buy transaction
    /// - Parameters:
    ///   - date: Transaction date
    ///   - description: Transaction description
    ///   - shares: Number of shares purchased
    ///   - pricePerShare: Price per share
    ///   - fees: Broker fees/commissions
    ///   - investmentAccount: The investment account receiving shares
    ///   - cashAccount: The cash account paying for the purchase
    ///   - context: Model context
    /// - Returns: The created transaction
    static func createInvestmentBuy(
        date: Date = Date(),
        description: String,
        shares: Decimal,
        pricePerShare: Decimal,
        fees: Decimal = 0,
        investmentAccount: Account,
        cashAccount: Account,
        context: ModelContext
    ) -> Transaction {
        let totalCost = (shares * pricePerShare) + fees
        
        let transaction = Transaction(
            date: date,
            descriptionText: description,
            reference: ""
        )
        
        // Set investment-specific properties
        transaction.investmentType = .buy
        transaction.shares = shares
        transaction.pricePerShare = pricePerShare
        transaction.fees = fees
        
        // Double-entry: Debit investment (asset increases), Credit cash (asset decreases)
        let debitEntry = Entry(entryType: .debit, amount: totalCost, account: investmentAccount)
        let creditEntry = Entry(entryType: .credit, amount: totalCost, account: cashAccount)
        
        context.insert(transaction)
        context.insert(debitEntry)
        context.insert(creditEntry)
        
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction
        
        return transaction
    }
    
    /// Create an investment sell transaction
    /// - Parameters:
    ///   - date: Transaction date
    ///   - description: Transaction description
    ///   - shares: Number of shares sold
    ///   - pricePerShare: Price per share
    ///   - fees: Broker fees/commissions
    ///   - investmentAccount: The investment account selling shares
    ///   - cashAccount: The cash account receiving proceeds
    ///   - context: Model context
    /// - Returns: The created transaction
    static func createInvestmentSell(
        date: Date = Date(),
        description: String,
        shares: Decimal,
        pricePerShare: Decimal,
        fees: Decimal = 0,
        investmentAccount: Account,
        cashAccount: Account,
        context: ModelContext
    ) -> Transaction {
        let proceeds = (shares * pricePerShare) - fees
        
        let transaction = Transaction(
            date: date,
            descriptionText: description,
            reference: ""
        )
        
        // Set investment-specific properties
        transaction.investmentType = .sell
        transaction.shares = shares
        transaction.pricePerShare = pricePerShare
        transaction.fees = fees
        
        // Double-entry: Debit cash (asset increases), Credit investment (asset decreases)
        let debitEntry = Entry(entryType: .debit, amount: proceeds, account: cashAccount)
        let creditEntry = Entry(entryType: .credit, amount: proceeds, account: investmentAccount)
        
        context.insert(transaction)
        context.insert(debitEntry)
        context.insert(creditEntry)
        
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction
        
        return transaction
    }
    
    /// Create a dividend transaction
    /// - Parameters:
    ///   - date: Transaction date
    ///   - description: Transaction description
    ///   - amount: Dividend amount
    ///   - investmentAccount: The investment account generating the dividend
    ///   - cashAccount: The cash account receiving the dividend
    ///   - incomeAccount: The income account to record dividend income
    ///   - context: Model context
    /// - Returns: The created transaction
    static func createDividend(
        date: Date = Date(),
        description: String,
        amount: Decimal,
        investmentAccount: Account,
        cashAccount: Account,
        incomeAccount: Account,
        context: ModelContext
    ) -> Transaction {
        let transaction = Transaction(
            date: date,
            descriptionText: description,
            reference: ""
        )
        
        // Set investment-specific properties
        transaction.investmentType = .dividend
        
        // Double-entry: Debit cash (asset increases), Credit dividend income
        let debitEntry = Entry(entryType: .debit, amount: amount, account: cashAccount)
        let creditEntry = Entry(entryType: .credit, amount: amount, account: incomeAccount)
        
        context.insert(transaction)
        context.insert(debitEntry)
        context.insert(creditEntry)
        
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction
        
        return transaction
    }
    
    /// Create a stock split transaction
    /// - Parameters:
    ///   - date: Transaction date
    ///   - description: Transaction description
    ///   - splitRatio: The split multiplier (e.g., 2 for 2:1 split)
    ///   - investmentAccount: The investment account with the shares
    ///   - context: Model context
    /// - Returns: The created transaction
    static func createStockSplit(
        date: Date = Date(),
        description: String,
        splitRatio: Decimal,
        investmentAccount: Account,
        context: ModelContext
    ) -> Transaction {
        let transaction = Transaction(
            date: date,
            descriptionText: description,
            reference: ""
        )
        
        // Set investment-specific properties
        transaction.investmentType = .split
        transaction.shares = splitRatio
        
        // Stock splits don't create actual accounting entries
        // They just record the event and the helper tracks share count changes
        context.insert(transaction)
        
        // Create a zero-value entry pair just to link to the account
        let debitEntry = Entry(entryType: .debit, amount: 0, account: investmentAccount)
        let creditEntry = Entry(entryType: .credit, amount: 0, account: investmentAccount)
        
        context.insert(debitEntry)
        context.insert(creditEntry)
        
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction
        
        return transaction
    }
}
