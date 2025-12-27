//
//  AddInvestmentTransactionView.swift
//  Cash
//
//  Created by Michele Broggi on 27/12/25.
//

import SwiftUI
import SwiftData

/// View for adding investment transactions (buy, sell, dividend)
struct AddInvestmentTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    
    var preselectedInvestmentAccount: Account?
    
    // MARK: - State
    
    @State private var transactionType: InvestmentTransactionType = .buy
    @State private var date: Date = Date()
    @State private var descriptionText: String = ""
    @State private var sharesText: String = ""
    @State private var pricePerShareText: String = ""
    @State private var feesText: String = ""
    @State private var dividendAmountText: String = ""
    @State private var splitRatioText: String = ""
    
    @State private var selectedInvestmentAccount: Account?
    @State private var selectedCashAccount: Account?
    @State private var selectedIncomeAccount: Account?
    
    @State private var showingValidationError = false
    @State private var validationErrors: [String] = []
    @State private var showingHelpTip = false
    @State private var isLoadingQuote = false
    
    // MARK: - Computed Properties
    
    private var investmentAccounts: [Account] {
        accounts.filter { $0.accountType == .investment && $0.isActive }
    }
    
    private var cashAccounts: [Account] {
        accounts.filter { 
            ($0.accountClass == .asset || $0.accountClass == .liability) && 
            $0.accountType != .investment && 
            $0.isActive 
        }
    }
    
    private var incomeAccounts: [Account] {
        accounts.filter { $0.accountClass == .income && $0.isActive }
    }
    
    private var shares: Decimal {
        CurrencyFormatter.parse(sharesText)
    }
    
    private var pricePerShare: Decimal {
        CurrencyFormatter.parse(pricePerShareText)
    }
    
    private var fees: Decimal {
        CurrencyFormatter.parse(feesText)
    }
    
    private var dividendAmount: Decimal {
        CurrencyFormatter.parse(dividendAmountText)
    }
    
    private var splitRatio: Decimal {
        CurrencyFormatter.parse(splitRatioText)
    }
    
    private var currentCurrency: String {
        selectedInvestmentAccount?.currency ?? selectedCashAccount?.currency ?? "EUR"
    }
    
    private var totalAmount: Decimal {
        switch transactionType {
        case .buy:
            return (shares * pricePerShare) + fees
        case .sell:
            return (shares * pricePerShare) - fees
        case .dividend:
            return dividendAmount
        case .split:
            return 0
        }
    }
    
    private var currentPosition: InvestmentPosition? {
        guard let account = selectedInvestmentAccount else { return nil }
        return InvestmentHelper.calculatePosition(for: account)
    }
    
    private func calculateUpdatedBalances() -> [(account: Account, newBalance: Decimal)] {
        switch transactionType {
        case .buy:
            guard let investment = selectedInvestmentAccount, let cash = selectedCashAccount else { return [] }
            return [
                (investment, investment.balance + totalAmount),
                (cash, cash.balance - totalAmount)
            ]
        case .sell:
            guard let investment = selectedInvestmentAccount, let cash = selectedCashAccount else { return [] }
            return [
                (investment, investment.balance - totalAmount),
                (cash, cash.balance + totalAmount)
            ]
        case .dividend:
            guard let cash = selectedCashAccount, let income = selectedIncomeAccount else { return [] }
            return [
                (cash, cash.balance + dividendAmount),
                (income, income.balance + dividendAmount)
            ]
        case .split:
            return []
        }
    }
    
    private var isValid: Bool {
        let errors = InvestmentHelper.validateTransaction(
            type: transactionType,
            shares: transactionType == .split ? splitRatio : shares,
            pricePerShare: pricePerShare,
            amount: dividendAmount,
            investmentAccount: selectedInvestmentAccount,
            cashAccount: transactionType.affectsCash ? selectedCashAccount : selectedInvestmentAccount
        )
        return errors.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Transaction Type Section
                Section {
                    transactionTypePicker
                } header: {
                    HStack {
                        Text("Transaction Type")
                        Spacer()
                        helpButton
                    }
                }
                
                // Investment Account Section
                Section("Investment Account") {
                    AccountPicker(
                        title: "Security",
                        accounts: investmentAccounts,
                        selection: $selectedInvestmentAccount
                    )
                    
                    if let position = currentPosition, position.hasShares {
                        HStack {
                            Text("Current Position")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(InvestmentHelper.formatShares(position.shares)) shares")
                                .fontWeight(.medium)
                        }
                    }
                }
                
                // Transaction Details Section
                switch transactionType {
                case .buy, .sell:
                    buySellSection
                case .dividend:
                    dividendSection
                case .split:
                    splitSection
                }
                
                // Cash Account Section (for buy/sell/dividend)
                if transactionType.affectsCash {
                    Section("Cash Account") {
                        AccountPicker(
                            title: transactionType == .buy ? String(localized: "Pay from") : String(localized: "Deposit to"),
                            accounts: cashAccounts,
                            selection: $selectedCashAccount
                        )
                    }
                }
                
                // Income Account (for dividends)
                if transactionType == .dividend {
                    Section("Income Category") {
                        AccountPicker(
                            title: "Dividend income",
                            accounts: incomeAccounts,
                            selection: $selectedIncomeAccount
                        )
                    }
                }
                
                // Date & Description
                Section("Details") {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    
                    TextField("Description (optional)", text: $descriptionText)
                }
                
                // Journal Preview
                Section {
                    journalPreview
                } header: {
                    Label("Journal Entry Preview", systemImage: "doc.text")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Investment Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTransaction() }
                        .disabled(!isValid)
                }
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationErrors.joined(separator: "\n"))
            }
            .popover(isPresented: $showingHelpTip) {
                helpContent
                    .padding()
                    .frame(width: 350)
            }
            .onAppear { setupPreselectedAccount() }
            .task(id: selectedInvestmentAccount) { 
                await loadQuoteForSelectedAccount() 
            }
            .task(id: transactionType) { 
                await loadQuoteForSelectedAccount() 
            }
        }
        .frame(minWidth: 500, minHeight: 550)
    }
    
    // MARK: - Subviews
    
    private var transactionTypePicker: some View {
        Picker("Type", selection: $transactionType) {
            ForEach([InvestmentTransactionType.buy, .sell, .dividend]) { type in
                Label(type.localizedName, systemImage: type.iconName)
                    .tag(type)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var helpButton: some View {
        Button(action: { showingHelpTip.toggle() }) {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
    
    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Investment Transactions")
                .font(.headline)
            
            Text("Track your investment activity to monitor portfolio performance and calculate gains/losses.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
            
            ForEach([InvestmentTransactionType.buy, .sell, .dividend]) { type in
                VStack(alignment: .leading, spacing: 4) {
                    Label(type.localizedName, systemImage: type.iconName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(type.helpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Average Cost Method")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Your cost basis is calculated using the Average Cost Method. When you sell shares, the app calculates your gain or loss based on the average price you paid for all shares.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var buySellSection: some View {
        Section("Transaction Details") {
            LabeledContent("Quantity") {
                TextField("", text: $sharesText)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }
            
            LabeledContent("Price per Share") {
                HStack {
                    if isLoadingQuote {
                        ProgressView()
                            .frame(width: 16, height: 16)
                    } else {
                        Spacer()
                            .frame(width: 16)
                    }
                    Text(CurrencyList.symbol(forCode: currentCurrency))
                        .foregroundStyle(.secondary)
                    TextField("", text: $pricePerShareText)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }
            
            LabeledContent("Fees") {
                HStack {
                    Text(CurrencyList.symbol(forCode: currentCurrency))
                        .foregroundStyle(.secondary)
                    TextField("", text: $feesText)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }
            
            Divider()
            
            LabeledContent("Total") {
                Text(CurrencyFormatter.format(totalAmount, currency: currentCurrency))
                    .fontWeight(.semibold)
            }
            .fontWeight(.semibold)
        }
    }
    
    @ViewBuilder
    private var dividendSection: some View {
        Section("Dividend Details") {
            HStack {
                Text("Amount")
                Spacer()
                Text(CurrencyList.symbol(forCode: currentCurrency))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $dividendAmountText)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
        }
    }
    
    @ViewBuilder
    private var splitSection: some View {
        Section {
            HStack {
                Text("Split Ratio")
                Spacer()
                TextField("2", text: $splitRatioText)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                Text(": 1")
                    .foregroundStyle(.secondary)
            }
            
            if let position = currentPosition, position.hasShares, splitRatio > 0 {
                HStack {
                    Text("New Share Count")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(InvestmentHelper.formatShares(position.shares * splitRatio))
                        .fontWeight(.medium)
                }
            }
        } header: {
            Text("Split Details")
        } footer: {
            Text("Enter the split ratio. For a 2:1 split, enter 2. For a 3:1 split, enter 3.")
        }
    }
    
    @ViewBuilder
    private var journalPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            let balances = calculateUpdatedBalances()
            if balances.isEmpty {
                Text("Stock splits do not create accounting entries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(balances, id: \.account.id) { item in
                    HStack {
                        Text(item.account.displayName)
                            .font(.subheadline)
                        Spacer()
                        Text(CurrencyFormatter.format(item.newBalance, currency: item.account.currency))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 4)
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func setupPreselectedAccount() {
        if let account = preselectedInvestmentAccount, account.accountType == .investment {
            selectedInvestmentAccount = account
        } else if investmentAccounts.count == 1 {
            selectedInvestmentAccount = investmentAccounts.first
        }
        
        // Pre-select first cash account if only one exists
        if cashAccounts.count == 1 {
            selectedCashAccount = cashAccounts.first
        }
        
        // Pre-select dividend income account if exists
        if let dividendAccount = incomeAccounts.first(where: { 
            $0.name.lowercased().contains("dividend") 
        }) {
            selectedIncomeAccount = dividendAccount
        } else {
            selectedIncomeAccount = incomeAccounts.first
        }
        
        // Load quote if account is preselected - handled by .task modifier
    }
    
    private func loadQuoteForSelectedAccount() async {
        guard settings.showLiveQuotes,
              let account = selectedInvestmentAccount,
              account.accountType == .investment,
              let isin = account.isin,
              !isin.isEmpty,
              transactionType == .buy || transactionType == .sell else {
            return
        }
        
        isLoadingQuote = true
        
        do {
            let locale = ETFAPIHelper.getUserLocale()
            let quote = try await ETFAPIHelper.shared.fetchQuote(isin: isin, locale: locale, currency: account.currency)
            
            // Set the price per share to the latest quote
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            pricePerShareText = formatter.string(from: quote.latestQuote.raw as NSDecimalNumber) ?? ""
        } catch {
            // Silently fail - user can enter price manually
            print("Failed to load ETF quote: \(error)")
        }
        
        isLoadingQuote = false
    }
    
    private func saveTransaction() {
        // Validate
        let errors = InvestmentHelper.validateTransaction(
            type: transactionType,
            shares: transactionType == .split ? splitRatio : shares,
            pricePerShare: pricePerShare,
            amount: dividendAmount,
            investmentAccount: selectedInvestmentAccount,
            cashAccount: transactionType.affectsCash ? selectedCashAccount : selectedInvestmentAccount
        )
        
        guard errors.isEmpty else {
            validationErrors = errors
            showingValidationError = true
            return
        }
        
        guard let investmentAccount = selectedInvestmentAccount else { return }
        
        let description = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultDescription = "\(transactionType.localizedName) \(investmentAccount.ticker ?? investmentAccount.name)"
        
        switch transactionType {
        case .buy:
            guard let cashAccount = selectedCashAccount else { return }
            _ = TransactionBuilder.createInvestmentBuy(
                date: date,
                description: description.isEmpty ? defaultDescription : description,
                shares: shares,
                pricePerShare: pricePerShare,
                fees: fees,
                investmentAccount: investmentAccount,
                cashAccount: cashAccount,
                context: modelContext
            )
            
        case .sell:
            guard let cashAccount = selectedCashAccount else { return }
            _ = TransactionBuilder.createInvestmentSell(
                date: date,
                description: description.isEmpty ? defaultDescription : description,
                shares: shares,
                pricePerShare: pricePerShare,
                fees: fees,
                investmentAccount: investmentAccount,
                cashAccount: cashAccount,
                context: modelContext
            )
            
        case .dividend:
            guard let cashAccount = selectedCashAccount,
                  let incomeAccount = selectedIncomeAccount else { return }
            _ = TransactionBuilder.createDividend(
                date: date,
                description: description.isEmpty ? "Dividend \(investmentAccount.ticker ?? investmentAccount.name)" : description,
                amount: dividendAmount,
                investmentAccount: investmentAccount,
                cashAccount: cashAccount,
                incomeAccount: incomeAccount,
                context: modelContext
            )
            
        case .split:
            _ = TransactionBuilder.createStockSplit(
                date: date,
                description: description.isEmpty ? "Stock split \(investmentAccount.ticker ?? investmentAccount.name)" : description,
                splitRatio: splitRatio,
                investmentAccount: investmentAccount,
                context: modelContext
            )
        }
        
        dismiss()
    }
}

#Preview {
    AddInvestmentTransactionView()
        .modelContainer(for: Account.self, inMemory: true)
        .environment(AppSettings.shared)
}
