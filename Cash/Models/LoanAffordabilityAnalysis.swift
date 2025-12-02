//
//  LoanAffordabilityAnalysis.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import Foundation
import SwiftData

// MARK: - Affordability Level

enum AffordabilityLevel: String, CaseIterable, Identifiable {
    case comfortable = "comfortable"
    case manageable = "manageable"
    case tight = "tight"
    case risky = "risky"
    case unaffordable = "unaffordable"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .comfortable:
            return String(localized: "Comfortable")
        case .manageable:
            return String(localized: "Manageable")
        case .tight:
            return String(localized: "Tight")
        case .risky:
            return String(localized: "Risky")
        case .unaffordable:
            return String(localized: "Unaffordable")
        }
    }
    
    var iconName: String {
        switch self {
        case .comfortable:
            return "checkmark.circle.fill"
        case .manageable:
            return "checkmark.circle"
        case .tight:
            return "exclamationmark.circle"
        case .risky:
            return "exclamationmark.triangle.fill"
        case .unaffordable:
            return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .comfortable:
            return "green"
        case .manageable:
            return "blue"
        case .tight:
            return "orange"
        case .risky:
            return "red"
        case .unaffordable:
            return "red"
        }
    }
    
    var description: String {
        switch self {
        case .comfortable:
            return String(localized: "The payment fits well within your budget with room to spare.")
        case .manageable:
            return String(localized: "The payment is affordable but leaves limited savings capacity.")
        case .tight:
            return String(localized: "The payment may strain your budget. Consider a smaller loan.")
        case .risky:
            return String(localized: "High risk of financial difficulty. Strongly reconsider.")
        case .unaffordable:
            return String(localized: "This payment exceeds your available surplus. Not recommended.")
        }
    }
    
    /// Determine affordability level based on debt-to-income ratio and surplus
    static func determine(debtToIncomeRatio: Double, surplusAfterLoan: Decimal) -> AffordabilityLevel {
        // If surplus is negative, it's unaffordable
        if surplusAfterLoan < 0 {
            return .unaffordable
        }
        
        // Based on debt-to-income ratio (payment / income)
        // Standard financial guidelines:
        // < 20% = Comfortable
        // 20-28% = Manageable
        // 28-36% = Tight
        // 36-43% = Risky
        // > 43% = Unaffordable
        switch debtToIncomeRatio {
        case ..<20:
            return .comfortable
        case 20..<28:
            return .manageable
        case 28..<36:
            return .tight
        case 36..<43:
            return .risky
        default:
            return .unaffordable
        }
    }
}

// MARK: - Loan Affordability Analysis

struct LoanAffordabilityAnalysis {
    // Historical data (last 6 months)
    let averageMonthlyIncome: Decimal
    let averageMonthlyExpenses: Decimal
    let monthsAnalyzed: Int
    
    // Future recurring expenses (already scheduled)
    let scheduledRecurringExpenses: Decimal
    
    // Proposed loan
    let proposedLoanPayment: Decimal
    
    // MARK: - Computed Properties
    
    /// Current monthly surplus before the new loan
    var currentMonthlySurplus: Decimal {
        averageMonthlyIncome - averageMonthlyExpenses
    }
    
    /// Total new monthly obligations
    var totalNewObligations: Decimal {
        proposedLoanPayment + scheduledRecurringExpenses
    }
    
    /// Surplus after accounting for the new loan payment
    var surplusAfterLoan: Decimal {
        currentMonthlySurplus - proposedLoanPayment
    }
    
    /// Debt-to-income ratio as percentage (payment / income * 100)
    var debtToIncomeRatio: Double {
        guard averageMonthlyIncome > 0 else { return 100 }
        return Double(truncating: (proposedLoanPayment / averageMonthlyIncome * 100) as NSDecimalNumber)
    }
    
    /// Total debt-to-income including existing recurring expenses
    var totalDebtToIncomeRatio: Double {
        guard averageMonthlyIncome > 0 else { return 100 }
        let totalObligations = proposedLoanPayment + scheduledRecurringExpenses
        return Double(truncating: (totalObligations / averageMonthlyIncome * 100) as NSDecimalNumber)
    }
    
    /// Affordability assessment
    var affordabilityLevel: AffordabilityLevel {
        AffordabilityLevel.determine(
            debtToIncomeRatio: debtToIncomeRatio,
            surplusAfterLoan: surplusAfterLoan
        )
    }
    
    /// Percentage of surplus consumed by the loan payment
    var surplusImpactPercentage: Double {
        guard currentMonthlySurplus > 0 else { return 100 }
        return Double(truncating: (proposedLoanPayment / currentMonthlySurplus * 100) as NSDecimalNumber)
    }
    
    /// Remaining savings capacity percentage
    var remainingSavingsCapacity: Double {
        max(0, 100 - surplusImpactPercentage)
    }
    
    /// Whether there's enough data for a reliable analysis
    var hasEnoughData: Bool {
        monthsAnalyzed >= 3
    }
    
    /// Data quality indicator
    var dataQualityDescription: String {
        switch monthsAnalyzed {
        case 0:
            return String(localized: "No historical data available")
        case 1...2:
            return String(localized: "Limited data (\(monthsAnalyzed) months) - results may vary")
        case 3...5:
            return String(localized: "Based on \(monthsAnalyzed) months of data")
        default:
            return String(localized: "Based on 6 months of data")
        }
    }
}

// MARK: - Affordability Calculator Service

struct AffordabilityCalculator {
    
    /// Calculate affordability analysis for a proposed loan payment
    /// - Parameters:
    ///   - proposedPayment: The monthly payment for the proposed loan
    ///   - modelContext: SwiftData model context
    /// - Returns: LoanAffordabilityAnalysis with calculated metrics
    static func analyze(
        proposedPayment: Decimal,
        modelContext: ModelContext
    ) -> LoanAffordabilityAnalysis {
        let calendar = Calendar.current
        let now = Date()
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now)!
        
        // Fetch all non-recurring transactions in the last 6 months
        let transactionPredicate = #Predicate<Transaction> { transaction in
            transaction.date >= sixMonthsAgo && 
            transaction.date <= now &&
            transaction.isRecurring == false
        }
        
        let transactionDescriptor = FetchDescriptor<Transaction>(predicate: transactionPredicate)
        
        var totalIncome: Decimal = 0
        var totalExpenses: Decimal = 0
        var monthsWithData = Set<String>()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        
        do {
            let transactions = try modelContext.fetch(transactionDescriptor)
            
            for transaction in transactions {
                let monthKey = dateFormatter.string(from: transaction.date)
                monthsWithData.insert(monthKey)
                
                totalIncome += BalanceCalculator.incomeAmount(for: transaction)
                totalExpenses += BalanceCalculator.expenseAmount(for: transaction)
            }
        } catch {
            // Return analysis with zero values on error
        }
        
        let monthsAnalyzed = max(1, monthsWithData.count)
        let averageIncome = totalIncome / Decimal(monthsAnalyzed)
        let averageExpenses = totalExpenses / Decimal(monthsAnalyzed)
        
        // Calculate future recurring expenses
        let scheduledExpenses = calculateScheduledRecurringExpenses(modelContext: modelContext)
        
        return LoanAffordabilityAnalysis(
            averageMonthlyIncome: averageIncome,
            averageMonthlyExpenses: averageExpenses,
            monthsAnalyzed: monthsAnalyzed,
            scheduledRecurringExpenses: scheduledExpenses,
            proposedLoanPayment: proposedPayment
        )
    }
    
    /// Calculate monthly equivalent of scheduled recurring expenses
    private static func calculateScheduledRecurringExpenses(modelContext: ModelContext) -> Decimal {
        let recurringPredicate = #Predicate<Transaction> { transaction in
            transaction.isRecurring == true
        }
        
        let descriptor = FetchDescriptor<Transaction>(predicate: recurringPredicate)
        
        var monthlyTotal: Decimal = 0
        
        do {
            let recurringTransactions = try modelContext.fetch(descriptor)
            
            for transaction in recurringTransactions {
                guard let rule = transaction.recurrenceRule, rule.isActive else { continue }
                
                // Only count expense transactions
                let expenseAmount = BalanceCalculator.expenseAmount(for: transaction)
                guard expenseAmount > 0 else { continue }
                
                // Convert to monthly equivalent based on frequency
                let monthlyEquivalent: Decimal
                switch rule.frequency {
                case .daily:
                    monthlyEquivalent = expenseAmount * 30 / Decimal(rule.interval)
                case .weekly:
                    monthlyEquivalent = expenseAmount * Decimal(52) / Decimal(12) / Decimal(rule.interval)
                case .monthly:
                    monthlyEquivalent = expenseAmount / Decimal(rule.interval)
                case .yearly:
                    monthlyEquivalent = expenseAmount / Decimal(12) / Decimal(rule.interval)
                }
                
                monthlyTotal += monthlyEquivalent
            }
        } catch {
            // Return 0 on error
        }
        
        return monthlyTotal
    }
    
    /// Calculate the maximum affordable payment based on a target debt-to-income ratio
    static func maxAffordablePayment(
        targetRatio: Double = 28,
        modelContext: ModelContext
    ) -> Decimal {
        let analysis = analyze(proposedPayment: 0, modelContext: modelContext)
        guard analysis.averageMonthlyIncome > 0 else { return 0 }
        
        // Max payment = income * (target ratio / 100)
        let maxPayment = analysis.averageMonthlyIncome * Decimal(targetRatio) / 100
        
        // Also ensure it doesn't exceed current surplus
        return min(maxPayment, analysis.currentMonthlySurplus)
    }
}
