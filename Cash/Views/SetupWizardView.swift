//
//  SetupWizardView.swift
//  Cash
//
//  Created by Michele Broggi on 26/11/25.
//

import SwiftUI
import SwiftData

enum WizardStep: Int, CaseIterable {
    case welcome = 0
    case preferences = 1
    case accounts = 2
}

struct AccountSetupInfo: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var accountNumber: String
    let accountClass: AccountClass
    var accountType: AccountType
    var initialBalance: String = ""
    
    var parsedBalance: Decimal {
        CurrencyFormatter.parse(initialBalance)
    }
    
    static func == (lhs: AccountSetupInfo, rhs: AccountSetupInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct SetupWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    @Binding var isPresented: Bool
    
    @State private var currentStep: WizardStep = .welcome
    @State private var selectedCurrency: String = "EUR"
    @State private var accountSetupList: [AccountSetupInfo] = []
    @State private var showingAddAccount = false
    @State private var addAccountForClass: AccountClass = .asset
    @State private var newAccountName: String = ""
    @State private var newAccountType: AccountType = .bank
    
    var body: some View {
        @Bindable var settings = settings
        
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(WizardStep.allCases, id: \.rawValue) { step in
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            // Step content
            Group {
                switch currentStep {
                case .welcome:
                    welcomeStep
                case .preferences:
                    preferencesStep(settings: $settings)
                case .accounts:
                    accountsStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Navigation buttons
            HStack {
                if currentStep != .welcome {
                    Button(String(localized: "Back")) {
                        withAnimation {
                            if let previous = WizardStep(rawValue: currentStep.rawValue - 1) {
                                currentStep = previous
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentStep == .accounts {
                    Button(String(localized: "Get Started")) {
                        completeSetup()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(String(localized: "Next")) {
                        withAnimation {
                            if let next = WizardStep(rawValue: currentStep.rawValue + 1) {
                                currentStep = next
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 650, height: 580)
        .environment(\.locale, settings.language.locale)
        .onChange(of: currentStep) { oldValue, newValue in
            // Initialize account list when entering the accounts step
            if newValue == .accounts {
                initializeAccountList()
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            addAccountSheet
        }
    }
    
    private func initializeAccountList() {
        // Keep user-added accounts when reinitializing
        let userAddedAccounts = accountSetupList.filter { info in
            !isDefaultAccount(info)
        }
        
        accountSetupList = [
            // Assets
            AccountSetupInfo(name: String(localized: "Cash"), accountNumber: "1000", accountClass: .asset, accountType: .cash),
            AccountSetupInfo(name: String(localized: "Bank Account"), accountNumber: "1010", accountClass: .asset, accountType: .bank),
            // Liabilities
            AccountSetupInfo(name: String(localized: "Credit Card"), accountNumber: "2000", accountClass: .liability, accountType: .creditCard),
            // Income
            AccountSetupInfo(name: String(localized: "Salary"), accountNumber: "4000", accountClass: .income, accountType: .salary),
            AccountSetupInfo(name: String(localized: "Other Income"), accountNumber: "4900", accountClass: .income, accountType: .otherIncome),
            // Expenses
            AccountSetupInfo(name: String(localized: "Food & Dining"), accountNumber: "5000", accountClass: .expense, accountType: .food),
            AccountSetupInfo(name: String(localized: "Transportation"), accountNumber: "5100", accountClass: .expense, accountType: .transportation),
            AccountSetupInfo(name: String(localized: "Utilities"), accountNumber: "5200", accountClass: .expense, accountType: .utilities),
            AccountSetupInfo(name: String(localized: "Housing"), accountNumber: "5300", accountClass: .expense, accountType: .housing),
            AccountSetupInfo(name: String(localized: "Healthcare"), accountNumber: "5400", accountClass: .expense, accountType: .healthcare),
            AccountSetupInfo(name: String(localized: "Entertainment"), accountNumber: "5500", accountClass: .expense, accountType: .entertainment),
            AccountSetupInfo(name: String(localized: "Shopping"), accountNumber: "5600", accountClass: .expense, accountType: .shopping),
            AccountSetupInfo(name: String(localized: "Subscriptions"), accountNumber: "5700", accountClass: .expense, accountType: .subscriptions),
            AccountSetupInfo(name: String(localized: "Other Expense"), accountNumber: "5900", accountClass: .expense, accountType: .otherExpense),
        ]
        
        // Re-add user accounts
        accountSetupList.append(contentsOf: userAddedAccounts)
    }
    
    private func isDefaultAccount(_ info: AccountSetupInfo) -> Bool {
        let defaultAccountNumbers = ["1000", "1010", "2000", "4000", "4900", "5000", "5100", "5200", "5300", "5400", "5500", "5600", "5700", "5900"]
        return defaultAccountNumbers.contains(info.accountNumber)
    }
    
    private func nextAccountNumber(for accountClass: AccountClass) -> String {
        let classAccounts = accountSetupList.filter { $0.accountClass == accountClass }
        let maxNumber = classAccounts.compactMap { Int($0.accountNumber) }.max() ?? 0
        return String(maxNumber + 10)
    }
    
    // MARK: - Welcome Step
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "building.columns.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
            
            Text("Welcome to Cash")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Track your personal finances with ease using double-entry bookkeeping.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("Press ESC to quit")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Preferences Step
    
    @ViewBuilder
    private func preferencesStep(settings: Bindable<AppSettings>) -> some View {
        VStack(spacing: 20) {
            Text("Choose Your Preferences")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            Text("Select your preferred language, currency, and theme.")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Form {
                Section(String(localized: "Language")) {
                    Picker(String(localized: "Language"), selection: settings.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.localizedName)
                                .tag(language)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
                
                Section(String(localized: "Default Currency")) {
                    Picker(String(localized: "Currency"), selection: $selectedCurrency) {
                        ForEach(CurrencyList.currencies) { currency in
                            Text(currency.displayName)
                                .tag(currency.code)
                        }
                    }
                    .labelsHidden()
                }
                
                Section(String(localized: "Theme")) {
                    Picker(String(localized: "Theme"), selection: settings.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.localizedName)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
            }
            .formStyle(.grouped)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Accounts Step
    
    private var accountsStep: some View {
        VStack(spacing: 12) {
            Text("Default Accounts")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            Text("These accounts will be created. Set opening balances for your asset and liability accounts.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            List {
                Section {
                    ForEach(assetAccounts) { accountInfo in
                        accountRow(for: accountInfo)
                    }
                    addAccountButton(for: .asset)
                } header: {
                    Text(AccountClass.asset.localizedPluralName)
                }
                
                Section {
                    ForEach(liabilityAccounts) { accountInfo in
                        accountRow(for: accountInfo)
                    }
                    addAccountButton(for: .liability)
                } header: {
                    Text(AccountClass.liability.localizedPluralName)
                }
                
                Section {
                    ForEach(incomeAccounts) { accountInfo in
                        accountRow(for: accountInfo)
                    }
                    addAccountButton(for: .income)
                } header: {
                    Text(AccountClass.income.localizedPluralName)
                }
                
                Section {
                    ForEach(expenseAccounts) { accountInfo in
                        accountRow(for: accountInfo)
                    }
                    addAccountButton(for: .expense)
                } header: {
                    Text(AccountClass.expense.localizedPluralName)
                }
            }
            .listStyle(.inset)
        }
        .padding(.horizontal)
    }
    
    private var assetAccounts: [AccountSetupInfo] {
        accountSetupList.filter { $0.accountClass == .asset }
    }
    
    private var liabilityAccounts: [AccountSetupInfo] {
        accountSetupList.filter { $0.accountClass == .liability }
    }
    
    private var incomeAccounts: [AccountSetupInfo] {
        accountSetupList.filter { $0.accountClass == .income }
    }
    
    private var expenseAccounts: [AccountSetupInfo] {
        accountSetupList.filter { $0.accountClass == .expense }
    }
    
    private func addAccountButton(for accountClass: AccountClass) -> some View {
        Button {
            addAccountForClass = accountClass
            newAccountName = ""
            newAccountType = AccountType.types(for: accountClass).first ?? .bank
            showingAddAccount = true
        } label: {
            Label(String(localized: "Add Account"), systemImage: "plus.circle")
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }
    
    private func accountRow(for accountInfo: AccountSetupInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: accountInfo.accountType.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            Text(accountInfo.accountType.localizedName)
            
            Spacer()
            
            // Show balance input only for assets and liabilities
            if accountInfo.accountClass == .asset || accountInfo.accountClass == .liability {
                HStack(spacing: 4) {
                    Text(CurrencyList.symbol(forCode: selectedCurrency))
                        .foregroundStyle(.secondary)
                    
                    TextField("0", text: binding(for: accountInfo))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    private func binding(for accountInfo: AccountSetupInfo) -> Binding<String> {
        Binding(
            get: { accountSetupList.first { $0.id == accountInfo.id }?.initialBalance ?? "" },
            set: { newValue in
                if let index = accountSetupList.firstIndex(where: { $0.id == accountInfo.id }) {
                    accountSetupList[index].initialBalance = newValue
                }
            }
        )
    }
    
    // MARK: - Add Account Sheet
    
    private var addAccountSheet: some View {
        VStack(spacing: 20) {
            Text(String(localized: "New Account"))
                .font(.headline)
            
            Form {
                TextField(String(localized: "Account Name"), text: $newAccountName)
                
                Picker(String(localized: "Type"), selection: $newAccountType) {
                    ForEach(AccountType.types(for: addAccountForClass)) { type in
                        Label(type.localizedName, systemImage: type.iconName)
                            .tag(type)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(height: 150)
            
            HStack {
                Button(String(localized: "Cancel")) {
                    showingAddAccount = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(String(localized: "Add")) {
                    let newAccount = AccountSetupInfo(
                        name: newAccountName,
                        accountNumber: nextAccountNumber(for: addAccountForClass),
                        accountClass: addAccountForClass,
                        accountType: newAccountType
                    )
                    accountSetupList.append(newAccount)
                    showingAddAccount = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newAccountName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 350, height: 280)
    }
    
    // MARK: - Complete Setup
    
    private func completeSetup() {
        // First create Opening Balance Equity account (system account, always needed)
        let equityAccount = Account(
            name: "Opening Balance Equity",
            accountNumber: "3000",
            currency: selectedCurrency,
            accountClass: .equity,
            accountType: .openingBalance,
            isSystem: true
        )
        modelContext.insert(equityAccount)
        
        // Create all user accounts and track those with balances
        var accountsWithBalances: [(Account, Decimal)] = []
        
        for info in accountSetupList {
            let account = Account(
                name: info.name,
                accountNumber: info.accountNumber,
                currency: selectedCurrency,
                accountClass: info.accountClass,
                accountType: info.accountType,
                isSystem: false
            )
            modelContext.insert(account)
            
            let balance = info.parsedBalance
            if balance > 0 {
                accountsWithBalances.append((account, balance))
            }
        }
        
        // Create opening balance transactions
        for (account, balance) in accountsWithBalances {
            _ = TransactionBuilder.createOpeningBalance(
                account: account,
                amount: balance,
                openingBalanceEquityAccount: equityAccount,
                context: modelContext
            )
        }
        
        // Mark setup as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
        
        // Close wizard
        isPresented = false
    }
}

#Preview {
    SetupWizardView(isPresented: .constant(true))
        .environment(AppSettings.shared)
        .modelContainer(for: Account.self, inMemory: true)
}
