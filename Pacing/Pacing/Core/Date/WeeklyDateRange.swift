import Foundation

enum WeeklyDateRange {
    static func start(containing date: Date, calendar sourceCalendar: Calendar = .current) -> Date {
        var calendar = sourceCalendar
        calendar.firstWeekday = 2

        let dayStart = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: dayStart)
        let daysFromMonday = (weekday - calendar.firstWeekday + 7) % 7

        return calendar.date(byAdding: .day, value: -daysFromMonday, to: dayStart) ?? dayStart
    }

    static func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let startDate = start(containing: date, calendar: calendar)
        let endDate = calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        return DateInterval(start: startDate, end: endDate)
    }
}
