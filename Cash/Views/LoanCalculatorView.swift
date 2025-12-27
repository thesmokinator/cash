//
//  LoanCalculatorView.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import SwiftUI
import SwiftData

struct LoanCalculatorView: View {
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
    @State private var durationYears: Int = 20
    @State private var durationMonths: Int = 0
    @State private var startDate: Date = Date()
    @State private var currency: String = "EUR"
    
    // Calculated values
    @State private var calculatedPayment: Decimal = 0
    @State private var totalInterest: Decimal = 0
    @State private var totalAmount: Decimal = 0
    
    // UI State
    @State private var showingAmortization = false
    @State private var showingScenarios = false
    @State private var showingSaveDialog = false
    @State private var showingAmortizationHelp = false
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
    
    private var totalPayments: Int {
        durationYears * paymentFrequency.paymentsPerYear + 
        (durationMonths * paymentFrequency.paymentsPerYear / 12)
    }
    
    private var isValid: Bool {
        principal > 0 && interestRate >= 0 && totalPayments > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Loan Details") {
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
                    
                    Picker("Currency", selection: $currency) {
                        ForEach(CurrencyList.currencies) { curr in
                            Text("\(curr.code) - \(curr.name)").tag(curr.code)
                        }
                    }
                }
                
                Section {
                    Picker("Amortization Type", selection: $amortizationType) {
                        ForEach(AmortizationType.allCases) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                    .onChange(of: amortizationType) { _, _ in calculate() }
                    
                    Text(amortizationType.descriptionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    HStack {
                        Text("Amortization Method")
                        Spacer()
                        Button {
                            showingAmortizationHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Section("Financial Details") {
                    HStack {
                        Text(CurrencyList.symbol(forCode: currency))
                            .foregroundStyle(.secondary)
                        TextField("Principal Amount", text: $principalText)
                            .onChange(of: principalText) { _, _ in calculate() }
                    }
                    
                    HStack {
                        TextField("Interest Rate (TAN)", text: $interestRateText)
                            .onChange(of: interestRateText) { _, _ in calculate() }
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        TextField("TAEG (optional)", text: $taegText)
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Duration") {
                    Stepper("\(durationYears) years", value: $durationYears, in: 1...50)
                        .onChange(of: durationYears) { _, _ in calculate() }
                    
                    Stepper("\(durationMonths) months", value: $durationMonths, in: 0...11)
                        .onChange(of: durationMonths) { _, _ in calculate() }
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    
                    HStack {
                        Text("Total Payments")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(totalPayments)")
                            .fontWeight(.medium)
                    }
                }
                
                if isValid {
                    Section("Calculation Results") {
                        ResultRow(label: "Monthly Payment", value: calculatedPayment, currency: currency, isHighlighted: true)
                        ResultRow(label: "Total Interest", value: totalInterest, currency: currency)
                        ResultRow(label: "Total Amount", value: totalAmount, currency: currency)
                    }
                    
                    Section {
                        Button {
                            showingAmortization = true
                        } label: {
                            Label("View Amortization Schedule", systemImage: "tablecells")
                        }
                        
                        Button {
                            showingScenarios = true
                        } label: {
                            Label("Rate Scenarios", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }
                    
                    Section("Budget Impact Analysis") {
                        LoanAffordabilityView(
                            proposedPayment: calculatedPayment,
                            currency: currency
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Loan Calculator")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        showingSaveDialog = true
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                currency = CurrencyHelper.defaultCurrency(from: accounts)
                calculate()
            }
            .sheet(isPresented: $showingAmortization) {
                AmortizationScheduleView(
                    principal: principal,
                    annualRate: interestRate,
                    totalPayments: totalPayments,
                    frequency: paymentFrequency,
                    amortizationType: amortizationType,
                    startDate: startDate,
                    currency: currency
                )
            }
            .sheet(isPresented: $showingScenarios) {
                LoanScenariosView(
                    principal: principal,
                    baseRate: interestRate,
                    totalPayments: totalPayments,
                    frequency: paymentFrequency,
                    amortizationType: amortizationType,
                    currency: currency
                )
            }
            .alert("Save Simulation", isPresented: $showingSaveDialog) {
                TextField("Name", text: $loanName)
                Button("Save") {
                    saveLoan()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter a name for this loan simulation")
            }
            .sheet(isPresented: $showingAmortizationHelp) {
                AmortizationHelpView()
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
        .frame(minWidth: 500, minHeight: 650)
        #endif
    }
    
    private func calculate() {
        guard isValid else {
            calculatedPayment = 0
            totalInterest = 0
            totalAmount = 0
            return
        }
        
        calculatedPayment = LoanCalculator.calculatePayment(
            principal: principal,
            annualRate: interestRate,
            totalPayments: totalPayments,
            frequency: paymentFrequency,
            amortizationType: amortizationType
        )
        
        totalInterest = LoanCalculator.calculateTotalInterest(
            principal: principal,
            annualRate: interestRate,
            totalPayments: totalPayments,
            frequency: paymentFrequency,
            amortizationType: amortizationType
        )
        
        totalAmount = principal + totalInterest
    }
    
    private func saveLoan() {
        let name = loanName.isEmpty ? "\(loanType.localizedName) - \(Date().formatted(date: .abbreviated, time: .omitted))" : loanName
        
        let loan = Loan(
            name: name,
            loanType: loanType,
            interestRateType: interestRateType,
            paymentFrequency: paymentFrequency,
            amortizationType: amortizationType,
            principalAmount: principal,
            currentInterestRate: interestRate,
            taeg: taeg,
            totalPayments: totalPayments,
            monthlyPayment: calculatedPayment,
            startDate: startDate,
            isExisting: false,
            paymentsMade: 0,
            currency: currency
        )
        
        modelContext.insert(loan)
        savedLoan = loan
        showingCreateRecurringDialog = true
    }
}

// MARK: - Amortization Help View

struct AmortizationHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(AmortizationType.allCases) { type in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(type.localizedName)
                            .font(.headline)
                        Text(type.descriptionText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Amortization Types")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }
}

// MARK: - Result Row

struct ResultRow: View {
    @Environment(AppSettings.self) private var settings
    let label: LocalizedStringKey
    let value: Decimal
    let currency: String
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(isHighlighted ? .primary : .secondary)
            Spacer()
            PrivacyAmountView(
                amount: CurrencyFormatter.format(value, currency: currency),
                isPrivate: settings.privacyMode,
                font: isHighlighted ? .headline : .body,
                fontWeight: isHighlighted ? .bold : .medium,
                color: isHighlighted ? Color.accentColor : Color.primary
            )
        }
    }
}

#Preview {
    LoanCalculatorView()
        .modelContainer(for: [Loan.self, Account.self], inMemory: true)
        .environment(AppSettings.shared)
}
