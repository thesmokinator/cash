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
        case .selectAccount: return "Account"
        case .categorize: return "Categorize"
        case .review: return "Review"
        case .importing: return "Importing"
        case .complete: return "Done"
        }
    }

    var iconName: String {
        switch self {
        case .selectAccount: return "building.columns"
        case .categorize: return "tag"
        case .review: return "checkmark.circle"
        case .importing: return "arrow.down.circle"
        case .complete: return "checkmark.seal"
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
                    .padding(.horizontal, CashSpacing.lg)
                    .padding(.vertical, CashSpacing.md)

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
            }
            .navigationTitle("Import OFX")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if currentStep != .complete && currentStep != .importing {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: CashSpacing.xs) {
            ForEach([OFXImportStep.selectAccount, .categorize, .review], id: \.self) { step in
                HStack(spacing: CashSpacing.xs) {
                    // Step circle
                    ZStack {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 32, height: 32)

                        if currentStep.rawValue > step.rawValue {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: step.iconName)
                                .font(.caption2.bold())
                                .foregroundStyle(currentStep.rawValue >= step.rawValue ? .white : .secondary)
                        }
                    }

                    // Step title (only on iPad or for current step)
                    Text(step.title)
                        .font(CashTypography.caption)
                        .foregroundStyle(currentStep.rawValue >= step.rawValue ? .primary : .secondary)
                        .lineLimit(1)

                    // Connector line
                    if step != .review {
                        Rectangle()
                            .fill(currentStep.rawValue > step.rawValue ? CashColors.primary : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func stepColor(for step: OFXImportStep) -> Color {
        if currentStep.rawValue > step.rawValue {
            return CashColors.success
        } else if currentStep == step {
            return CashColors.primary
        } else {
            return .secondary.opacity(0.3)
        }
    }

    // MARK: - Step 1: Select Account

    private var selectAccountStep: some View {
        VStack(spacing: 0) {
            // Header section
            VStack(spacing: CashSpacing.md) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(CashColors.primary)

                Text("Select Bank Account")
                    .font(CashTypography.title2)

                Text("\(ofxTransactions.count) transactions found in OFX file")
                    .font(CashTypography.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, CashSpacing.xl)

            // Account list
            List {
                Section {
                    ForEach(bankAccounts) { account in
                        Button {
                            selectedBankAccount = account
                        } label: {
                            HStack(spacing: CashSpacing.md) {
                                Image(systemName: account.effectiveIconName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(accountColor(for: account))
                                    .clipShape(RoundedRectangle(cornerRadius: CashRadius.small))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.displayName)
                                        .font(CashTypography.body)
                                        .foregroundStyle(.primary)

                                    Text(account.accountType.localizedName)
                                        .font(CashTypography.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedBankAccount?.id == account.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(CashColors.primary)
                                }
                            }
                            .padding(.vertical, CashSpacing.xs)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Choose the destination account")
                }
            }
            .listStyleInsetGrouped()

            // Next button
            VStack(spacing: CashSpacing.md) {
                Button {
                    setupImportItems()
                    withAnimation {
                        currentStep = .categorize
                    }
                } label: {
                    Text("Continue")
                        .font(CashTypography.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CashSpacing.md)
                }
                .buttonStyle(.borderedProminent)
                .tint(CashColors.primary)
                .disabled(selectedBankAccount == nil)
            }
            .padding(CashSpacing.lg)
            .background(.bar)
        }
    }

    private func accountColor(for account: Account) -> Color {
        switch account.accountClass {
        case .asset: return CashColors.success
        case .liability: return CashColors.error
        default: return CashColors.primary
        }
    }

    // MARK: - Step 2: Categorize

    private var categorizeStep: some View {
        VStack(spacing: 0) {
            // Progress header
            VStack(spacing: CashSpacing.sm) {
                HStack {
                    Text("Transaction \(currentItemIndex + 1) of \(importItems.count)")
                        .font(CashTypography.headline)
                    Spacer()
                    Text("\(importItems.filter { $0.selectedCategory != nil }.count) categorized")
                        .font(CashTypography.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: Double(currentItemIndex + 1), total: Double(importItems.count))
                    .tint(CashColors.primary)
            }
            .padding(.horizontal, CashSpacing.lg)
            .padding(.vertical, CashSpacing.md)

            Divider()

            if let item = currentItem {
                ScrollView {
                    VStack(spacing: CashSpacing.lg) {
                        // Transaction card
                        transactionCard(item: item)

                        // Category selection
                        categorySelection(item: item)
                    }
                    .padding(CashSpacing.lg)
                }
            }

            // Navigation buttons
            HStack(spacing: CashSpacing.md) {
                Button {
                    if currentItemIndex > 0 {
                        currentItemIndex -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(currentItemIndex == 0)

                Button {
                    importItems[currentItemIndex].shouldImport = false
                    moveToNextItem()
                } label: {
                    Text("Skip")
                        .font(CashTypography.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CashSpacing.sm)
                }
                .buttonStyle(.bordered)

                Button {
                    moveToNextItem()
                } label: {
                    HStack {
                        Text(currentItemIndex < importItems.count - 1 ? "Next" : "Review")
                        Image(systemName: "chevron.right")
                    }
                    .font(CashTypography.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CashSpacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(CashColors.primary)
                .disabled(currentItem?.selectedCategory == nil)
            }
            .padding(CashSpacing.lg)
            .background(.bar)
        }
    }

    private func transactionCard(item: OFXImportItem) -> some View {
        VStack(spacing: CashSpacing.md) {
            HStack(alignment: .top, spacing: CashSpacing.md) {
                // Transaction icon
                Image(systemName: item.ofxTransaction.isExpense ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(item.ofxTransaction.isExpense ? CashColors.error : CashColors.success)

                VStack(alignment: .leading, spacing: CashSpacing.xs) {
                    Text(item.ofxTransaction.name)
                        .font(CashTypography.headline)

                    if let memo = item.ofxTransaction.memo, !memo.isEmpty {
                        Text(memo)
                            .font(CashTypography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: CashSpacing.md) {
                        Label(item.ofxTransaction.datePosted.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")

                        Text(item.ofxTransaction.type.rawValue)
                            .padding(.horizontal, CashSpacing.sm)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                    .font(CashTypography.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(CurrencyFormatter.format(item.ofxTransaction.absoluteAmount, currency: selectedBankAccount?.currency ?? "EUR"))
                    .font(CashTypography.title2.weight(.bold))
                    .foregroundStyle(item.ofxTransaction.isExpense ? CashColors.error : CashColors.success)
            }
        }
        .padding(CashSpacing.lg)
        .background(.ultraThinMaterial)
        .background(CashColors.glassBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CashRadius.large))
    }

    private func categorySelection(item: OFXImportItem) -> some View {
        VStack(alignment: .leading, spacing: CashSpacing.md) {
            Text(item.ofxTransaction.isExpense ? "Select expense category" : "Select income category")
                .font(CashTypography.subheadline)
                .foregroundStyle(.secondary)

            let categoryAccounts = item.ofxTransaction.isExpense ? expenseAccounts : incomeAccounts

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: CashSpacing.sm)], spacing: CashSpacing.sm) {
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
    }

    // MARK: - Step 3: Review

    private var reviewStep: some View {
        VStack(spacing: 0) {
            // Summary header
            VStack(spacing: CashSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ready to Import")
                            .font(CashTypography.headline)
                        Text("\(itemsToImport.count) transactions will be imported")
                            .font(CashTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if uncategorizedCount > 0 {
                        Label("\(uncategorizedCount) uncategorized", systemImage: "exclamationmark.triangle.fill")
                            .font(CashTypography.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.horizontal, CashSpacing.lg)
            .padding(.vertical, CashSpacing.md)

            Divider()

            List {
                ForEach(importItems) { item in
                    HStack(spacing: CashSpacing.md) {
                        Toggle("", isOn: Binding(
                            get: { item.shouldImport },
                            set: { newValue in
                                if let index = importItems.firstIndex(where: { $0.id == item.id }) {
                                    importItems[index].shouldImport = newValue
                                }
                            }
                        ))
                        .labelsHidden()

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.ofxTransaction.name)
                                .font(CashTypography.body)
                                .lineLimit(1)

                            HStack(spacing: CashSpacing.xs) {
                                Text(item.ofxTransaction.datePosted.formatted(date: .abbreviated, time: .omitted))
                                if let category = item.selectedCategory {
                                    Image(systemName: "arrow.right")
                                    Text(category.displayName)
                                        .foregroundStyle(CashColors.primary)
                                } else if item.shouldImport {
                                    Image(systemName: "arrow.right")
                                    Text("No category")
                                        .foregroundStyle(.orange)
                                }
                            }
                            .font(CashTypography.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(CurrencyFormatter.format(item.ofxTransaction.absoluteAmount, currency: selectedBankAccount?.currency ?? "EUR"))
                            .font(CashTypography.body.weight(.semibold))
                            .foregroundStyle(item.ofxTransaction.isExpense ? CashColors.error : CashColors.success)
                    }
                    .opacity(item.shouldImport ? 1 : 0.4)
                }
            }
            .listStyle(.plain)

            // Action buttons
            HStack(spacing: CashSpacing.md) {
                Button {
                    withAnimation {
                        currentStep = .categorize
                    }
                } label: {
                    Text("Back")
                        .font(CashTypography.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CashSpacing.sm)
                }
                .buttonStyle(.bordered)

                Button {
                    performImport()
                } label: {
                    Text("Import \(itemsToImport.count)")
                        .font(CashTypography.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CashSpacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(CashColors.primary)
                .disabled(itemsToImport.isEmpty)
            }
            .padding(CashSpacing.lg)
            .background(.bar)
        }
    }

    // MARK: - Step 4: Importing

    private var importingStep: some View {
        VStack(spacing: CashSpacing.xl) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Importing transactions...")
                .font(CashTypography.headline)

            ProgressView(value: importProgress)
                .tint(CashColors.primary)
                .frame(maxWidth: 280)

            Text("\(importedCount) of \(itemsToImport.count)")
                .font(CashTypography.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(CashSpacing.xl)
    }

    // MARK: - Step 5: Complete

    private var completeStep: some View {
        VStack(spacing: CashSpacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(CashColors.success)

            Text("Import Complete!")
                .font(CashTypography.title)

            VStack(spacing: CashSpacing.sm) {
                Text("\(importedCount) transactions imported")
                    .font(CashTypography.body)

                if skippedCount > 0 {
                    Text("\(skippedCount) transactions skipped")
                        .font(CashTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(CashTypography.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CashSpacing.md)
            }
            .buttonStyle(.borderedProminent)
            .tint(CashColors.primary)
            .padding(.horizontal, CashSpacing.xl)
        }
        .padding(CashSpacing.xl)
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
            withAnimation {
                currentStep = .review
            }
        }
    }

    private func performImport() {
        withAnimation {
            currentStep = .importing
        }
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
                withAnimation {
                    currentStep = .complete
                }
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
            HStack(spacing: CashSpacing.xs) {
                Image(systemName: account.accountType.iconName)
                    .font(.caption)
                Text(account.displayName)
                    .font(CashTypography.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, CashSpacing.sm)
            .padding(.vertical, CashSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(isSelected ? CashColors.primary : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: CashRadius.small))
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
