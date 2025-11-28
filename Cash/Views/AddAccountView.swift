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
                
                if selectedClass == .asset || selectedClass == .liability {
                    Section("Opening balance") {
                        Toggle("Set opening balance", isOn: $createOpeningBalance)
                        
                        if createOpeningBalance {
                            TextField("Amount", text: $initialBalance)
                                .help("Enter the starting balance for this account")
                        }
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
            accountType: selectedType
        )
        
        modelContext.insert(account)
        
        if createOpeningBalance && balance > 0, let equityAccount = openingBalanceEquityAccount {
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
