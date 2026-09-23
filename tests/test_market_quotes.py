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


class RegressionTests(unittest.TestCase):
    def payload(self, closes, times, **meta):
        return {"chart": {"result": [{"meta": meta, "timestamp": times,
            "indicators": {"quote": [{"close": closes}]}}]}}

    def test_null_tail_preserves_price_timestamp_pair(self):
        q = market_quotes.normalize_chart(self.payload([10, 11, None], [1000, 2000, 3000]), "A")
        self.assertEqual((q['price'], q['timestamp']), (11, 2000))

    def test_misaligned_arrays_do_not_invent_a_timestamp(self):
        with self.assertRaises(market_quotes.QuoteError):
            market_quotes.normalize_chart(self.payload([None, 11], [1000]), "A")

    def test_nonfinite_and_boolean_prices_are_not_quotes(self):
        for value in [float('nan'), float('inf'), True]:
            with self.subTest(value=value), self.assertRaises(market_quotes.QuoteError):
                market_quotes.normalize_chart(self.payload([value], [1000], regularMarketPrice=value), 'A')

    def test_zero_price_and_missing_timestamp_are_not_fabricated(self):
        q = market_quotes.normalize_chart(self.payload([11], [1000], regularMarketPrice=0), 'A')
        self.assertEqual((q['price'], q['timestamp']), (0, 0))

    def test_old_success_and_session_are_independent(self):
        with mock.patch.object(market_quotes.time, 'time', return_value=5000):
            q = market_quotes.normalize_chart(self.payload([], [], regularMarketPrice=11,
                regularMarketTime=1000, marketState='CLOSED', priceHint=3), 'A')
        self.assertEqual((q['timestamp'], q['fetchedAt'], q['marketState'], q['priceHint']), (1000, 5000, 'CLOSED', 3))
        q = market_quotes.normalize_chart(self.payload([], [], regularMarketPrice=11, regularMarketTime=1000), 'A')
        self.assertEqual(q['marketState'], 'UNKNOWN')

    def test_stream_yields_success_before_slow_batch_finishes(self):
        import threading
        release = threading.Event()
        events = []
        def fetch(symbol):
            if symbol == 'SLOW':
                if not release.wait(2):
                    raise AssertionError('A completed quote was not streamed')
            if symbol.startswith('BAD'):
                raise market_quotes.QuoteError('Network unavailable')
            return {'symbol': symbol, 'price': 1}
        def receive(event):
            events.append(event)
            if event['quotes'] and event['quotes'][0]['symbol'] == 'FIRST':
                release.set()
        symbols = ['FIRST', 'SLOW'] + ['BAD' + str(i) for i in range(4)] + ['S' + str(i) for i in range(15)]
        with mock.patch.object(market_quotes, 'fetch_quote', side_effect=fetch):
            result = market_quotes.fetch_quotes(symbols + ['FIRST'], receive)
        self.assertEqual(len(events), 21)
        self.assertEqual(len(result['quotes']), 17)
        self.assertEqual(len(result['errors']), 4)
        self.assertTrue(release.is_set())

    def test_invalid_symbol_never_reaches_network(self):
        with mock.patch.object(market_quotes.urllib.request, 'urlopen') as net:
            with self.assertRaises(market_quotes.QuoteError):
                market_quotes.fetch_quote('A;echo bad')
            net.assert_not_called()


if __name__ == "__main__":
    unittest.main()
