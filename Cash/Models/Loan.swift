//
//  Loan.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import Foundation
import SwiftData

// MARK: - Loan Type

enum LoanType: String, Codable, CaseIterable, Identifiable {
    case mortgage = "mortgage"
    case personalLoan = "personalLoan"
    case carLoan = "carLoan"
    case other = "other"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .mortgage:
            return String(localized: "Mortgage")
        case .personalLoan:
            return String(localized: "Personal Loan")
        case .carLoan:
            return String(localized: "Car Loan")
        case .other:
            return String(localized: "Other")
        }
    }
    
    var iconName: String {
        switch self {
        case .mortgage:
            return "house.fill"
        case .personalLoan:
            return "person.fill"
        case .carLoan:
            return "car.fill"
        case .other:
            return "creditcard.fill"
        }
    }
}

// MARK: - Interest Rate Type

enum InterestRateType: String, Codable, CaseIterable, Identifiable {
    case fixed = "fixed"
    case variable = "variable"
    case mixed = "mixed"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .fixed:
            return String(localized: "Fixed")
        case .variable:
            return String(localized: "Variable")
        case .mixed:
            return String(localized: "Mixed")
        }
    }
}

// MARK: - Payment Frequency

enum PaymentFrequency: String, Codable, CaseIterable, Identifiable {
    case monthly = "monthly"
    case bimonthly = "bimonthly"
    case quarterly = "quarterly"
    case semiannual = "semiannual"
    case annual = "annual"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .monthly:
            return String(localized: "Monthly")
        case .bimonthly:
            return String(localized: "Bimonthly")
        case .quarterly:
            return String(localized: "Quarterly")
        case .semiannual:
            return String(localized: "Semiannual")
        case .annual:
            return String(localized: "Annual")
        }
    }
    
    var paymentsPerYear: Int {
        switch self {
        case .monthly: return 12
        case .bimonthly: return 6
        case .quarterly: return 4
        case .semiannual: return 2
        case .annual: return 1
        }
    }
    
    var monthsBetweenPayments: Int {
        switch self {
        case .monthly: return 1
        case .bimonthly: return 2
        case .quarterly: return 3
        case .semiannual: return 6
        case .annual: return 12
        }
    }
}

// MARK: - Amortization Entry

struct AmortizationEntry: Identifiable {
    let id = UUID()
    let paymentNumber: Int
    let date: Date
    let payment: Decimal
    let principal: Decimal
    let interest: Decimal
    let remainingBalance: Decimal
}

// MARK: - Loan Model

@Model
final class Loan {
    var id: UUID
    var name: String
    var loanTypeRawValue: String
    var interestRateTypeRawValue: String
    var paymentFrequencyRawValue: String
    
    // Financial details
    var principalAmount: Decimal
    var currentInterestRate: Decimal  // TAN as percentage (e.g., 3.5 for 3.5%)
    var taeg: Decimal?  // TAEG as percentage
    var totalPayments: Int  // Total number of payments
    var monthlyPayment: Decimal
    
    // Dates
    var startDate: Date
    var createdAt: Date
    
    // For existing loans
    var isExisting: Bool  // true if this is an existing loan being tracked
    var paymentsMade: Int  // Number of payments already made
    
    // Currency
    var currency: String
    
    // Optional link to recurring transaction
    var linkedRecurringTransactionId: UUID?
    
    // Computed properties
    var loanType: LoanType {
        get { LoanType(rawValue: loanTypeRawValue) ?? .other }
        set { loanTypeRawValue = newValue.rawValue }
    }
    
    var interestRateType: InterestRateType {
        get { InterestRateType(rawValue: interestRateTypeRawValue) ?? .fixed }
        set { interestRateTypeRawValue = newValue.rawValue }
    }
    
    var paymentFrequency: PaymentFrequency {
        get { PaymentFrequency(rawValue: paymentFrequencyRawValue) ?? .monthly }
        set { paymentFrequencyRawValue = newValue.rawValue }
    }
    
    var remainingPayments: Int {
        max(0, totalPayments - paymentsMade)
    }
    
    var endDate: Date {
        let calendar = Calendar.current
        let monthsToAdd = totalPayments * paymentFrequency.monthsBetweenPayments
        return calendar.date(byAdding: .month, value: monthsToAdd, to: startDate) ?? startDate
    }
    
    var nextPaymentDate: Date? {
        guard remainingPayments > 0 else { return nil }
        let calendar = Calendar.current
        let monthsFromStart = paymentsMade * paymentFrequency.monthsBetweenPayments
        return calendar.date(byAdding: .month, value: monthsFromStart, to: startDate)
    }
    
    var progressPercentage: Double {
        guard totalPayments > 0 else { return 0 }
        return Double(paymentsMade) / Double(totalPayments) * 100
    }
    
    var totalAmountPaid: Decimal {
        monthlyPayment * Decimal(paymentsMade)
    }
    
    var totalAmountToPay: Decimal {
        monthlyPayment * Decimal(totalPayments)
    }
    
    var totalInterest: Decimal {
        totalAmountToPay - principalAmount
    }
    
    init(
        name: String,
        loanType: LoanType,
        interestRateType: InterestRateType,
        paymentFrequency: PaymentFrequency = .monthly,
        principalAmount: Decimal,
        currentInterestRate: Decimal,
        taeg: Decimal? = nil,
        totalPayments: Int,
        monthlyPayment: Decimal,
        startDate: Date,
        isExisting: Bool = false,
        paymentsMade: Int = 0,
        currency: String = "EUR"
    ) {
        self.id = UUID()
        self.name = name
        self.loanTypeRawValue = loanType.rawValue
        self.interestRateTypeRawValue = interestRateType.rawValue
        self.paymentFrequencyRawValue = paymentFrequency.rawValue
        self.principalAmount = principalAmount
        self.currentInterestRate = currentInterestRate
        self.taeg = taeg
        self.totalPayments = totalPayments
        self.monthlyPayment = monthlyPayment
        self.startDate = startDate
        self.createdAt = Date()
        self.isExisting = isExisting
        self.paymentsMade = paymentsMade
        self.currency = currency
        self.linkedRecurringTransactionId = nil
    }
}

// MARK: - Loan Calculator

struct LoanCalculator {
    
    /// Calculate monthly payment using French amortization (most common)
    /// Formula: M = P * [r(1+r)^n] / [(1+r)^n - 1]
    /// Where: M = monthly payment, P = principal, r = periodic interest rate, n = number of payments
    static func calculatePayment(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        frequency: PaymentFrequency = .monthly
    ) -> Decimal {
        guard principal > 0, annualRate >= 0, totalPayments > 0 else { return 0 }
        
        // If rate is 0, simple division
        if annualRate == 0 {
            return principal / Decimal(totalPayments)
        }
        
        // Convert annual rate to periodic rate
        let periodicRate = annualRate / 100 / Decimal(frequency.paymentsPerYear)
        
        // Calculate using Double for complex math, then convert back
        let r = NSDecimalNumber(decimal: periodicRate).doubleValue
        let p = NSDecimalNumber(decimal: principal).doubleValue
        let n = Double(totalPayments)
        
        let numerator = r * pow(1 + r, n)
        let denominator = pow(1 + r, n) - 1
        
        guard denominator != 0 else { return principal / Decimal(totalPayments) }
        
        let payment = p * (numerator / denominator)
        
        return Decimal(payment).rounded(2)
    }
    
    /// Generate full amortization schedule
    static func generateAmortizationSchedule(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        frequency: PaymentFrequency = .monthly,
        startDate: Date,
        startingPayment: Int = 1
    ) -> [AmortizationEntry] {
        var schedule: [AmortizationEntry] = []
        var remainingBalance = principal
        let payment = calculatePayment(principal: principal, annualRate: annualRate, totalPayments: totalPayments, frequency: frequency)
        let periodicRate = annualRate / 100 / Decimal(frequency.paymentsPerYear)
        let calendar = Calendar.current
        
        for i in startingPayment...totalPayments {
            let interest = (remainingBalance * periodicRate).rounded(2)
            var principalPaid = payment - interest
            
            // Adjust last payment
            if i == totalPayments {
                principalPaid = remainingBalance
            }
            
            remainingBalance -= principalPaid
            if remainingBalance < 0 { remainingBalance = 0 }
            
            let monthsFromStart = (i - 1) * frequency.monthsBetweenPayments
            let paymentDate = calendar.date(byAdding: .month, value: monthsFromStart, to: startDate) ?? startDate
            
            let entry = AmortizationEntry(
                paymentNumber: i,
                date: paymentDate,
                payment: i == totalPayments ? principalPaid + interest : payment,
                principal: principalPaid,
                interest: interest,
                remainingBalance: remainingBalance
            )
            schedule.append(entry)
        }
        
        return schedule
    }
    
    /// Calculate remaining balance at a specific payment number
    static func remainingBalance(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        paymentsMade: Int,
        frequency: PaymentFrequency = .monthly
    ) -> Decimal {
        guard paymentsMade < totalPayments else { return 0 }
        guard paymentsMade >= 0 else { return principal }
        
        if annualRate == 0 {
            let paymentAmount = principal / Decimal(totalPayments)
            return principal - (paymentAmount * Decimal(paymentsMade))
        }
        
        let periodicRate = annualRate / 100 / Decimal(frequency.paymentsPerYear)
        let payment = calculatePayment(principal: principal, annualRate: annualRate, totalPayments: totalPayments, frequency: frequency)
        
        var balance = principal
        for _ in 0..<paymentsMade {
            let interest = balance * periodicRate
            let principalPaid = payment - interest
            balance -= principalPaid
        }
        
        return max(0, balance).rounded(2)
    }
    
    /// Calculate early repayment savings
    static func calculateEarlyRepayment(
        remainingBalance: Decimal,
        remainingPayments: Int,
        annualRate: Decimal,
        frequency: PaymentFrequency = .monthly,
        earlyRepaymentAmount: Decimal,
        penaltyPercentage: Decimal = 0
    ) -> (savedInterest: Decimal, penaltyAmount: Decimal, netSavings: Decimal, newRemainingPayments: Int) {
        
        let currentPayment = calculatePayment(
            principal: remainingBalance,
            annualRate: annualRate,
            totalPayments: remainingPayments,
            frequency: frequency
        )
        
        let totalWithoutEarlyRepayment = currentPayment * Decimal(remainingPayments)
        let interestWithoutEarlyRepayment = totalWithoutEarlyRepayment - remainingBalance
        
        // After early repayment
        let newBalance = remainingBalance - earlyRepaymentAmount
        guard newBalance > 0 else {
            // Full repayment
            let penalty = (earlyRepaymentAmount * penaltyPercentage / 100).rounded(2)
            return (interestWithoutEarlyRepayment, penalty, interestWithoutEarlyRepayment - penalty, 0)
        }
        
        // Calculate new schedule with same payment
        var tempBalance = newBalance
        var newPayments = 0
        let periodicRate = annualRate / 100 / Decimal(frequency.paymentsPerYear)
        
        while tempBalance > 0 && newPayments < remainingPayments {
            let interest = tempBalance * periodicRate
            let principalPaid = currentPayment - interest
            if principalPaid <= 0 { break }
            tempBalance -= principalPaid
            newPayments += 1
        }
        
        let totalWithEarlyRepayment = currentPayment * Decimal(newPayments) + earlyRepaymentAmount
        let interestWithEarlyRepayment = totalWithEarlyRepayment - remainingBalance
        
        let savedInterest = (interestWithoutEarlyRepayment - interestWithEarlyRepayment).rounded(2)
        let penaltyAmount = (earlyRepaymentAmount * penaltyPercentage / 100).rounded(2)
        let netSavings = savedInterest - penaltyAmount
        
        return (savedInterest, penaltyAmount, netSavings, newPayments)
    }
    
    /// Simulate different interest rate scenarios
    static func simulateRateScenarios(
        principal: Decimal,
        baseRate: Decimal,
        totalPayments: Int,
        frequency: PaymentFrequency = .monthly,
        variations: [Decimal] = [-1, -0.5, 0, 0.5, 1, 1.5, 2]
    ) -> [(rateChange: Decimal, newRate: Decimal, payment: Decimal, totalInterest: Decimal)] {
        
        var scenarios: [(Decimal, Decimal, Decimal, Decimal)] = []
        
        for variation in variations {
            let newRate = max(0, baseRate + variation)
            let payment = calculatePayment(principal: principal, annualRate: newRate, totalPayments: totalPayments, frequency: frequency)
            let totalPaid = payment * Decimal(totalPayments)
            let totalInterest = totalPaid - principal
            
            scenarios.append((variation, newRate, payment, totalInterest))
        }
        
        return scenarios
    }
}

// MARK: - Decimal Extension

extension Decimal {
    func rounded(_ scale: Int) -> Decimal {
        var result = Decimal()
        var mutableSelf = self
        NSDecimalRound(&result, &mutableSelf, scale, .bankers)
        return result
    }
}
