//
//  ReportsView.swift
//  Cash
//
//  Created by Michele Broggi on 28/11/25.
//

import SwiftUI
import SwiftData

// MARK: - Report Type

enum ReportType: String, CaseIterable, Identifiable {
    case expensesByCategory = "expensesByCategory"
    case fixedIncomeExpenseRatio = "fixedIncomeExpenseRatio"
    case yearOverYear = "yearOverYear"
    case balanceHistory = "balanceHistory"
    case longTermProjection = "longTermProjection"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .expensesByCategory:
            return String(localized: "Expenses by Category")
        case .fixedIncomeExpenseRatio:
            return String(localized: "Fixed Income vs Expenses")
        case .yearOverYear:
            return String(localized: "Year over Year")
        case .balanceHistory:
            return String(localized: "Balance History")
        case .longTermProjection:
            return String(localized: "Long Term Projection")
        }
    }
    
    var iconName: String {
        switch self {
        case .expensesByCategory:
            return "chart.bar.fill"
        case .fixedIncomeExpenseRatio:
            return "scale.3d"
        case .yearOverYear:
            return "calendar.badge.clock"
        case .balanceHistory:
            return "chart.xyaxis.line"
        case .longTermProjection:
            return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Reports View (Main Container)

struct ReportsView: View {
    @State private var selectedReport: ReportType = .expensesByCategory
    
    var body: some View {
        VStack(spacing: 0) {
            // Report type selector
            HStack {
                Spacer()
                GlassMenuPicker(selectedReport.localizedName, selection: $selectedReport) {
                    ForEach(ReportType.allCases) { report in
                        Button {
                            selectedReport = report
                        } label: {
                            HStack {
                                Text(report.localizedName)
                                if selectedReport == report {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Selected report view
            switch selectedReport {
            case .expensesByCategory:
                ExpenseByCategoryReportView()
            case .fixedIncomeExpenseRatio:
                FixedIncomeExpenseRatioReportView()
            case .yearOverYear:
                YearOverYearReportView()
            case .balanceHistory:
                BalanceHistoryReportView()
            case .longTermProjection:
                LongTermProjectionReportView()
            }
        }
        .cashBackground()
        .navigationTitle("Reports")
    }
}

#Preview {
    ReportsView()
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
        .environment(AppSettings.shared)
}
