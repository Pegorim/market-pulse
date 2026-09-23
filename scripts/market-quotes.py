#!/usr/bin/env python3
"""Fetch and normalize a small set of best-effort Yahoo Finance quotes."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


BASE_URL = "https://query2.finance.yahoo.com/v8/finance/chart/{}"
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) Omarchy-Market-Pulse/1.0"
MAX_RESPONSE_BYTES = 1_500_000
TIMEOUT_SECONDS = 7


class QuoteError(RuntimeError):
    """A user-facing quote retrieval error."""


def _last_number(values: Any) -> float | None:
    if not isinstance(values, list):
        return None
    for value in reversed(values):
        if isinstance(value, (int, float)):
            return float(value)
    return None


def normalize_chart(payload: dict[str, Any], requested_symbol: str) -> dict[str, Any]:
    chart = payload.get("chart")
    if not isinstance(chart, dict):
        raise QuoteError("Malformed response")
    if chart.get("error"):
        description = chart["error"].get("description") if isinstance(chart["error"], dict) else None
        raise QuoteError(str(description or "Quote unavailable"))

    results = chart.get("result")
    if not isinstance(results, list) or not results or not isinstance(results[0], dict):
        raise QuoteError("Quote unavailable")

    result = results[0]
    meta = result.get("meta") if isinstance(result.get("meta"), dict) else {}
    price = meta.get("regularMarketPrice")
    if not isinstance(price, (int, float)):
        indicators = result.get("indicators") if isinstance(result.get("indicators"), dict) else {}
        quote_sets = indicators.get("quote") if isinstance(indicators.get("quote"), list) else []
        closes = quote_sets[0].get("close") if quote_sets and isinstance(quote_sets[0], dict) else []
        price = _last_number(closes)
    if not isinstance(price, (int, float)):
        raise QuoteError("Price unavailable")

    previous = meta.get("chartPreviousClose")
    if not isinstance(previous, (int, float)) or previous == 0:
        previous = meta.get("previousClose")
    if not isinstance(previous, (int, float)) or previous == 0:
        previous = None

    numeric_price = float(price)
    change = numeric_price - float(previous) if previous is not None else None
    change_percent = (change / float(previous) * 100.0) if previous is not None else None

    timestamp = meta.get("regularMarketTime")
    if not isinstance(timestamp, (int, float)):
        timestamps = result.get("timestamp")
        timestamp = _last_number(timestamps)

    return {
        "symbol": requested_symbol,
        "sourceSymbol": str(meta.get("symbol") or requested_symbol),
        "name": str(meta.get("shortName") or meta.get("longName") or requested_symbol),
        "instrumentType": str(meta.get("instrumentType") or ""),
        "exchange": str(meta.get("fullExchangeName") or meta.get("exchangeName") or ""),
        "currency": str(meta.get("currency") or ""),
        "price": numeric_price,
        "previousClose": float(previous) if previous is not None else None,
        "change": change,
        "changePercent": change_percent,
        "timestamp": int(timestamp) if isinstance(timestamp, (int, float)) else 0,
    }


def fetch_quote(symbol: str) -> dict[str, Any]:
    encoded = urllib.parse.quote(symbol, safe="")
    query = urllib.parse.urlencode({"interval": "5m", "range": "1d"})
    request = urllib.request.Request(
        f"{BASE_URL.format(encoded)}?{query}",
        headers={"Accept": "application/json", "User-Agent": USER_AGENT},
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            raw = response.read(MAX_RESPONSE_BYTES + 1)
    except urllib.error.HTTPError as error:
        if error.code == 429:
            raise QuoteError("Rate limited; showing the last quote") from error
        raise QuoteError(f"HTTP {error.code}") from error
    except (urllib.error.URLError, TimeoutError) as error:
        raise QuoteError("Network unavailable") from error

    if len(raw) > MAX_RESPONSE_BYTES:
        raise QuoteError("Response too large")
    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise QuoteError("Malformed response") from error
    if not isinstance(payload, dict):
        raise QuoteError("Malformed response")
    return normalize_chart(payload, symbol)


def fetch_quotes(symbols: list[str]) -> dict[str, Any]:
    unique_symbols = list(dict.fromkeys(symbol.strip() for symbol in symbols if symbol.strip()))
    quotes: list[dict[str, Any]] = []
    errors: list[dict[str, str]] = []
    worker_count = max(1, min(4, len(unique_symbols)))

    with concurrent.futures.ThreadPoolExecutor(max_workers=worker_count) as executor:
        futures = {executor.submit(fetch_quote, symbol): symbol for symbol in unique_symbols}
        for future in concurrent.futures.as_completed(futures):
            symbol = futures[future]
            try:
                quotes.append(future.result())
            except QuoteError as error:
                errors.append({"symbol": symbol, "message": str(error)})
            except Exception:
                errors.append({"symbol": symbol, "message": "Unexpected quote error"})

    order = {symbol: index for index, symbol in enumerate(unique_symbols)}
    quotes.sort(key=lambda quote: order.get(str(quote.get("symbol")), len(order)))
    errors.sort(key=lambda error: order.get(str(error.get("symbol")), len(order)))
    return {"quotes": quotes, "errors": errors, "fetchedAt": int(time.time())}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--symbols", nargs="+", required=True, help="Yahoo Finance symbols")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    result = fetch_quotes(args.symbols)
    json.dump(result, sys.stdout, separators=(",", ":"), allow_nan=False)
    sys.stdout.write("\n")
    return 0 if result["quotes"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
