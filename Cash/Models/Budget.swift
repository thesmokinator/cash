//
//  Budget.swift
//  Cash
//
//  Created by Michele Broggi on 28/11/25.
//

import Foundation
import SwiftData

// MARK: - Budget Period Type

enum BudgetPeriodType: String, Codable, CaseIterable, Identifiable {
    case weekly = "weekly"
    case monthly = "monthly"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .weekly:
            return String(localized: "Weekly")
        case .monthly:
            return String(localized: "Monthly")
        }
    }
    
    var iconName: String {
        switch self {
        case .weekly:
            return "calendar.badge.clock"
        case .monthly:
            return "calendar"
        }
    }
}

// MARK: - Budget Model

@Model
final class Budget {
    var id: UUID = UUID()
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var periodTypeRawValue: String = BudgetPeriodType.monthly.rawValue
    var isActive: Bool = true
    var rolloverEnabled: Bool = false
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \Envelope.budget)
    var envelopes: [Envelope]?
    
    var periodType: BudgetPeriodType {
        get { BudgetPeriodType(rawValue: periodTypeRawValue) ?? .monthly }
        set { periodTypeRawValue = newValue.rawValue }
    }
    
    // MARK: - Computed Properties
    
    var totalBudgeted: Decimal {
        (envelopes ?? []).reduce(Decimal.zero) { $0 + $1.budgetedAmount }
    }
    
    var totalSpent: Decimal {
        (envelopes ?? []).reduce(Decimal.zero) { $0 + $1.spentAmount }
    }
    
    var totalAvailable: Decimal {
        totalBudgeted - totalSpent
    }
    
    var percentageUsed: Double {
        guard totalBudgeted > 0 else { return 0 }
        return Double(truncating: (totalSpent / totalBudgeted * 100) as NSDecimalNumber)
    }
    
    var isOverBudget: Bool {
        totalSpent > totalBudgeted
    }
    
    var displayName: String {
        if name.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = periodType == .monthly ? "MMMM yyyy" : "'Week' w, yyyy"
            return formatter.string(from: startDate)
        }
        return name
    }
    
    var isCurrentPeriod: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    // MARK: - Initializers
    
    init(
        name: String = "",
        startDate: Date = Date(),
        periodType: BudgetPeriodType = .monthly,
        rolloverEnabled: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.periodTypeRawValue = periodType.rawValue
        self.rolloverEnabled = rolloverEnabled
        self.isActive = true
        self.createdAt = Date()
        
        // Calculate end date based on period type
        self.endDate = Budget.calculateEndDate(from: startDate, periodType: periodType)
    }
    
    // MARK: - Static Methods
    
    static func calculateEndDate(from startDate: Date, periodType: BudgetPeriodType) -> Date {
        let calendar = Calendar.current
        switch periodType {
        case .weekly:
            return calendar.date(byAdding: .day, value: 6, to: startDate) ?? startDate
        case .monthly:
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: startDate) else {
                return startDate
            }
            return calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? startDate
        }
    }
    
    static func createMonthlyBudget(for date: Date = Date(), rolloverEnabled: Bool = false) -> Budget {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        let startOfMonth = calendar.date(from: components) ?? date
        
        return Budget(
            startDate: startOfMonth,
            periodType: .monthly,
            rolloverEnabled: rolloverEnabled
        )
    }
    
    static func createWeeklyBudget(for date: Date = Date(), rolloverEnabled: Bool = false) -> Budget {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        
        return Budget(
            startDate: startOfWeek,
            periodType: .weekly,
            rolloverEnabled: rolloverEnabled
        )
    }
}

// MARK: - Envelope Model

@Model
final class Envelope {
    var id: UUID = UUID()
    var name: String = ""
    var budgetedAmount: Decimal = 0
    var colorHex: String = "#007AFF"
    var sortOrder: Int = 0
    var rolloverAmount: Decimal = 0
    var categoryAccountId: UUID? // Store Account ID for CloudKit compatibility
    
    var budget: Budget?
    
    // MARK: - Transient Properties
    @Transient
    var category: Account?
    
    // MARK: - Computed Properties
    
    var displayName: String {
        if !name.isEmpty {
            return name
        }
        return category?.displayName ?? String(localized: "Unnamed Envelope")
    }
    
    var iconName: String {
        category?.accountType.iconName ?? "envelope.fill"
    }
    
    var effectiveBudget: Decimal {
        budgetedAmount + rolloverAmount
    }
    
    var spentAmount: Decimal {
        guard let category = category,
              let budget = budget else { return 0 }
        
        let entries = category.entries ?? []
        var total: Decimal = 0
        
        for entry in entries {
            guard let transaction = entry.transaction,
                  !transaction.isRecurring,
                  transaction.date >= budget.startDate,
                  transaction.date <= budget.endDate else {
                continue
            }
            
            // For expenses: debits increase spending
            if entry.entryType == .debit {
                total += entry.amount
            } else {
                total -= entry.amount
            }
        }
        
        return max(total, 0)
    }
    
    var availableAmount: Decimal {
        effectiveBudget - spentAmount
    }
    
    var percentageUsed: Double {
        guard effectiveBudget > 0 else { return 0 }
        return min(Double(truncating: (spentAmount / effectiveBudget * 100) as NSDecimalNumber), 100)
    }
    
    var isOverBudget: Bool {
        spentAmount > effectiveBudget
    }
    
    var statusColor: EnvelopeStatus {
        let percentage = percentageUsed
        if percentage >= 100 || isOverBudget {
            return .exceeded
        } else if percentage >= 80 {
            return .warning
        } else {
            return .healthy
        }
    }
    
    // MARK: - Initializers
    
    init(
        name: String = "",
        budgetedAmount: Decimal = 0,
        category: Account? = nil,
        colorHex: String = "#007AFF",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.budgetedAmount = budgetedAmount
        self.categoryAccountId = category?.id
        self.category = category
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.rolloverAmount = 0
    }
}

// MARK: - Envelope Status

enum EnvelopeStatus {
    case healthy
    case warning
    case exceeded
    
    var color: String {
        switch self {
        case .healthy:
            return "green"
        case .warning:
            return "orange"
        case .exceeded:
            return "red"
        }
    }
}

// MARK: - Envelope Transfer

struct EnvelopeTransfer {
    let fromEnvelope: Envelope
    let toEnvelope: Envelope
    let amount: Decimal
    
    var isValid: Bool {
        amount > 0 && fromEnvelope.availableAmount >= amount
    }
    
    func execute() {
        guard isValid else { return }
        fromEnvelope.budgetedAmount -= amount
        toEnvelope.budgetedAmount += amount
    }
}
