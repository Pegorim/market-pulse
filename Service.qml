import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property string selectedSymbol: "^GSPC"
  property int refreshIntervalSec: 60
  property var quotes: ({})
  property string lastError: ""
  property int lastFetchedAt: 0
  property string _stdout: ""
  property string _stderr: ""
  property var _activeSymbols: []
  property var _pendingSymbols: []
  property bool _timedOut: false
  property bool _stopping: false
  readonly property bool refreshing: quoteProcess.running || _stopping
  readonly property string helperPath: Quickshell.env("HOME")
    + "/.config/omarchy/plugins/mateus.market-pulse/scripts/market-quotes.py"

  function quoteFor(symbol) {
    return quotes[String(symbol || "")] || null
  }

  function normalizedSymbols(symbols) {
    var seen = ({})
    var result = []
    for (var i = 0; i < symbols.length; i++) {
      var symbol = String(symbols[i] || "").trim()
      if (symbol === "" || seen[symbol]) continue
      seen[symbol] = true
      result.push(symbol)
    }
    return result
  }

  function mergePending(symbols) {
    _pendingSymbols = normalizedSymbols(_pendingSymbols.concat(symbols))
  }

  function refreshSelected() {
    refreshSymbols([selectedSymbol])
  }

  function refreshSymbols(symbols) {
    var requested = normalizedSymbols(symbols || [])
    if (requested.length === 0) return
    if (quoteProcess.running || _stopping) {
      mergePending(requested)
      return
    }

    _activeSymbols = requested
    _stdout = ""
    _stderr = ""
    _timedOut = false
    _stopping = false
    var command = ["python3", helperPath, "--symbols"]
    for (var i = 0; i < requested.length; i++) command.push(requested[i])
    quoteProcess.command = command
    quoteProcess.running = true
    watchdog.restart()
  }

  function cloneQuote(quote) {
    var result = ({})
    if (!quote) return result
    for (var key in quote) result[key] = quote[key]
    return result
  }

  function markFailed(symbols, message) {
    var next = ({})
    for (var existing in quotes) next[existing] = quotes[existing]
    for (var i = 0; i < symbols.length; i++) {
      var symbol = symbols[i]
      if (!next[symbol]) continue
      var stale = cloneQuote(next[symbol])
      stale.stale = true
      stale.error = message
      next[symbol] = stale
    }
    quotes = next
    lastError = message
  }

  function applySnapshot(raw) {
    var snapshot
    try {
      snapshot = JSON.parse(String(raw || "{}"))
    } catch (error) {
      markFailed(_activeSymbols, "Could not read market data")
      return
    }

    var next = ({})
    for (var existing in quotes) next[existing] = quotes[existing]

    var received = Array.isArray(snapshot.quotes) ? snapshot.quotes : []
    for (var i = 0; i < received.length; i++) {
      var quote = received[i]
      if (!quote || !quote.symbol) continue
      quote.stale = false
      quote.error = ""
      next[String(quote.symbol)] = quote
    }

    var errors = Array.isArray(snapshot.errors) ? snapshot.errors : []
    var messages = []
    for (var j = 0; j < errors.length; j++) {
      var failure = errors[j] || ({})
      var symbol = String(failure.symbol || "")
      var message = String(failure.message || "Quote unavailable")
      if (symbol !== "" && next[symbol]) {
        var stale = cloneQuote(next[symbol])
        stale.stale = true
        stale.error = message
        next[symbol] = stale
      }
      messages.push(symbol === "" ? message : symbol + ": " + message)
    }

    quotes = next
    lastFetchedAt = Number(snapshot.fetchedAt || 0)
    lastError = messages.join(" · ")
  }

  function startPending() {
    if (_pendingSymbols.length === 0) return
    var pending = _pendingSymbols
    _pendingSymbols = []
    Qt.callLater(function() { root.refreshSymbols(pending) })
  }

  onSelectedSymbolChanged: if (selectedSymbol !== "") refreshSelected()
  Component.onCompleted: refreshSelected()

  Timer {
    interval: Math.max(30, Math.min(900, root.refreshIntervalSec)) * 1000
    repeat: true
    running: true
    onTriggered: root.refreshSelected()
  }

  Timer {
    id: watchdog
    interval: 12000
    repeat: false
    onTriggered: {
      if (!quoteProcess.running) return
      root._timedOut = true
      root._stopping = true
      root.markFailed(root._activeSymbols, "Market data request timed out")
      quoteProcess.running = false
    }
  }

  Process {
    id: quoteProcess
    running: false
    command: []

    stdout: StdioCollector {
      id: stdoutCollector
      waitForEnd: true
      onStreamFinished: root._stdout = text
    }

    stderr: StdioCollector {
      id: stderrCollector
      waitForEnd: true
      onStreamFinished: root._stderr = text
    }

    onExited: function(exitCode) {
      watchdog.stop()
      var output = String(root._stdout || stdoutCollector.text || "")
      var errorText = String(root._stderr || stderrCollector.text || "").trim()
      if (!root._timedOut) {
        if (output !== "") root.applySnapshot(output)
        else root.markFailed(root._activeSymbols, errorText || "Market data request failed")
      }
      root._timedOut = false
      root._stopping = false
      root.startPending()
    }
  }
}
