//
//  LoansView.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import SwiftUI
import SwiftData

struct LoansView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Loan.createdAt, order: .reverse) private var loans: [Loan]
    
    @State private var showingNewLoanCalculator = false
    @State private var showingAddExistingLoan = false
    @State private var selectedLoan: Loan?
    
    var body: some View {
        VStack(spacing: 0) {
            if loans.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("No loans", systemImage: "house.fill")
                } description: {
                    Text("Add a new loan calculation or track an existing loan")
                } actions: {
                    VStack(spacing: 12) {
                        Button {
                            showingNewLoanCalculator = true
                        } label: {
                            Text("New calculation")
                        }
                        .buttonStyle(GlassActionButtonStyle())
                        
                        Button {
                            showingAddExistingLoan = true
                        } label: {
                            Text("Add existing")
                        }
                        .buttonStyle(GlassSecondaryButtonStyle())
                    }
                }
                Spacer()
            } else {
                List(selection: $selectedLoan) {
                    ForEach(loans) { loan in
                        LoanRowView(loan: loan)
                            .tag(loan)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteLoan(loan)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete(perform: deleteLoans)
                }
            }
        }
        .cashBackground()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingNewLoanCalculator = true
                    } label: {
                        Label("New Calculation", systemImage: "function")
                    }
                    
                    Button {
                        showingAddExistingLoan = true
                    } label: {
                        Label("Add Existing Loan", systemImage: "plus.circle")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewLoanCalculator) {
            LoanCalculatorView()
        }
        .sheet(isPresented: $showingAddExistingLoan) {
            AddExistingLoanView()
        }
        .sheet(item: $selectedLoan) { loan in
            LoanDetailView(loan: loan)
        }
        .navigationTitle("Loans & Mortgages")
    }
    
    private func deleteLoan(_ loan: Loan) {
        modelContext.delete(loan)
    }
    
    private func deleteLoans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(loans[index])
        }
    }
}

// MARK: - Loan Row View

struct LoanRowView: View {
    @Environment(AppSettings.self) private var settings
    let loan: Loan
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: loan.loanType.iconName)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(loan.name)
                        .font(.headline)
                    
                    if loan.isExisting {
                        Text("Tracking")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                
                Text("\(loan.interestRateType.localizedName) • \(loan.currentInterestRate.formatted())% • \(loan.paymentFrequency.localizedName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                PrivacyAmountView(
                    amount: CurrencyFormatter.format(loan.monthlyPayment, currency: loan.currency),
                    isPrivate: settings.privacyMode,
                    font: .subheadline,
                    fontWeight: .semibold
                )
                
                Text("\(loan.remainingPayments) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Progress indicator
            CircularProgressView(progress: loan.progressPercentage / 100)
                .frame(width: 36, height: 36)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(.tertiary.opacity(0.3), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    LoansView()
        .modelContainer(for: Loan.self, inMemory: true)
        .environment(AppSettings.shared)
}
