//
//  LongTermProjectionReportView.swift
//  Cash
//
//  Created by Michele Broggi on 28/11/25.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Base Period (for trend calculation)

enum TrendBasePeriod: String, CaseIterable, Identifiable {
    case threeMonths = "threeMonths"
    case sixMonths = "sixMonths"
    case year = "year"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .threeMonths:
            return String(localized: "Last 3 Months")
        case .sixMonths:
            return String(localized: "Last 6 Months")
        case .year:
            return String(localized: "Last Year")
        }
    }
    
    var months: Int {
        switch self {
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .year: return 12
        }
    }
    
    var startDate: Date {
        Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
    }
}

// MARK: - Projection Period

enum ProjectionPeriod: String, CaseIterable, Identifiable {
    case sixMonths = "sixMonths"
    case year = "year"
    case twoYears = "twoYears"
    case fiveYears = "fiveYears"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .sixMonths:
            return String(localized: "6 Months")
        case .year:
            return String(localized: "1 Year")
        case .twoYears:
            return String(localized: "2 Years")
        case .fiveYears:
            return String(localized: "5 Years")
        }
    }
    
    var months: Int {
        switch self {
        case .sixMonths: return 6
        case .year: return 12
        case .twoYears: return 24
        case .fiveYears: return 60
        }
    }
    
    var endDate: Date {
        Calendar.current.date(byAdding: .month, value: months, to: Date()) ?? Date()
    }
}

// MARK: - Projection Data Point

struct ProjectionDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Decimal
    let isProjected: Bool
    
    var balanceDouble: Double {
        NSDecimalNumber(decimal: balance).doubleValue
    }
}

// MARK: - Long Term Projection Report View

struct LongTermProjectionReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    @Query(sort: \Transaction.date) private var allTransactions: [Transaction]
    
    @State private var basePeriod: TrendBasePeriod = .sixMonths
    @State private var projectionPeriod: ProjectionPeriod = .year
    @State private var isLoading = true
    @State private var historicalData: [ProjectionDataPoint] = []
    @State private var projectionData: [ProjectionDataPoint] = []
    @State private var trendData: (slope: Double, intercept: Double, monthlyChange: Decimal)?
    
    private var transactions: [Transaction] {
        allTransactions.filter { !$0.isRecurring }
    }
    
    private var assetAccounts: [Account] {
        accounts.filter { $0.accountClass == .asset && $0.isActive && !$0.isSystem }
    }
    
    private var liabilityAccounts: [Account] {
        accounts.filter { $0.accountClass == .liability && $0.isActive && !$0.isSystem }
    }
    
    private var allDataPoints: [ProjectionDataPoint] {
        historicalData + projectionData.dropFirst()
    }
    
    private var currentBalance: Decimal {
        historicalData.last?.balance ?? 0
    }
    
    private var projectedBalance: Decimal {
        projectionData.last?.balance ?? currentBalance
    }
    
    private var projectedChange: Decimal {
        projectedBalance - currentBalance
    }
    
    private var currency: String {
        assetAccounts.first?.currency ?? liabilityAccounts.first?.currency ?? "EUR"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Controls
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trend based on")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Picker(selection: $basePeriod) {
                        ForEach(TrendBasePeriod.allCases) { period in
                            Text(period.localizedName).tag(period)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.menu)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Project for")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Picker(selection: $projectionPeriod) {
                        ForEach(ProjectionPeriod.allCases) { period in
                            Text(period.localizedName).tag(period)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.menu)
                }
                
                Spacer()
            }
            .padding()
            .background(.bar)
            
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Spacer()
            } else if historicalData.count < 2 {
                ContentUnavailableView {
                    Label("Not enough data", systemImage: "chart.line.uptrend.xyaxis")
                } description: {
                    Text("Add more transactions to generate projections")
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Chart
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Balance Projection")
                                    .font(.headline)
                                
                                Spacer()
                                
                                HStack(spacing: 16) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 8, height: 8)
                                        Text("Historical")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 8, height: 8)
                                        Text("Projected")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            Chart {
                                ForEach(historicalData) { point in
                                    LineMark(
                                        x: .value("Date", point.date),
                                        y: .value("Balance", point.balanceDouble)
                                    )
                                    .foregroundStyle(Color.blue)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                }
                                
                                ForEach(projectionData) { point in
                                    LineMark(
                                        x: .value("Date", point.date),
                                        y: .value("Balance", point.balanceDouble)
                                    )
                                    .foregroundStyle(Color.orange)
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                }
                                
                                RuleMark(x: .value("Today", Date()))
                                    .foregroundStyle(Color.gray.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                    .annotation(position: .top) {
                                        Text("Today")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let doubleValue = value.as(Double.self) {
                                            Text(formatAxisValue(doubleValue))
                                                .font(.caption2)
                                        }
                                    }
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic) { value in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                                }
                            }
                            .frame(height: 280)
                            .privacyBlur(settings.privacyMode)
                        }
                        .padding()
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Stats
                        HStack(spacing: 16) {
                            StatCard(
                                title: String(localized: "Current Balance"),
                                value: CurrencyFormatter.format(currentBalance, currency: currency),
                                color: currentBalance >= 0 ? .blue : .red,
                                isPrivate: settings.privacyMode
                            )
                            
                            StatCard(
                                title: String(localized: "Projected Balance"),
                                value: CurrencyFormatter.format(projectedBalance, currency: currency),
                                color: projectedBalance >= 0 ? .orange : .red,
                                isPrivate: settings.privacyMode
                            )
                        }
                        .padding(.horizontal)
                        
                        if let trend = trendData {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Trend Analysis")
                                    .font(.headline)
                                
                                HStack(spacing: 20) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Monthly Trend")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: trend.monthlyChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                                            
                                            PrivacyAmountView(
                                                amount: "\(trend.monthlyChange >= 0 ? "+" : "")\(CurrencyFormatter.format(trend.monthlyChange, currency: currency))",
                                                isPrivate: settings.privacyMode,
                                                font: .body,
                                                fontWeight: .semibold,
                                                color: trend.monthlyChange >= 0 ? .green : .red
                                            )
                                            
                                            Text("/ month")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .foregroundStyle(trend.monthlyChange >= 0 ? .green : .red)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Projected Change")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        
                                        PrivacyAmountView(
                                            amount: "\(projectedChange >= 0 ? "+" : "")\(CurrencyFormatter.format(projectedChange, currency: currency))",
                                            isPrivate: settings.privacyMode,
                                            font: .body,
                                            fontWeight: .semibold,
                                            color: projectedChange >= 0 ? .green : .red
                                        )
                                    }
                                }
                            }
                            .padding()
                            .background(.quaternary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                        
                        Text("Projections are based on historical trends and do not account for changes in income, expenses, or market conditions.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: basePeriod) { _, _ in
            Task { await loadData() }
        }
        .onChange(of: projectionPeriod) { _, _ in
            Task { await loadData() }
        }
    }
    
    private func loadData() async {
        isLoading = true
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let txns = transactions
        guard !txns.isEmpty else {
            await MainActor.run {
                historicalData = []
                projectionData = []
                trendData = nil
                isLoading = false
            }
            return
        }
        
        let sortedTransactions = txns.sorted { $0.date < $1.date }
        let startDate = basePeriod.startDate
        let calendar = Calendar.current
        
        // Calculate historical data
        var dataPoints: [ProjectionDataPoint] = []
        var runningBalance: Decimal = 0
        
        for transaction in sortedTransactions where transaction.date < startDate {
            runningBalance += BalanceCalculator.netBalanceChange(for: transaction)
        }
        
        dataPoints.append(ProjectionDataPoint(date: startDate, balance: runningBalance, isProjected: false))
        
        var dailyBalances: [Date: Decimal] = [:]
        var currentBalance = runningBalance
        
        for transaction in sortedTransactions where transaction.date >= startDate && transaction.date <= Date() {
            currentBalance += BalanceCalculator.netBalanceChange(for: transaction)
            let dayStart = calendar.startOfDay(for: transaction.date)
            dailyBalances[dayStart] = currentBalance
        }
        
        for day in dailyBalances.keys.sorted() {
            if let balance = dailyBalances[day] {
                dataPoints.append(ProjectionDataPoint(date: day, balance: balance, isProjected: false))
            }
        }
        
        let today = calendar.startOfDay(for: Date())
        if dataPoints.last?.date != today {
            dataPoints.append(ProjectionDataPoint(date: today, balance: currentBalance, isProjected: false))
        }
        
        // Calculate trend
        var calculatedTrend: (slope: Double, intercept: Double, monthlyChange: Decimal)?
        if dataPoints.count >= 2 {
            let firstDate = dataPoints.first!.date
            let points: [(x: Double, y: Double)] = dataPoints.map { point in
                let days = calendar.dateComponents([.day], from: firstDate, to: point.date).day ?? 0
                return (x: Double(days), y: point.balanceDouble)
            }
            
            let n = Double(points.count)
            let sumX = points.reduce(0) { $0 + $1.x }
            let sumY = points.reduce(0) { $0 + $1.y }
            let sumXY = points.reduce(0) { $0 + $1.x * $1.y }
            let sumX2 = points.reduce(0) { $0 + $1.x * $1.x }
            
            let denominator = n * sumX2 - sumX * sumX
            if denominator != 0 {
                let slope = (n * sumXY - sumX * sumY) / denominator
                let intercept = (sumY - slope * sumX) / n
                let monthlyChange = Decimal(slope * 30)
                calculatedTrend = (slope: slope, intercept: intercept, monthlyChange: monthlyChange)
            }
        }
        
        // Calculate projection
        var projectedPoints: [ProjectionDataPoint] = []
        if let trend = calculatedTrend, !dataPoints.isEmpty {
            let firstDate = dataPoints.first!.date
            var currentDate = calendar.startOfDay(for: Date())
            let endDate = projectionPeriod.endDate
            
            while currentDate <= endDate {
                let days = calendar.dateComponents([.day], from: firstDate, to: currentDate).day ?? 0
                let projectedBalance = trend.intercept + trend.slope * Double(days)
                
                projectedPoints.append(ProjectionDataPoint(
                    date: currentDate,
                    balance: Decimal(projectedBalance),
                    isProjected: true
                ))
                
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            }
        }
        
        await MainActor.run {
            historicalData = dataPoints
            projectionData = projectedPoints
            trendData = calculatedTrend
            isLoading = false
        }
    }
    
    private func formatAxisValue(_ value: Double) -> String {
        ChartAxisFormatter.format(value)
    }
}

#Preview {
    LongTermProjectionReportView()
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
        .environment(AppSettings.shared)
}
