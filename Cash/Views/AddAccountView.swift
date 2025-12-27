//
//  AddAccountView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData

struct AddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    
    @State private var name: String = ""
    @State private var accountNumber: String = ""
    @State private var selectedCurrency: String = "EUR"
    @State private var selectedClass: AccountClass = .asset
    @State private var selectedType: AccountType = .bank
    @State private var initialBalance: String = ""
    @State private var createOpeningBalance: Bool = false
    @State private var includedInBudget: Bool = false
    
    // Investment-specific fields
    @State private var isin: String = ""
    @State private var ticker: String = ""
    
    // Custom icon
    @State private var showingIconPicker = false
    @State private var customIconName: String?
    
    @State private var showingValidationError = false
    @State private var validationMessage: LocalizedStringKey = ""
    
    private var availableTypes: [AccountType] {
        AccountType.types(for: selectedClass)
    }
    
    private var openingBalanceEquityAccount: Account? {
        accounts.first { $0.accountType == .openingBalance && $0.isSystem }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account information") {
                    TextField("Account name", text: $name)
                    TextField("Account number", text: $accountNumber)
                        .help("Optional number for organizing accounts (e.g., 1000, 2000)")
                }
                
                Section("Account class") {
                    Picker("Class", selection: $selectedClass) {
                        ForEach(AccountClass.allCases) { accountClass in
                            Label(accountClass.localizedName, systemImage: accountClass.iconName)
                                .tag(accountClass)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .onChange(of: selectedClass) {
                        if let firstType = availableTypes.first {
                            selectedType = firstType
                        }
                    }
                }
                
                Section("Account type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(availableTypes) { type in
                            Label(type.localizedName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                
                Section("Currency") {
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(CurrencyList.currencies) { currency in
                            Text(currency.displayName)
                                .tag(currency.code)
                        }
                    }
                }
                
                // Investment-specific fields
                if selectedType == .investment {
                    Section {
                        TextField("ISIN", text: $isin)
                            .help("International Securities Identification Number (e.g., IE00B4L5Y983)")
                        
                        TextField("Ticker", text: $ticker)
                            .help("Stock ticker symbol (e.g., IWDA)")
                    } header: {
                        Text("Investment Details")
                    } footer: {
                        Text("Optional: Add ISIN and ticker for better tracking of your investments.")
                    }
                }
                
                // Custom icon picker
                if selectedType == .otherExpense || selectedType == .otherIncome {
                    Section {
                        HStack {
                            Image(systemName: customIconName ?? selectedType.iconName)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            
                            Text("Icon")
                            
                            Spacer()
                            
                            Button(customIconName == nil ? "Choose Icon" : "Change Icon") {
                                showingIconPicker = true
                            }
                        }
                        
                        if customIconName != nil {
                            Button("Reset to Default") {
                                customIconName = nil
                            }
                            .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Personalization")
                    } footer: {
                        Text("Customize the icon to better represent this category.")
                    }
                }
                
                if selectedClass == .asset || selectedClass == .liability {
                    Section("Opening balance") {
                        Toggle("Set opening balance", isOn: $createOpeningBalance)
                        
                        if createOpeningBalance {
                            TextField("Amount", text: $initialBalance)
                                .help("Enter the starting balance for this account")
                        }
                    }
                }
                
                if selectedClass == .expense {
                    Section {
                        Toggle("Include in Budget", isOn: $includedInBudget)
                    } header: {
                        Text("Budget")
                    } footer: {
                        Text("Enable this to use this category as an envelope in your budget.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAccount()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .alert("Validation error", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
            .onAppear {
                if let firstType = availableTypes.first {
                    selectedType = firstType
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $customIconName)
            }
            .id(settings.refreshID)
        }
        .frame(minWidth: 400, minHeight: 550)
    }
    
    private func saveAccount() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Please enter an account name."
            showingValidationError = true
            return
        }
        
        var balance: Decimal = 0
        if createOpeningBalance && !initialBalance.isEmpty {
            let parsed = CurrencyFormatter.parse(initialBalance)
            if parsed > 0 {
                balance = parsed
            } else if !initialBalance.isEmpty {
                validationMessage = "Please enter a valid number for the balance."
                showingValidationError = true
                return
            }
        }
        
        let account = Account(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            accountNumber: accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            currency: selectedCurrency,
            accountClass: selectedClass,
            accountType: selectedType,
            includedInBudget: selectedClass == .expense ? includedInBudget : false
        )
        
        // Set investment-specific fields
        if selectedType == .investment {
            account.isin = isin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().isEmpty ? nil : isin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            account.ticker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().isEmpty ? nil : ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }
        
        // Set custom icon if selected
        account.customIconName = customIconName
        
        modelContext.insert(account)
        
        if createOpeningBalance && balance > 0 {
            // Find or create the Opening Balance Equity account
            let equityAccount: Account
            if let existingEquity = openingBalanceEquityAccount {
                equityAccount = existingEquity
            } else {
                // Create the Opening Balance Equity account if it doesn't exist
                equityAccount = Account(
                    name: AccountType.openingBalance.localizedName,
                    accountNumber: "",
                    currency: selectedCurrency,
                    accountClass: .equity,
                    accountType: .openingBalance,
                    isSystem: true
                )
                modelContext.insert(equityAccount)
            }
            
            _ = TransactionBuilder.createOpeningBalance(
                account: account,
                amount: balance,
                openingBalanceEquityAccount: equityAccount,
                context: modelContext
            )
        }
        
        dismiss()
    }
}

#Preview {
    AddAccountView()
        .modelContainer(for: Account.self, inMemory: true)
        .environment(AppSettings.shared)
}
