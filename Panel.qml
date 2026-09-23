import "MarketCatalog.js" as Catalog
import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import Quickshell
import "QuoteState.js" as State
import qs.Commons
import qs.Ui

Panel {
    id: root

    readonly property color foreground: Color.popups.text
    readonly property color background: Color.popups.background
    readonly property bool lightBackground: background.r * 0.299 + background.g * 0.587 + background.b * 0.114 > 0.5
    readonly property color gain: lightBackground ? "#126a37" : "#79dfa0"
    readonly property color loss: lightBackground ? "#ad2238" : "#ff9aa7"
    readonly property color dim: lightBackground ? "#505966" : "#aeb8c4"
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property string pinnedSymbol: String(setting("instrumentSymbol", "^GSPC"))
    readonly property string customBarLabel: String(setting("barLabel", "")).trim()
    readonly property int configuredRefreshInterval: Math.max(30, Math.min(900, Number(setting("refreshIntervalSec", 60)) || 60))
    readonly property var customSymbols: State.unique(setting("customSymbols", [String(setting("customSymbol", ""))]))
    readonly property var favorites: State.unique(setting("favorites", []))
    readonly property var pinnedInstrument: Catalog.findInstrument(pinnedSymbol, customSymbols)
    readonly property var pinnedQuote: quoteService.quoteFor(pinnedSymbol)
    property string inspectedSymbol: pinnedSymbol
    readonly property var inspectedInstrument: Catalog.findInstrument(inspectedSymbol, customSymbols)
    readonly property var inspectedQuote: quoteService.quoteFor(inspectedSymbol)
    property string filterId: String(setting("viewFilter", setting("marketId", "us")))
    property bool preferencesOpen: false
    property string notice: ""
    property string validatingSymbol: ""
    readonly property var visibleInstruments: {
        var query = searchField.text.trim();
        var all = Catalog.allInstruments(customSymbols);
        if (query === "" && filterId !== "all" && filterId !== "favorites")
            return Catalog.marketById(filterId).instruments.map(function(i) {
            return Catalog.findInstrument(i.symbol, customSymbols);
        });

        if (filterId === "favorites" && query === "")
            return favorites.map(function(s) {
            return Catalog.findInstrument(s, customSymbols);
        });

        return all.filter(function(item) {
            return Catalog.matches(item, query) && (query !== "" || filterId === "all" || item.marketId === filterId || (filterId === "futures" && Catalog.hasInstrument("futures", item.symbol)));
        });
    }

    function persistSettings(values) {
        var entry = State.copy(root.settings);
        entry.id = root.moduleName;
        for (var key in values) entry[key] = values[key]
        if (JSON.stringify(entry) === JSON.stringify(root.settings))
            return true;

        if (!root.bar || !root.bar.shell || typeof root.bar.shell.updateEntryInline !== "function") {
            notice = "Não foi possível salvar as preferências. Tente novamente.";
            return false;
        }
        if (!root.bar.shell.updateEntryInline(root.moduleName, entry)) {
            notice = "As preferências não foram alteradas.";
            return false;
        }
        root.settings = entry;
        notice = "";
        return true;
    }

    function inspect(symbol) {
        inspectedSymbol = symbol;
        quoteService.refreshSymbols([symbol], true);
    }

    function pinInspected() {
        persistSettings({
            "instrumentSymbol": inspectedSymbol,
            "marketId": inspectedInstrument.marketId === "custom" ? String(setting("marketId", "us")) : inspectedInstrument.marketId
        });
    }

    function toggleFavorite(symbol) {
        var next = favorites.slice();
        var index = next.indexOf(symbol);
        if (index < 0)
            next.push(symbol);
        else
            next.splice(index, 1);
        persistSettings({
            "favorites": next
        });
    }

    function setFilter(value) {
        filterId = value;
        persistSettings({
            "viewFilter": value
        });
        searchField.text = "";
        refreshDebounce.restart();
    }

    function validateCustom() {
        var symbol = customSymbolField.text.trim().toUpperCase();
        if (!/^[A-Z0-9.^=_-]{1,32}$/.test(symbol)) {
            notice = "Use um ticker válido, como VALE, BTC-USD ou KC=F.";
            return ;
        }
        validatingSymbol = symbol;
        notice = "Consultando " + symbol + "…";
        quoteService.refreshSymbols([symbol], true);
        validationTimer.restart();
    }

    function removeCustom() {
        var symbol = inspectedSymbol;
        if (symbol === pinnedSymbol) {
            notice = "Fixe outro ativo na barra antes de remover este símbolo.";
            return ;
        }
        if (persistSettings({
            "customSymbols": customSymbols.filter(function(s) {
                return s !== symbol;
            }),
            "customSymbol": "",
            "favorites": favorites.filter(function(s) {
                return s !== symbol;
            })
        }))
            inspect(pinnedSymbol);

    }

    function refreshAll() {
        quoteService.refreshSymbols([pinnedSymbol, inspectedSymbol], true);
        quoteService.refreshSymbols(visibleInstruments.map(function(i) {
            return i.symbol;
        }));
    }

    function formatPrice(q) {
        if (!q || q.price === null || q.price === undefined || !isFinite(q.price))
            return "—";

        return Number(q.price).toLocaleString(Qt.locale(), "f", q.priceHint === undefined ? 2 : q.priceHint);
    }

    function formatChange(q) {
        if (!q || q.changePercent === null || q.changePercent === undefined || !isFinite(q.changePercent))
            return "—";

        return (q.changePercent > 0 ? "+" : "") + Number(q.changePercent).toLocaleString(Qt.locale(), "f", 2) + "%";
    }

    function changeColor(q) {
        return !q || q.changePercent === null || !isFinite(q.changePercent) || Number(q.changePercent) === 0 ? foreground : q.changePercent < 0 ? loss : gain;
    }

    function formatTime(epoch) {
        return epoch > 0 ? new Date(epoch * 1000).toLocaleString(Qt.locale(), "dd MMM HH:mm") : "não informado";
    }

    function unit(item, q) {
        return item.unit || (item.kind === "Index" ? "pontos" : q ? String(q.currency || "") : "");
    }

    function status(q) {
        return State.status(q, quoteService.now);
    }

    function moveToList() {
        if (watchlist.count) {
            watchlist.currentIndex = Math.max(0, watchlist.currentIndex);
            watchlist.forceActiveFocus();
            watchlist.positionViewAtIndex(watchlist.currentIndex, ListView.Contain);
        }
    }

    function dismissLayer() {
        if (preferencesOpen) {
            preferencesOpen = false;
            settingsButton.forceActiveFocus();
        } else if (searchField.text !== "") {
            searchField.text = "";
            searchField.forceActiveFocus();
        } else {
            root.close();
        }
    }

    moduleName: "mateus.market-pulse"
    ipcTarget: "mateus.market-pulse"
    implicitWidth: barButton.implicitWidth
    implicitHeight: barButton.implicitHeight
    onOpenedChanged: {
        if (opened) {
            inspectedSymbol = pinnedSymbol;
            preferencesOpen = false;
            notice = "";
            barLabelField.text = customBarLabel;
            intervalField.text = String(configuredRefreshInterval);
            refreshAll();
        }
    }
    onVisibleInstrumentsChanged: {
        watchlist.currentIndex = -1;
        refreshDebounce.restart();
    }

    Service {
        id: quoteService

        objectName: "quoteService"
        selectedSymbol: root.pinnedSymbol
        refreshIntervalSec: root.configuredRefreshInterval
        onResultReceived: function(symbol, success) {
            if (symbol !== root.validatingSymbol)
                return ;

            validationTimer.stop();
            root.validatingSymbol = "";
            if (!success) {
                root.notice = "Não foi possível validar " + symbol + ". Confira o ticker ou tente novamente; pode ser falha de rede.";
                return ;
            }
            if (root.persistSettings({
                "customSymbols": State.unique(root.customSymbols.concat([symbol])),
                "favorites": State.unique(root.favorites.concat([symbol]))
            })) {
                root.inspectedSymbol = symbol;
                root.notice = symbol + " adicionado aos favoritos.";
                root.filterId = "favorites";
            }
        }
    }

    Timer {
        id: validationTimer

        interval: 20000
        onTriggered: {
            root.notice = "Validação indisponível. Aguarde e tente novamente.";
            root.validatingSymbol = "";
        }
    }

    Timer {
        id: refreshDebounce

        interval: 350
        onTriggered: {
            if (root.opened) {
                root.refreshAll();
            }
        }
    }

    Timer {
        interval: 300000
        repeat: true
        running: root.opened
        onTriggered: root.refreshAll()
    }

    WidgetButton {
        id: barButton

        anchors.fill: parent
        bar: root.bar
        text: root.bar && root.bar.vertical ? root.formatChange(root.pinnedQuote) : (root.customBarLabel || root.pinnedInstrument.shortLabel) + "  " + root.formatPrice(root.pinnedQuote) + "  " + root.formatChange(root.pinnedQuote)
        tooltipText: root.pinnedInstrument.label + "\n" + root.formatPrice(root.pinnedQuote) + " " + root.unit(root.pinnedInstrument, root.pinnedQuote) + " · " + root.formatChange(root.pinnedQuote) + "\n" + root.status(root.pinnedQuote)
        active: !!root.pinnedQuote && root.pinnedQuote.changePercent !== null && root.pinnedQuote.changePercent !== 0
        activeColor: root.changeColor(root.pinnedQuote)
        fontSize: Style.font.caption
        onPressed: function(button) {
            if (button === Qt.MiddleButton)
                root.refreshAll();
            else if (button === Qt.LeftButton)
                root.toggle();
        }
    }

    KeyboardPanel {
        id: panel

        objectName: "panel"
        anchorItem: barButton
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: searchField
        contentWidth: panel.fittedContentWidth(Style.space(460))
        contentHeight: panel.fittedContentHeight(Style.space(590), Style.space(650))

        FocusScope {
            id: scope

            objectName: "scope"
            anchors.fill: parent
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.dismissLayer();
                    event.accepted = true;
                } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                    searchField.forceActiveFocus();
                    searchField.selectAll();
                    event.accepted = true;
                } else if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) {
                    root.refreshAll();
                    event.accepted = true;
                }
            }

            Rectangle {
                anchors.fill: parent
                color: root.background
                z: -1
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: Style.space(8)

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Market Pulse"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    ActionButton {
                        id: refreshButton

                        text: "↻"
                        tooltipText: "Atualizar cotações · Ctrl+R"
                        foreground: root.foreground
                        onClicked: root.refreshAll()
                    }

                    ActionButton {
                        id: settingsButton

                        objectName: "settingsButton"
                        text: root.preferencesOpen ? "Voltar" : "⚙"
                        tooltipText: "Preferências"
                        foreground: root.foreground
                        onClicked: {
                            root.preferencesOpen = !root.preferencesOpen;
                            if (root.preferencesOpen)
                                barLabelField.forceActiveFocus();
                            else
                                searchField.forceActiveFocus();
                        }
                    }

                }

                Text {
                    Layout.fillWidth: true
                    text: root.notice
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    color: root.foreground
                    font.pixelSize: Style.font.caption
                }

                ColumnLayout {
                    visible: !root.preferencesOpen
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Style.space(8)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(2)

                        Text {
                            Layout.fillWidth: true
                            text: root.inspectedInstrument.label
                            elide: Text.ElideRight
                            color: root.foreground
                            font.family: root.fontFamily
                            font.bold: true
                            font.pixelSize: Style.font.body
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: root.formatPrice(root.inspectedQuote)
                                elide: Text.ElideRight
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.display
                                font.bold: true
                            }

                            Text {
                                text: root.formatChange(root.inspectedQuote)
                                color: root.changeColor(root.inspectedQuote)
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                                font.bold: true
                                Accessible.name: "Variação diária " + text
                            }

                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.unit(root.inspectedInstrument, root.inspectedQuote) + " · " + root.inspectedInstrument.symbol + (root.inspectedSymbol.indexOf("=F") >= 0 ? " · futuro" : "") + " · variação diária"
                            color: root.dim
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.status(root.inspectedQuote)
                            color: root.foreground
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            ActionButton {
                                objectName: "pinButton"
                                text: root.inspectedSymbol === root.pinnedSymbol ? "✓ Na barra" : "Mostrar na barra"
                                foreground: root.foreground
                                enabled: root.inspectedSymbol !== root.pinnedSymbol
                                onClicked: root.pinInspected()
                            }

                            ActionButton {
                                objectName: "favoriteButton"
                                text: root.favorites.indexOf(root.inspectedSymbol) >= 0 ? "★" : "☆"
                                tooltipText: "Alternar favorito de " + root.inspectedInstrument.label
                                foreground: root.foreground
                                onClicked: root.toggleFavorite(root.inspectedSymbol)
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            ActionButton {
                                objectName: "detailsButton"
                                text: "ⓘ"
                                tooltipText: "Horários e fonte da cotação"
                                foreground: root.foreground
                                onClicked: {
                                    detailPopup.open();
                                    detailClose.forceActiveFocus();
                                }
                            }

                        }

                    }

                    MarketTextField {
                        id: searchField

                        objectName: "searchField"
                        Layout.fillWidth: true
                        placeholderText: "Buscar ativo ou ticker · Ctrl+F"
                        foreground: root.foreground
                        Accessible.name: "Buscar ativo ou ticker"
                        onAccepted: root.moveToList()
                        Keys.onDownPressed: root.moveToList()
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        ActionButton {
                            text: "Todos"
                            selected: root.filterId === "all"
                            foreground: root.foreground
                            onClicked: root.setFilter("all")
                        }

                        ActionButton {
                            text: "★ Favoritos"
                            selected: root.filterId === "favorites"
                            foreground: root.foreground
                            onClicked: root.setFilter("favorites")
                        }

                        QQC.ComboBox {
                            id: marketDropdown

                            Layout.fillWidth: true
                            model: Catalog.marketOptions()
                            textRole: "label"
                            valueRole: "value"
                            currentIndex: model.findIndex(function(m) {
                                return m.value === root.filterId;
                            })
                            displayText: currentIndex < 0 ? "Mercados" : currentText
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.bodySmall
                            Accessible.name: "Filtrar por mercado"
                            palette.buttonText: root.foreground
                            palette.text: root.foreground
                            palette.window: root.background
                            palette.base: root.background
                            palette.highlight: root.foreground
                            palette.highlightedText: root.background
                            onActivated: root.setFilter(currentValue)

                            background: Rectangle {
                                color: Util.alpha(root.foreground, 0.05)
                                radius: Style.cornerRadius
                                border.width: marketDropdown.activeFocus ? 2 : 1
                                border.color: root.dim
                            }

                        }

                    }

                    ListView {
                        id: watchlist

                        objectName: "watchlist"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.visibleInstruments
                        spacing: Style.space(2)
                        activeFocusOnTab: true
                        keyNavigationEnabled: true
                        boundsBehavior: Flickable.StopAtBounds
                        Accessible.role: Accessible.List
                        Accessible.name: "Cotações; setas navegam, Enter consulta, espaço favorita"
                        Keys.onReturnPressed: {
                            if (currentItem) {
                                root.inspect(currentItem.modelData.symbol);
                            }
                        }
                        Keys.onEnterPressed: {
                            if (currentItem) {
                                root.inspect(currentItem.modelData.symbol);
                            }
                        }
                        Keys.onSpacePressed: {
                            if (currentItem) {
                                root.toggleFavorite(currentItem.modelData.symbol);
                            }
                        }
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0) {
                                positionViewAtIndex(currentIndex, ListView.Contain);
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width
                            visible: watchlist.count === 0
                            spacing: Style.space(8)

                            Text {
                                width: parent.width
                                text: root.filterId === "favorites" && searchField.text === "" ? "Seus favoritos aparecem aqui. Use ☆ para adicionar." : "Nenhum ativo encontrado."
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                                color: root.foreground
                                font.pixelSize: Style.font.bodySmall
                            }

                            ActionButton {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Adicionar símbolo"
                                foreground: root.foreground
                                onClicked: {
                                    root.preferencesOpen = true;
                                    customSymbolField.text = searchField.text.toUpperCase();
                                    customSymbolField.forceActiveFocus();
                                }
                            }

                        }

                        QQC.ScrollBar.vertical: QQC.ScrollBar {
                            policy: QQC.ScrollBar.AsNeeded
                        }

                        delegate: Rectangle {
                            id: quoteRow

                            required property var modelData
                            required property int index
                            readonly property var quote: quoteService.quoteFor(modelData.symbol)

                            width: watchlist.width
                            height: Style.space(47)
                            radius: Style.cornerRadius
                            color: rowMouse.containsMouse || root.inspectedSymbol === modelData.symbol ? Util.alpha(root.foreground, 0.07) : "transparent"
                            border.width: watchlist.activeFocus && watchlist.currentIndex === index ? 2 : 0
                            border.color: root.foreground
                            Accessible.role: Accessible.ListItem
                            Accessible.name: modelData.label + ", " + root.formatPrice(quote) + " " + root.unit(modelData, quote) + ", variação " + root.formatChange(quote) + ", " + root.status(quote)
                            Accessible.onPressAction: root.inspect(modelData.symbol)

                            MouseArea {
                                id: rowMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    watchlist.currentIndex = quoteRow.index;
                                    watchlist.forceActiveFocus();
                                    root.inspect(quoteRow.modelData.symbol);
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Style.space(5)
                                spacing: Style.space(7)

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 30
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: quoteRow.modelData.shortLabel + (quoteRow.modelData.symbol === root.pinnedSymbol ? " · ●" : "")
                                        color: root.foreground
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.bodySmall
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: quoteRow.modelData.symbol
                                        color: root.dim
                                        font.pixelSize: Style.font.caption
                                        elide: Text.ElideRight
                                    }

                                }

                                ColumnLayout {
                                    Layout.preferredWidth: watchlist.width * 0.32
                                    Layout.minimumWidth: 60
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.formatPrice(quoteRow.quote)
                                        horizontalAlignment: Text.AlignRight
                                        color: root.foreground
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.bodySmall
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.unit(quoteRow.modelData, quoteRow.quote) + (quoteRow.quote && (quoteRow.quote.error || quoteService.now - quoteRow.quote.timestamp > 900) ? " · antigo" : "")
                                        horizontalAlignment: Text.AlignRight
                                        color: root.dim
                                        font.pixelSize: Style.font.caption
                                        elide: Text.ElideRight
                                    }

                                }

                                Text {
                                    Layout.preferredWidth: Style.space(76)
                                    text: root.formatChange(quoteRow.quote)
                                    horizontalAlignment: Text.AlignRight
                                    color: root.changeColor(quoteRow.quote)
                                    font.family: root.fontFamily
                                    font.pixelSize: Style.font.bodySmall
                                }

                                ActionButton {
                                    text: root.favorites.indexOf(quoteRow.modelData.symbol) >= 0 ? "★" : "☆"
                                    tooltipText: "Favorito: " + quoteRow.modelData.label
                                    foreground: root.foreground
                                    horizontalPadding: 1
                                    focusable: false
                                    onClicked: root.toggleFavorite(quoteRow.modelData.symbol)
                                }

                            }

                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        text: quoteService.refreshing ? "Atualizando · resultados aparecem progressivamente" : quoteService.failureCount ? quoteService.failureCount + " consulta(s) indisponível(is) · Ctrl+R para tentar novamente" : "Yahoo Finance · dados podem ter atraso"
                        color: root.dim
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }

                }

                Flickable {
                    visible: root.preferencesOpen
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: prefs.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: prefs

                        width: parent.width
                        spacing: Style.space(12)

                        Text {
                            text: "Preferências"
                            color: root.foreground
                            font.pixelSize: Style.font.body
                            font.bold: true
                        }

                        Text {
                            text: "Rótulo na barra (vazio = automático)"
                            color: root.foreground
                            font.pixelSize: Style.font.bodySmall
                        }

                        MarketTextField {
                            id: barLabelField

                            objectName: "barLabelField"
                            Layout.fillWidth: true
                            maximumLength: 32
                            foreground: root.foreground
                            Accessible.name: "Rótulo na barra"
                        }

                        Text {
                            text: "Atualização da barra · 30 a 900 segundos"
                            color: root.foreground
                            font.pixelSize: Style.font.bodySmall
                        }

                        MarketTextField {
                            id: intervalField

                            objectName: "intervalField"
                            Layout.fillWidth: true
                            foreground: root.foreground
                            Accessible.name: "Intervalo em segundos"

                            validator: IntValidator {
                                bottom: 30
                                top: 900
                            }

                        }

                        ActionButton {
                            objectName: "savePreferences"
                            text: "Salvar preferências"
                            foreground: root.foreground
                            onClicked: {
                                if (intervalField.acceptableInput && root.persistSettings({
                                    "barLabel": barLabelField.text.trim(),
                                    "refreshIntervalSec": Number(intervalField.text)
                                }))
                                    root.notice = "Preferências salvas.";
                                else
                                    root.notice = "Confira o intervalo (30–900 segundos).";
                            }
                        }

                        PanelSeparator {
                            Layout.fillWidth: true
                            foreground: root.foreground
                        }

                        Text {
                            text: "Adicionar símbolo do Yahoo Finance"
                            color: root.foreground
                            font.pixelSize: Style.font.bodySmall
                        }

                        MarketTextField {
                            id: customSymbolField

                            objectName: "customSymbolField"
                            Layout.fillWidth: true
                            placeholderText: "Ex.: BTC-USD ou VALE"
                            maximumLength: 32
                            foreground: root.foreground
                            Accessible.name: "Símbolo personalizado"
                            onAccepted: root.validateCustom()
                        }

                        ActionButton {
                            text: root.validatingSymbol ? "Validando…" : "Validar e adicionar"
                            enabled: !root.validatingSymbol
                            foreground: root.foreground
                            onClicked: root.validateCustom()
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "O símbolo só é salvo após uma cotação válida. Adicionar um favorito não altera o ativo da barra."
                            wrapMode: Text.Wrap
                            color: root.foreground
                            font.pixelSize: Style.font.caption
                        }

                        ActionButton {
                            visible: root.customSymbols.indexOf(root.inspectedSymbol) >= 0
                            text: "Remover " + root.inspectedSymbol
                            foreground: root.foreground
                            onClicked: root.removeCustom()
                        }

                    }

                    QQC.ScrollBar.vertical: QQC.ScrollBar {
                    }

                }

            }

            QQC.Popup {
                id: detailPopup

                anchors.centerIn: parent
                width: parent.width
                height: Math.min(parent.height, details.implicitHeight + 32)
                modal: true
                focus: true
                closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside
                onClosed: searchField.forceActiveFocus()

                background: Rectangle {
                    color: root.background
                    border.color: root.foreground
                    radius: Style.cornerRadius
                }

                contentItem: ColumnLayout {
                    id: details

                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root.inspectedInstrument.label
                        wrapMode: Text.Wrap
                        color: root.foreground
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: State.session(root.inspectedQuote) + "\nCotação: " + root.formatTime(root.inspectedQuote ? root.inspectedQuote.timestamp : 0) + "\nConsulta: " + root.formatTime(root.inspectedQuote ? root.inspectedQuote.fetchedAt : 0) + "\nHorários no fuso local · " + (root.inspectedQuote ? root.inspectedQuote.exchangeTimezone || "bolsa sem fuso informado" : "") + "\n" + root.status(root.inspectedQuote) + "\n" + (root.inspectedQuote ? root.inspectedQuote.error || "" : "") + "\nFonte: Yahoo Finance · melhor esforço"
                        wrapMode: Text.Wrap
                        color: root.foreground
                        font.pixelSize: Style.font.bodySmall
                    }

                    ActionButton {
                        id: detailClose

                        text: "Fechar"
                        foreground: root.foreground
                        onClicked: detailPopup.close()
                    }

                }

            }

        }

    }

}
