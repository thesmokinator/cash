//
//  EditAccountView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData

struct EditAccountView: View {
    @Bindable var account: Account
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var name: String = ""
    @State private var accountNumber: String = ""
    @State private var selectedCurrency: String = "EUR"
    @State private var selectedClass: AccountClass = .asset
    @State private var selectedType: AccountType = .bank
    @State private var isActive: Bool = true
    
    @State private var showingValidationError = false
    @State private var validationMessage: LocalizedStringKey = ""
    
    private var availableTypes: [AccountType] {
        AccountType.types(for: selectedClass)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account information") {
                    TextField("Account name", text: $name)
                    TextField("Account number", text: $accountNumber)
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
                
                Section("Status") {
                    Toggle("Active", isOn: $isActive)
                        .help("Inactive accounts are hidden from selection lists")
                }
                
                Section {
                    HStack {
                        Text("Current balance")
                        Spacer()
                        Text(CurrencyFormatter.format(account.balance, currency: account.currency))
                            .fontWeight(.medium)
                    }
                } header: {
                    Text("Balance")
                } footer: {
                    Text("Balance is calculated from all journal entries. To adjust, create a correcting entry.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
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
                loadAccountData()
            }
            .id(settings.refreshID)
        }
        .frame(minWidth: 400, minHeight: 550)
    }
    
    private func loadAccountData() {
        name = account.name
        accountNumber = account.accountNumber
        selectedCurrency = account.currency
        selectedClass = account.accountClass
        selectedType = account.accountType
        isActive = account.isActive
    }
    
    private func saveChanges() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Please enter an account name."
            showingValidationError = true
            return
        }
        
        account.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        account.accountNumber = accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        account.currency = selectedCurrency
        account.accountClass = selectedClass
        account.accountType = selectedType
        account.isActive = isActive
        
        dismiss()
    }
}

#Preview {
    @Previewable @State var account = Account(
        name: "Checking Account",
        accountNumber: "1010",
        currency: "EUR",
        accountClass: .asset,
        accountType: .bank
    )
    
    EditAccountView(account: account)
        .modelContainer(for: Account.self, inMemory: true)
        .environment(AppSettings.shared)
}
