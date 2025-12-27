//
//  OFXImportWizard.swift
//  Cash
//
//  Created by Michele Broggi on 27/11/25.
//

import SwiftUI
import SwiftData

/// Holds the import state for each OFX transaction
struct OFXImportItem: Identifiable {
    let id = UUID()
    let ofxTransaction: OFXTransaction
    var selectedCategory: Account?
    var shouldImport: Bool = true
}

/// Wizard steps
enum OFXImportStep: Int, CaseIterable {
    case selectAccount = 0
    case categorize = 1
    case review = 2
    case importing = 3
    case complete = 4
    
    var title: LocalizedStringKey {
        switch self {
        case .selectAccount: return "Select Account"
        case .categorize: return "Categorize Transactions"
        case .review: return "Review"
        case .importing: return "Importing..."
        case .complete: return "Complete"
        }
    }
}

struct OFXImportWizard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    
    let ofxTransactions: [OFXTransaction]
    
    @State private var currentStep: OFXImportStep = .selectAccount
    @State private var selectedBankAccount: Account?
    @State private var importItems: [OFXImportItem] = []
    @State private var currentItemIndex: Int = 0
    @State private var importProgress: Double = 0
    @State private var importedCount: Int = 0
    @State private var skippedCount: Int = 0
    
    private var bankAccounts: [Account] {
        accounts.filter { ($0.accountClass == .asset || $0.accountClass == .liability) && $0.isActive && !$0.isSystem }
    }
    
    private var expenseAccounts: [Account] {
        accounts.filter { $0.accountClass == .expense && $0.isActive }
    }
    
    private var incomeAccounts: [Account] {
        accounts.filter { $0.accountClass == .income && $0.isActive }
    }
    
    private var currentItem: OFXImportItem? {
        guard currentItemIndex < importItems.count else { return nil }
        return importItems[currentItemIndex]
    }
    
    private var itemsToImport: [OFXImportItem] {
        importItems.filter { $0.shouldImport && $0.selectedCategory != nil }
    }
    
    private var uncategorizedCount: Int {
        importItems.filter { $0.shouldImport && $0.selectedCategory == nil }.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                Divider()
                
                // Content based on step
                Group {
                    switch currentStep {
                    case .selectAccount:
                        selectAccountStep
                    case .categorize:
                        categorizeStep
                    case .review:
                        reviewStep
                    case .importing:
                        importingStep
                    case .complete:
                        completeStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                
                // Navigation buttons
                navigationButtons
            }
            .navigationTitle("Import OFX")
            .frame(minWidth: 600, minHeight: 500)
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 0) {
            ForEach(Array(OFXImportStep.allCases.enumerated()), id: \.element) { index, step in
                if step == .importing { EmptyView() }
                else {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if currentStep.rawValue > step.rawValue {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                } else {
                                    Text("\(step.rawValue + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(currentStep == step ? .white : .secondary)
                                }
                            }
                        
                        if step != .complete {
                            Text(step.title)
                                .font(.caption)
                                .foregroundStyle(currentStep.rawValue >= step.rawValue ? .primary : .secondary)
                            
                            if index < OFXImportStep.allCases.count - 2 {
                                Rectangle()
                                    .fill(currentStep.rawValue > step.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                                    .frame(height: 2)
                                    .frame(maxWidth: 40)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private func stepColor(for step: OFXImportStep) -> Color {
        if currentStep.rawValue > step.rawValue {
            return .green
        } else if currentStep == step {
            return .accentColor
        } else {
            return .secondary.opacity(0.3)
        }
    }
    
    // MARK: - Step 1: Select Account
    
    private var selectAccountStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "building.columns")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Select the bank account for these transactions")
                .font(.headline)
            
            Text("\(ofxTransactions.count) transactions found")
                .foregroundStyle(.secondary)
            
            Picker("Bank Account", selection: $selectedBankAccount) {
                Text("Select an account").tag(nil as Account?)
                ForEach(bankAccounts) { account in
                    Label(account.displayName, systemImage: account.effectiveIconName)
                        .tag(account as Account?)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 300)
        }
        .padding()
    }
    
    // MARK: - Step 2: Categorize
    
    private var categorizeStep: some View {
        VStack(spacing: 16) {
            // Progress
            HStack {
                Text("Transaction \(currentItemIndex + 1) of \(importItems.count)")
                    .font(.headline)
                Spacer()
                Text("\(importItems.filter { $0.selectedCategory != nil }.count) categorized")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            ProgressView(value: Double(currentItemIndex), total: Double(importItems.count))
                .padding(.horizontal)
            
            if let item = currentItem {
                categorizeItemView(item: item)
            }
            
            // Quick navigation
            HStack {
                Button("Previous") {
                    if currentItemIndex > 0 {
                        currentItemIndex -= 1
                    }
                }
                .disabled(currentItemIndex == 0)
                
                Spacer()
                
                Button("Skip") {
                    importItems[currentItemIndex].shouldImport = false
                    moveToNextItem()
                }
                
                Button("Next") {
                    moveToNextItem()
                }
                .disabled(currentItem?.selectedCategory == nil)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private func categorizeItemView(item: OFXImportItem) -> some View {
        VStack(spacing: 16) {
            // Transaction details card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: item.ofxTransaction.isExpense ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.title)
                        .foregroundStyle(item.ofxTransaction.isExpense ? .red : .green)
                    
                    VStack(alignment: .leading) {
                        Text(item.ofxTransaction.name)
                            .font(.headline)
                        
                        if let memo = item.ofxTransaction.memo, !memo.isEmpty {
                            Text(memo)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Text(CurrencyFormatter.format(item.ofxTransaction.absoluteAmount, currency: selectedBankAccount?.currency ?? "EUR"))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(item.ofxTransaction.isExpense ? .red : .green)
                }
                
                HStack {
                    Label(item.ofxTransaction.datePosted.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    Spacer()
                    Text(item.ofxTransaction.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            // Category selection
            VStack(alignment: .leading, spacing: 8) {
                Text(item.ofxTransaction.isExpense ? "Select expense category" : "Select income category")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                let categoryAccounts = item.ofxTransaction.isExpense ? expenseAccounts : incomeAccounts
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 8) {
                    ForEach(categoryAccounts) { account in
                        CategoryButton(
                            account: account,
                            isSelected: importItems[currentItemIndex].selectedCategory?.id == account.id
                        ) {
                            importItems[currentItemIndex].selectedCategory = account
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Step 3: Review
    
    private var reviewStep: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Ready to import")
                        .font(.headline)
                    Text("\(itemsToImport.count) transactions will be imported")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if uncategorizedCount > 0 {
                    Label("\(uncategorizedCount) uncategorized", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            
            List {
                ForEach(importItems) { item in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { item.shouldImport },
                            set: { newValue in
                                if let index = importItems.firstIndex(where: { $0.id == item.id }) {
                                    importItems[index].shouldImport = newValue
                                }
                            }
                        ))
                        .labelsHidden()
                        
                        VStack(alignment: .leading) {
                            Text(item.ofxTransaction.name)
                                .font(.subheadline)
                            HStack {
                                Text(item.ofxTransaction.datePosted.formatted(date: .abbreviated, time: .omitted))
                                if let category = item.selectedCategory {
                                    Text("→")
                                    Text(category.displayName)
                                        .foregroundStyle(.blue)
                                } else if item.shouldImport {
                                    Text("→")
                                    Text("No category")
                                        .foregroundStyle(.orange)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(CurrencyFormatter.format(item.ofxTransaction.absoluteAmount, currency: selectedBankAccount?.currency ?? "EUR"))
                            .foregroundStyle(item.ofxTransaction.isExpense ? .red : .green)
                            .fontWeight(.medium)
                    }
                    .opacity(item.shouldImport ? 1 : 0.5)
                }
            }
        }
    }
    
    // MARK: - Step 4: Importing
    
    private var importingStep: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Importing transactions...")
                .font(.headline)
            
            ProgressView(value: importProgress)
                .frame(maxWidth: 300)
            
            Text("\(importedCount) of \(itemsToImport.count)")
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Step 5: Complete
    
    private var completeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            
            Text("Import Complete!")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                Text("\(importedCount) transactions imported")
                if skippedCount > 0 {
                    Text("\(skippedCount) transactions skipped")
                        .foregroundStyle(.secondary)
                }
            }
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            
            Spacer()
            
            if currentStep == .selectAccount {
                Button("Next") {
                    setupImportItems()
                    currentStep = .categorize
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedBankAccount == nil)
            } else if currentStep == .categorize {
                Button("Review All") {
                    currentStep = .review
                }
                .buttonStyle(.borderedProminent)
            } else if currentStep == .review {
                Button("Back") {
                    currentStep = .categorize
                }
                
                Button("Import \(itemsToImport.count) Transactions") {
                    performImport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(itemsToImport.isEmpty)
            }
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func setupImportItems() {
        importItems = ofxTransactions.map { OFXImportItem(ofxTransaction: $0) }
        currentItemIndex = 0
    }
    
    private func moveToNextItem() {
        if currentItemIndex < importItems.count - 1 {
            currentItemIndex += 1
        } else {
            currentStep = .review
        }
    }
    
    private func performImport() {
        currentStep = .importing
        let items = itemsToImport
        let bankAccount = selectedBankAccount!
        
        Task {
            for (index, item) in items.enumerated() {
                await MainActor.run {
                    importProgress = Double(index) / Double(items.count)
                }
                
                await MainActor.run {
                    createTransaction(from: item, bankAccount: bankAccount)
                    importedCount += 1
                }
                
                // Small delay for visual feedback
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            
            await MainActor.run {
                skippedCount = importItems.filter { !$0.shouldImport }.count
                importProgress = 1.0
                currentStep = .complete
            }
        }
    }
    
    private func createTransaction(from item: OFXImportItem, bankAccount: Account) {
        guard let category = item.selectedCategory else { return }
        
        let ofx = item.ofxTransaction
        let description = ofx.memo ?? ofx.name
        
        if ofx.isExpense {
            _ = TransactionBuilder.createExpense(
                date: ofx.datePosted,
                description: description,
                amount: ofx.absoluteAmount,
                expenseAccount: category,
                paymentAccount: bankAccount,
                reference: ofx.fitId,
                context: modelContext
            )
        } else {
            _ = TransactionBuilder.createIncome(
                date: ofx.datePosted,
                description: description,
                amount: ofx.absoluteAmount,
                depositAccount: bankAccount,
                incomeAccount: category,
                reference: ofx.fitId,
                context: modelContext
            )
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let account: Account
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: account.accountType.iconName)
                Text(account.displayName)
                    .lineLimit(1)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OFXImportWizard(ofxTransactions: [
        OFXTransaction(fitId: "1", type: .debit, datePosted: Date(), amount: -50.00, name: "Grocery Store", memo: "Weekly shopping"),
        OFXTransaction(fitId: "2", type: .credit, datePosted: Date(), amount: 1500.00, name: "Salary", memo: nil),
        OFXTransaction(fitId: "3", type: .debit, datePosted: Date(), amount: -120.00, name: "Electric Company", memo: "Monthly bill")
    ])
    .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
    .environment(AppSettings.shared)
}
