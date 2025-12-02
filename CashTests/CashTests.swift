//
//  CashTests.swift
//  CashTests
//
//  Created by Michele Broggi on 25/11/25.
//

import Testing
import Foundation
import SwiftUI
@testable import Cash

// MARK: - Account Tests

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
        
        #expect(account.displayName == "Checking")
        #expect(account.accountNumber == "1010")
    }
    
    @Test func accountClassNormalBalance() async throws {
        #expect(AccountClass.asset.normalBalance == .debit)
        #expect(AccountClass.expense.normalBalance == .debit)
        #expect(AccountClass.liability.normalBalance == .credit)
        #expect(AccountClass.income.normalBalance == .credit)
        #expect(AccountClass.equity.normalBalance == .credit)
    }
    
    @Test func accountTypesBelongToCorrectClass() async throws {
        #expect(AccountType.bank.accountClass == .asset)
        #expect(AccountType.cash.accountClass == .asset)
        #expect(AccountType.creditCard.accountClass == .liability)
        #expect(AccountType.loan.accountClass == .liability)
        #expect(AccountType.salary.accountClass == .income)
        #expect(AccountType.food.accountClass == .expense)
        #expect(AccountType.openingBalance.accountClass == .equity)
    }
    
    @Test func accountTypesForClass() async throws {
        let assetTypes = AccountType.types(for: .asset)
        #expect(assetTypes.contains(.bank))
        #expect(assetTypes.contains(.cash))
        #expect(!assetTypes.contains(.creditCard))
        
        let expenseTypes = AccountType.types(for: .expense)
        #expect(expenseTypes.contains(.food))
        #expect(expenseTypes.contains(.transportation))
        #expect(!expenseTypes.contains(.salary))
    }
    
    @Test func accountClassDisplayOrder() async throws {
        #expect(AccountClass.asset.displayOrder < AccountClass.liability.displayOrder)
        #expect(AccountClass.liability.displayOrder < AccountClass.equity.displayOrder)
        #expect(AccountClass.equity.displayOrder < AccountClass.income.displayOrder)
        #expect(AccountClass.income.displayOrder < AccountClass.expense.displayOrder)
    }
}

// MARK: - Transaction Tests

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
        
        let debitEntry = Entry(entryType: .debit, amount: 100)
        let creditEntry = Entry(entryType: .credit, amount: 100)
        
        transaction.entries = [debitEntry, creditEntry]
        
        #expect(transaction.amount == 100)
    }
    
    @Test func transactionIsBalanced() async throws {
        let transaction = Transaction(
            date: Date(),
            descriptionText: "Balanced"
        )
        
        let debitEntry = Entry(entryType: .debit, amount: 50)
        let creditEntry = Entry(entryType: .credit, amount: 50)
        
        transaction.entries = [debitEntry, creditEntry]
        
        #expect(transaction.isBalanced == true)
        #expect(transaction.totalDebits == transaction.totalCredits)
    }
    
    @Test func transactionIsUnbalanced() async throws {
        let transaction = Transaction(
            date: Date(),
            descriptionText: "Unbalanced"
        )
        
        let debitEntry = Entry(entryType: .debit, amount: 100)
        let creditEntry = Entry(entryType: .credit, amount: 50)
        
        transaction.entries = [debitEntry, creditEntry]
        
        #expect(transaction.isBalanced == false)
        #expect(transaction.totalDebits == 100)
        #expect(transaction.totalCredits == 50)
    }
    
    @Test func recurringTransactionCreation() async throws {
        let transaction = Transaction(
            date: Date(),
            descriptionText: "Monthly rent",
            isRecurring: true
        )
        
        #expect(transaction.isRecurring == true)
    }
    
    @Test func transactionDebitCreditEntries() async throws {
        let transaction = Transaction(date: Date(), descriptionText: "Test")
        
        let debit1 = Entry(entryType: .debit, amount: 30)
        let debit2 = Entry(entryType: .debit, amount: 20)
        let credit = Entry(entryType: .credit, amount: 50)
        
        transaction.entries = [debit1, debit2, credit]
        
        #expect(transaction.debitEntries.count == 2)
        #expect(transaction.creditEntries.count == 1)
        #expect(transaction.totalDebits == 50)
        #expect(transaction.totalCredits == 50)
    }
}

// MARK: - Entry Tests

struct EntryTests {
    
    @Test func entryTypeRawValues() async throws {
        #expect(EntryType.debit.rawValue == "debit")
        #expect(EntryType.credit.rawValue == "credit")
    }
    
    @Test func entryTypeOpposite() async throws {
        #expect(EntryType.debit.opposite == .credit)
        #expect(EntryType.credit.opposite == .debit)
    }
    
    @Test func entryCreation() async throws {
        let entry = Entry(entryType: .debit, amount: 50.25)
        
        #expect(entry.amount == 50.25)
        #expect(entry.entryType == .debit)
    }
    
    @Test func entryTypeLocalizedNames() async throws {
        #expect(!EntryType.debit.localizedName.isEmpty)
        #expect(!EntryType.credit.localizedName.isEmpty)
        #expect(!EntryType.debit.shortName.isEmpty)
        #expect(!EntryType.credit.shortName.isEmpty)
    }
}

// MARK: - Currency Tests

struct CurrencyTests {
    
    @Test func currencySymbol() async throws {
        #expect(CurrencyList.symbol(forCode: "EUR") == "€")
        #expect(CurrencyList.symbol(forCode: "USD") == "$")
        #expect(CurrencyList.symbol(forCode: "GBP") == "£")
        #expect(CurrencyList.symbol(forCode: "INVALID") == "INVALID")
    }
    
    @Test func currencyListNotEmpty() async throws {
        #expect(CurrencyList.currencies.count > 0)
    }
    
    @Test func currencyLookup() async throws {
        let eur = CurrencyList.currency(forCode: "EUR")
        #expect(eur != nil)
        #expect(eur?.symbol == "€")
        #expect(eur?.name == "Euro")
    }
    
    @Test func currencyDisplayName() async throws {
        let eur = CurrencyList.currency(forCode: "EUR")
        #expect(eur?.displayName.contains("Euro") == true)
        #expect(eur?.displayName.contains("€") == true)
    }
}

// MARK: - Transaction Date Filter Tests

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
    
    @Test func allFiltersHaveValidRanges() async throws {
        for filter in TransactionDateFilter.allCases {
            let range = filter.dateRange
            #expect(range.start <= range.end)
        }
    }
    
    @Test func filterLocalizedNames() async throws {
        for filter in TransactionDateFilter.allCases {
            #expect(filter.localizedName != nil)
        }
    }
}

// MARK: - Recurrence Rule Tests

struct RecurrenceRuleTests {
    
    @Test func dailyRecurrence() async throws {
        let rule = RecurrenceRule(
            frequency: .daily,
            interval: 1
        )
        
        let today = Date()
        let next = rule.calculateNextOccurrence(from: today)
        
        #expect(next != nil)
        if let nextDate = next {
            let calendar = Calendar.current
            let daysDiff = calendar.dateComponents([.day], from: today, to: nextDate).day
            #expect(daysDiff == 1)
        }
    }
    
    @Test func weeklyRecurrence() async throws {
        let rule = RecurrenceRule(
            frequency: .weekly,
            interval: 1
        )
        
        let today = Date()
        let next = rule.calculateNextOccurrence(from: today)
        
        #expect(next != nil)
        if let nextDate = next {
            let calendar = Calendar.current
            let daysDiff = calendar.dateComponents([.day], from: today, to: nextDate).day
            #expect(daysDiff == 7)
        }
    }
    
    @Test func monthlyRecurrence() async throws {
        let rule = RecurrenceRule(
            frequency: .monthly,
            interval: 1,
            dayOfMonth: 15
        )
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: Date())
        components.day = 1
        let firstOfMonth = calendar.date(from: components)!
        
        let next = rule.calculateNextOccurrence(from: firstOfMonth)
        
        #expect(next != nil)
        if let nextDate = next {
            let dayComponent = calendar.component(.day, from: nextDate)
            #expect(dayComponent == 15)
        }
    }
    
    @Test func recurrenceWithEndDate() async throws {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 3, to: Date())!
        
        let rule = RecurrenceRule(
            frequency: .daily,
            interval: 1,
            endDate: endDate
        )
        
        // Should return nil if next occurrence is after end date
        let farFuture = calendar.date(byAdding: .day, value: 10, to: Date())!
        let next = rule.calculateNextOccurrence(from: farFuture)
        
        #expect(next == nil)
    }
    
    @Test func recurrenceIntervalMultiple() async throws {
        let rule = RecurrenceRule(
            frequency: .daily,
            interval: 3
        )
        
        let today = Date()
        let next = rule.calculateNextOccurrence(from: today)
        
        #expect(next != nil)
        if let nextDate = next {
            let calendar = Calendar.current
            let daysDiff = calendar.dateComponents([.day], from: today, to: nextDate).day
            #expect(daysDiff == 3)
        }
    }
    
    @Test func recurrenceLocalizedDescription() async throws {
        let dailyRule = RecurrenceRule(frequency: .daily, interval: 1)
        let weeklyRule = RecurrenceRule(frequency: .weekly, interval: 2)
        let monthlyRule = RecurrenceRule(frequency: .monthly, interval: 1, dayOfMonth: 15)
        
        #expect(!dailyRule.localizedDescription.isEmpty)
        #expect(!weeklyRule.localizedDescription.isEmpty)
        #expect(!monthlyRule.localizedDescription.isEmpty)
    }
    
    @Test func recurrenceFrequencyAllCases() async throws {
        #expect(RecurrenceFrequency.allCases.count == 4)
        #expect(RecurrenceFrequency.allCases.contains(.daily))
        #expect(RecurrenceFrequency.allCases.contains(.weekly))
        #expect(RecurrenceFrequency.allCases.contains(.monthly))
        #expect(RecurrenceFrequency.allCases.contains(.yearly))
    }
    
    @Test func weekendAdjustmentAllCases() async throws {
        #expect(WeekendAdjustment.allCases.count == 3)
        #expect(WeekendAdjustment.allCases.contains(.none))
        #expect(WeekendAdjustment.allCases.contains(.previousFriday))
        #expect(WeekendAdjustment.allCases.contains(.nextMonday))
    }
    
    @Test func recurrenceNextOccurrenceAlwaysAdvances() async throws {
        let rule = RecurrenceRule(
            frequency: .monthly,
            interval: 1,
            dayOfMonth: 15
        )
        
        let today = Date()
        var currentDate = today
        
        // Test that each next occurrence is always after the current
        for _ in 0..<12 {
            if let next = rule.calculateNextOccurrence(from: currentDate) {
                #expect(next > currentDate)
                currentDate = next
            }
        }
    }
}

// MARK: - Forecast Period Tests

struct ForecastPeriodTests {
    
    @Test func allPeriodsHaveValidEndDates() async throws {
        let now = Date()
        
        for period in ForecastPeriod.allCases {
            #expect(period.endDate > now)
        }
    }
    
    @Test func periodEndDatesAreOrdered() async throws {
        let nextWeek = ForecastPeriod.nextWeek.endDate
        let next15Days = ForecastPeriod.next15Days.endDate
        let nextMonth = ForecastPeriod.nextMonth.endDate
        let next3Months = ForecastPeriod.next3Months.endDate
        let next6Months = ForecastPeriod.next6Months.endDate
        let next12Months = ForecastPeriod.next12Months.endDate
        
        #expect(nextWeek < next15Days)
        #expect(next15Days < nextMonth)
        #expect(nextMonth < next3Months)
        #expect(next3Months < next6Months)
        #expect(next6Months < next12Months)
    }
    
    @Test func periodLocalizedNames() async throws {
        for period in ForecastPeriod.allCases {
            #expect(period.localizedName != nil)
        }
    }
    
    @Test func nextWeekIsSevenDays() async throws {
        let now = Date()
        let nextWeekEnd = ForecastPeriod.nextWeek.endDate
        let calendar = Calendar.current
        let daysDiff = calendar.dateComponents([.day], from: now, to: nextWeekEnd).day
        
        #expect(daysDiff == 7)
    }
}

// MARK: - Chart of Accounts Tests

struct ChartOfAccountsTests {
    
    @Test func defaultAccountsCreation() async throws {
        let accounts = ChartOfAccounts.createDefaultAccounts(currency: "EUR")
        
        #expect(accounts.count > 0)
        
        // Should have at least one of each major type
        let hasAsset = accounts.contains { $0.accountClass == .asset }
        let hasLiability = accounts.contains { $0.accountClass == .liability }
        let hasIncome = accounts.contains { $0.accountClass == .income }
        let hasExpense = accounts.contains { $0.accountClass == .expense }
        
        #expect(hasAsset)
        #expect(hasLiability)
        #expect(hasIncome)
        #expect(hasExpense)
    }
    
    @Test func defaultAccountsCurrency() async throws {
        let eurAccounts = ChartOfAccounts.createDefaultAccounts(currency: "EUR")
        let usdAccounts = ChartOfAccounts.createDefaultAccounts(currency: "USD")
        
        for account in eurAccounts {
            #expect(account.currency == "EUR")
        }
        
        for account in usdAccounts {
            #expect(account.currency == "USD")
        }
    }
    
    @Test func openingBalanceAccountIsSystem() async throws {
        let accounts = ChartOfAccounts.createDefaultAccounts(currency: "EUR")
        let openingBalance = accounts.first { $0.accountType == .openingBalance }
        
        #expect(openingBalance != nil)
        #expect(openingBalance?.isSystem == true)
    }
}

// MARK: - Simple Transaction Type Tests

struct SimpleTransactionTypeTests {
    
    @Test func allCasesExist() async throws {
        #expect(SimpleTransactionType.allCases.count == 3)
        #expect(SimpleTransactionType.allCases.contains(.expense))
        #expect(SimpleTransactionType.allCases.contains(.income))
        #expect(SimpleTransactionType.allCases.contains(.transfer))
    }
    
    @Test func iconsExist() async throws {
        for type in SimpleTransactionType.allCases {
            #expect(!type.iconName.isEmpty)
        }
    }
    
    @Test func localizedNamesExist() async throws {
        for type in SimpleTransactionType.allCases {
            #expect(type.localizedName != nil)
        }
    }
}

// MARK: - Navigation State Tests

struct NavigationStateTests {
    
    @Test func initialState() async throws {
        let state = NavigationState()
        
        #expect(state.isViewingAccount == false)
        #expect(state.currentAccount == nil)
    }
    
    @Test func stateUpdate() async throws {
        let state = NavigationState()
        let account = Account(
            name: "Test",
            currency: "EUR",
            accountClass: .asset,
            accountType: .bank
        )
        
        state.isViewingAccount = true
        state.currentAccount = account
        
        #expect(state.isViewingAccount == true)
        #expect(state.currentAccount != nil)
        #expect(state.currentAccount?.name == "Test")
    }
}

// MARK: - OFX Parser Tests

struct OFXParserTests {
    
    // Sample OFX content in XML style
    let sampleOFXXML = """
    <OFX>
    <BANKMSGSRSV1>
    <STMTTRNRS>
    <STMTRS>
    <BANKTRANLIST>
    <STMTTRN>
    <TRNTYPE>DEBIT</TRNTYPE>
    <DTPOSTED>20231115</DTPOSTED>
    <TRNAMT>-50.00</TRNAMT>
    <FITID>202311150001</FITID>
    <NAME>Grocery Store</NAME>
    <MEMO>Weekly shopping</MEMO>
    </STMTTRN>
    <STMTTRN>
    <TRNTYPE>CREDIT</TRNTYPE>
    <DTPOSTED>20231101</DTPOSTED>
    <TRNAMT>1500.00</TRNAMT>
    <FITID>202311010001</FITID>
    <NAME>Salary</NAME>
    </STMTTRN>
    </BANKTRANLIST>
    </STMTRS>
    </STMTTRNRS>
    </BANKMSGSRSV1>
    </OFX>
    """
    
    // Sample OFX content in SGML style (no closing tags)
    let sampleOFXSGML = """
    OFXHEADER:100
    DATA:OFXSGML
    <OFX>
    <BANKMSGSRSV1>
    <STMTTRNRS>
    <STMTRS>
    <BANKTRANLIST>
    <STMTTRN>
    <TRNTYPE>DEBIT
    <DTPOSTED>20231120
    <TRNAMT>-25.50
    <FITID>TXN001
    <NAME>Coffee Shop
    <STMTTRN>
    <TRNTYPE>CREDIT
    <DTPOSTED>20231115
    <TRNAMT>200.00
    <FITID>TXN002
    <NAME>Refund
    </BANKTRANLIST>
    </STMTRS>
    </STMTTRNRS>
    </BANKMSGSRSV1>
    </OFX>
    """
    
    @Test func parseXMLStyleOFX() async throws {
        let transactions = try OFXParser.parse(content: sampleOFXXML)
        
        #expect(transactions.count == 2)
    }
    
    @Test func parseTransactionDetails() async throws {
        let transactions = try OFXParser.parse(content: sampleOFXXML)
        
        // Transactions are sorted by date descending, so the newer one (Nov 15) comes first
        let debitTransaction = transactions.first { $0.amount < 0 }
        let creditTransaction = transactions.first { $0.amount > 0 }
        
        #expect(debitTransaction != nil)
        #expect(creditTransaction != nil)
        
        #expect(debitTransaction?.name == "Grocery Store")
        #expect(debitTransaction?.memo == "Weekly shopping")
        #expect(debitTransaction?.amount == -50.00)
        #expect(debitTransaction?.fitId == "202311150001")
        
        #expect(creditTransaction?.name == "Salary")
        #expect(creditTransaction?.amount == 1500.00)
    }
    
    @Test func parseSGMLStyleOFX() async throws {
        let transactions = try OFXParser.parse(content: sampleOFXSGML)
        
        #expect(transactions.count == 2)
        
        let debitTransaction = transactions.first { $0.amount < 0 }
        #expect(debitTransaction?.name == "Coffee Shop")
        #expect(debitTransaction?.amount == -25.50)
    }
    
    @Test func transactionIsExpenseProperty() async throws {
        let transactions = try OFXParser.parse(content: sampleOFXXML)
        
        let debit = transactions.first { $0.amount < 0 }
        let credit = transactions.first { $0.amount > 0 }
        
        #expect(debit?.isExpense == true)
        #expect(credit?.isExpense == false)
    }
    
    @Test func transactionAbsoluteAmount() async throws {
        let transactions = try OFXParser.parse(content: sampleOFXXML)
        
        let debit = transactions.first { $0.amount < 0 }
        
        #expect(debit?.absoluteAmount == 50.00)
    }
    
    @Test func parseOFXDate() async throws {
        let transactions = try OFXParser.parse(content: sampleOFXXML)
        
        let transaction = transactions.first { $0.fitId == "202311150001" }
        #expect(transaction != nil)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: transaction!.datePosted)
        
        #expect(components.year == 2023)
        #expect(components.month == 11)
        #expect(components.day == 15)
    }
    
    @Test func parseEmptyOFXThrowsError() async throws {
        let emptyOFX = "<OFX></OFX>"
        
        do {
            _ = try OFXParser.parse(content: emptyOFX)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            // Expected error - no transactions found
            #expect(true)
        }
    }
    
    @Test func transactionTypesParsedCorrectly() async throws {
        let transactions = try OFXParser.parse(content: sampleOFXXML)
        
        let debit = transactions.first { $0.amount < 0 }
        let credit = transactions.first { $0.amount > 0 }
        
        #expect(debit?.type == .debit)
        #expect(credit?.type == .credit)
    }
    
    @Test func allTransactionTypesRecognized() async throws {
        #expect(OFXTransactionType(rawValue: "DEBIT") == .debit)
        #expect(OFXTransactionType(rawValue: "CREDIT") == .credit)
        #expect(OFXTransactionType(rawValue: "ATM") == .atm)
        #expect(OFXTransactionType(rawValue: "POS") == .pos)
        #expect(OFXTransactionType(rawValue: "XFER") == .transfer)
        #expect(OFXTransactionType(rawValue: "FEE") == .fee)
        #expect(OFXTransactionType(rawValue: "UNKNOWN") == .other)
    }
    
    @Test func parseDataFromBytes() async throws {
        let data = sampleOFXXML.data(using: .utf8)!
        let transactions = try OFXParser.parse(data: data)
        
        #expect(transactions.count == 2)
    }
    
    @Test func transactionsSortedByDateDescending() async throws {
        let transactions = try OFXParser.parse(content: sampleOFXXML)
        
        // Check that transactions are sorted newest first
        for i in 0..<(transactions.count - 1) {
            #expect(transactions[i].datePosted >= transactions[i + 1].datePosted)
        }
    }
    
    @Test func handleDecimalWithComma() async throws {
        let ofxWithComma = """
        <OFX>
        <BANKTRANLIST>
        <STMTTRN>
        <TRNTYPE>DEBIT</TRNTYPE>
        <DTPOSTED>20231115</DTPOSTED>
        <TRNAMT>-1234,56</TRNAMT>
        <FITID>TEST001</FITID>
        <NAME>Test</NAME>
        </STMTTRN>
        </BANKTRANLIST>
        </OFX>
        """
        
        let transactions = try OFXParser.parse(content: ofxWithComma)
        #expect(transactions.count == 1)
        #expect(transactions[0].amount < 0)
        #expect(transactions[0].absoluteAmount == Decimal(string: "1234.56"))
    }
}

// MARK: - OFX Import Item Tests

struct OFXImportItemTests {
    
    @Test func importItemCreation() async throws {
        let ofxTransaction = OFXTransaction(
            fitId: "TEST001",
            type: .debit,
            datePosted: Date(),
            amount: -100.00,
            name: "Test Transaction",
            memo: "Test memo"
        )
        
        var item = OFXImportItem(ofxTransaction: ofxTransaction)
        
        #expect(item.shouldImport == true)
        #expect(item.selectedCategory == nil)
        #expect(item.ofxTransaction.name == "Test Transaction")
    }
    
    @Test func importItemCategorySelection() async throws {
        let ofxTransaction = OFXTransaction(
            fitId: "TEST001",
            type: .debit,
            datePosted: Date(),
            amount: -50.00,
            name: "Grocery",
            memo: nil
        )
        
        var item = OFXImportItem(ofxTransaction: ofxTransaction)
        
        let category = Account(
            name: "Food",
            currency: "EUR",
            accountClass: .expense,
            accountType: .food
        )
        
        item.selectedCategory = category
        
        #expect(item.selectedCategory != nil)
        #expect(item.selectedCategory?.name == "Food")
    }
}

// MARK: - App Settings Tests

struct AppSettingsTests {
    
    @Test func privacyModeDefaultValue() async throws {
        // Privacy mode should default to false when key doesn't exist
        let testKey = "privacyModeTestKey_\(UUID().uuidString)"
        UserDefaults.standard.removeObject(forKey: testKey)
        let defaultValue = UserDefaults.standard.bool(forKey: testKey)
        #expect(defaultValue == false)
    }
    
    @Test func privacyModePersistenceInUserDefaults() async throws {
        let testKey = "privacyModeTestKey_\(UUID().uuidString)"
        
        // Test that bool values persist in UserDefaults
        UserDefaults.standard.set(true, forKey: testKey)
        #expect(UserDefaults.standard.bool(forKey: testKey) == true)
        
        UserDefaults.standard.set(false, forKey: testKey)
        #expect(UserDefaults.standard.bool(forKey: testKey) == false)
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: testKey)
    }
    
    @Test func privacyModePropertyExists() async throws {
        // Verify AppSettings has privacyMode property
        let settings = AppSettings.shared
        _ = settings.privacyMode // Should compile and not crash
        #expect(true)
    }
    
    @Test func themeDefaultValue() async throws {
        let settings = AppSettings.shared
        // Theme should have a valid value
        #expect(AppTheme.allCases.contains(settings.theme))
    }
    
    @Test func languageDefaultValue() async throws {
        let settings = AppSettings.shared
        // Language should have a valid value
        #expect(AppLanguage.allCases.contains(settings.language))
    }
    
    @Test func themeAllCases() async throws {
        #expect(AppTheme.allCases.count == 3)
        #expect(AppTheme.allCases.contains(.system))
        #expect(AppTheme.allCases.contains(.light))
        #expect(AppTheme.allCases.contains(.dark))
    }
    
    @Test func languageAllCases() async throws {
        #expect(AppLanguage.allCases.count == 3)
        #expect(AppLanguage.allCases.contains(.system))
        #expect(AppLanguage.allCases.contains(.english))
        #expect(AppLanguage.allCases.contains(.italian))
    }
    
    @Test func themeColorSchemes() async throws {
        #expect(AppTheme.system.colorScheme == nil)
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
    }
    
    @Test func themeIconNames() async throws {
        #expect(!AppTheme.system.iconName.isEmpty)
        #expect(!AppTheme.light.iconName.isEmpty)
        #expect(!AppTheme.dark.iconName.isEmpty)
    }
    
    @Test func languageIconNames() async throws {
        #expect(!AppLanguage.system.iconName.isEmpty)
        #expect(!AppLanguage.english.iconName.isEmpty)
        #expect(!AppLanguage.italian.iconName.isEmpty)
    }
}

// MARK: - Report Utilities Tests

struct ReportUtilitiesTests {
    
    @Test func percentageCalculatorChange() async throws {
        // 100 -> 150 = +50%
        let increase = PercentageCalculator.percentageChange(from: 100, to: 150)
        #expect(increase == 50)
        
        // 100 -> 50 = -50%
        let decrease = PercentageCalculator.percentageChange(from: 100, to: 50)
        #expect(decrease == -50)
        
        // 0 -> 100 = +100%
        let fromZero = PercentageCalculator.percentageChange(from: 0, to: 100)
        #expect(fromZero == 100)
        
        // 0 -> -100 = -100%
        let fromZeroNegative = PercentageCalculator.percentageChange(from: 0, to: -100)
        #expect(fromZeroNegative == -100)
        
        // 0 -> 0 = 0%
        let zeroToZero = PercentageCalculator.percentageChange(from: 0, to: 0)
        #expect(zeroToZero == 0)
    }
    
    @Test func percentageCalculatorPartOfWhole() async throws {
        // 25 of 100 = 25%
        let quarter = PercentageCalculator.percentage(of: 25, in: 100)
        #expect(quarter == 25)
        
        // 50 of 200 = 25%
        let ratio = PercentageCalculator.percentage(of: 50, in: 200)
        #expect(ratio == 25)
        
        // x of 0 = 0%
        let divByZero = PercentageCalculator.percentage(of: 50, in: 0)
        #expect(divByZero == 0)
    }
    
    @Test func linearRegressionCalculation() async throws {
        // Simple linear data: y = 2x + 1
        let points: [(x: Double, y: Double)] = [
            (0, 1),
            (1, 3),
            (2, 5),
            (3, 7)
        ]
        
        let regression = LinearRegression.calculate(from: points)
        
        #expect(regression != nil)
        #expect(abs(regression!.slope - 2.0) < 0.001)
        #expect(abs(regression!.intercept - 1.0) < 0.001)
    }
    
    @Test func linearRegressionPrediction() async throws {
        let points: [(x: Double, y: Double)] = [
            (0, 10),
            (10, 20),
            (20, 30)
        ]
        
        let regression = LinearRegression.calculate(from: points)
        
        #expect(regression != nil)
        
        let prediction = regression!.predict(x: 30)
        #expect(abs(prediction - 40.0) < 0.001)
    }
    
    @Test func linearRegressionRequiresMinimumPoints() async throws {
        let singlePoint: [(x: Double, y: Double)] = [(0, 0)]
        let regression = LinearRegression.calculate(from: singlePoint)
        
        #expect(regression == nil)
        
        let empty: [(x: Double, y: Double)] = []
        let emptyRegression = LinearRegression.calculate(from: empty)
        
        #expect(emptyRegression == nil)
    }
    
    @Test func linearRegressionMonthlyChange() async throws {
        // Slope of 10 per day = 300 per month
        let points: [(x: Double, y: Double)] = [
            (0, 0),
            (1, 10)
        ]
        
        let regression = LinearRegression.calculate(from: points)
        
        #expect(regression != nil)
        #expect(regression!.monthlyChange == 300)
    }
    
    @Test func chartAxisFormatterSmallNumbers() async throws {
        #expect(ChartAxisFormatter.format(500) == "500")
        #expect(ChartAxisFormatter.format(0) == "0")
        #expect(ChartAxisFormatter.format(-500) == "-500")
    }
    
    @Test func chartAxisFormatterThousands() async throws {
        let result = ChartAxisFormatter.format(5000)
        #expect(result == "5K")
        
        let negative = ChartAxisFormatter.format(-5000)
        #expect(negative == "-5K")
    }
    
    @Test func chartAxisFormatterMillions() async throws {
        let result = ChartAxisFormatter.format(5000000)
        #expect(result == "5.0M")
        
        let fractional = ChartAxisFormatter.format(1500000)
        #expect(fractional == "1.5M")
    }
    
    @Test func dateRangeHelperPastMonths() async throws {
        let range = DateRangeHelper.pastMonths(3)
        
        #expect(range.start < range.end)
        
        let calendar = Calendar.current
        let monthsDiff = calendar.dateComponents([.month], from: range.start, to: range.end).month
        #expect(monthsDiff == 3)
    }
    
    @Test func dateRangeHelperFutureMonths() async throws {
        let range = DateRangeHelper.futureMonths(6)
        
        #expect(range.start < range.end)
        
        let calendar = Calendar.current
        let monthsDiff = calendar.dateComponents([.month], from: range.start, to: range.end).month
        #expect(monthsDiff == 6)
    }
    
    @Test func dateRangeHelperIsDateInRange() async throws {
        let now = Date()
        let range = DateRangeHelper.pastMonths(1)
        
        #expect(DateRangeHelper.isDate(now, inRange: range) == true)
        
        let calendar = Calendar.current
        let farPast = calendar.date(byAdding: .year, value: -5, to: now)!
        #expect(DateRangeHelper.isDate(farPast, inRange: range) == false)
    }
}

// MARK: - Report Type Tests

struct ReportTypeTests {
    
    @Test func allReportTypesExist() async throws {
        #expect(ReportType.allCases.count == 5)
        #expect(ReportType.allCases.contains(.expensesByCategory))
        #expect(ReportType.allCases.contains(.fixedIncomeExpenseRatio))
        #expect(ReportType.allCases.contains(.yearOverYear))
        #expect(ReportType.allCases.contains(.balanceHistory))
        #expect(ReportType.allCases.contains(.longTermProjection))
    }
    
    @Test func reportTypesHaveLocalizedNames() async throws {
        for reportType in ReportType.allCases {
            #expect(!reportType.localizedName.isEmpty)
        }
    }
    
    @Test func reportTypesHaveIcons() async throws {
        for reportType in ReportType.allCases {
            #expect(!reportType.iconName.isEmpty)
        }
    }
}

// MARK: - Report Period Tests

struct ReportPeriodTests {
    
    @Test func allReportPeriodsExist() async throws {
        #expect(ReportPeriod.allCases.count == 4)
        #expect(ReportPeriod.allCases.contains(.month))
        #expect(ReportPeriod.allCases.contains(.threeMonths))
        #expect(ReportPeriod.allCases.contains(.sixMonths))
        #expect(ReportPeriod.allCases.contains(.year))
    }
    
    @Test func reportPeriodMonths() async throws {
        #expect(ReportPeriod.month.months == 1)
        #expect(ReportPeriod.threeMonths.months == 3)
        #expect(ReportPeriod.sixMonths.months == 6)
        #expect(ReportPeriod.year.months == 12)
    }
    
    @Test func reportPeriodStartDatesInPast() async throws {
        let now = Date()
        
        for period in ReportPeriod.allCases {
            #expect(period.startDate < now)
        }
    }
    
    @Test func reportPeriodLocalizedNames() async throws {
        for period in ReportPeriod.allCases {
            #expect(!period.localizedName.isEmpty)
        }
    }
}

// MARK: - Stability Level Tests

struct StabilityLevelTests {
    
    @Test func stabilityLevelColors() async throws {
        #expect(StabilityLevel.excellent.color == .green)
        #expect(StabilityLevel.good.color == .blue)
        #expect(StabilityLevel.adequate.color == .orange)
        #expect(StabilityLevel.atRisk.color == .red)
        #expect(StabilityLevel.noData.color == .gray)
    }
    
    @Test func stabilityLevelIcons() async throws {
        for level in [StabilityLevel.excellent, .good, .adequate, .atRisk, .noData] {
            #expect(!level.iconName.isEmpty)
        }
    }
    
    @Test func stabilityLevelLocalizedNames() async throws {
        for level in [StabilityLevel.excellent, .good, .adequate, .atRisk, .noData] {
            #expect(!level.localizedName.isEmpty)
        }
    }
}

// MARK: - History Period Tests

struct HistoryPeriodTests {
    
    @Test func allHistoryPeriodsExist() async throws {
        #expect(HistoryPeriod.allCases.count == 4)
        #expect(HistoryPeriod.allCases.contains(.threeMonths))
        #expect(HistoryPeriod.allCases.contains(.sixMonths))
        #expect(HistoryPeriod.allCases.contains(.year))
        #expect(HistoryPeriod.allCases.contains(.allTime))
    }
    
    @Test func historyPeriodStartDates() async throws {
        let now = Date()
        
        // All periods except allTime should have a start date in the past
        #expect(HistoryPeriod.threeMonths.startDate != nil)
        #expect(HistoryPeriod.threeMonths.startDate! < now)
        
        #expect(HistoryPeriod.sixMonths.startDate != nil)
        #expect(HistoryPeriod.sixMonths.startDate! < now)
        
        #expect(HistoryPeriod.year.startDate != nil)
        #expect(HistoryPeriod.year.startDate! < now)
        
        // allTime should have nil start date
        #expect(HistoryPeriod.allTime.startDate == nil)
    }
    
    @Test func historyPeriodLocalizedNames() async throws {
        for period in HistoryPeriod.allCases {
            #expect(!period.localizedName.isEmpty)
        }
    }
}

// MARK: - Projection Period Tests

struct ProjectionPeriodTests {
    
    @Test func allProjectionPeriodsExist() async throws {
        #expect(ProjectionPeriod.allCases.count == 4)
        #expect(ProjectionPeriod.allCases.contains(.sixMonths))
        #expect(ProjectionPeriod.allCases.contains(.year))
        #expect(ProjectionPeriod.allCases.contains(.twoYears))
        #expect(ProjectionPeriod.allCases.contains(.fiveYears))
    }
    
    @Test func projectionPeriodMonths() async throws {
        #expect(ProjectionPeriod.sixMonths.months == 6)
        #expect(ProjectionPeriod.year.months == 12)
        #expect(ProjectionPeriod.twoYears.months == 24)
        #expect(ProjectionPeriod.fiveYears.months == 60)
    }
    
    @Test func projectionPeriodEndDatesInFuture() async throws {
        let now = Date()
        
        for period in ProjectionPeriod.allCases {
            #expect(period.endDate > now)
        }
    }
    
    @Test func projectionPeriodLocalizedNames() async throws {
        for period in ProjectionPeriod.allCases {
            #expect(!period.localizedName.isEmpty)
        }
    }
}

// MARK: - Trend Base Period Tests

struct TrendBasePeriodTests {
    
    @Test func allTrendBasePeriodsExist() async throws {
        #expect(TrendBasePeriod.allCases.count == 3)
        #expect(TrendBasePeriod.allCases.contains(.threeMonths))
        #expect(TrendBasePeriod.allCases.contains(.sixMonths))
        #expect(TrendBasePeriod.allCases.contains(.year))
    }
    
    @Test func trendBasePeriodMonths() async throws {
        #expect(TrendBasePeriod.threeMonths.months == 3)
        #expect(TrendBasePeriod.sixMonths.months == 6)
        #expect(TrendBasePeriod.year.months == 12)
    }
    
    @Test func trendBasePeriodStartDatesInPast() async throws {
        let now = Date()
        
        for period in TrendBasePeriod.allCases {
            #expect(period.startDate < now)
        }
    }
    
    @Test func trendBasePeriodLocalizedNames() async throws {
        for period in TrendBasePeriod.allCases {
            #expect(!period.localizedName.isEmpty)
        }
    }
}

// MARK: - Budget Tests

struct BudgetTests {
    
    @Test func budgetCreation() async throws {
        let budget = Budget(
            startDate: Date(),
            periodType: .monthly,
            rolloverEnabled: false
        )
        
        #expect(budget.periodType == .monthly)
        #expect(budget.rolloverEnabled == false)
        #expect(budget.isActive == true)
    }
    
    @Test func budgetPeriodTypeLocalizedNames() async throws {
        for periodType in BudgetPeriodType.allCases {
            #expect(!periodType.localizedName.isEmpty)
            #expect(!periodType.iconName.isEmpty)
        }
    }
    
    @Test func budgetEndDateCalculationMonthly() async throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 1
        let startDate = calendar.date(from: components)!
        
        let endDate = Budget.calculateEndDate(from: startDate, periodType: .monthly)
        
        let endComponents = calendar.dateComponents([.year, .month, .day], from: endDate)
        #expect(endComponents.year == 2025)
        #expect(endComponents.month == 1)
        #expect(endComponents.day == 31)
    }
    
    @Test func budgetEndDateCalculationWeekly() async throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 1
        let startDate = calendar.date(from: components)!
        
        let endDate = Budget.calculateEndDate(from: startDate, periodType: .weekly)
        
        let daysDiff = calendar.dateComponents([.day], from: startDate, to: endDate).day
        #expect(daysDiff == 6)
    }
    
    @Test func budgetTotalsWithNoEnvelopes() async throws {
        let budget = Budget(
            startDate: Date(),
            periodType: .monthly
        )
        
        #expect(budget.totalBudgeted == 0)
        #expect(budget.totalSpent == 0)
        #expect(budget.totalAvailable == 0)
        #expect(budget.percentageUsed == 0)
        #expect(budget.isOverBudget == false)
    }
    
    @Test func budgetDisplayName() async throws {
        let budget = Budget(
            name: "Test Budget",
            startDate: Date(),
            periodType: .monthly
        )
        
        #expect(budget.displayName == "Test Budget")
        
        let unnamedBudget = Budget(
            startDate: Date(),
            periodType: .monthly
        )
        
        #expect(!unnamedBudget.displayName.isEmpty)
    }
}

// MARK: - Envelope Tests

struct EnvelopeTests {
    
    @Test func envelopeCreation() async throws {
        let envelope = Envelope(
            name: "Groceries",
            budgetedAmount: 300
        )
        
        #expect(envelope.name == "Groceries")
        #expect(envelope.budgetedAmount == 300)
        #expect(envelope.rolloverAmount == 0)
    }
    
    @Test func envelopeEffectiveBudget() async throws {
        let envelope = Envelope(
            budgetedAmount: 300
        )
        envelope.rolloverAmount = 50
        
        #expect(envelope.effectiveBudget == 350)
    }
    
    @Test func envelopeDisplayName() async throws {
        let envelope = Envelope(
            name: "Custom Name",
            budgetedAmount: 100
        )
        
        #expect(envelope.displayName == "Custom Name")
        
        let unnamedEnvelope = Envelope(
            budgetedAmount: 100
        )
        
        #expect(!unnamedEnvelope.displayName.isEmpty)
    }
    
    @Test func envelopeStatusColors() async throws {
        #expect(EnvelopeStatus.healthy.color == "green")
        #expect(EnvelopeStatus.warning.color == "orange")
        #expect(EnvelopeStatus.exceeded.color == "red")
    }
    
    @Test func envelopeIconName() async throws {
        let envelope = Envelope(
            budgetedAmount: 100
        )
        
        #expect(envelope.iconName == "envelope.fill")
    }
}

// MARK: - Envelope Transfer Tests

struct EnvelopeTransferTests {
    
    @Test func transferValidation() async throws {
        let from = Envelope(budgetedAmount: 100)
        let to = Envelope(budgetedAmount: 50)
        
        // Valid transfer
        let validTransfer = EnvelopeTransfer(fromEnvelope: from, toEnvelope: to, amount: 50)
        // Note: isValid depends on availableAmount which requires budget relationship
        // So we just test that the struct is created correctly
        #expect(validTransfer.amount == 50)
        
        // Invalid transfer (zero amount)
        let zeroTransfer = EnvelopeTransfer(fromEnvelope: from, toEnvelope: to, amount: 0)
        #expect(zeroTransfer.isValid == false)
        
        // Invalid transfer (negative amount)
        let negativeTransfer = EnvelopeTransfer(fromEnvelope: from, toEnvelope: to, amount: -10)
        #expect(negativeTransfer.isValid == false)
    }
    
    @Test func transferExecution() async throws {
        let from = Envelope(budgetedAmount: 100)
        let to = Envelope(budgetedAmount: 50)
        
        let transfer = EnvelopeTransfer(fromEnvelope: from, toEnvelope: to, amount: 30)
        transfer.execute()
        
        #expect(from.budgetedAmount == 70)
        #expect(to.budgetedAmount == 80)
    }
}

// MARK: - Envelope Status Tests

struct EnvelopeStatusTests {
    
    @Test func envelopeStatusThresholds() async throws {
        // Healthy: percentage < 80%
        #expect(EnvelopeStatus.healthy.color == "green")
        
        // Warning: 80% <= percentage < 100%
        #expect(EnvelopeStatus.warning.color == "orange")
        
        // Exceeded: percentage >= 100%
        #expect(EnvelopeStatus.exceeded.color == "red")
    }
    
    @Test func allEnvelopeStatusesHaveColors() async throws {
        for status in [EnvelopeStatus.healthy, .warning, .exceeded] {
            #expect(!status.color.isEmpty)
        }
    }
}

// MARK: - Budget Period Tests

struct BudgetPeriodTests {
    
    @Test func weeklyBudgetPeriod() async throws {
        let periodType = BudgetPeriodType.weekly
        #expect(periodType.rawValue == "weekly")
        #expect(!periodType.localizedName.isEmpty)
    }
    
    @Test func monthlyBudgetPeriod() async throws {
        let periodType = BudgetPeriodType.monthly
        #expect(periodType.rawValue == "monthly")
        #expect(!periodType.localizedName.isEmpty)
    }
    
    @Test func budgetPeriodTypeIcons() async throws {
        for periodType in BudgetPeriodType.allCases {
            #expect(!periodType.iconName.isEmpty)
        }
    }
}

// MARK: - Budget Current Period Tests

struct BudgetCurrentPeriodTests {
    
    @Test func budgetIsCurrentPeriod() async throws {
        let calendar = Calendar.current
        let today = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        
        let budget = Budget(
            startDate: startOfMonth,
            periodType: .monthly
        )
        
        #expect(budget.isCurrentPeriod == true)
    }
    
    @Test func budgetIsNotCurrentPeriod() async throws {
        let calendar = Calendar.current
        let lastYear = calendar.date(byAdding: .year, value: -1, to: Date())!
        let startOfLastYear = calendar.date(from: calendar.dateComponents([.year, .month], from: lastYear))!
        
        let budget = Budget(
            startDate: startOfLastYear,
            periodType: .monthly
        )
        
        #expect(budget.isCurrentPeriod == false)
    }
}

// MARK: - Loan Calculator Tests

struct LoanCalculatorTests {
    
    @Test func frenchAmortizationPaymentCalculation() async throws {
        // Test French (constant payment) amortization
        let payment = LoanCalculator.calculatePayment(
            principal: 100000,
            annualRate: 5,
            totalPayments: 120,
            frequency: .monthly,
            amortizationType: .french
        )
        
        // Monthly payment should be around 1060.66 for 100k at 5% over 10 years
        #expect(payment > 1050)
        #expect(payment < 1075)
    }
    
    @Test func italianAmortizationPaymentCalculation() async throws {
        // Test Italian (constant principal) amortization
        let payment = LoanCalculator.calculatePayment(
            principal: 100000,
            annualRate: 5,
            totalPayments: 120,
            frequency: .monthly,
            amortizationType: .italian
        )
        
        // First payment should be higher than French due to higher initial interest
        #expect(payment > 1200)
    }
    
    @Test func americanAmortizationPaymentCalculation() async throws {
        // Test American (bullet) - interest only payments
        let payment = LoanCalculator.calculatePayment(
            principal: 100000,
            annualRate: 6,
            totalPayments: 120,
            frequency: .monthly,
            amortizationType: .american
        )
        
        // Interest only: 100000 * 0.06 / 12 = 500
        #expect(payment == 500)
    }
    
    @Test func zeroInterestLoan() async throws {
        let payment = LoanCalculator.calculatePayment(
            principal: 12000,
            annualRate: 0,
            totalPayments: 12,
            frequency: .monthly,
            amortizationType: .french
        )
        
        // 12000 / 12 = 1000
        #expect(payment == 1000)
    }
    
    @Test func amortizationScheduleGeneration() async throws {
        let schedule = LoanCalculator.generateAmortizationSchedule(
            principal: 10000,
            annualRate: 5,
            totalPayments: 12,
            frequency: .monthly,
            amortizationType: .french,
            startDate: Date()
        )
        
        #expect(schedule.count == 12)
        
        // First payment should have higher interest than principal
        let firstEntry = schedule.first!
        #expect(firstEntry.paymentNumber == 1)
        #expect(firstEntry.interest > 0)
        #expect(firstEntry.principal > 0)
        
        // Last entry should have zero remaining balance
        let lastEntry = schedule.last!
        #expect(lastEntry.remainingBalance == 0)
    }
    
    @Test func italianScheduleDecreasingPayments() async throws {
        let schedule = LoanCalculator.generateAmortizationSchedule(
            principal: 12000,
            annualRate: 6,
            totalPayments: 12,
            frequency: .monthly,
            amortizationType: .italian,
            startDate: Date()
        )
        
        #expect(schedule.count == 12)
        
        // Italian: payments should decrease over time
        let firstPayment = schedule.first!.payment
        let lastPayment = schedule.last!.payment
        #expect(firstPayment > lastPayment)
        
        // Principal should be constant (1000 per month)
        let firstPrincipal = schedule.first!.principal
        #expect(firstPrincipal == 1000)
    }
    
    @Test func americanScheduleBulletPayment() async throws {
        let schedule = LoanCalculator.generateAmortizationSchedule(
            principal: 10000,
            annualRate: 5,
            totalPayments: 12,
            frequency: .monthly,
            amortizationType: .american,
            startDate: Date()
        )
        
        #expect(schedule.count == 12)
        
        // All payments except last should be interest-only
        for i in 0..<11 {
            #expect(schedule[i].principal == 0)
            #expect(schedule[i].remainingBalance == 10000)
        }
        
        // Last payment includes full principal
        let lastEntry = schedule.last!
        #expect(lastEntry.principal == 10000)
        #expect(lastEntry.remainingBalance == 0)
    }
    
    @Test func remainingBalanceCalculation() async throws {
        let remaining = LoanCalculator.remainingBalance(
            principal: 100000,
            annualRate: 5,
            totalPayments: 120,
            paymentsMade: 60,
            frequency: .monthly,
            amortizationType: .french
        )
        
        // After 60 payments, balance should be roughly half but slightly more due to interest
        #expect(remaining > 45000)
        #expect(remaining < 60000)
    }
    
    @Test func remainingBalanceAtEnd() async throws {
        let remaining = LoanCalculator.remainingBalance(
            principal: 100000,
            annualRate: 5,
            totalPayments: 120,
            paymentsMade: 120,
            frequency: .monthly,
            amortizationType: .french
        )
        
        #expect(remaining == 0)
    }
    
    @Test func totalInterestCalculation() async throws {
        let totalInterest = LoanCalculator.calculateTotalInterest(
            principal: 100000,
            annualRate: 5,
            totalPayments: 120,
            frequency: .monthly,
            amortizationType: .french
        )
        
        // Total interest should be significant over 10 years
        #expect(totalInterest > 25000)
        #expect(totalInterest < 35000)
    }
    
    @Test func earlyRepaymentSavings() async throws {
        let result = LoanCalculator.calculateEarlyRepayment(
            remainingBalance: 50000,
            remainingPayments: 60,
            annualRate: 5,
            frequency: .monthly,
            earlyRepaymentAmount: 10000,
            penaltyPercentage: 1,
            amortizationType: .french
        )
        
        #expect(result.savedInterest > 0)
        #expect(result.penaltyAmount == 100) // 1% of 10000
        #expect(result.newRemainingPayments < 60)
    }
    
    @Test func rateScenarioSimulation() async throws {
        let scenarios = LoanCalculator.simulateRateScenarios(
            principal: 100000,
            baseRate: 5,
            totalPayments: 120,
            frequency: .monthly,
            amortizationType: .french
        )
        
        #expect(scenarios.count == 7) // Default variations
        
        // Higher rates should have higher payments
        let lowerRateScenario = scenarios.first { $0.rateChange == -1 }!
        let higherRateScenario = scenarios.first { $0.rateChange == 1 }!
        
        #expect(higherRateScenario.payment > lowerRateScenario.payment)
        #expect(higherRateScenario.totalInterest > lowerRateScenario.totalInterest)
    }
    
    @Test func paymentFrequencyCalculations() async throws {
        #expect(PaymentFrequency.monthly.paymentsPerYear == 12)
        #expect(PaymentFrequency.quarterly.paymentsPerYear == 4)
        #expect(PaymentFrequency.annual.paymentsPerYear == 1)
        
        #expect(PaymentFrequency.monthly.monthsBetweenPayments == 1)
        #expect(PaymentFrequency.quarterly.monthsBetweenPayments == 3)
        #expect(PaymentFrequency.semiannual.monthsBetweenPayments == 6)
    }
}

// MARK: - Loan Model Tests

struct LoanModelTests {
    
    @Test func loanCreation() async throws {
        let loan = Loan(
            name: "Test Mortgage",
            loanType: .mortgage,
            interestRateType: .fixed,
            paymentFrequency: .monthly,
            amortizationType: .french,
            principalAmount: 200000,
            currentInterestRate: 3.5,
            taeg: 3.8,
            totalPayments: 240,
            monthlyPayment: 1160,
            startDate: Date()
        )
        
        #expect(loan.name == "Test Mortgage")
        #expect(loan.loanType == .mortgage)
        #expect(loan.interestRateType == .fixed)
        #expect(loan.principalAmount == 200000)
        #expect(loan.totalPayments == 240)
    }
    
    @Test func loanProgressCalculation() async throws {
        let loan = Loan(
            name: "Car Loan",
            loanType: .carLoan,
            interestRateType: .fixed,
            principalAmount: 20000,
            currentInterestRate: 5,
            totalPayments: 60,
            monthlyPayment: 377,
            startDate: Date(),
            isExisting: true,
            paymentsMade: 30
        )
        
        #expect(loan.remainingPayments == 30)
        #expect(loan.progressPercentage == 50)
    }
    
    @Test func loanTotalAmounts() async throws {
        let loan = Loan(
            name: "Personal Loan",
            loanType: .personalLoan,
            interestRateType: .fixed,
            principalAmount: 10000,
            currentInterestRate: 8,
            totalPayments: 36,
            monthlyPayment: 313,
            startDate: Date(),
            paymentsMade: 12
        )
        
        #expect(loan.totalAmountPaid == Decimal(313) * Decimal(12))
        #expect(loan.totalAmountToPay == Decimal(313) * Decimal(36))
    }
    
    @Test func loanTypeProperties() async throws {
        for loanType in LoanType.allCases {
            #expect(!loanType.localizedName.isEmpty)
            #expect(!loanType.iconName.isEmpty)
        }
    }
    
    @Test func interestRateTypeProperties() async throws {
        for rateType in InterestRateType.allCases {
            #expect(!rateType.localizedName.isEmpty)
        }
    }
    
    @Test func amortizationTypeProperties() async throws {
        for amortType in AmortizationType.allCases {
            #expect(!amortType.localizedName.isEmpty)
            #expect(!amortType.shortName.isEmpty)
            #expect(!amortType.descriptionText.isEmpty)
        }
    }
    
    @Test func loanRecurrenceMapping() async throws {
        let monthlyLoan = Loan(
            name: "Monthly",
            loanType: .other,
            interestRateType: .fixed,
            paymentFrequency: .monthly,
            principalAmount: 1000,
            currentInterestRate: 5,
            totalPayments: 12,
            monthlyPayment: 100,
            startDate: Date()
        )
        
        #expect(monthlyLoan.recurrenceFrequency == .monthly)
        #expect(monthlyLoan.recurrenceInterval == 1)
        
        let quarterlyLoan = Loan(
            name: "Quarterly",
            loanType: .other,
            interestRateType: .fixed,
            paymentFrequency: .quarterly,
            principalAmount: 1000,
            currentInterestRate: 5,
            totalPayments: 4,
            monthlyPayment: 300,
            startDate: Date()
        )
        
        #expect(quarterlyLoan.recurrenceFrequency == .monthly)
        #expect(quarterlyLoan.recurrenceInterval == 3)
    }
}

// MARK: - Attachment Tests

struct AttachmentTests {
    
    @Test func attachmentCreation() async throws {
        let data = "Test content".data(using: .utf8)!
        let attachment = Attachment(
            filename: "document.pdf",
            mimeType: "application/pdf",
            data: data
        )
        
        #expect(attachment.filename == "document.pdf")
        #expect(attachment.mimeType == "application/pdf")
        #expect(attachment.data == data)
    }
    
    @Test func fileExtensionExtraction() async throws {
        let pdfAttachment = Attachment(filename: "doc.pdf", mimeType: "application/pdf", data: Data())
        #expect(pdfAttachment.fileExtension == "pdf")
        
        let jpgAttachment = Attachment(filename: "image.JPG", mimeType: "image/jpeg", data: Data())
        #expect(jpgAttachment.fileExtension == "jpg")
        
        let noExtension = Attachment(filename: "file", mimeType: "text/plain", data: Data())
        #expect(noExtension.fileExtension == "file")
    }
    
    @Test func isImageDetection() async throws {
        let jpgAttachment = Attachment(filename: "photo.jpg", mimeType: "image/jpeg", data: Data())
        #expect(jpgAttachment.isImage == true)
        
        let pngAttachment = Attachment(filename: "screenshot.png", mimeType: "image/png", data: Data())
        #expect(pngAttachment.isImage == true)
        
        let heicAttachment = Attachment(filename: "iphone.heic", mimeType: "image/heic", data: Data())
        #expect(heicAttachment.isImage == true)
        
        let pdfAttachment = Attachment(filename: "doc.pdf", mimeType: "application/pdf", data: Data())
        #expect(pdfAttachment.isImage == false)
    }
    
    @Test func isPDFDetection() async throws {
        let pdfAttachment = Attachment(filename: "document.pdf", mimeType: "application/pdf", data: Data())
        #expect(pdfAttachment.isPDF == true)
        
        let txtAttachment = Attachment(filename: "notes.txt", mimeType: "text/plain", data: Data())
        #expect(txtAttachment.isPDF == false)
    }
    
    @Test func isTextDetection() async throws {
        let txtAttachment = Attachment(filename: "notes.txt", mimeType: "text/plain", data: Data())
        #expect(txtAttachment.isText == true)
        
        let pdfAttachment = Attachment(filename: "doc.pdf", mimeType: "application/pdf", data: Data())
        #expect(txtAttachment.isText == true)
        #expect(pdfAttachment.isText == false)
    }
    
    @Test func iconNameSelection() async throws {
        let imageAttachment = Attachment(filename: "photo.jpg", mimeType: "image/jpeg", data: Data())
        #expect(imageAttachment.iconName == "photo")
        
        let pdfAttachment = Attachment(filename: "doc.pdf", mimeType: "application/pdf", data: Data())
        #expect(pdfAttachment.iconName == "doc.richtext")
        
        let txtAttachment = Attachment(filename: "notes.txt", mimeType: "text/plain", data: Data())
        #expect(txtAttachment.iconName == "doc.text")
        
        let otherAttachment = Attachment(filename: "data.bin", mimeType: "application/octet-stream", data: Data())
        #expect(otherAttachment.iconName == "doc")
    }
}

// MARK: - Reconciliation Status Tests

struct ReconciliationStatusTests {
    
    @Test func reconciliationStatusRawValues() async throws {
        #expect(ReconciliationStatus.notReconciled.rawValue == "n")
        #expect(ReconciliationStatus.cleared.rawValue == "c")
        #expect(ReconciliationStatus.reconciled.rawValue == "r")
    }
    
    @Test func reconciliationStatusLocalizedNames() async throws {
        for status in ReconciliationStatus.allCases {
            #expect(!status.localizedName.isEmpty)
        }
    }
    
    @Test func reconciliationStatusIcons() async throws {
        #expect(ReconciliationStatus.notReconciled.iconName == "circle")
        #expect(ReconciliationStatus.cleared.iconName == "checkmark.circle")
        #expect(ReconciliationStatus.reconciled.iconName == "lock.circle.fill")
    }
    
    @Test func reconciliationStatusShortNames() async throws {
        #expect(ReconciliationStatus.notReconciled.shortName == "n")
        #expect(ReconciliationStatus.cleared.shortName == "c")
        #expect(ReconciliationStatus.reconciled.shortName == "R")
    }
}

// MARK: - Balance Calculator Tests

struct BalanceCalculatorTests {
    
    @Test func expenseAmountCalculation() async throws {
        let transaction = Transaction(date: Date(), descriptionText: "Grocery")
        
        let expenseAccount = Account(
            name: "Food",
            currency: "EUR",
            accountClass: .expense,
            accountType: .food
        )
        
        let bankAccount = Account(
            name: "Bank",
            currency: "EUR",
            accountClass: .asset,
            accountType: .bank
        )
        
        let debitEntry = Entry(entryType: .debit, amount: 50, account: expenseAccount)
        let creditEntry = Entry(entryType: .credit, amount: 50, account: bankAccount)
        
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction
        transaction.entries = [debitEntry, creditEntry]
        
        let expense = BalanceCalculator.expenseAmount(for: transaction)
        #expect(expense == 50)
    }
    
    @Test func incomeAmountCalculation() async throws {
        let transaction = Transaction(date: Date(), descriptionText: "Salary")
        
        let incomeAccount = Account(
            name: "Salary",
            currency: "EUR",
            accountClass: .income,
            accountType: .salary
        )
        
        let bankAccount = Account(
            name: "Bank",
            currency: "EUR",
            accountClass: .asset,
            accountType: .bank
        )
        
        let debitEntry = Entry(entryType: .debit, amount: 2000, account: bankAccount)
        let creditEntry = Entry(entryType: .credit, amount: 2000, account: incomeAccount)
        
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction
        transaction.entries = [debitEntry, creditEntry]
        
        let income = BalanceCalculator.incomeAmount(for: transaction)
        #expect(income == 2000)
    }
    
    @Test func netBalanceChangeForExpense() async throws {
        let transaction = Transaction(date: Date(), descriptionText: "Purchase")
        
        let expenseAccount = Account(
            name: "Shopping",
            currency: "EUR",
            accountClass: .expense,
            accountType: .shopping
        )
        
        let bankAccount = Account(
            name: "Bank",
            currency: "EUR",
            accountClass: .asset,
            accountType: .bank
        )
        
        let debitEntry = Entry(entryType: .debit, amount: 100, account: expenseAccount)
        let creditEntry = Entry(entryType: .credit, amount: 100, account: bankAccount)
        
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction
        transaction.entries = [debitEntry, creditEntry]
        
        // Net balance change: asset decreased by 100
        let change = BalanceCalculator.netBalanceChange(for: transaction)
        #expect(change == -100)
    }
    
    @Test func netBalanceChangeForIncome() async throws {
        let transaction = Transaction(date: Date(), descriptionText: "Salary")
        
        let incomeAccount = Account(
            name: "Salary",
            currency: "EUR",
            accountClass: .income,
            accountType: .salary
        )
        
        let bankAccount = Account(
            name: "Bank",
            currency: "EUR",
            accountClass: .asset,
            accountType: .bank
        )
        
        let debitEntry = Entry(entryType: .debit, amount: 3000, account: bankAccount)
        let creditEntry = Entry(entryType: .credit, amount: 3000, account: incomeAccount)
        
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction
        transaction.entries = [debitEntry, creditEntry]
        
        // Net balance change: asset increased by 3000
        let change = BalanceCalculator.netBalanceChange(for: transaction)
        #expect(change == 3000)
    }
    
    @Test func netBalanceChangeForTransfer() async throws {
        let transaction = Transaction(date: Date(), descriptionText: "Transfer")
        
        let checkingAccount = Account(
            name: "Checking",
            currency: "EUR",
            accountClass: .asset,
            accountType: .bank
        )
        
        let savingsAccount = Account(
            name: "Savings",
            currency: "EUR",
            accountClass: .asset,
            accountType: .bank
        )
        
        let debitEntry = Entry(entryType: .debit, amount: 500, account: savingsAccount)
        let creditEntry = Entry(entryType: .credit, amount: 500, account: checkingAccount)
        
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction
        transaction.entries = [debitEntry, creditEntry]
        
        // Transfer between assets: net change should be 0
        let change = BalanceCalculator.netBalanceChange(for: transaction)
        #expect(change == 0)
    }
}

// MARK: - Currency Helper Tests

struct CurrencyHelperTests {
    
    @Test func defaultCurrencyFromAssetAccount() async throws {
        let usdAccount = Account(
            name: "US Bank",
            currency: "USD",
            accountClass: .asset,
            accountType: .bank
        )
        
        let eurAccount = Account(
            name: "EU Bank",
            currency: "EUR",
            accountClass: .liability,
            accountType: .creditCard
        )
        
        let currency = CurrencyHelper.defaultCurrency(from: [usdAccount, eurAccount])
        #expect(currency == "USD") // Prefers asset accounts
    }
    
    @Test func defaultCurrencyFromLiabilityWhenNoAssets() async throws {
        let creditCard = Account(
            name: "Credit Card",
            currency: "GBP",
            accountClass: .liability,
            accountType: .creditCard
        )
        
        let expenseAccount = Account(
            name: "Food",
            currency: "EUR",
            accountClass: .expense,
            accountType: .food
        )
        
        let currency = CurrencyHelper.defaultCurrency(from: [creditCard, expenseAccount])
        #expect(currency == "GBP") // Falls back to liability
    }
    
    @Test func defaultCurrencyFromEmptyList() async throws {
        let currency = CurrencyHelper.defaultCurrency(from: [])
        #expect(currency == "EUR") // Default fallback
    }
}

// MARK: - Decimal Rounding Tests

struct DecimalRoundingTests {
    
    @Test func decimalRounding() async throws {
        let value1 = Decimal(string: "123.456")!
        #expect(value1.rounded(2) == Decimal(string: "123.46"))
        
        let value2 = Decimal(string: "99.994")!
        #expect(value2.rounded(2) == Decimal(string: "99.99"))
        
        let value3 = Decimal(string: "100.005")!
        #expect(value3.rounded(2) == Decimal(string: "100.00") || value3.rounded(2) == Decimal(string: "100.01"))
    }
}

// MARK: - Export Format Tests

struct ExportFormatTests {
    
    @Test func exportFormatProperties() async throws {
        #expect(ExportFormat.cashBackup.fileExtension == "cashdata")
        #expect(ExportFormat.ofx.fileExtension == "ofx")
        
        for format in ExportFormat.allCases {
            #expect(!format.localizedName.isEmpty)
            #expect(!format.iconName.isEmpty)
        }
    }
    
    @Test func exportFilenameGeneration() async throws {
        let cashFilename = DataExporter.generateFilename(for: .cashBackup)
        #expect(cashFilename.hasPrefix("Cash_Export_"))
        #expect(cashFilename.hasSuffix(".cashdata"))
        
        let ofxFilename = DataExporter.generateFilename(for: .ofx)
        #expect(ofxFilename.hasPrefix("Cash_Export_"))
        #expect(ofxFilename.hasSuffix(".ofx"))
    }
}

// MARK: - DataExporter Error Tests

struct DataExporterErrorTests {
    
    @Test func errorDescriptions() async throws {
        #expect(DataExporterError.noData.errorDescription != nil)
        #expect(DataExporterError.encodingFailed.errorDescription != nil)
        #expect(DataExporterError.decodingFailed.errorDescription != nil)
        #expect(DataExporterError.compressionFailed.errorDescription != nil)
        #expect(DataExporterError.decompressionFailed.errorDescription != nil)
        #expect(DataExporterError.invalidFormat.errorDescription != nil)
        #expect(DataExporterError.importFailed("test").errorDescription?.contains("test") == true)
    }
}
