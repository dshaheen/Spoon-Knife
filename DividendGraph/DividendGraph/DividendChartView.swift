import Charts
import SwiftUI

struct DividendChartView: View {
    let history: DividendHistory
    let range: HistoryRange
    let mode: ChartMode

    @State private var selectedDate: Date?

    var body: some View {
        Group {
            switch mode {
            case .annual: annualChart
            case .payments: paymentsChart
            }
        }
        .frame(height: 260)
        .onChange(of: mode) { selectedDate = nil }
        .onChange(of: range) { selectedDate = nil }
    }

    // MARK: Annual totals

    private var annualChart: some View {
        let years = history.annualTotals(in: range)
        let selected = selectedDate.flatMap { date in
            years.first { $0.year == Calendar.current.component(.year, from: date) }
        }

        return Chart {
            ForEach(years) { year in
                BarMark(
                    x: .value("Year", year.startDate, unit: .year),
                    y: .value("Total", year.total)
                )
                .foregroundStyle(barColor(for: year, selected: selected))
            }

            if let selected {
                RuleMark(x: .value("Year", selected.startDate, unit: .year))
                    .foregroundStyle(Color.clear)
                    .annotation(
                        position: .top,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        SelectionCallout(
                            title: selected.isPartial ? "\(String(selected.year)) (so far)" : String(selected.year),
                            value: history.format(selected.total),
                            detail: selected.paymentCount == 1 ? "1 payment" : "\(selected.paymentCount) payments"
                        )
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.year())
            }
        }
        .chartYAxis { currencyAxis }
    }

    private func barColor(for year: AnnualDividend, selected: AnnualDividend?) -> Color {
        var opacity = year.isPartial ? 0.45 : 1.0
        if let selected, selected.year != year.year { opacity *= 0.4 }
        return Color.accentColor.opacity(opacity)
    }

    // MARK: Individual payments

    private var paymentsChart: some View {
        let payments = history.payments(in: range)
        let selected = selectedDate.flatMap { date in
            payments.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        }

        return Chart {
            ForEach(payments) { payment in
                LineMark(
                    x: .value("Ex-Date", payment.date),
                    y: .value("Dividend", payment.amount)
                )
                .interpolationMethod(.stepEnd)
                .foregroundStyle(Color.accentColor)

                PointMark(
                    x: .value("Ex-Date", payment.date),
                    y: .value("Dividend", payment.amount)
                )
                .symbolSize(payments.count > 60 ? 12 : 30)
                .foregroundStyle(Color.accentColor)
            }

            if let selected {
                RuleMark(x: .value("Ex-Date", selected.date))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .annotation(
                        position: .top,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        SelectionCallout(
                            title: selected.date.formatted(date: .abbreviated, time: .omitted),
                            value: history.format(selected.amount),
                            detail: "Ex-dividend date"
                        )
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYAxis { currencyAxis }
    }

    // MARK: Shared

    private var currencyAxis: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine()
            AxisValueLabel {
                if let amount = value.as(Double.self) {
                    Text(amount.formatted(.currency(code: history.currency).precision(.fractionLength(2))))
                }
            }
        }
    }
}

private struct SelectionCallout: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
