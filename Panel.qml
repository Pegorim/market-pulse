import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import qs.Commons
import qs.Ui
import "MarketCatalog.js" as Catalog

Panel {
  id: root
  moduleName: "mateus.market-pulse"
  ipcTarget: "mateus.market-pulse"

  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string selectedMarketId: Catalog.normalizedMarketId(setting("marketId", "us"))
  readonly property string storedInstrumentSymbol: String(setting("instrumentSymbol", "^GSPC"))
  readonly property string customSymbol: String(setting("customSymbol", "")).trim().toUpperCase()
  readonly property bool selectedIsCustom: customSymbol !== ""
    && storedInstrumentSymbol.toUpperCase() === customSymbol
  readonly property string selectedInstrumentSymbol: selectedIsCustom
    ? customSymbol
    : Catalog.normalizedSymbol(selectedMarketId, storedInstrumentSymbol)
  readonly property string customBarLabel: String(setting("barLabel", "")).trim()
  readonly property int configuredRefreshInterval: {
    var value = parseInt(String(setting("refreshIntervalSec", 60)), 10)
    if (!isFinite(value)) value = 60
    return Math.max(30, Math.min(900, value))
  }
  readonly property var selectedMarket: Catalog.marketById(selectedMarketId)
  readonly property var selectedInstrument: selectedIsCustom
    ? ({ symbol: customSymbol, label: customSymbol, shortLabel: customSymbol, kind: "Custom", unit: "" })
    : Catalog.instrumentBySymbol(selectedMarketId, selectedInstrumentSymbol)
  readonly property string effectiveBarLabel: customBarLabel !== ""
    ? customBarLabel
    : (selectedInstrument ? selectedInstrument.shortLabel : selectedInstrumentSymbol)
  readonly property var selectedQuote: quoteService.quoteFor(selectedInstrumentSymbol)
  readonly property var marketOptions: Catalog.marketOptions()
  readonly property var instrumentOptions: buildInstrumentOptions()
  readonly property var marketSymbols: buildMarketSymbols()
  readonly property var marketInstruments: buildMarketInstruments()
  readonly property bool selectedIsNegative: selectedQuote
    && Number(selectedQuote.changePercent) < 0
  property string customSymbolError: ""

  function buildInstrumentOptions() {
    var options = Catalog.instrumentOptions(selectedMarketId)
    if (selectedIsCustom) options.push({
      value: customSymbol,
      label: customSymbol,
      description: "Custom quote symbol"
    })
    return options
  }

  function buildMarketSymbols() {
    var symbols = Catalog.symbolsForMarket(selectedMarketId)
    if (selectedIsCustom) symbols.push(customSymbol)
    return symbols
  }

  function buildMarketInstruments() {
    var instruments = selectedMarket.instruments.slice(0)
    if (selectedIsCustom) instruments.push(selectedInstrument)
    return instruments
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function selectMarket(marketId) {
    var normalized = Catalog.normalizedMarketId(marketId)
    var market = Catalog.marketById(normalized)
    persistSettings({ marketId: normalized, instrumentSymbol: market.defaultSymbol })
    Qt.callLater(function() { quoteService.refreshSymbols(Catalog.symbolsForMarket(normalized)) })
  }

  function selectInstrument(symbol) {
    var requested = String(symbol || "").trim().toUpperCase()
    var normalized = requested === customSymbol && customSymbol !== ""
      ? customSymbol
      : Catalog.normalizedSymbol(selectedMarketId, requested)
    persistSettings({ instrumentSymbol: normalized })
    Qt.callLater(quoteService.refreshSelected)
  }

  function saveBarLabel() {
    persistSettings({ barLabel: String(barLabelField.text || "").trim() })
    keyCatcher.forceActiveFocus()
  }

  function applyCustomSymbol() {
    var symbol = String(customSymbolField.text || "").trim().toUpperCase()
    if (!symbol.match(/^[A-Z0-9.^=_-]{1,32}$/)) {
      customSymbolError = "Use a valid quote symbol, such as VALE, BTC-USD, or KC=F"
      return
    }
    customSymbolError = ""
    customSymbolField.text = symbol
    persistSettings({ customSymbol: symbol, instrumentSymbol: symbol })
    Qt.callLater(quoteService.refreshSelected)
  }

  function refreshAll() {
    quoteService.refreshSymbols(marketSymbols)
  }

  function quoteFor(symbol) {
    return quoteService.quoteFor(symbol)
  }

  function formatPrice(value) {
    var number = Number(value)
    if (!isFinite(number)) return "—"
    var decimals = Math.abs(number) < 10 ? 3 : (Math.abs(number) < 1000 ? 2 : 1)
    return number.toLocaleString(Qt.locale(), "f", decimals)
  }

  function formatChange(value) {
    if (value === null || value === undefined) return "—"
    var number = Number(value)
    if (!isFinite(number)) return "—"
    return (number > 0 ? "+" : "") + number.toFixed(2) + "%"
  }

  function formatTime(epoch) {
    var seconds = Number(epoch)
    if (!isFinite(seconds) || seconds <= 0) return "not updated"
    return new Date(seconds * 1000).toLocaleString(Qt.locale(), "MMM d, HH:mm")
  }

  function displayUnit() {
    if (selectedInstrument && selectedInstrument.unit) return selectedInstrument.unit
    return selectedQuote ? String(selectedQuote.currency || "") : ""
  }

  function barText() {
    var label = effectiveBarLabel
    if (!selectedQuote) return label + "  …"
    return label + "  " + formatPrice(selectedQuote.price) + "  "
      + formatChange(selectedQuote.changePercent)
  }

  function verticalBarText() {
    if (!selectedQuote) return "󰄬"
    return formatChange(selectedQuote.changePercent)
  }

  function tooltipText() {
    var label = selectedInstrument ? selectedInstrument.label : selectedInstrumentSymbol
    if (!selectedQuote) return label + "\nWaiting for quote"
    var freshness = selectedQuote.stale ? " · stale" : ""
    var unit = displayUnit()
    return label + "\n" + formatPrice(selectedQuote.price) + (unit !== "" ? " " + unit : "") + "  "
      + formatChange(selectedQuote.changePercent) + "\nUpdated "
      + formatTime(selectedQuote.timestamp) + freshness
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    barLabelField.text = customBarLabel
    customSymbolField.text = customSymbol
    customSymbolError = ""
    refreshAll()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: quoteService
    selectedSymbol: root.selectedInstrumentSymbol
    refreshIntervalSec: root.configuredRefreshInterval
  }

  Timer {
    interval: Math.max(300, root.configuredRefreshInterval) * 1000
    repeat: true
    running: root.opened
    onTriggered: root.refreshAll()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.bar && root.bar.vertical ? root.verticalBarText() : root.barText()
    tooltipText: root.tooltipText()
    active: root.selectedIsNegative
    activeColor: root.urgent
    dimmed: root.selectedQuote && root.selectedQuote.stale === true
    fontSize: Style.font.caption
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refreshAll()
      else if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(650))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: marketDropdown.popupOpen || instrumentDropdown.popupOpen
        || barLabelField.activeFocus || customSymbolField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refreshAll()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: root.selectedInstrument ? root.selectedInstrument.label : root.selectedInstrumentSymbol
            meta: root.selectedMarket.label + " · " + (root.selectedQuote ? root.formatTime(root.selectedQuote.timestamp) : "waiting for quote")
            detail: quoteService.refreshing ? "refreshing" : (root.selectedQuote && root.selectedQuote.stale ? "stale" : "")
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󰄬"
                color: root.selectedIsNegative ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          BorderSurface {
            width: parent.width
            implicitHeight: pulseColumn.implicitHeight + Style.space(22)
            color: Util.alpha(root.foreground, 0.04)
            radius: Style.cornerRadius
            borderSpec: Border.flat(Util.alpha(root.foreground, 0.10), 1)

            Column {
              id: pulseColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(14)
              anchors.rightMargin: Style.space(14)
              spacing: Style.space(3)

              Text {
                text: root.selectedQuote ? root.formatPrice(root.selectedQuote.price) : "—"
                color: root.selectedIsNegative ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                font.bold: true
              }

              Row {
                spacing: Style.space(10)
                Text {
                  text: root.selectedQuote ? root.formatChange(root.selectedQuote.changePercent) : "Waiting for market data"
                  color: root.selectedIsNegative ? root.urgent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  visible: root.selectedQuote && root.selectedQuote.currency
                  text: root.displayUnit()
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }

          Text {
            visible: quoteService.lastError !== ""
            width: parent.width
            text: quoteService.lastError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          SearchableDropdown {
            id: marketDropdown
            width: parent.width
            label: "MARKET"
            value: root.selectedMarketId
            options: root.marketOptions
            placeholderText: "Search markets..."
            foreground: root.foreground
            fontFamily: root.fontFamily
            onChanged: function(value) { root.selectMarket(value) }
          }

          SearchableDropdown {
            id: instrumentDropdown
            width: parent.width
            label: "INSTRUMENT / BENCHMARK"
            value: root.selectedInstrumentSymbol
            options: root.instrumentOptions
            placeholderText: "Search instruments..."
            foreground: root.foreground
            fontFamily: root.fontFamily
            onChanged: function(value) { root.selectInstrument(value) }
          }

          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader {
            text: "CUSTOMIZE"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Column {
            width: parent.width
            spacing: Style.space(5)

            Text {
              text: "BAR TEXT"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: barLabelField
                width: parent.width - saveLabelButton.implicitWidth - parent.spacing
                maximumLength: 32
                placeholderText: root.selectedInstrument ? root.selectedInstrument.shortLabel : "Bar label"
                foreground: root.foreground
                font.family: root.fontFamily
                onAccepted: root.saveBarLabel()
              }

              Button {
                id: saveLabelButton
                text: "Save"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.saveBarLabel()
              }
            }

            Text {
              width: parent.width
              text: "Leave blank to use the selected instrument label (S&P 500, IBOV, Gold, and so on)."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(5)

            Text {
              text: "CUSTOM QUOTE SYMBOL"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: customSymbolField
                width: parent.width - useSymbolButton.implicitWidth - parent.spacing
                maximumLength: 32
                placeholderText: "Yahoo symbol, for example KC=F"
                foreground: root.foreground
                font.family: root.fontFamily
                onAccepted: root.applyCustomSymbol()
              }

              Button {
                id: useSymbolButton
                text: "Use"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.applyCustomSymbol()
              }
            }

            Text {
              visible: root.customSymbolError !== ""
              width: parent.width
              text: root.customSymbolError
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              text: "Adds any supported Yahoo Finance symbol to the current market without running a shell command."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator { foreground: root.foreground }

          Row {
            width: parent.width
            PanelSectionHeader {
              width: parent.width - refreshButton.width
              text: root.selectedMarket.label.toUpperCase()
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            PanelActionButton {
              id: refreshButton
              iconText: "󰑐"
              tooltipText: "Refresh market"
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !quoteService.refreshing
              onClicked: root.refreshAll()
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(3)

            Repeater {
              model: root.marketInstruments

              BorderSurface {
                required property var modelData
                width: parent.width
                height: Style.space(38)
                radius: Style.cornerRadius
                color: rowMouse.containsMouse || modelData.symbol === root.selectedInstrumentSymbol
                  ? Style.hoverFillFor(root.foreground, Color.accent)
                  : "transparent"
                borderSpec: modelData.symbol === root.selectedInstrumentSymbol
                  ? Border.controlSpec("selected", root.foreground, Color.accent)
                  : Border.none()
                readonly property var rowQuote: root.quoteFor(modelData.symbol)
                readonly property bool negative: rowQuote && Number(rowQuote.changePercent) < 0

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(10)
                  width: parent.width * 0.50
                  text: modelData.shortLabel
                  color: parent.negative ? root.urgent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: modelData.symbol === root.selectedInstrumentSymbol
                  elide: Text.ElideRight
                }

                Text {
                  anchors.right: changeText.left
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.rightMargin: Style.space(12)
                  text: parent.rowQuote ? root.formatPrice(parent.rowQuote.price) : "—"
                  color: parent.rowQuote && parent.rowQuote.stale ? root.dim : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }

                Text {
                  id: changeText
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.rightMargin: Style.space(10)
                  width: Style.space(58)
                  horizontalAlignment: Text.AlignRight
                  text: parent.rowQuote ? root.formatChange(parent.rowQuote.changePercent) : "—"
                  color: parent.negative ? root.urgent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }

                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectInstrument(parent.modelData.symbol)
                }
              }
            }
          }

          Text {
            width: parent.width
            text: "Best-effort quotes · delayed data may apply · press R to refresh"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
