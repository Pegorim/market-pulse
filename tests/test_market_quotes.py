import importlib.util
import json
import pathlib
import urllib.error
import unittest
from unittest import mock


PLUGIN_ROOT = pathlib.Path(__file__).resolve().parents[1]
MODULE_PATH = PLUGIN_ROOT / "scripts" / "market-quotes.py"
SPEC = importlib.util.spec_from_file_location("market_quotes", MODULE_PATH)
market_quotes = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(market_quotes)


def fixture(name):
    with (pathlib.Path(__file__).parent / "fixtures" / name).open(encoding="utf-8") as handle:
        return json.load(handle)


class NormalizeChartTests(unittest.TestCase):
    def test_normalizes_meta_price_and_change(self):
        quote = market_quotes.normalize_chart(fixture("success.json"), "^GSPC")
        self.assertEqual(quote["symbol"], "^GSPC")
        self.assertEqual(quote["price"], 5000.25)
        self.assertAlmostEqual(quote["change"], 25.25)
        self.assertAlmostEqual(quote["changePercent"], 25.25 / 4975.0 * 100)
        self.assertEqual(quote["timestamp"], 1700000000)

    def test_falls_back_to_last_close(self):
        quote = market_quotes.normalize_chart(fixture("missing-price.json"), "ES=F")
        self.assertEqual(quote["price"], 5112.5)
        self.assertEqual(quote["timestamp"], 1700000000)

    def test_rejects_malformed_payload(self):
        with self.assertRaisesRegex(market_quotes.QuoteError, "Malformed response"):
            market_quotes.normalize_chart({}, "AAPL")


class BatchTests(unittest.TestCase):
    def test_partial_results_keep_successes_and_errors(self):
        def fake_fetch(symbol):
            if symbol == "BAD":
                raise market_quotes.QuoteError("Quote unavailable")
            return {"symbol": symbol, "price": 1.0}

        with mock.patch.object(market_quotes, "fetch_quote", side_effect=fake_fetch):
            result = market_quotes.fetch_quotes(["AAPL", "BAD", "AAPL"])

        self.assertEqual([quote["symbol"] for quote in result["quotes"]], ["AAPL"])
        self.assertEqual(result["errors"], [{"symbol": "BAD", "message": "Quote unavailable"}])


class FetchTests(unittest.TestCase):
    def test_http_429_has_a_clear_message(self):
        error = urllib.error.HTTPError("https://example.invalid", 429, "limited", {}, None)
        with mock.patch.object(market_quotes.urllib.request, "urlopen", side_effect=error):
            with self.assertRaisesRegex(market_quotes.QuoteError, "Rate limited"):
                market_quotes.fetch_quote("AAPL")

    def test_timeout_is_reported_as_network_unavailable(self):
        with mock.patch.object(market_quotes.urllib.request, "urlopen", side_effect=TimeoutError()):
            with self.assertRaisesRegex(market_quotes.QuoteError, "Network unavailable"):
                market_quotes.fetch_quote("AAPL")


if __name__ == "__main__":
    unittest.main()
