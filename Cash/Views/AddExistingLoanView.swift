//
//  AddExistingLoanView.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import SwiftUI
import SwiftData

struct AddExistingLoanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    
    // Input fields
    @State private var loanName: String = ""
    @State private var loanType: LoanType = .mortgage
    @State private var interestRateType: InterestRateType = .fixed
    @State private var paymentFrequency: PaymentFrequency = .monthly
    @State private var amortizationType: AmortizationType = .french
    @State private var principalText: String = ""
    @State private var interestRateText: String = ""
    @State private var taegText: String = ""
    @State private var monthlyPaymentText: String = ""
    @State private var totalPaymentsText: String = ""
    @State private var paymentsMadeText: String = ""
    @State private var startDate: Date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var currency: String = "EUR"
    
    // Validation
    @State private var showingValidationError = false
    @State private var validationMessage = ""
    @State private var showingCreateRecurringDialog = false
    @State private var savedLoan: Loan?
    
    private var principal: Decimal {
        Decimal(string: principalText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var interestRate: Decimal {
        Decimal(string: interestRateText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var taeg: Decimal? {
        guard !taegText.isEmpty else { return nil }
        return Decimal(string: taegText.replacingOccurrences(of: ",", with: "."))
    }
    
    private var monthlyPayment: Decimal {
        Decimal(string: monthlyPaymentText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var totalPayments: Int {
        Int(totalPaymentsText) ?? 0
    }
    
    private var paymentsMade: Int {
        Int(paymentsMadeText) ?? 0
    }
    
    private var isValid: Bool {
        !loanName.isEmpty &&
        principal > 0 &&
        interestRate >= 0 &&
        monthlyPayment > 0 &&
        totalPayments > 0 &&
        paymentsMade >= 0 &&
        paymentsMade <= totalPayments
    }
    
    private var remainingBalance: Decimal {
        LoanCalculator.remainingBalance(
            principal: principal,
            annualRate: interestRate,
            totalPayments: totalPayments,
            paymentsMade: paymentsMade,
            frequency: paymentFrequency
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Loan Information") {
                    TextField("Name", text: $loanName)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("Type", selection: $loanType) {
                        ForEach(LoanType.allCases) { type in
                            Label(type.localizedName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    
                    Picker("Interest Rate Type", selection: $interestRateType) {
                        ForEach(InterestRateType.allCases) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                    
                    Picker("Payment Frequency", selection: $paymentFrequency) {
                        ForEach(PaymentFrequency.allCases) { freq in
                            Text(freq.localizedName).tag(freq)
                        }
                    }
                    
                    Picker("Amortization Type", selection: $amortizationType) {
                        ForEach(AmortizationType.allCases) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                    
                    Picker("Currency", selection: $currency) {
                        ForEach(CurrencyList.currencies) { curr in
                            Text("\(curr.code) - \(curr.name)").tag(curr.code)
                        }
                    }
                }
                
                Section("Original Loan Details") {
                    HStack {
                        Text(CurrencyList.symbol(forCode: currency))
                            .foregroundStyle(.secondary)
                        TextField("Original Principal", text: $principalText)
                    }
                    
                    HStack {
                        TextField("Interest Rate (TAN)", text: $interestRateText)
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        TextField("TAEG (optional)", text: $taegText)
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                }
                
                Section("Payment Details") {
                    HStack {
                        Text(CurrencyList.symbol(forCode: currency))
                            .foregroundStyle(.secondary)
                        TextField("Payment Amount", text: $monthlyPaymentText)
                    }
                    
                    HStack {
                        Text("Total Payments")
                        Spacer()
                        TextField("", text: $totalPaymentsText)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Payments Already Made")
                        Spacer()
                        TextField("", text: $paymentsMadeText)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                if isValid {
                    Section("Current Status") {
                        HStack {
                            Text("Remaining Payments")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(totalPayments - paymentsMade)")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Estimated Remaining Balance")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(CurrencyFormatter.format(remainingBalance, currency: currency))
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Progress")
                                .foregroundStyle(.secondary)
                            Spacer()
                            ProgressView(value: Double(paymentsMade), total: Double(totalPayments))
                                .frame(width: 100)
                            Text("\(Int(Double(paymentsMade) / Double(totalPayments) * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Existing Loan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addLoan()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                currency = CurrencyHelper.defaultCurrency(from: accounts)
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
            .sheet(isPresented: $showingCreateRecurringDialog) {
                if let loan = savedLoan {
                    CreateLoanRecurringView(loan: loan, onComplete: {
                        dismiss()
                    }, onSkip: {
                        dismiss()
                    })
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 550)
        #endif
    }
    
    private func addLoan() {
        guard isValid else {
            validationMessage = "Please fill in all required fields correctly."
            showingValidationError = true
            return
        }
        
        let loan = Loan(
            name: loanName,
            loanType: loanType,
            interestRateType: interestRateType,
            paymentFrequency: paymentFrequency,
            amortizationType: amortizationType,
            principalAmount: principal,
            currentInterestRate: interestRate,
            taeg: taeg,
            totalPayments: totalPayments,
            monthlyPayment: monthlyPayment,
            startDate: startDate,
            isExisting: true,
            paymentsMade: paymentsMade,
            currency: currency
        )
        
        modelContext.insert(loan)
        savedLoan = loan
        showingCreateRecurringDialog = true
    }
}

#Preview {
    AddExistingLoanView()
        .modelContainer(for: [Loan.self, Account.self], inMemory: true)
        .environment(AppSettings.shared)
}
