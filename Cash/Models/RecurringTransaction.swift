//
//  RecurringTransaction.swift
//  Cash
//
//  Created by Michele Broggi on 26/11/25.
//

import Foundation
import SwiftData

// MARK: - Recurrence Frequency

enum RecurrenceFrequency: String, CaseIterable, Identifiable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .daily: return String(localized: "Daily")
        case .weekly: return String(localized: "Weekly")
        case .monthly: return String(localized: "Monthly")
        case .yearly: return String(localized: "Yearly")
        }
    }
    
    var iconName: String {
        switch self {
        case .daily: return "sun.max"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .yearly: return "calendar.badge.plus"
        }
    }
}

// MARK: - Weekend Adjustment

enum WeekendAdjustment: String, CaseIterable, Identifiable, Codable {
    case none = "none"
    case previousFriday = "previousFriday"
    case nextMonday = "nextMonday"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .none: return String(localized: "No adjustment")
        case .previousFriday: return String(localized: "Previous Friday")
        case .nextMonday: return String(localized: "Next Monday")
        }
    }
}

// MARK: - Recurrence Rule

@Model
final class RecurrenceRule {
    var id: UUID = UUID()
    var frequencyRawValue: String = RecurrenceFrequency.monthly.rawValue
    var interval: Int = 1
    var dayOfMonth: Int?
    var dayOfWeek: Int?
    var monthOfYear: Int?
    var weekendAdjustmentRawValue: String = WeekendAdjustment.none.rawValue
    var startDate: Date = Date()
    var endDate: Date?
    var nextOccurrence: Date?
    var isActive: Bool = true
    
    var transaction: Transaction?
    
    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: frequencyRawValue) ?? .monthly }
        set { frequencyRawValue = newValue.rawValue }
    }
    
    var weekendAdjustment: WeekendAdjustment {
        get { WeekendAdjustment(rawValue: weekendAdjustmentRawValue) ?? .none }
        set { weekendAdjustmentRawValue = newValue.rawValue }
    }
    
    init(
        frequency: RecurrenceFrequency = .monthly,
        interval: Int = 1,
        dayOfMonth: Int? = nil,
        dayOfWeek: Int? = nil,
        monthOfYear: Int? = nil,
        weekendAdjustment: WeekendAdjustment = .none,
        startDate: Date = Date(),
        endDate: Date? = nil
    ) {
        self.id = UUID()
        self.frequencyRawValue = frequency.rawValue
        self.interval = interval
        self.dayOfMonth = dayOfMonth
        self.dayOfWeek = dayOfWeek
        self.monthOfYear = monthOfYear
        self.weekendAdjustmentRawValue = weekendAdjustment.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = true
        self.nextOccurrence = startDate
    }
    
    // MARK: - Recurrence Description
    
    var localizedDescription: String {
        var desc = ""
        
        if interval == 1 {
            desc = frequency.localizedName
        } else {
            switch frequency {
            case .daily:
                desc = String(localized: "Every \(interval) days")
            case .weekly:
                desc = String(localized: "Every \(interval) weeks")
            case .monthly:
                desc = String(localized: "Every \(interval) months")
            case .yearly:
                desc = String(localized: "Every \(interval) years")
            }
        }
        
        if let day = dayOfMonth, frequency == .monthly || frequency == .yearly {
            desc += " " + String(localized: "on day \(day)")
        }
        
        return desc
    }
    
    // MARK: - Next Occurrence Calculation
    
    /// Calculate the next occurrence date
    /// - Parameters:
    ///   - date: The reference date to calculate from
    ///   - includeDate: If true, the reference date itself can be returned if it matches the pattern
    func calculateNextOccurrence(from date: Date = Date(), includeDate: Bool = false) -> Date? {
        let calendar = Calendar.current
        var nextDate: Date?
        
        switch frequency {
        case .daily:
            if includeDate {
                nextDate = date
            } else {
                nextDate = calendar.date(byAdding: .day, value: interval, to: date)
            }
            
        case .weekly:
            if includeDate {
                nextDate = date
            } else {
                nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: date)
            }
            
        case .monthly:
            if let day = dayOfMonth {
                // Get the target day in the current month
                var components = calendar.dateComponents([.year, .month], from: date)
                let targetDay = min(day, daysInMonth(for: date))
                components.day = targetDay
                
                if let targetDate = calendar.date(from: components) {
                    // Compare dates without time
                    let dateOnly = calendar.startOfDay(for: date)
                    let targetOnly = calendar.startOfDay(for: targetDate)
                    
                    if includeDate && targetOnly >= dateOnly {
                        // Include the target date if it's on or after the reference date
                        nextDate = targetDate
                    } else if targetOnly <= dateOnly {
                        // Target date is in the past or today, go to next interval
                        if let nextMonth = calendar.date(byAdding: .month, value: interval, to: targetDate) {
                            var nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
                            nextComponents.day = min(day, daysInMonth(for: nextMonth))
                            nextDate = calendar.date(from: nextComponents)
                        }
                    } else {
                        nextDate = targetDate
                    }
                }
            } else {
                if includeDate {
                    nextDate = date
                } else {
                    nextDate = calendar.date(byAdding: .month, value: interval, to: date)
                }
            }
            
        case .yearly:
            if let month = monthOfYear, let day = dayOfMonth {
                var components = calendar.dateComponents([.year], from: date)
                components.month = month
                components.day = day
                
                if let targetDate = calendar.date(from: components) {
                    // Compare dates without time
                    let dateOnly = calendar.startOfDay(for: date)
                    let targetOnly = calendar.startOfDay(for: targetDate)
                    
                    if includeDate && targetOnly >= dateOnly {
                        nextDate = targetDate
                    } else if targetOnly <= dateOnly {
                        components.year = (components.year ?? 2024) + interval
                        nextDate = calendar.date(from: components)
                    } else {
                        nextDate = targetDate
                    }
                }
            } else {
                if includeDate {
                    nextDate = date
                } else {
                    nextDate = calendar.date(byAdding: .year, value: interval, to: date)
                }
            }
        }
        
        // Apply weekend adjustment
        if let next = nextDate {
            nextDate = applyWeekendAdjustment(to: next)
        }
        
        // Check end date
        if let end = endDate, let next = nextDate, next > end {
            return nil
        }
        
        return nextDate
    }
    
    private func daysInMonth(for date: Date) -> Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: date)
        return range?.count ?? 31
    }
    
    private func applyWeekendAdjustment(to date: Date) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // 1 = Sunday, 7 = Saturday
        let isSaturday = weekday == 7
        let isSunday = weekday == 1
        
        guard isSaturday || isSunday else { return date }
        
        switch weekendAdjustment {
        case .none:
            return date
        case .previousFriday:
            let daysToSubtract = isSaturday ? 1 : 2
            return calendar.date(byAdding: .day, value: -daysToSubtract, to: date) ?? date
        case .nextMonday:
            let daysToAdd = isSaturday ? 2 : 1
            return calendar.date(byAdding: .day, value: daysToAdd, to: date) ?? date
        }
    }
}
