import Foundation

enum DividendServiceError: LocalizedError {
    case invalidSymbol
    case notFound(String)
    case noDividends(String)
    case badResponse(Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidSymbol:
            "Enter a ticker symbol such as AAPL, KO or VTI."
        case .notFound(let symbol):
            "No stock was found for \"\(symbol)\"."
        case .noDividends(let symbol):
            "\(symbol) has no dividend history."
        case .badResponse(let status):
            "The data provider returned an error (HTTP \(status)). Please try again."
        case .decoding:
            "The data provider returned an unexpected response."
        }
    }
}

/// Fetches dividend history from Yahoo Finance's public chart endpoint (no API key required).
struct DividendService {
    var session: URLSession = .shared

    func fetchHistory(for rawSymbol: String) async throws -> DividendHistory {
        let symbol = rawSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !symbol.isEmpty, symbol.count <= 15,
              symbol.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || ".-^=".contains($0)) })
        else { throw DividendServiceError.invalidSymbol }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "query1.finance.yahoo.com"
        components.path = "/v8/finance/chart/\(symbol)"
        components.queryItems = [
            URLQueryItem(name: "range", value: "max"),
            URLQueryItem(name: "interval", value: "1mo"),
            URLQueryItem(name: "events", value: "div"),
        ]
        guard let url = components.url else { throw DividendServiceError.invalidSymbol }

        var request = URLRequest(url: url, timeoutInterval: 20)
        // Yahoo rejects requests without a browser-like user agent.
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        let decoded: ChartResponse
        do {
            decoded = try JSONDecoder().decode(ChartResponse.self, from: data)
        } catch {
            throw status == 200 ? DividendServiceError.decoding : DividendServiceError.badResponse(status)
        }

        // Unknown symbols come back as a 404 whose body carries `chart.error`.
        guard let result = decoded.chart.result?.first else {
            if decoded.chart.error != nil || status == 404 { throw DividendServiceError.notFound(symbol) }
            throw DividendServiceError.badResponse(status)
        }

        let payments = (result.events?.dividends ?? [:]).values
            .map { DividendPayment(date: Date(timeIntervalSince1970: $0.date), amount: $0.amount) }
            .sorted { $0.date < $1.date }
        guard !payments.isEmpty else { throw DividendServiceError.noDividends(result.meta.symbol) }

        return DividendHistory(
            symbol: result.meta.symbol,
            companyName: result.meta.longName ?? result.meta.shortName,
            currency: result.meta.currency ?? "USD",
            price: result.meta.regularMarketPrice,
            payments: payments
        )
    }
}

private struct ChartResponse: Decodable {
    let chart: Chart

    struct Chart: Decodable {
        let result: [Result]?
        let error: APIError?
    }

    struct APIError: Decodable {
        let code: String?
        let description: String?
    }

    struct Result: Decodable {
        let meta: Meta
        let events: Events?
    }

    struct Meta: Decodable {
        let symbol: String
        let currency: String?
        let regularMarketPrice: Double?
        let longName: String?
        let shortName: String?
    }

    struct Events: Decodable {
        /// Keyed by the ex-date as a Unix timestamp string.
        let dividends: [String: Dividend]?
    }

    struct Dividend: Decodable {
        let amount: Double
        let date: TimeInterval
    }
}
