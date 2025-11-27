//
//  Transaction.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import Foundation
import SwiftData

// MARK: - Entry Model

/// A single debit or credit entry within a transaction.
/// Every transaction must have at least one debit entry and one credit entry
/// that balance to zero.
@Model
final class Entry {
    var id: UUID
    var entryTypeRawValue: String
    var amount: Decimal
    
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
    var id: UUID
    var date: Date
    var descriptionText: String
    var reference: String
    var createdAt: Date
    var isRecurring: Bool // Recurring transactions are templates not counted in balances
    
    @Relationship(deleteRule: .cascade, inverse: \Entry.transaction)
    var entries: [Entry]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \Attachment.transaction)
    var attachments: [Attachment]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \RecurrenceRule.transaction)
    var recurrenceRule: RecurrenceRule?
    
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
}
