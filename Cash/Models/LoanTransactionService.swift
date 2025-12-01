//
//  LoanTransactionService.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import Foundation
import SwiftData

/// Service to create and manage recurring transactions linked to loans
struct LoanTransactionService {
    
    /// Creates a recurring transaction for loan payments
    /// - Parameters:
    ///   - loan: The loan to create a recurring transaction for
    ///   - paymentAccount: The account from which payments will be made (debit)
    ///   - expenseCategory: The expense category for loan payments (credit)
    ///   - modelContext: The SwiftData model context
    /// - Returns: The created Transaction, or nil if creation failed
    @discardableResult
    static func createRecurringTransaction(
        for loan: Loan,
        paymentAccount: Account,
        expenseCategory: Account,
        modelContext: ModelContext
    ) -> Transaction? {
        
        // Calculate next payment date
        guard let nextPaymentDate = loan.nextPaymentDate else { return nil }
        
        // Create the recurring transaction
        let transaction = Transaction(
            date: nextPaymentDate,
            descriptionText: loan.name,
            reference: "LOAN-\(loan.id.uuidString.prefix(8))"
        )
        transaction.isRecurring = true
        transaction.linkedLoanId = loan.id
        
        // Create debit entry (from payment account)
        let debitEntry = Entry(
            entryType: .debit,
            amount: loan.monthlyPayment,
            account: paymentAccount
        )
        
        // Create credit entry (to expense category)
        let creditEntry = Entry(
            entryType: .credit,
            amount: loan.monthlyPayment,
            account: expenseCategory
        )
        
        transaction.entries = [debitEntry, creditEntry]
        
        // Create recurrence rule
        let dayOfMonth = Calendar.current.component(.day, from: nextPaymentDate)
        let recurrenceRule = RecurrenceRule(
            frequency: loan.recurrenceFrequency,
            interval: loan.recurrenceInterval,
            dayOfMonth: dayOfMonth,
            startDate: nextPaymentDate,
            endDate: loan.endDate
        )
        recurrenceRule.nextOccurrence = nextPaymentDate
        transaction.recurrenceRule = recurrenceRule
        
        // Insert into context
        modelContext.insert(transaction)
        
        // Update loan with the linked transaction ID
        loan.linkedRecurringTransactionId = transaction.id
        
        return transaction
    }
    
    /// Updates an existing recurring transaction when loan details change
    /// - Parameters:
    ///   - loan: The loan with updated details
    ///   - transaction: The linked recurring transaction
    static func updateRecurringTransaction(
        for loan: Loan,
        transaction: Transaction
    ) {
        // Update amount in entries
        if let entries = transaction.entries {
            for entry in entries {
                entry.amount = loan.monthlyPayment
            }
        }
        
        // Update description
        transaction.descriptionText = loan.name
        
        // Update recurrence rule if frequency changed
        if let rule = transaction.recurrenceRule {
            rule.frequency = loan.recurrenceFrequency
            rule.interval = loan.recurrenceInterval
            rule.endDate = loan.endDate
        }
    }
    
    /// Finds the recurring transaction linked to a loan
    /// - Parameters:
    ///   - loan: The loan to find the transaction for
    ///   - modelContext: The SwiftData model context
    /// - Returns: The linked Transaction, or nil if not found
    static func findLinkedTransaction(
        for loan: Loan,
        modelContext: ModelContext
    ) -> Transaction? {
        guard let linkedId = loan.linkedRecurringTransactionId else { return nil }
        
        let predicate = #Predicate<Transaction> { transaction in
            transaction.id == linkedId
        }
        
        let descriptor = FetchDescriptor<Transaction>(predicate: predicate)
        
        do {
            let results = try modelContext.fetch(descriptor)
            return results.first
        } catch {
            return nil
        }
    }
    
    /// Removes the link between a loan and its recurring transaction
    /// - Parameters:
    ///   - loan: The loan to unlink
    ///   - deleteTransaction: If true, also deletes the recurring transaction
    ///   - modelContext: The SwiftData model context
    static func unlinkTransaction(
        for loan: Loan,
        deleteTransaction: Bool = false,
        modelContext: ModelContext
    ) {
        if deleteTransaction, let transaction = findLinkedTransaction(for: loan, modelContext: modelContext) {
            modelContext.delete(transaction)
        }
        
        loan.linkedRecurringTransactionId = nil
    }
}
