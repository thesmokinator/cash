//
//  CashTests.swift
//  CashTests
//
//  Created by Michele Broggi on 25/11/25.
//

import Testing
import Foundation
@testable import Cash

struct AccountTests {
    
    @Test func accountCreation() async throws {
        let account = Account(
            name: "Test Bank",
            accountNumber: "1000",
            currency: "EUR",
            accountClass: .asset,
            accountType: .bank
        )
        
        #expect(account.name == "Test Bank")
        #expect(account.accountNumber == "1000")
        #expect(account.currency == "EUR")
        #expect(account.accountClass == .asset)
        #expect(account.accountType == .bank)
        #expect(account.isActive == true)
        #expect(account.isSystem == false)
    }
    
    @Test func accountDisplayName() async throws {
        let account = Account(
            name: "Checking",
            accountNumber: "1010",
            currency: "EUR",
            accountClass: .asset,
            accountType: .bank
        )
        
        #expect(account.displayName == "1010 - Checking")
        
        let accountNoNumber = Account(
            name: "Cash",
            accountNumber: "",
            currency: "EUR",
            accountClass: .asset,
            accountType: .cash
        )
        
        #expect(accountNoNumber.displayName == "Cash")
    }
    
    @Test func accountClassNormalBalance() async throws {
        #expect(AccountClass.asset.normalBalance == .debit)
        #expect(AccountClass.expense.normalBalance == .debit)
        #expect(AccountClass.liability.normalBalance == .credit)
        #expect(AccountClass.income.normalBalance == .credit)
        #expect(AccountClass.equity.normalBalance == .credit)
    }
}

struct TransactionTests {
    
    @Test func transactionCreation() async throws {
        let transaction = Transaction(
            date: Date(),
            descriptionText: "Test transaction"
        )
        
        #expect(transaction.descriptionText == "Test transaction")
        #expect(transaction.isRecurring == false)
    }
    
    @Test func transactionAmount() async throws {
        let transaction = Transaction(
            date: Date(),
            descriptionText: "Purchase"
        )
        
        let debitEntry = JournalEntry(amount: 100, entryType: .debit)
        let creditEntry = JournalEntry(amount: 100, entryType: .credit)
        
        transaction.entries = [debitEntry, creditEntry]
        
        #expect(transaction.amount == 100)
    }
}

struct JournalEntryTests {
    
    @Test func entryTypeShortNames() async throws {
        #expect(EntryType.debit.shortName == "Dr")
        #expect(EntryType.credit.shortName == "Cr")
    }
    
    @Test func journalEntryCreation() async throws {
        let entry = JournalEntry(amount: 50.25, entryType: .debit)
        
        #expect(entry.amount == 50.25)
        #expect(entry.entryType == .debit)
    }
}

struct CurrencyTests {
    
    @Test func currencySymbol() async throws {
        #expect(CurrencyList.symbol(forCode: "EUR") == "€")
        #expect(CurrencyList.symbol(forCode: "USD") == "$")
        #expect(CurrencyList.symbol(forCode: "GBP") == "£")
        #expect(CurrencyList.symbol(forCode: "INVALID") == "INVALID")
    }
    
    @Test func currencyListNotEmpty() async throws {
        #expect(CurrencyList.all.count > 0)
    }
}

struct TransactionDateFilterTests {
    
    @Test func dateFilterRanges() async throws {
        let today = TransactionDateFilter.today
        let range = today.dateRange
        
        #expect(range.start <= range.end)
    }
    
    @Test func thisMonthFilter() async throws {
        let thisMonth = TransactionDateFilter.thisMonth
        let range = thisMonth.dateRange
        let calendar = Calendar.current
        
        let startComponents = calendar.dateComponents([.day], from: range.start)
        #expect(startComponents.day == 1)
    }
}
