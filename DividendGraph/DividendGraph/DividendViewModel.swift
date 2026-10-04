import Foundation
import Observation

@MainActor
@Observable
final class DividendViewModel {
    enum LoadState {
        case idle
        case loading(String)
        case loaded(DividendHistory)
        case failed(String)
    }

    var symbolInput = ""
    var state: LoadState = .idle
    var range: HistoryRange = .tenYears
    var mode: ChartMode = .annual

    private let service = DividendService()
    private var task: Task<Void, Never>?

    func search() {
        let symbol = symbolInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !symbol.isEmpty else { return }
        symbolInput = symbol

        task?.cancel()
        state = .loading(symbol)
        task = Task {
            do {
                let history = try await service.fetchHistory(for: symbol)
                guard !Task.isCancelled else { return }
                state = .loaded(history)
            } catch is CancellationError {
                // A newer search replaced this one.
            } catch let error as URLError where error.code == .cancelled {
                // Same as above, surfaced by URLSession.
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(error.localizedDescription)
            }
        }
    }

    func search(_ symbol: String) {
        symbolInput = symbol
        search()
    }
}
