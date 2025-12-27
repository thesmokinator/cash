//
//  InvestmentTransaction.swift
//  Cash
//
//  Created by Michele Broggi on 27/12/25.
//

import Foundation

// MARK: - Investment Transaction Type

/// Types of investment transactions
enum InvestmentTransactionType: String, Codable, CaseIterable, Identifiable {
    case buy = "buy"
    case sell = "sell"
    case dividend = "dividend"
    case split = "split"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .buy:
            return String(localized: "Buy")
        case .sell:
            return String(localized: "Sell")
        case .dividend:
            return String(localized: "Dividend")
        case .split:
            return String(localized: "Stock Split")
        }
    }
    
    var iconName: String {
        switch self {
        case .buy:
            return "arrow.down.circle.fill"
        case .sell:
            return "arrow.up.circle.fill"
        case .dividend:
            return "banknote.fill"
        case .split:
            return "arrow.triangle.branch"
        }
    }
    
    var iconColor: String {
        switch self {
        case .buy:
            return "green"
        case .sell:
            return "red"
        case .dividend:
            return "blue"
        case .split:
            return "orange"
        }
    }
    
    /// Help text explaining the transaction type
    var helpText: String {
        switch self {
        case .buy:
            return String(localized: "Purchase shares of a security. Money flows from your cash account to your investment account, and you receive shares.")
        case .sell:
            return String(localized: "Sell shares of a security. Shares are removed from your investment account and money flows to your cash account.")
        case .dividend:
            return String(localized: "Cash payment from a security. Dividends are deposited to your cash account without affecting your share count.")
        case .split:
            return String(localized: "A stock split changes the number of shares you own without changing the total value. For example, a 2:1 split doubles your shares but halves the price per share.")
        }
    }
    
    /// Whether this transaction type affects cash
    var affectsCash: Bool {
        switch self {
        case .buy, .sell, .dividend:
            return true
        case .split:
            return false
        }
    }
    
    /// Whether this transaction type affects share count
    var affectsShares: Bool {
        switch self {
        case .buy, .sell, .split:
            return true
        case .dividend:
            return false
        }
    }
}

// MARK: - Investment Position

/// Represents the current position in an investment
struct InvestmentPosition {
    let shares: Decimal
    let totalCost: Decimal
    let averageCost: Decimal
    let marketValue: Decimal?
    let unrealizedGain: Decimal?
    let unrealizedGainPercent: Decimal?
    
    /// Creates an empty position
    static var empty: InvestmentPosition {
        InvestmentPosition(
            shares: 0,
            totalCost: 0,
            averageCost: 0,
            marketValue: nil,
            unrealizedGain: nil,
            unrealizedGainPercent: nil
        )
    }
    
    /// Whether the position has any shares
    var hasShares: Bool {
        shares > 0
    }
    
    /// Whether we have market data to calculate gains
    var hasMarketData: Bool {
        marketValue != nil
    }
}

// MARK: - Investment Lot

/// Represents a single purchase lot for tax tracking (future use)
struct InvestmentLot: Identifiable {
    let id: UUID
    let purchaseDate: Date
    let shares: Decimal
    let costPerShare: Decimal
    let totalCost: Decimal
    let transactionId: UUID
    
    var remainingShares: Decimal
    
    init(
        purchaseDate: Date,
        shares: Decimal,
        costPerShare: Decimal,
        transactionId: UUID
    ) {
        self.id = UUID()
        self.purchaseDate = purchaseDate
        self.shares = shares
        self.costPerShare = costPerShare
        self.totalCost = shares * costPerShare
        self.transactionId = transactionId
        self.remainingShares = shares
    }
}
