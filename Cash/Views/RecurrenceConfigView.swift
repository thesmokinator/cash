//
//  RecurrenceConfigView.swift
//  Cash
//
//  Created by Michele Broggi on 26/11/25.
//

import SwiftUI

struct RecurrenceConfigView: View {
    @Binding var isRecurring: Bool
    @Binding var frequency: RecurrenceFrequency
    @Binding var interval: Int
    @Binding var dayOfMonth: Int
    @Binding var dayOfWeek: Int
    @Binding var weekendAdjustment: WeekendAdjustment
    @Binding var endDate: Date?
    var showToggle: Bool = true
    @State private var hasEndDate: Bool = false
    
    private let weekdays = [
        (1, String(localized: "Sunday")),
        (2, String(localized: "Monday")),
        (3, String(localized: "Tuesday")),
        (4, String(localized: "Wednesday")),
        (5, String(localized: "Thursday")),
        (6, String(localized: "Friday")),
        (7, String(localized: "Saturday"))
    ]
    
    var body: some View {
        if showToggle {
            Toggle("Recurring transaction", isOn: $isRecurring)
        }
        
        if isRecurring {
            Picker("Frequency", selection: $frequency) {
                ForEach(RecurrenceFrequency.allCases) { freq in
                    Label(freq.localizedName, systemImage: freq.iconName)
                        .tag(freq)
                }
            }
            
            Stepper(value: $interval, in: 1...99) {
                HStack {
                    Text("Every")
                    Text("\(interval)")
                        .fontWeight(.semibold)
                    Text(intervalUnitName)
                }
            }
            
            if frequency == .weekly {
                Picker("Day of week", selection: $dayOfWeek) {
                    ForEach(weekdays, id: \.0) { day in
                        Text(day.1).tag(day.0)
                    }
                }
            }
            
            if frequency == .monthly || frequency == .yearly {
                Stepper(value: $dayOfMonth, in: 1...31) {
                    HStack {
                        Text("On day")
                        Text("\(dayOfMonth)")
                            .fontWeight(.semibold)
                    }
                }
                
                Picker("Weekend adjustment", selection: $weekendAdjustment) {
                    ForEach(WeekendAdjustment.allCases) { adjustment in
                        Text(adjustment.localizedName).tag(adjustment)
                    }
                }
            }
            
            Toggle("End date", isOn: $hasEndDate)
                .onChange(of: hasEndDate) { _, newValue in
                    if newValue {
                        endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
                    } else {
                        endDate = nil
                    }
                }
            
            if hasEndDate, let binding = Binding($endDate) {
                DatePicker("Until", selection: binding, displayedComponents: .date)
            }
        }
    }
    
    private var intervalUnitName: String {
        switch frequency {
        case .daily:
            return interval == 1 ? String(localized: "day") : String(localized: "days")
        case .weekly:
            return interval == 1 ? String(localized: "week") : String(localized: "weeks")
        case .monthly:
            return interval == 1 ? String(localized: "month") : String(localized: "months")
        case .yearly:
            return interval == 1 ? String(localized: "year") : String(localized: "years")
        }
    }
}

// MARK: - Recurrence Summary Badge

struct RecurrenceBadge: View {
    let rule: RecurrenceRule
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "repeat")
                .font(.caption2)
            Text(rule.localizedDescription)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.blue.opacity(0.15))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
    }
}

// MARK: - Recurring Transaction Icon

struct RecurringIcon: View {
    var body: some View {
        Image(systemName: "repeat")
            .font(.caption)
            .foregroundStyle(.blue)
    }
}
