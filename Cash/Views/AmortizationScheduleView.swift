//  AmortizationScheduleView.swift
//  Cash
//
//  Created by Michele Broggi on 01/12/25.
//

import SwiftUI

struct AmortizationScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    let principal: Decimal
    let annualRate: Decimal
    let totalPayments: Int
    let frequency: PaymentFrequency
    var amortizationType: AmortizationType = .french
    let startDate: Date
    let currency: String
    var startingPayment: Int = 1

    @State private var schedule: [AmortizationEntry] = []
    @State private var isLoading = true

    private var totalInterestPaid: Decimal {
        schedule.reduce(Decimal.zero) { $0 + $1.interest }
    }

    private var totalPrincipalPaid: Decimal {
        schedule.reduce(Decimal.zero) { $0 + $1.principal }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with summary
                VStack(spacing: 12) {
                    HStack {
                        Text(String(localized: "Amortization Schedule"))
                            .font(.headline)
                        Spacer()
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text(String(localized: "Principal"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(principal, currency: currency),
                                isPrivate: settings.privacyMode,
                                font: .title3,
                                fontWeight: .semibold
                            )
                        }

                        HStack {
                            Text(String(localized: "Interest Rate"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(annualRate.formatted())%")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text(String(localized: "Total Interest"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(
                                    totalInterestPaid, currency: currency),
                                isPrivate: settings.privacyMode,
                                font: .title3,
                                fontWeight: .semibold
                            )
                        }

                        HStack {
                            Text(String(localized: "Total Amount"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(
                                    principal + totalInterestPaid, currency: currency),
                                isPrivate: settings.privacyMode,
                                font: .title3,
                                fontWeight: .semibold
                            )
                        }

                        HStack {
                            Text(String(localized: "Method"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(amortizationType.shortName)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)

                Divider()

                if isLoading {
                    Spacer()
                    ProgressView(String(localized: "Calculating..."))
                    Spacer()
                } else {
                    // iOS Layout with List using reusable components
                    List(schedule) { entry in
                        ListCard(
                            header: {
                                HStack {
                                    Text("#\(entry.paymentNumber)")
                                        .font(.headline)
                                        .monospacedDigit()
                                    Spacer()
                                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            },
                            content: {
                                VStack(spacing: 8) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(String(localized: "Payment"))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            PrivacyAmountView(
                                                amount: CurrencyFormatter.format(
                                                    entry.payment, currency: currency),
                                                isPrivate: settings.privacyMode,
                                                font: .body,
                                                fontWeight: .semibold
                                            )
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(String(localized: "Balance"))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            PrivacyAmountView(
                                                amount: CurrencyFormatter.format(
                                                    entry.remainingBalance, currency: currency),
                                                isPrivate: settings.privacyMode,
                                                font: .body,
                                                fontWeight: .medium
                                            )
                                        }
                                    }

                                    HStack(spacing: 16) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .foregroundStyle(.green)
                                                .font(.caption)
                                            PrivacyAmountView(
                                                amount: CurrencyFormatter.format(
                                                    entry.principal, currency: currency),
                                                isPrivate: settings.privacyMode,
                                                font: .caption,
                                                fontWeight: .regular,
                                                color: .green
                                            )
                                        }

                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.up.circle.fill")
                                                .foregroundStyle(.orange)
                                                .font(.caption)
                                            PrivacyAmountView(
                                                amount: CurrencyFormatter.format(
                                                    entry.interest, currency: currency),
                                                isPrivate: settings.privacyMode,
                                                font: .caption,
                                                fontWeight: .regular,
                                                color: .orange
                                            )
                                        }
                                    }
                                }
                            }
                        )
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle(String(localized: "Amortization Schedule"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
            .task {
                await generateSchedule()
            }
        }
    }

    private func generateSchedule() async {
        isLoading = true

        // Small delay to show loading
        try? await Task.sleep(nanoseconds: 100_000_000)

        let result = LoanCalculator.generateAmortizationSchedule(
            principal: principal,
            annualRate: annualRate,
            totalPayments: totalPayments,
            frequency: frequency,
            amortizationType: amortizationType,
            startDate: startDate,
            startingPayment: startingPayment
        )

        await MainActor.run {
            schedule = result
            isLoading = false
        }
    }
}

#Preview {
    AmortizationScheduleView(
        principal: 200000,
        annualRate: 3.5,
        totalPayments: 240,
        frequency: .monthly,
        startDate: Date(),
        currency: "EUR"
    )
    .environment(AppSettings.shared)
}
