//
//  Recurrence.swift
//  CalendarSharing
//
//  Created by Domantas Jocas on 21/11/2025.
//

import Foundation

/// Pure functions that implement the recurrence semantics for events.
/// Currently supports:
///  - weekly events: `occuringOnDays` contains weekday indices 1...7 (Mon...Sun)
///  - specific-date events: `occuringOnDays` contains epoch-day integers
enum Recurrence {

    /// Use a stable calendar with the *current* timezone everywhere.
    /// This must match how you build Dates in the UI.
    static var calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2   // Monday as first weekday (not strictly required, but consistent)
        return cal
    }()

    // MARK: - Global biweekly anchor (kept for future extension)

    /// Global anchor date used for biweekly style calculations.
    /// Currently unused now that `Event` no longer carries an explicit
    /// recurrence type, but kept here so it can be re-used if you ever
    /// add richer recurrence rules again.
    static let globalBiweeklyAnchor: Date = {
        let d = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        return calendar.startOfDay(for: d)
    }()

    static let globalBiweeklyAnchorIndex: Int = {
        absoluteWeekIndex(for: globalBiweeklyAnchor)
    }()


    // MARK: - Recurrence Matching

    /// Returns true if `event` occurs on `date`.
    ///
    /// Interpretation:
    ///  - if `occuringOnDays` ⊆ 1...7  => treat as weekly recurrence (Mon...Sun)
    ///  - otherwise                   => treat as list of specific dates encoded as epoch-day ints
    static func eventOccurs(on date: Date, event: Event) -> Bool {
        let cal = calendar

        // Normalize date to local midnight so that comparisons are stable.
        let dayStart = cal.startOfDay(for: date)

        // Convert swift weekday → app weekday (Mon = 1 ... Sun = 7)
        let swiftWeekday = cal.component(.weekday, from: dayStart)
        let appWeekday = ((swiftWeekday + 5) % 7) + 1  // Mon=1,...,Sun=7

        // ----------------------------------------
        // CASE 1 — WEEKLY EVENT (days 1–7)
        // ----------------------------------------
        if event.occuringOnDays.allSatisfy({ (1...7).contains($0) }) {
            return event.occuringOnDays.contains(appWeekday)
        }

        // ----------------------------------------
        // CASE 2 — SPECIFIC-DATE EVENT (epoch ints)
        // ----------------------------------------
        let epochDay = startOfDayEpochInt(for: date)
        return event.occuringOnDays.contains(epochDay)
    }


    /// Filter a list of events down to those that occur on `date`.
    static func events(on date: Date, from events: [Event]) -> [Event] {
        events.filter { eventOccurs(on: date, event: $0) }
    }


    // MARK: - Week Index Calculation

    /// Computes a stable "absolute week index" (for biweekly parity).
    /// This purposely ignores day and time within the week, so that any
    /// date in the same ISO week returns the same index.
    static func absoluteWeekIndex(for date: Date) -> Int {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let y = comps.yearForWeekOfYear ?? 0
        let w = comps.weekOfYear ?? 0
        return y * 100 + w
    }


    // MARK: - Specific-date utilities

    /// Convert a Date to a stable local start-of-day epoch integer.
    /// This is used as the storage format for one-off events.
    static func startOfDayEpochInt(for date: Date) -> Int {
        let start = calendar.startOfDay(for: date)
        return Int(start.timeIntervalSince1970)
    }
}
