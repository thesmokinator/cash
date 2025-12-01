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

// MARK: - Amortization Type

enum AmortizationType: String, Codable, CaseIterable, Identifiable {
    case french = "french"
    case italian = "italian"
    case german = "german"
    case american = "american"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .french:
            return String(localized: "French (Constant Payment)")
        case .italian:
            return String(localized: "Italian (Constant Principal)")
        case .german:
            return String(localized: "German (Prepaid Interest)")
        case .american:
            return String(localized: "American (Bullet)")
        }
    }
    
    var shortName: String {
        switch self {
        case .french:
            return String(localized: "French")
        case .italian:
            return String(localized: "Italian")
        case .german:
            return String(localized: "German")
        case .american:
            return String(localized: "American")
        }
    }
    
    var descriptionText: String {
        switch self {
        case .french:
            return String(localized: "Constant payments with increasing principal and decreasing interest over time. Most common type.")
        case .italian:
            return String(localized: "Constant principal payments with decreasing total payments over time.")
        case .german:
            return String(localized: "Similar to French but interest is paid at the beginning of each period.")
        case .american:
            return String(localized: "Interest-only payments with full principal due at maturity (bullet payment).")
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
    var amortizationTypeRawValue: String?
    
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
    
    var amortizationType: AmortizationType {
        get { AmortizationType(rawValue: amortizationTypeRawValue ?? "french") ?? .french }
        set { amortizationTypeRawValue = newValue.rawValue }
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
        amortizationType: AmortizationType = .french,
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
        self.amortizationTypeRawValue = amortizationType.rawValue
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
    
    // MARK: - Recurrence Frequency Mapping
    
    /// Maps PaymentFrequency to RecurrenceFrequency
    var recurrenceFrequency: RecurrenceFrequency {
        switch paymentFrequency {
        case .monthly:
            return .monthly
        case .bimonthly:
            return .monthly  // interval = 2
        case .quarterly:
            return .monthly  // interval = 3
        case .semiannual:
            return .monthly  // interval = 6
        case .annual:
            return .yearly
        }
    }
    
    /// Recurrence interval based on payment frequency
    var recurrenceInterval: Int {
        switch paymentFrequency {
        case .monthly:
            return 1
        case .bimonthly:
            return 2
        case .quarterly:
            return 3
        case .semiannual:
            return 6
        case .annual:
            return 1
        }
    }
}

// MARK: - Loan Calculator

struct LoanCalculator {
    
    // MARK: - Payment Calculation
    
    /// Calculate payment based on amortization type
    static func calculatePayment(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        frequency: PaymentFrequency = .monthly,
        amortizationType: AmortizationType = .french
    ) -> Decimal {
        switch amortizationType {
        case .french:
            return calculateFrenchPayment(principal: principal, annualRate: annualRate, totalPayments: totalPayments, frequency: frequency)
        case .italian:
            return calculateItalianFirstPayment(principal: principal, annualRate: annualRate, totalPayments: totalPayments, frequency: frequency)
        case .german:
            return calculateGermanPayment(principal: principal, annualRate: annualRate, totalPayments: totalPayments, frequency: frequency)
        case .american:
            return calculateAmericanPayment(principal: principal, annualRate: annualRate, frequency: frequency)
        }
    }
    
    /// French amortization: Constant payments
    /// Formula: M = P * [r(1+r)^n] / [(1+r)^n - 1]
    private static func calculateFrenchPayment(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        frequency: PaymentFrequency
    ) -> Decimal {
        guard principal > 0, annualRate >= 0, totalPayments > 0 else { return 0 }
        
        if annualRate == 0 {
            return principal / Decimal(totalPayments)
        }
        
        let periodicRate = annualRate / 100 / Decimal(frequency.paymentsPerYear)
        let r = NSDecimalNumber(decimal: periodicRate).doubleValue
        let p = NSDecimalNumber(decimal: principal).doubleValue
        let n = Double(totalPayments)
        
        let numerator = r * pow(1 + r, n)
        let denominator = pow(1 + r, n) - 1
        
        guard denominator != 0 else { return principal / Decimal(totalPayments) }
        
        let payment = p * (numerator / denominator)
        return Decimal(payment).rounded(2)
    }
    
    /// Italian amortization: Constant principal, first payment (highest)
    private static func calculateItalianFirstPayment(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        frequency: PaymentFrequency
    ) -> Decimal {
        guard principal > 0, totalPayments > 0 else { return 0 }
        
        let constantPrincipal = principal / Decimal(totalPayments)
        let periodicRate = annualRate / 100 / Decimal(frequency.paymentsPerYear)
        let firstInterest = principal * periodicRate
        
        return (constantPrincipal + firstInterest).rounded(2)
    }
    
    /// German amortization: Similar to French but interest paid in advance
    private static func calculateGermanPayment(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        frequency: PaymentFrequency
    ) -> Decimal {
        // German is similar to French for the payment amount
        return calculateFrenchPayment(principal: principal, annualRate: annualRate, totalPayments: totalPayments, frequency: frequency)
    }
    
    /// American amortization: Interest-only payments
    private static func calculateAmericanPayment(
        principal: Decimal,
        annualRate: Decimal,
        frequency: PaymentFrequency
    ) -> Decimal {
        guard principal > 0, annualRate >= 0 else { return 0 }
        
        let periodicRate = annualRate / 100 / Decimal(frequency.paymentsPerYear)
        return (principal * periodicRate).rounded(2)
    }
    
    // MARK: - Amortization Schedule Generation
    
    /// Generate amortization schedule based on type
    static func generateAmortizationSchedule(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        frequency: PaymentFrequency = .monthly,
        amortizationType: AmortizationType = .french,
        startDate: Date,
        startingPayment: Int = 1
    ) -> [AmortizationEntry] {
        switch amortizationType {
        case .french:
            return generateFrenchSchedule(principal: principal, annualRate: annualRate, totalPayments: totalPayments, frequency: frequency, startDate: startDate, startingPayment: startingPayment)
        case .italian:
            return generateItalianSchedule(principal: principal, annualRate: annualRate, totalPayments: totalPayments, frequency: frequency, startDate: startDate, startingPayment: startingPayment)
        case .german:
            return generateGermanSchedule(principal: principal, annualRate: annualRate, totalPayments: totalPayments, frequency: frequency, startDate: startDate, startingPayment: startingPayment)
        case .american:
            return generateAmericanSchedule(principal: principal, annualRate: annualRate, totalPayments: totalPayments, frequency: frequency, startDate: startDate, startingPayment: startingPayment)
        }
    }
    
    /// French: Constant payment, increasing principal, decreasing interest
    private static func generateFrenchSchedule(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        frequency: PaymentFrequency,
        startDate: Date,
        startingPayment: Int
    ) -> [AmortizationEntry] {
        guard totalPayments > 0, startingPayment <= totalPayments else { return [] }
        
        var schedule: [AmortizationEntry] = []
        var remainingBalance = principal
        let payment = calculateFrenchPayment(principal: principal, annualRate: annualRate, totalPayments: totalPayments, frequency: frequency)
        let periodicRate = annualRate / 100 / Decimal(frequency.paymentsPerYear)
        let calendar = Calendar.current
        
        for i in startingPayment...totalPayments {
            let interest = (remainingBalance * periodicRate).rounded(2)
            var principalPaid = payment - interest
            
            if i == totalPayments {
                principalPaid = remainingBalance
            }
            
            remainingBalance -= principalPaid
            if remainingBalance < 0 { remainingBalance = 0 }
            
            let monthsFromStart = (i - 1) * frequency.monthsBetweenPayments
            let paymentDate = calendar.date(byAdding: .month, value: monthsFromStart, to: startDate) ?? startDate
            
            schedule.append(AmortizationEntry(
                paymentNumber: i,
                date: paymentDate,
                payment: i == totalPayments ? principalPaid + interest : payment,
                principal: principalPaid,
                interest: interest,
                remainingBalance: remainingBalance
            ))
        }
        
        return schedule
    }
    
    /// Italian: Constant principal, decreasing payment
    private static func generateItalianSchedule(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        frequency: PaymentFrequency,
        startDate: Date,
        startingPayment: Int
    ) -> [AmortizationEntry] {
        guard totalPayments > 0, startingPayment <= totalPayments else { return [] }
        
        var schedule: [AmortizationEntry] = []
        var remainingBalance = principal
        let constantPrincipal = (principal / Decimal(totalPayments)).rounded(2)
        let periodicRate = annualRate / 100 / Decimal(frequency.paymentsPerYear)
        let calendar = Calendar.current
        
        for i in startingPayment...totalPayments {
            let interest = (remainingBalance * periodicRate).rounded(2)
            var principalPaid = constantPrincipal
            
            // Adjust last payment for rounding
            if i == totalPayments {
                principalPaid = remainingBalance
            }
            
            let payment = principalPaid + interest
            remainingBalance -= principalPaid
            if remainingBalance < 0 { remainingBalance = 0 }
            
            let monthsFromStart = (i - 1) * frequency.monthsBetweenPayments
            let paymentDate = calendar.date(byAdding: .month, value: monthsFromStart, to: startDate) ?? startDate
            
            schedule.append(AmortizationEntry(
                paymentNumber: i,
                date: paymentDate,
                payment: payment,
                principal: principalPaid,
                interest: interest,
                remainingBalance: remainingBalance
            ))
        }
        
        return schedule
    }
    
    /// German: Interest paid at beginning of period (prepaid)
    private static func generateGermanSchedule(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        frequency: PaymentFrequency,
        startDate: Date,
        startingPayment: Int
    ) -> [AmortizationEntry] {
        guard totalPayments > 0, startingPayment <= totalPayments else { return [] }
        
        var schedule: [AmortizationEntry] = []
        var remainingBalance = principal
        let payment = calculateFrenchPayment(principal: principal, annualRate: annualRate, totalPayments: totalPayments, frequency: frequency)
        let periodicRate = annualRate / 100 / Decimal(frequency.paymentsPerYear)
        let calendar = Calendar.current
        
        for i in startingPayment...totalPayments {
            // German: interest is calculated on remaining balance AFTER principal payment
            // This means we pay interest "in advance" for the upcoming period
            var principalPaid: Decimal
            var interest: Decimal
            
            if i == 1 {
                // First payment: full interest on principal
                interest = (principal * periodicRate).rounded(2)
                principalPaid = payment - interest
            } else {
                // Subsequent payments: interest on balance after previous principal
                interest = (remainingBalance * periodicRate).rounded(2)
                principalPaid = payment - interest
            }
            
            if i == totalPayments {
                principalPaid = remainingBalance
            }
            
            remainingBalance -= principalPaid
            if remainingBalance < 0 { remainingBalance = 0 }
            
            let monthsFromStart = (i - 1) * frequency.monthsBetweenPayments
            let paymentDate = calendar.date(byAdding: .month, value: monthsFromStart, to: startDate) ?? startDate
            
            schedule.append(AmortizationEntry(
                paymentNumber: i,
                date: paymentDate,
                payment: i == totalPayments ? principalPaid + interest : payment,
                principal: principalPaid,
                interest: interest,
                remainingBalance: remainingBalance
            ))
        }
        
        return schedule
    }
    
    /// American: Interest-only payments, bullet principal at end
    private static func generateAmericanSchedule(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        frequency: PaymentFrequency,
        startDate: Date,
        startingPayment: Int
    ) -> [AmortizationEntry] {
        guard totalPayments > 0, startingPayment <= totalPayments else { return [] }
        
        var schedule: [AmortizationEntry] = []
        let periodicRate = annualRate / 100 / Decimal(frequency.paymentsPerYear)
        let interestPayment = (principal * periodicRate).rounded(2)
        let calendar = Calendar.current
        
        for i in startingPayment...totalPayments {
            let isLastPayment = i == totalPayments
            let principalPaid = isLastPayment ? principal : Decimal(0)
            let payment = isLastPayment ? principal + interestPayment : interestPayment
            let remainingBalance = isLastPayment ? Decimal(0) : principal
            
            let monthsFromStart = (i - 1) * frequency.monthsBetweenPayments
            let paymentDate = calendar.date(byAdding: .month, value: monthsFromStart, to: startDate) ?? startDate
            
            schedule.append(AmortizationEntry(
                paymentNumber: i,
                date: paymentDate,
                payment: payment,
                principal: principalPaid,
                interest: interestPayment,
                remainingBalance: remainingBalance
            ))
        }
        
        return schedule
    }
    
    // MARK: - Utility Methods
    
    /// Calculate remaining balance at a specific payment number
    static func remainingBalance(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        paymentsMade: Int,
        frequency: PaymentFrequency = .monthly,
        amortizationType: AmortizationType = .french
    ) -> Decimal {
        guard paymentsMade < totalPayments else { return 0 }
        guard paymentsMade >= 0 else { return principal }
        
        switch amortizationType {
        case .american:
            // American: principal remains until final payment
            return principal
        case .italian:
            // Italian: constant principal reduction
            let constantPrincipal = principal / Decimal(totalPayments)
            return (principal - (constantPrincipal * Decimal(paymentsMade))).rounded(2)
        case .french, .german:
            if annualRate == 0 {
                let paymentAmount = principal / Decimal(totalPayments)
                return principal - (paymentAmount * Decimal(paymentsMade))
            }
            
            let periodicRate = annualRate / 100 / Decimal(frequency.paymentsPerYear)
            let payment = calculateFrenchPayment(principal: principal, annualRate: annualRate, totalPayments: totalPayments, frequency: frequency)
            
            var balance = principal
            for _ in 0..<paymentsMade {
                let interest = balance * periodicRate
                let principalPaid = payment - interest
                balance -= principalPaid
            }
            
            return max(0, balance).rounded(2)
        }
    }
    
    /// Calculate total interest for a loan
    static func calculateTotalInterest(
        principal: Decimal,
        annualRate: Decimal,
        totalPayments: Int,
        frequency: PaymentFrequency = .monthly,
        amortizationType: AmortizationType = .french
    ) -> Decimal {
        let schedule = generateAmortizationSchedule(
            principal: principal,
            annualRate: annualRate,
            totalPayments: totalPayments,
            frequency: frequency,
            amortizationType: amortizationType,
            startDate: Date()
        )
        return schedule.reduce(Decimal.zero) { $0 + $1.interest }
    }
    
    /// Calculate early repayment savings
    static func calculateEarlyRepayment(
        remainingBalance: Decimal,
        remainingPayments: Int,
        annualRate: Decimal,
        frequency: PaymentFrequency = .monthly,
        earlyRepaymentAmount: Decimal,
        penaltyPercentage: Decimal = 0,
        amortizationType: AmortizationType = .french
    ) -> (savedInterest: Decimal, penaltyAmount: Decimal, netSavings: Decimal, newRemainingPayments: Int) {
        
        let currentPayment = calculatePayment(
            principal: remainingBalance,
            annualRate: annualRate,
            totalPayments: remainingPayments,
            frequency: frequency,
            amortizationType: amortizationType
        )
        
        // Calculate interest without early repayment
        let interestWithoutEarlyRepayment = calculateTotalInterest(
            principal: remainingBalance,
            annualRate: annualRate,
            totalPayments: remainingPayments,
            frequency: frequency,
            amortizationType: amortizationType
        )
        
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
        
        let interestWithEarlyRepayment = calculateTotalInterest(
            principal: newBalance,
            annualRate: annualRate,
            totalPayments: newPayments,
            frequency: frequency,
            amortizationType: amortizationType
        )
        
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
        amortizationType: AmortizationType = .french,
        variations: [Decimal] = [-1, -0.5, 0, 0.5, 1, 1.5, 2]
    ) -> [(rateChange: Decimal, newRate: Decimal, payment: Decimal, totalInterest: Decimal)] {
        
        var scenarios: [(Decimal, Decimal, Decimal, Decimal)] = []
        
        for variation in variations {
            let newRate = max(0, baseRate + variation)
            let payment = calculatePayment(principal: principal, annualRate: newRate, totalPayments: totalPayments, frequency: frequency, amortizationType: amortizationType)
            let totalInterest = calculateTotalInterest(principal: principal, annualRate: newRate, totalPayments: totalPayments, frequency: frequency, amortizationType: amortizationType)
            
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
