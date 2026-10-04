import Foundation

/// A single dividend payment, keyed by its ex-dividend date.
struct DividendPayment: Identifiable, Hashable {
    let date: Date
    let amount: Double

    var id: Date { date }
}

/// The sum of all dividends paid in one calendar year.
struct AnnualDividend: Identifiable, Hashable {
    let year: Int
    let total: Double
    let paymentCount: Int
    /// True for the current year, which has not finished paying out yet.
    let isPartial: Bool

    var id: Int { year }

    /// January 1st of `year` in the device's calendar, used to place the bar on a date axis.
    var startDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .distantPast
    }
}

enum HistoryRange: String, CaseIterable, Identifiable {
    case fiveYears = "5Y"
    case tenYears = "10Y"
    case twentyYears = "20Y"
    case max = "Max"

    var id: String { rawValue }

    var years: Int? {
        switch self {
        case .fiveYears: 5
        case .tenYears: 10
        case .twentyYears: 20
        case .max: nil
        }
    }
}

enum ChartMode: String, CaseIterable, Identifiable {
    case annual = "Annual Total"
    case payments = "Per Payment"

    var id: String { rawValue }
}

struct DividendHistory {
    let symbol: String
    let companyName: String?
    let currency: String
    let price: Double?
    /// All known payments, oldest first.
    let payments: [DividendPayment]

    /// Yahoo reports ex-dates as UTC timestamps, so bucket years in UTC to avoid
    /// a payment on Jan 1 slipping into the previous year in western time zones.
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    var latest: DividendPayment? { payments.last }

    func payments(in range: HistoryRange, now: Date = .now) -> [DividendPayment] {
        guard let years = range.years,
              let cutoff = Calendar.current.date(byAdding: .year, value: -years, to: now)
        else { return payments }
        return payments.filter { $0.date >= cutoff }
    }

    func annualTotals(in range: HistoryRange, now: Date = .now) -> [AnnualDividend] {
        let currentYear = Self.utcCalendar.component(.year, from: now)
        let grouped = Dictionary(grouping: payments) { Self.utcCalendar.component(.year, from: $0.date) }
        let all = grouped.map { year, items in
            AnnualDividend(
                year: year,
                total: items.reduce(0) { $0 + $1.amount },
                paymentCount: items.count,
                isPartial: year == currentYear
            )
        }
        .sorted { $0.year < $1.year }

        guard let years = range.years else { return all }
        return all.filter { $0.year > currentYear - years }
    }

    /// Sum of dividends with an ex-date in the last 12 months.
    func trailingTwelveMonths(now: Date = .now) -> [DividendPayment] {
        guard let cutoff = Calendar.current.date(byAdding: .year, value: -1, to: now) else { return [] }
        return payments.filter { $0.date > cutoff }
    }

    var trailingTotal: Double {
        trailingTwelveMonths().reduce(0) { $0 + $1.amount }
    }

    var trailingYield: Double? {
        guard let price, price > 0, trailingTotal > 0 else { return nil }
        return trailingTotal / price
    }

    /// Compound annual growth of the yearly total over the last five complete years.
    var fiveYearGrowth: Double? {
        let complete = annualTotals(in: .max).filter { !$0.isPartial }
        guard complete.count >= 6,
              let end = complete.last,
              let start = complete.first(where: { $0.year == end.year - 5 }),
              start.total > 0
        else { return nil }
        return pow(end.total / start.total, 1.0 / 5.0) - 1
    }

    func format(_ amount: Double) -> String {
        amount.formatted(.currency(code: currency).precision(.fractionLength(2...4)))
    }
}
