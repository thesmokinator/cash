//
//  Report.swift
//  Cash
//
//  Created by Michele Broggi on 28/11/25.
//

import SwiftUI
import SwiftData

// MARK: - Balance Calculator

/// Utility class for calculating balance changes from transactions
struct BalanceCalculator {
    
    /// Calculate the net balance change for a transaction (considering only asset and liability accounts)
    static func netBalanceChange(for transaction: Transaction) -> Decimal {
        var change: Decimal = 0
        
        for entry in transaction.entries ?? [] {
            guard let account = entry.account else { continue }
            
            // Only consider asset and liability accounts for net worth
            if account.accountClass == .asset {
                // Assets: debits increase, credits decrease
                change += entry.entryType == .debit ? entry.amount : -entry.amount
            } else if account.accountClass == .liability {
                // Liabilities: credits increase (decrease net worth), debits decrease (increase net worth)
                change += entry.entryType == .credit ? -entry.amount : entry.amount
            }
        }
        
        return change
    }
    
    /// Calculate the expense amount for a transaction
    static func expenseAmount(for transaction: Transaction) -> Decimal {
        var total: Decimal = 0
        
        for entry in transaction.entries ?? [] {
            guard let account = entry.account,
                  account.accountClass == .expense else { continue }
            
            // Expense accounts: debits increase, credits decrease
            if entry.entryType == .debit {
                total += entry.amount
            } else {
                total -= entry.amount
            }
        }
        
        return total
    }
    
    /// Calculate the income amount for a transaction
    static func incomeAmount(for transaction: Transaction) -> Decimal {
        var total: Decimal = 0
        
        for entry in transaction.entries ?? [] {
            guard let account = entry.account,
                  account.accountClass == .income else { continue }
            
            // Income accounts: credits increase
            if entry.entryType == .credit {
                total += entry.amount
            }
        }
        
        return total
    }
}

// MARK: - Percentage Calculator

/// Utility for percentage calculations
struct PercentageCalculator {
    
    /// Calculate percentage change between two values
    static func percentageChange(from oldValue: Decimal, to newValue: Decimal) -> Double {
        guard oldValue != 0 else {
            return newValue > 0 ? 100 : (newValue < 0 ? -100 : 0)
        }
        return Double(truncating: ((newValue - oldValue) / abs(oldValue) * 100) as NSDecimalNumber)
    }
    
    /// Calculate percentage of a part relative to a whole
    static func percentage(of part: Decimal, in whole: Decimal) -> Double {
        guard whole != 0 else { return 0 }
        return Double(truncating: (part / whole * 100) as NSDecimalNumber)
    }
}

// MARK: - Linear Regression

/// Utility for trend line calculations using linear regression
struct LinearRegression {
    let slope: Double
    let intercept: Double
    
    /// Calculate linear regression from data points
    /// - Parameters:
    ///   - points: Array of (x, y) tuples
    /// - Returns: LinearRegression result or nil if calculation not possible
    static func calculate(from points: [(x: Double, y: Double)]) -> LinearRegression? {
        guard points.count >= 2 else { return nil }
        
        let n = Double(points.count)
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        let sumXY = points.reduce(0) { $0 + $1.x * $1.y }
        let sumX2 = points.reduce(0) { $0 + $1.x * $1.x }
        
        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return nil }
        
        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n
        
        return LinearRegression(slope: slope, intercept: intercept)
    }
    
    /// Predict y value for a given x
    func predict(x: Double) -> Double {
        return intercept + slope * x
    }
    
    /// Monthly change (assuming x is in days)
    var monthlyChange: Decimal {
        Decimal(slope * 30)
    }
}

// MARK: - Chart Axis Formatter

/// Utility for formatting chart axis values
struct ChartAxisFormatter {
    
    /// Format a numeric value for display on chart axis
    static func format(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if absValue >= 1_000 {
            return String(format: "%.0fK", value / 1_000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Date Range Helper

/// Utility for date range calculations
struct DateRangeHelper {
    
    /// Get date range for a number of months in the past
    static func pastMonths(_ months: Int) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .month, value: -months, to: end) ?? end
        return (start: start, end: end)
    }
    
    /// Get date range for a number of months in the future
    static func futureMonths(_ months: Int) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = Date()
        let end = calendar.date(byAdding: .month, value: months, to: start) ?? start
        return (start: start, end: end)
    }
    
    /// Check if a date is within a range
    static func isDate(_ date: Date, inRange range: (start: Date, end: Date)) -> Bool {
        return date >= range.start && date <= range.end
    }
}

// MARK: - Currency Helper

/// Utility for getting default currency from accounts
struct CurrencyHelper {
    
    /// Get default currency from a list of accounts
    static func defaultCurrency(from accounts: [Account]) -> String {
        // Prefer asset accounts, then liability, then any account
        if let assetAccount = accounts.first(where: { $0.accountClass == .asset && $0.isActive && !$0.isSystem }) {
            return assetAccount.currency
        }
        if let liabilityAccount = accounts.first(where: { $0.accountClass == .liability && $0.isActive && !$0.isSystem }) {
            return liabilityAccount.currency
        }
        return accounts.first?.currency ?? "EUR"
    }
}
