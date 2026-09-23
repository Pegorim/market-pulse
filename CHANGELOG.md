# Changelog

## 1.2.0 (2026-09-23)

- Rebuild the native panel around quotes, global search, optional market filters and persistent favorites.
- Separate inspection, favorites and the instrument pinned to the bar.
- Move configuration into preferences; validate custom symbols against the provider before saving.
- Fix loss/gain colors, price/time fallback pairing, non-finite values and locale-consistent precision.
- Separate quote age, provider session and per-symbol request errors; preserve previous values.
- Stream partial results in bounded batches; deduplicate refreshes and back off after HTTP 429.
- Implement keyboard navigation, visible focus, accessible names and layered Escape.
- Preserve legacy settings and custom symbols. Add data, catalog, native keyboard, disk round-trip and watchdog regression tests.

## 1.1.0

Installed baseline preserved in Git and in the pre-upgrade backup.
