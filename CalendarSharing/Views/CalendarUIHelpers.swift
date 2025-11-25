import Foundation
import SwiftUI

enum CalendarUIHelpers {
    static func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.calendar = Calendar.current
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    static func mondayFirstWeekdaySymbols() -> [String] {
        let cal = Calendar.current
        var symbols = cal.shortWeekdaySymbols
        // Reorder so that Monday is first, respecting current symbols
        // shortWeekdaySymbols is Sunday-first for Gregorian; rotate left by 1
        if symbols.count == 7 {
            symbols = Array(symbols[1...]) + [symbols[0]]
        }
        return symbols
    }

    static func makeMonthDays(for date: Date) -> [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 0

        var days: [Date?] = []
        // Convert Sunday=1..Saturday=7 to Monday-first offset (0..6 where 0 means Monday)
        let offset = (firstWeekday + 5) % 7
        for _ in 0..<offset { days.append(nil) }

        for day in 0..<daysInMonth {
            if let d = calendar.date(byAdding: .day, value: day, to: firstDay) {
                days.append(d)
            }
        }
        return days
    }

    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}
