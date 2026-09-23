# Market Pulse for Omarchy

A small Omarchy bar plugin for monitoring stock indexes, large-cap stocks, futures, and commodities.

## Use

- The bar shows the selected instrument's latest price and daily change.
- Left-click opens the panel.
- Middle-click, the panel refresh button, or `R` refreshes quotes.
- Search the **Market** dropdown first, then choose an instrument from the dependent **Instrument / Benchmark** dropdown.
- Edit **Bar text** to replace the instrument's short label with any text. Clear the field and save to restore the automatic label.
- Enter a Yahoo Finance symbol under **Custom quote symbol** to monitor an instrument outside the curated catalog.
- Your market and instrument selection are stored inline in `~/.config/omarchy/shell.json`.

The default is **United States → S&P 500 Index**. Selecting a region starts from its main benchmark: S&P 500 for the United States, IBOV for Brazil, Euro Stoxx 50 for Europe, and Nikkei 225 for Asia. The instrument selector can then override it.

The **Commodities** market includes current futures quotes for energy, metals, grains, coffee and other softs, cattle and other livestock, and lumber. Yahoo's direct iron-ore series is stale, so the catalog deliberately uses **BHP as a clearly labeled iron-ore exposure proxy** instead of displaying an obsolete ore price as current.

## Data and privacy

The helper uses Python's standard library to request best-effort data from Yahoo Finance's public chart endpoint. It requires no API key and installs no packages. Quotes may be delayed or temporarily unavailable and are not suitable for trading decisions. Requests contain only the selected public ticker symbols.

## Configuration

Use Omarchy's plugin settings to change the selected quote refresh interval from 30 to 900 seconds. The default is 60 seconds. The larger open-panel watchlist refreshes every five minutes to avoid unnecessary provider throttling. Market, instrument, custom symbol, and bar-label choices are changed directly in the panel.

## Files

- `Panel.qml` — bar pulse, popup, searchable selectors, and watchlist
- `Service.qml` — polling, timeout handling, stale state, and quote cache
- `MarketCatalog.js` — curated parent markets and instruments
- `scripts/market-quotes.py` — dependency-free quote normalization

## Validation

```bash
omarchy plugin validate ~/.config/omarchy/plugins/mateus.market-pulse
python3 -m unittest discover -s ~/.config/omarchy/plugins/mateus.market-pulse/tests -v
```
