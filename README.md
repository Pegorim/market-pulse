# Market Pulse for Omarchy

A native, compact monitor for indexes, stocks, futures and commodities. Version 1.2.0 puts quotes first and keeps the inspected instrument independent from the bar.

## Everyday use

- Click the bar widget to open. Its existing instrument, label and refresh interval are preserved.
- Search any name or ticker directly. Search spans all regions, including Portuguese aliases such as **café**, **ouro** and **petróleo**.
- Click a row or press Enter to inspect it. Choose **Mostrar na barra** to pin it explicitly.
- Use ☆ / ★ to add or remove favorites. Favorites retain insertion order across sessions.
- **Todos**, **Favoritos** and the market filter control the list when search is empty.
- Open ⚙ for the bar label, 30–900 second refresh interval, and custom symbols. A custom symbol is only saved after a successful provider quote. A failed request does not change the bar.
- Details ⓘ show the price timestamp, last request timestamp, provider session when available, exchange timezone and any request failure. Times are displayed in the local system timezone.

### Keyboard

`Ctrl+F` focuses search. Down/Enter from search enters the list. Up/Down navigate, Enter inspects, Space toggles a favorite. Tab/Shift+Tab traverse controls, including pin, refresh and preferences. `Ctrl+R` refreshes without intercepting ordinary typing. Escape dismisses an open popup first, then preferences/search, then the panel. Middle-clicking the bar also refreshes.

## Data semantics

Yahoo Finance public chart endpoint, Python standard library only; no keys or extra runtime packages. Requests contain public ticker symbols, not portfolio or personal information.

- Positive and negative changes use plugin-local green/red palettes, independent of the theme's `urgent` color. Signs supplement color. Prices and names stay neutral.
- Price precision uses provider `priceHint` (two decimals if absent), with locale-consistent percentages. Units distinguish currency, points, futures contract units and the explicitly labeled BHP iron-ore **equity proxy**.
- An old price stays old even after a successful request. “Cotação antiga” means older than 15 minutes; it is an age indicator, **not** proof of a closed market or a provider's declared delay. Unknown timestamps remain unknown.
- Session state is shown only from explicit provider metadata. Missing state is “Sessão não informada”, never inferred from weekday or quote age.
- Each successful result is streamed immediately. Four symbols per batch, seven-second network timeouts, twelve-second process watchdog. The watchdog marks only unfinished symbols as failed and preserves previous prices.
- The bar/inspected symbol is prioritized for the next available batch. Active/queued symbols are deduplicated, queue capped at 100, and 429 triggers five minutes of per-symbol backoff.
- The bar refreshes every 60 seconds by default; an open list every five minutes. Data is best-effort and may be delayed.

## Settings and migration

Settings stay in the widget entry of `~/.config/omarchy/shell.json`. Existing `instrumentSymbol`, `marketId`, `barLabel`, `customSymbol`, `refreshIntervalSec` and unknown keys are preserved. New fields: `favorites`, `customSymbols`, `viewFilter`. A legacy custom symbol remains discoverable even after inspecting another instrument. Removing a favorite never silently changes the pin. Removing a custom symbol pinned to the bar requires first pinning another instrument.

The shell's scoped settings API is used for writes; a rejected write does not update local state. The shell performs its own asynchronous atomic disk write.

## Development and validation

Work in a checkout, not in the installed plugin directory. No shell/theme source files need modifications.

```bash
python3 -m unittest discover -s tests -v
node tests/test_state.cjs
python3 tests/run_native.py
omarchy plugin validate .
```

Node is only needed for the development-only JS tests. `run_native.py` requires an existing Wayland/Quickshell session. It opens an isolated test panel, uses fixture subprocesses, writes a temporary settings file, tests real Qt keyboard events and the twelve-second watchdog, then exits. It does not write production settings. The native test catches failed saves, custom validation errors, favorites disk round-trips, legacy settings and layered Escape handling.

## Local installation and rollback

```bash
python3 scripts/install-local.py
```

The installer validates the manifest, backs up the installed plugin and current shell configuration, stages the new package, replaces only `mateus.market-pulse`, and asks the shell to rescan. No theme, other plugin or shell settings are overwritten. The printed backup contains `plugin/` and `shell.json`.

For rollback, close the panel, move the current plugin to a temporary holding directory, copy `plugin/` from the chosen backup to `~/.config/omarchy/plugins/mateus.market-pulse`, then run `omarchy-shell shell rescanPlugins`. Restore only the Market Pulse settings entry if needed; do not replace all of `shell.json`, which may contain subsequent unrelated changes.

## Scope

Historical charts, price alerts, positions/holdings and paid providers are intentionally outside this release. No synthetic chart or portfolio values are presented.
