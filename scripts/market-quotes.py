#!/usr/bin/env python3
"""Fetch and normalize a small set of best-effort Yahoo Finance quotes."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import math
import re
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


def finite(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _last_number(values: Any) -> float | None:
    if not isinstance(values, list):
        return None
    return next((float(v) for v in reversed(values) if finite(v)), None)


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
    timestamp = meta.get("regularMarketTime")
    if not finite(price):
        indicators = result.get("indicators") or {}
        quote_sets = indicators.get("quote") or []
        closes = quote_sets[0].get("close", []) if quote_sets and isinstance(quote_sets[0], dict) else []
        timestamps = result.get("timestamp") or []
        pairs = [(p, t) for p, t in zip(closes or [], timestamps)
                 if finite(p) and finite(t) and t > 0]
        if not pairs:
            raise QuoteError("Price unavailable")
        price, timestamp = pairs[-1]
    # Never attach a candle's timestamp to an unrelated metadata price.
    timestamp = int(timestamp) if finite(timestamp) and timestamp > 0 else 0
    previous = meta.get("chartPreviousClose")
    if not finite(previous) or previous == 0:
        previous = meta.get("previousClose")
    if not finite(previous) or previous == 0:
        previous = None
    numeric_price = float(price)
    change = numeric_price - float(previous) if previous is not None else None
    change_percent = (change / float(previous) * 100.0) if previous is not None else None
    change = change if finite(change) else None
    change_percent = change_percent if finite(change_percent) else None
    now = int(time.time())
    # Only explicit provider state, never infer a session from stale schedules/age.
    session = str(meta.get("marketState") or "UNKNOWN").upper()
    if session not in ("REGULAR", "PRE", "POST", "CLOSED", "PREPRE", "POSTPOST"):
        session = "UNKNOWN"
    precision = meta.get("priceHint")
    precision = int(precision) if finite(precision) and 0 <= precision <= 8 else 2

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
        "timestamp": timestamp,
        "quoteTimestamp": timestamp,
        "fetchedAt": now,
        "lastSuccessAt": now,
        "marketState": session,
        "exchangeTimezone": str(meta.get("exchangeTimezoneName") or ""),
        "priceHint": precision,
        "dataDelayMinutes": meta.get("exchangeDataDelayedBy") if finite(meta.get("exchangeDataDelayedBy")) else None,
    }


def fetch_quote(symbol: str) -> dict[str, Any]:
    if not re.fullmatch(r"[A-Z0-9.^=_-]{1,32}", symbol):
        raise QuoteError("Invalid symbol format")
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


def fetch_quotes(symbols: list[str], on_result=None) -> dict[str, Any]:
    unique_symbols = list(dict.fromkeys(symbol.strip() for symbol in symbols if symbol.strip()))
    quotes: list[dict[str, Any]] = []
    errors: list[dict[str, str]] = []
    worker_count = max(1, min(4, len(unique_symbols)))

    with concurrent.futures.ThreadPoolExecutor(max_workers=worker_count) as executor:
        futures = {executor.submit(fetch_quote, symbol): symbol for symbol in unique_symbols}
        for future in concurrent.futures.as_completed(futures):
            symbol = futures[future]
            try:
                quote = future.result()
                quotes.append(quote)
                event = {"quotes": [quote], "errors": [], "fetchedAt": int(time.time())}
            except QuoteError as error:
                failure = {"symbol": symbol, "message": str(error)}
                errors.append(failure)
                event = {"quotes": [], "errors": [failure], "fetchedAt": int(time.time())}
            except Exception:
                failure = {"symbol": symbol, "message": "Unexpected quote error"}
                errors.append(failure)
                event = {"quotes": [], "errors": [failure], "fetchedAt": int(time.time())}
            if on_result:
                on_result(event)

    order = {symbol: index for index, symbol in enumerate(unique_symbols)}
    quotes.sort(key=lambda quote: order.get(str(quote.get("symbol")), len(order)))
    errors.sort(key=lambda error: order.get(str(error.get("symbol")), len(order)))
    return {"quotes": quotes, "errors": errors, "fetchedAt": int(time.time())}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stream", action="store_true", help="Emit one JSON line per completed symbol")
    parser.add_argument("--symbols", nargs="+", required=True, help="Yahoo Finance symbols")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    def emit(event):
        print(json.dumps(event, separators=(",", ":"), allow_nan=False), flush=True)
    result = fetch_quotes(args.symbols, on_result=emit if args.stream else None)
    if not args.stream:
        emit(result)
    return 0 if result["quotes"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
