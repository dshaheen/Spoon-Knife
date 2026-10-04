import SwiftUI

struct ContentView: View {
    @State private var model = DividendViewModel()
    @FocusState private var fieldFocused: Bool

    private let suggestions = ["AAPL", "KO", "JNJ", "O", "MSFT", "PG"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    searchRow
                }

                switch model.state {
                case .idle:
                    suggestionsSection
                case .loading(let symbol):
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Loading \(symbol)…")
                                .foregroundStyle(.secondary)
                        }
                    }
                case .failed(let message):
                    Section {
                        ContentUnavailableView(
                            "Couldn't Load Dividends",
                            systemImage: "exclamationmark.triangle",
                            description: Text(message)
                        )
                    }
                    suggestionsSection
                case .loaded(let history):
                    loadedSections(history)
                }
            }
            .navigationTitle("Dividends")
            .scrollDismissesKeyboard(.immediately)
        }
    }

    // MARK: Search

    private var searchRow: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Ticker symbol (e.g. AAPL)", text: $model.symbolInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($fieldFocused)
                .onSubmit(submit)
            Button("Go", action: submit)
                .buttonStyle(.borderedProminent)
                .disabled(model.symbolInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func submit() {
        fieldFocused = false
        model.search()
    }

    private var suggestionsSection: some View {
        Section("Popular dividend stocks") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(suggestions, id: \.self) { symbol in
                        Button(symbol) {
                            fieldFocused = false
                            model.search(symbol)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    // MARK: Results

    @ViewBuilder
    private func loadedSections(_ history: DividendHistory) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(history.symbol)
                    .font(.largeTitle.bold())
                if let name = history.companyName {
                    Text(name)
                        .foregroundStyle(.secondary)
                }
                if let price = history.price {
                    Text("Price \(history.format(price))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Section {
            Picker("Chart", selection: $model.mode) {
                ForEach(ChartMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            DividendChartView(history: history, range: model.range, mode: model.mode)
                .padding(.top, 8)

            Picker("Range", selection: $model.range) {
                ForEach(HistoryRange.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        } footer: {
            Text("Touch and drag on the chart to inspect values. Faded bar = current year to date.")
        }

        Section("Summary") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
                StatTile(title: "Latest", value: history.latest.map { history.format($0.amount) } ?? "—",
                         detail: history.latest?.date.formatted(date: .abbreviated, time: .omitted))
                StatTile(title: "Trailing 12 mo", value: history.format(history.trailingTotal),
                         detail: "\(history.trailingTwelveMonths().count) payments")
                StatTile(title: "Yield (TTM)",
                         value: history.trailingYield.map { $0.formatted(.percent.precision(.fractionLength(2))) } ?? "—",
                         detail: nil)
                StatTile(title: "5Y growth / yr",
                         value: history.fiveYearGrowth.map { $0.formatted(.percent.precision(.fractionLength(1))) } ?? "—",
                         detail: nil)
            }
            .padding(.vertical, 4)
        }

        Section("Payment history (\(history.payments.count))") {
            ForEach(history.payments.reversed()) { payment in
                HStack {
                    Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                    Spacer()
                    Text(history.format(payment.amount))
                        .monospacedDigit()
                }
            }
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
