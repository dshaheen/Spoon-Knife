# Dividend Graph (iPhone)

A SwiftUI iPhone app. Type in a stock ticker and it fetches the stock's full dividend history, then draws it as an interactive graph.

## Features

- **Ticker search.** Enter any symbol (for example `AAPL`, `KO`, `JNJ` or `O`), or tap one of the suggested symbols.
- **Two chart modes** (built with Swift Charts):
  - **Annual Total:** a bar chart of the dividends paid in each calendar year. The current year is drawn faded because it is year-to-date.
  - **Per Payment:** a step line of each individual dividend, plotted by ex-dividend date.
- **Range picker:** 5Y, 10Y, 20Y or Max.
- **Touch and drag** on the chart to see the exact value for a year or payment.
- **Summary:** latest payment, trailing-12-month total, trailing yield and 5-year compound growth rate.
- **Full payment history** list.

## Requirements

- Xcode 16 or later. The project uses folder-synced groups, so any file you add under `DividendGraph/` is picked up automatically.
- iOS 17 or later.

## Running

1. Open `DividendGraph/DividendGraph.xcodeproj` in Xcode.
2. Select the **DividendGraph** scheme and an iPhone simulator, then press **Run** (⌘R).
3. To run on a physical iPhone, open *Signing & Capabilities*, pick your Team, and change the bundle identifier (`com.example.DividendGraph`) to one you own.

## Data source

Dividend data comes from Yahoo Finance's public chart endpoint, which needs no API key:

```
https://query1.finance.yahoo.com/v8/finance/chart/<SYMBOL>?range=max&interval=1mo&events=div
```

This is an unofficial endpoint. Yahoo can rate-limit it or change it without notice. All networking lives in `DividendService.swift`, so you can swap in another provider (Polygon, Alpha Vantage, etc.) by changing only that file.

## Code layout

| File | Purpose |
| --- | --- |
| `DividendGraphApp.swift` | App entry point |
| `ContentView.swift` | Search field, chart controls, summary and payment list |
| `DividendChartView.swift` | Swift Charts bar and line graphs with touch selection |
| `DividendViewModel.swift` | Loading state; cancels a search that a newer one replaces |
| `DividendService.swift` | Fetches and decodes Yahoo Finance data |
| `Models.swift` | Payment and annual models, yield and growth calculations |
