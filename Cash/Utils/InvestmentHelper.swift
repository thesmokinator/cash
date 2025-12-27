//
//  InvestmentHelper.swift
//  Cash
//
//  Created by Michele Broggi on 27/12/25.
//

import Foundation
import SwiftData

/// Helper class for investment calculations
final class InvestmentHelper {
    
    // MARK: - Position Calculation
    
    /// Calculate the current position for an investment account
    /// Uses average cost method (ACM) for cost basis
    static func calculatePosition(
        for account: Account,
        currentPrice: Decimal? = nil
    ) -> InvestmentPosition {
        guard account.accountType == .investment else {
            return .empty
        }
        
        // Get all investment transactions for this account
        let transactions = getInvestmentTransactions(for: account)
        
        var totalShares: Decimal = 0
        var totalCost: Decimal = 0
        
        for transaction in transactions {
            guard let investmentType = transaction.investmentType else { continue }
            
            let shares = transaction.shares ?? 0
            let pricePerShare = transaction.pricePerShare ?? 0
            let fees = transaction.fees ?? 0
            
            switch investmentType {
            case .buy:
                totalShares += shares
                totalCost += (shares * pricePerShare) + fees
                
            case .sell:
                let sharesSold = min(shares, totalShares)
                let avgCost = totalShares > 0 ? totalCost / totalShares : 0
                totalShares -= sharesSold
                totalCost -= sharesSold * avgCost
                
            case .dividend:
                // Dividends don't affect shares or cost basis
                break
                
            case .split:
                // For splits, shares change but cost basis doesn't
                // shares field represents the multiplier (e.g., 2 for 2:1 split)
                if shares > 0 {
                    totalShares = totalShares * shares
                }
            }
        }
        
        // Ensure no negative values due to rounding
        totalShares = max(0, totalShares)
        totalCost = max(0, totalCost)
        
        let averageCost = totalShares > 0 ? totalCost / totalShares : 0
        
        // Calculate market value and gains if price is available
        var marketValue: Decimal? = nil
        var unrealizedGain: Decimal? = nil
        var unrealizedGainPercent: Decimal? = nil
        
        if let price = currentPrice, totalShares > 0 {
            marketValue = totalShares * price
            unrealizedGain = marketValue! - totalCost
            
            if totalCost > 0 {
                unrealizedGainPercent = (unrealizedGain! / totalCost) * 100
            }
        }
        
        return InvestmentPosition(
            shares: totalShares,
            totalCost: totalCost,
            averageCost: averageCost,
            marketValue: marketValue,
            unrealizedGain: unrealizedGain,
            unrealizedGainPercent: unrealizedGainPercent
        )
    }
    
    // MARK: - Transaction Helpers
    
    /// Get all investment transactions for an account, sorted by date
    static func getInvestmentTransactions(for account: Account) -> [Transaction] {
        // Get all transactions that have entries to this account
        // and have investment-specific data
        var investmentTransactions: [Transaction] = []
        
        // Collect all transactions from entries
        let transactions = Set((account.entries ?? []).compactMap { $0.transaction })
        
        for transaction in transactions {
            if transaction.investmentType != nil {
                investmentTransactions.append(transaction)
            }
        }
        
        // Sort by date
        return investmentTransactions.sorted { $0.date < $1.date }
    }
    
    /// Calculate total dividends received for an account
    static func calculateTotalDividends(for account: Account) -> Decimal {
        let transactions = getInvestmentTransactions(for: account)
        
        return transactions
            .filter { $0.investmentType == .dividend }
            .reduce(0) { sum, transaction in
                let amount = (transaction.entries ?? [])
                    .filter { $0.entryType == .credit }
                    .reduce(Decimal(0)) { $0 + $1.amount }
                return sum + amount
            }
    }
    
    /// Calculate realized gains/losses from sells
    static func calculateRealizedGains(for account: Account) -> Decimal {
        let transactions = getInvestmentTransactions(for: account)
        
        var totalShares: Decimal = 0
        var totalCost: Decimal = 0
        var realizedGains: Decimal = 0
        
        for transaction in transactions {
            guard let investmentType = transaction.investmentType else { continue }
            
            let shares = transaction.shares ?? 0
            let pricePerShare = transaction.pricePerShare ?? 0
            let fees = transaction.fees ?? 0
            
            switch investmentType {
            case .buy:
                totalShares += shares
                totalCost += (shares * pricePerShare) + fees
                
            case .sell:
                let avgCost = totalShares > 0 ? totalCost / totalShares : 0
                let sharesSold = min(shares, totalShares)
                let proceeds = (sharesSold * pricePerShare) - fees
                let costBasis = sharesSold * avgCost
                
                realizedGains += proceeds - costBasis
                
                totalShares -= sharesSold
                totalCost -= sharesSold * avgCost
                
            case .dividend, .split:
                break
            }
        }
        
        return realizedGains
    }
    
    // MARK: - Validation
    
    /// Validate an investment transaction before saving
    static func validateTransaction(
        type: InvestmentTransactionType,
        shares: Decimal?,
        pricePerShare: Decimal?,
        amount: Decimal?,
        investmentAccount: Account?,
        cashAccount: Account?
    ) -> [String] {
        var errors: [String] = []
        
        if investmentAccount == nil {
            errors.append(String(localized: "Please select an investment account"))
        }
        
        switch type {
        case .buy, .sell:
            if shares == nil || shares! <= 0 {
                errors.append(String(localized: "Please enter a valid number of shares"))
            }
            if pricePerShare == nil || pricePerShare! <= 0 {
                errors.append(String(localized: "Please enter a valid price per share"))
            }
            if cashAccount == nil {
                errors.append(String(localized: "Please select a cash account for the transaction"))
            }
            
            // For sell, check if there are enough shares
            if type == .sell, let account = investmentAccount {
                let position = calculatePosition(for: account)
                if let sharesToSell = shares, sharesToSell > position.shares {
                    errors.append(String(localized: "You cannot sell more shares than you own (\(formatShares(position.shares)) available)"))
                }
            }
            
        case .dividend:
            if amount == nil || amount! <= 0 {
                errors.append(String(localized: "Please enter a valid dividend amount"))
            }
            if cashAccount == nil {
                errors.append(String(localized: "Please select a cash account to receive the dividend"))
            }
            
        case .split:
            if shares == nil || shares! <= 0 {
                errors.append(String(localized: "Please enter a valid split ratio"))
            }
        }
        
        return errors
    }
    
    // MARK: - Formatting
    
    /// Format shares with appropriate precision
    static func formatShares(_ shares: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.groupingSeparator = ","
        return formatter.string(from: shares as NSDecimalNumber) ?? "\(shares)"
    }
    
    /// Format price with currency
    static func formatPrice(_ price: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: price as NSDecimalNumber) ?? "\(price)"
    }
    
    /// Format percentage with sign
    static func formatPercentage(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        return (formatter.string(from: value as NSDecimalNumber) ?? "\(value)") + "%"
    }
    
    /// Format gain/loss with color hint
    static func formatGainLoss(_ value: Decimal, currency: String) -> (text: String, isPositive: Bool) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        
        let text = formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
        return (text, value >= 0)
    }
}
