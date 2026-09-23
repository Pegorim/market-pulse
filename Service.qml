import QtQuick
import Quickshell
import Quickshell.Io
import "QuoteState.js" as State

Item {
    id: root

    property string selectedSymbol: "^GSPC"
    property int refreshIntervalSec: 60
    property bool autoRefresh: true
    property var quotes: ({
    })
    property var _activeSymbols: []
    property var _pendingSymbols: []
    property var _received: []
    property var _retryAfter: ({
    })
    property bool _stopping: false
    property int now: Math.floor(Date.now() / 1000)
    readonly property bool refreshing: quoteProcess.running || _stopping || queueTimer.running
    property string helperPath: Qt.resolvedUrl("scripts/market-quotes.py").toString().replace(/^file:\/\//, "")
    readonly property int failureCount: Object.keys(quotes).filter(function(s) {
        return !!quotes[s].error;
    }).length

    signal resultReceived(string symbol, bool success)

    function quoteFor(symbol) {
        return quotes[String(symbol || "")] || null;
    }

    function refreshSelected() {
        refreshSymbols([selectedSymbol], true);
    }

    function refreshSymbols(symbols, priority) {
        var requested = State.unique(symbols).filter(function(s) {
            return root._activeSymbols.indexOf(s) < 0 && Number(root._retryAfter[s] || 0) <= Date.now() / 1000;
        });
        _pendingSymbols = State.unique(priority ? requested.concat(_pendingSymbols) : _pendingSymbols.concat(requested)).slice(0, 100);
        if (!quoteProcess.running && !_stopping && _pendingSymbols.length)
            queueTimer.restart();

    }

    function startNext() {
        if (quoteProcess.running || _stopping || !_pendingSymbols.length)
            return ;
 // Four requests per process: the next priority selection waits at most one small batch.
        _activeSymbols = _pendingSymbols.slice(0, 4);
        _pendingSymbols = _pendingSymbols.slice(4);
        _received = [];
        quoteProcess.command = ["python3", helperPath, "--stream", "--symbols"].concat(_activeSymbols);
        quoteProcess.running = true;
        watchdog.restart();
    }

    function applySnapshot(raw) {
        var snapshot;
        try {
            snapshot = JSON.parse(raw);
        } catch (e) {
            return ;
        }
        quotes = State.merge(quotes, snapshot);
        var retry = State.copy(_retryAfter);
        (snapshot.quotes || []).forEach(function(q) {
            root._received = State.unique(root._received.concat([q.symbol]));
            delete retry[q.symbol];
            root.resultReceived(q.symbol, true);
        });
        (snapshot.errors || []).forEach(function(e) {
            root._received = State.unique(root._received.concat([e.symbol]));
            if (/Rate limited|429/.test(e.message))
                retry[e.symbol] = Date.now() / 1000 + 300;

            root.resultReceived(e.symbol, false);
        });
        _retryAfter = retry;
    }

    function failUnfinished(message) {
        var errors = _activeSymbols.filter(function(s) {
            return root._received.indexOf(s) < 0;
        }).map(function(s) {
            return {
                "symbol": s,
                "message": message
            };
        });
        applySnapshot(JSON.stringify({
            "quotes": [],
            "errors": errors,
            "fetchedAt": Math.floor(Date.now() / 1000)
        }));
    }

    onSelectedSymbolChanged: {
        if (autoRefresh && selectedSymbol) {
            refreshSelected();
        }
    }
    Component.onCompleted: {
        if (autoRefresh) {
            refreshSelected();
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.now = Math.floor(Date.now() / 1000)
    }

    Timer {
        interval: Math.max(30, Math.min(900, root.refreshIntervalSec)) * 1000
        repeat: true
        running: root.autoRefresh
        onTriggered: root.refreshSelected()
    }

    Timer {
        id: queueTimer

        interval: 1
        onTriggered: root.startNext()
    }

    Timer {
        id: watchdog

        interval: 12000
        onTriggered: {
            root._stopping = true;
            root.failUnfinished("Consulta excedeu o prazo; tente novamente");
            quoteProcess.running = false;
        }
    }

    Process {
        id: quoteProcess

        onExited: function(exitCode) {
            watchdog.stop();
            root.failUnfinished("Não foi possível obter a cotação");
            root._activeSymbols = [];
            root._stopping = false;
            if (root._pendingSymbols.length)
                queueTimer.restart();

        }

        stdout: SplitParser {
            onRead: (data) => {
                return root.applySnapshot(data);
            }
        }

        stderr: StdioCollector {
        }

    }

}
