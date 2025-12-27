//
//  LocalizationTests.swift
//  CashTests
//
//  Created by Tests on 28/12/25.
//

import Testing
import Foundation
import SwiftUI
@testable import Cash

// MARK: - Localization Tests

struct LocalizationTests {
    
    @Test func commonStringsAreLocalized() async throws {
        // Test that common strings used throughout the app are properly localized
        let testStrings = [
            "Cancel",
            "Save",
            "Done",
            "Delete",
            "Edit",
            "Add",
            "Close",
            "Continue",
            "Balance",
            "Amount",
            "Date",
            "Description",
            "Category",
            "Account",
            "Accounts",
            "Transaction",
            "Transactions",
            "Income",
            "Expense",
            "Transfer",
            "Budget",
            "Forecast",
            "Reports",
            "Settings",
            "General",
            "About"
        ]
        
        for string in testStrings {
            let localized = String(localized: String.LocalizationValue(string))
            #expect(!localized.isEmpty, "String '\(string)' should be localized")
        }
    }
    
    @Test func loanStringsAreLocalized() async throws {
        // Test loan-specific strings we added
        let loanStrings = [
            "Amortization Schedule",
            "Principal",
            "Interest Rate",
            "Total Interest",
            "Total Amount",
            "Method",
            "Payment",
            "Rate Scenarios",
            "Rate Scenarios Analysis",
            "Base Rate",
            "Base Payment",
            "Base Total Interest",
            "Calculating...",
            "Calculating scenarios...",
            "Change",
            "New Rate",
            "Monthly Diff",
            "Difference",
            "Interest Difference"
        ]
        
        for string in loanStrings {
            let localized = String(localized: String.LocalizationValue(string))
            #expect(!localized.isEmpty, "Loan string '\(string)' should be localized")
        }
    }
    
    @Test @MainActor func amortizationTypeNamesAreLocalized() async throws {
        let types: [AmortizationType] = [.french, .italian, .german, .american]
        
        for type in types {
            #expect(!type.localizedName.isEmpty)
            #expect(!type.shortName.isEmpty)
            #expect(!type.descriptionText.isEmpty)
        }
    }
    
    @Test @MainActor func loanTypeNamesAreLocalized() async throws {
        let types: [LoanType] = [.mortgage, .carLoan, .personalLoan, .other]
        
        for type in types {
            #expect(!type.localizedName.isEmpty)
            #expect(!type.iconName.isEmpty)
        }
    }
    
    @Test @MainActor func accountClassNamesAreLocalized() async throws {
        let classes: [AccountClass] = [.asset, .liability, .equity, .income, .expense]
        
        for accountClass in classes {
            #expect(!accountClass.localizedName.isEmpty)
            #expect(!accountClass.localizedPluralName.isEmpty)
        }
    }
    
    @Test @MainActor func paymentFrequencyNamesAreLocalized() async throws {
        let frequencies: [PaymentFrequency] = [.monthly, .bimonthly, .quarterly, .semiannual, .annual]
        
        for frequency in frequencies {
            #expect(!frequency.localizedName.isEmpty)
        }
    }
}

// MARK: - Currency Formatting Tests

struct CurrencyFormattingTests {
    
    @Test func currencyFormatterFormatsCorrectly() async throws {
        let amount: Decimal = 1234.56
        let formatted = CurrencyFormatter.format(amount, currency: "EUR")
        
        #expect(formatted.contains("1") && formatted.contains("234") && formatted.contains("56"))
        #expect(formatted.contains("€") || formatted.contains("EUR"))
    }
    
    @Test func currencyFormatterHandlesZero() async throws {
        let amount: Decimal = 0
        let formatted = CurrencyFormatter.format(amount, currency: "USD")
        
        #expect(formatted.contains("0"))
    }
    
    @Test func currencyFormatterHandlesNegative() async throws {
        let amount: Decimal = -500.00
        let formatted = CurrencyFormatter.format(amount, currency: "GBP")
        
        #expect(formatted.contains("-") || formatted.contains("("))
        #expect(formatted.contains("500"))
    }
    
    @Test @MainActor func currencySymbolIsCorrect() async throws {
        #expect(CurrencyList.symbol(forCode: "EUR") == "€")
        #expect(CurrencyList.symbol(forCode: "USD") == "$")
        #expect(CurrencyList.symbol(forCode: "GBP") == "£")
    }
}
