//
//  CashTests.swift
//  CashTests
//
//  Created by Michele Broggi on 25/11/25.
//

import Testing
import Foundation
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
