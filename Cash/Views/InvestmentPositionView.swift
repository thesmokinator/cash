//
//  InvestmentPositionView.swift
//  Cash
//
//  Created by Michele Broggi on 27/12/25.
//

import SwiftUI

/// Displays the current position summary for an investment account
struct InvestmentPositionView: View {
    let position: InvestmentPosition
    let currency: String
    let showHelpTips: Bool
    
    @State private var showingHelp = false
    
    init(position: InvestmentPosition, currency: String, showHelpTips: Bool = true) {
        self.position = position
        self.currency = currency
        self.showHelpTips = showHelpTips
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Position Summary", systemImage: "chart.pie.fill")
                    .font(.headline)
                
                Spacer()
                
                if showHelpTips {
                    Button(action: { showingHelp.toggle() }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingHelp) {
                        helpContent
                            .padding()
                            .frame(width: 300)
                    }
                }
            }
            
            Divider()
            
            if position.hasShares {
                // Shares row
                PositionRow(
                    label: String(localized: "Shares"),
                    value: InvestmentHelper.formatShares(position.shares),
                    icon: "number.square.fill"
                )
                
                // Average Cost row
                PositionRow(
                    label: String(localized: "Average Cost"),
                    value: InvestmentHelper.formatPrice(position.averageCost, currency: currency),
                    icon: "tag.fill"
                )
                
                // Total Cost row
                PositionRow(
                    label: String(localized: "Total Cost"),
                    value: InvestmentHelper.formatPrice(position.totalCost, currency: currency),
                    icon: "creditcard.fill"
                )
                
                if position.hasMarketData {
                    Divider()
                    
                    // Market Value row
                    if let marketValue = position.marketValue {
                        PositionRow(
                            label: String(localized: "Market Value"),
                            value: InvestmentHelper.formatPrice(marketValue, currency: currency),
                            icon: "chart.line.uptrend.xyaxis"
                        )
                    }
                    
                    // Unrealized Gain/Loss row
                    if let gain = position.unrealizedGain,
                       let gainPercent = position.unrealizedGainPercent {
                        let formatted = InvestmentHelper.formatGainLoss(gain, currency: currency)
                        HStack {
                            Label(String(localized: "Unrealized P/L"), systemImage: gain >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text(formatted.text)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(formatted.isPositive ? .green : .red)
                                
                                Text(InvestmentHelper.formatPercentage(gainPercent))
                                    .font(.caption)
                                    .foregroundStyle(formatted.isPositive ? .green : .red)
                            }
                        }
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    
                    Text("No shares held")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("Add a buy transaction to start tracking your investment.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Understanding Your Position")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HelpItem(
                    term: "Shares",
                    definition: "The total number of shares you currently own."
                )
                
                HelpItem(
                    term: "Average Cost",
                    definition: "The average price you paid per share, calculated using the Average Cost Method."
                )
                
                HelpItem(
                    term: "Total Cost",
                    definition: "The total amount you've invested (shares × average cost)."
                )
                
                HelpItem(
                    term: "Market Value",
                    definition: "Current value of your holdings based on the latest market price."
                )
                
                HelpItem(
                    term: "Unrealized P/L",
                    definition: "Profit or loss if you sold all shares at the current market price. 'Unrealized' means you haven't actually sold yet."
                )
            }
        }
    }
}

// MARK: - Position Row

private struct PositionRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Help Item

private struct HelpItem: View {
    let term: String
    let definition: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(term)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(definition)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Compact Position Badge

/// A compact view showing just the key position metrics
struct InvestmentPositionBadge: View {
    let position: InvestmentPosition
    let currency: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Shares
            VStack(alignment: .leading, spacing: 2) {
                Text("Shares")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(InvestmentHelper.formatShares(position.shares))
                    .font(.callout)
                    .fontWeight(.medium)
            }
            
            Divider()
                .frame(height: 24)
            
            // Average Cost
            VStack(alignment: .leading, spacing: 2) {
                Text("Avg Cost")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(InvestmentHelper.formatPrice(position.averageCost, currency: currency))
                    .font(.callout)
                    .fontWeight(.medium)
            }
            
            if let gain = position.unrealizedGain {
                Divider()
                    .frame(height: 24)
                
                // P/L
                VStack(alignment: .leading, spacing: 2) {
                    Text("P/L")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    let formatted = InvestmentHelper.formatGainLoss(gain, currency: currency)
                    Text(formatted.text)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(formatted.isPositive ? .green : .red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        InvestmentPositionView(
            position: InvestmentPosition(
                shares: 150.5,
                totalCost: 15050,
                averageCost: 100,
                marketValue: 18060,
                unrealizedGain: 3010,
                unrealizedGainPercent: 20
            ),
            currency: "EUR"
        )
        
        InvestmentPositionBadge(
            position: InvestmentPosition(
                shares: 150.5,
                totalCost: 15050,
                averageCost: 100,
                marketValue: 18060,
                unrealizedGain: 3010,
                unrealizedGainPercent: 20
            ),
            currency: "EUR"
        )
        
        InvestmentPositionView(
            position: .empty,
            currency: "EUR"
        )
    }
    .padding()
}
