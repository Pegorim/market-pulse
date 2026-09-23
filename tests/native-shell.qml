import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Commons
import "Pulse" as Pulse
ShellRoot {
  id: harness
  property bool allowWrites: true
  FileView { id: disk; path: Quickshell.env("MARKET_PULSE_TEST_STATE"); atomicWrites: true; printErrors: false }
  property var saved: ({instrumentSymbol:"KC=F",marketId:"commodities",customSymbol:"BTC-USD",barLabel:"Café",refreshIntervalSec:120})
  QtObject {
    id: host
    function updateEntryInline(id, entry) { if (!harness.allowWrites) return false; harness.saved = JSON.parse(JSON.stringify(entry)); disk.setText(JSON.stringify(entry)); return true }
  }
  QtObject {
    id: fakeBar
    property var shell: host
    property color barForeground: Color.foreground
    property color urgent: Color.urgent
    property string fontFamily: Style.font.family
    property bool foregroundAnimationEnabled: false
    property string position: "top"
    property bool vertical: position === "left" || position === "right"
    property int barSize: 35
    property var activePopout: null
    property var clickTargets: []
    function requestPopout(owner) { activePopout = owner }
    function releasePopout(owner) { activePopout = null }
    function registerClickTarget(target) {}
    function unregisterClickTarget(target) {}
    function hideTooltip(target) {}
    function showTooltip(target, text) {}
  }
  PanelWindow {
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 35
    exclusionMode: ExclusionMode.Ignore
    color: Color.background
    Pulse.Panel { id: pulse; bar: fakeBar; manageIpc: false; anchors.centerIn: parent; settings: harness.saved
      Component.onCompleted: {
        var service=tests.control("quoteService")
        service.autoRefresh=false
        service.helperPath=Quickshell.env("MARKET_PULSE_FIXTURE_HELPER")
      }
    }
  }
  Pulse.Service { id: timeoutService; autoRefresh: false; helperPath: Quickshell.env("MARKET_PULSE_FIXTURE_HELPER") }
  TestCase {
    id: tests
    name: "MarketPulseNative"
    when: false
    function check(value, message) { console.log("CHECK", message, value); verify(value,message) }
    function equal(a,b,message) { console.log("EQUAL",message,a,b); compare(a,b,message) }
    function control(name) { return findChild(pulse, name) }
    function seed() {
      var service = control("quoteService")
      service.autoRefresh = false
      var symbols = ["GC=F","SI=F","HG=F","PL=F","PA=F","BHP","CL=F","BZ=F","NG=F","KC=F","SB=F","CC=F","CT=F","OJ=F","ZC=F","ZW=F","ZS=F","LE=F","GF=F","HE=F","LBR=F"]
      var now = Math.floor(Date.now()/1000)
      var q = symbols.map(function(s,i){return {symbol:s,price:i===9?305.15:100+i*321.12,changePercent:i%3===0?-1.23:0.82,timestamp:now-120,fetchedAt:now,marketState:"UNKNOWN",priceHint:2,currency:"USD"}})
      service.applySnapshot(JSON.stringify({quotes:q,errors:[],fetchedAt:now}))
    }
    function runChecks() {
      tests.parent = control("scope")
      seed()
      pulse.open()
      wait(500)
      var search = control("searchField"), list = control("watchlist")
      check(search.activeFocus, "Search receives initial focus")
      equal(pulse.pinnedSymbol,"KC=F")
      equal(pulse.customBarLabel,"Café")
      equal(pulse.configuredRefreshInterval,120)
      check(list.height / (Style.space(47) + Style.space(2)) >= 6, "Six full rows visible: " + list.height / (Style.space(47)+Style.space(2)))
      search.text = "café"
      wait(50)
      equal(list.count,1)
      keyClick(Qt.Key_Down)
      check(list.activeFocus,"Arrow down enters list")
      keyClick(Qt.Key_Return)
      equal(pulse.inspectedSymbol,"KC=F")
      search.text = "ouro"
      search.forceActiveFocus()
      wait(50)
      keyClick(Qt.Key_Down)
      keyClick(Qt.Key_Return)
      equal(pulse.inspectedSymbol,"GC=F")
      equal(pulse.pinnedSymbol,"KC=F", "Inspection preserves bar")
      keyClick(Qt.Key_Space)
      check(pulse.favorites.indexOf("GC=F")>=0, "Space adds favorite")
      control("pinButton").forceActiveFocus()
      keyClick(Qt.Key_Return)
      equal(harness.saved.instrumentSymbol,"GC=F")
      equal(harness.saved.customSymbol,"BTC-USD")
      equal(harness.saved.barLabel,"Café")
      keyClick(Qt.Key_F,Qt.ControlModifier)
      check(search.activeFocus,"Ctrl+F focuses search")
      keyClick(Qt.Key_Tab)
      check(!search.activeFocus,"Tab moves to another control")
      equal(pulse.opened,true,"Tab does not switch panel")
      pulse.preferencesOpen=true
      control("customSymbolField").text="INVALID!"
      pulse.validateCustom()
      equal(harness.saved.instrumentSymbol,"GC=F")
      check(pulse.notice.indexOf("válido")>=0)
      control("customSymbolField").text="BAD"
      pulse.validateCustom()
      tryCompare(pulse,"validatingSymbol","",10000)
      check(pulse.customSymbols.indexOf("BAD")<0,"Failed validation does not save symbol")
      equal(pulse.pinnedSymbol,"GC=F")
      control("customSymbolField").text="ETH-USD"
      pulse.validateCustom()
      tryCompare(pulse,"validatingSymbol","",10000)
      check(pulse.favorites.indexOf("ETH-USD")>=0,"Valid custom persists as favorite")
      equal(pulse.pinnedSymbol,"GC=F","Adding a custom does not pin")
      harness.allowWrites=false
      pulse.pinInspected()
      equal(pulse.pinnedSymbol,"GC=F","Rejected save preserves pin")
      harness.allowWrites=true
      wait(100)
      disk.reload()
      var restored=JSON.parse(disk.text())
      check(restored.favorites.indexOf("ETH-USD")>=0,"Favorites round-trip through disk")
      equal(restored.barLabel,"Café")
      equal(restored.refreshIntervalSec,120)
      pulse.preferencesOpen=false
      search.text=""
      pulse.setFilter("commodities")
      pulse.inspect("KC=F")
      pulse.pinInspected()
      pulse.notice=""
      seed()
      control("detailsButton").forceActiveFocus()
      keyClick(Qt.Key_Return)
      wait(50)
      keyClick(Qt.Key_Escape)
      check(pulse.opened,"Escape first dismisses details")
      search.forceActiveFocus()
      keyClick(Qt.Key_Escape)
      check(!pulse.opened,"Escape closes panel")
      pulse.open()
      timeoutService.applySnapshot(JSON.stringify({quotes:[{symbol:"TIMEOUT",price:42,timestamp:1000}],fetchedAt:2000}))
      timeoutService.refreshSymbols(["FIRST","TIMEOUT"])
      wait(100)
      for(var i=0;i<100;i++) timeoutService.refreshSymbols(["FIRST","TIMEOUT"])
      equal(timeoutService._pendingSymbols.length,0,"Repeated refresh does not grow queue")
      check(timeoutService._activeSymbols.length<=4,"At most four active symbols")
      tryCompare(timeoutService,"refreshing",false,15000)
      equal(timeoutService.quoteFor("FIRST").price,100.12,"Completed result survives timeout")
      equal(timeoutService.quoteFor("TIMEOUT").price,42,"Timed-out symbol preserves previous price")
      check(!!timeoutService.quoteFor("TIMEOUT").error,"Timed-out symbol has an explicit error")
      console.log("NATIVE_CHECKS_PASSED")
      if (!Quickshell.env("MARKET_PULSE_KEEP_PREVIEW")) Qt.quit()
    }
  }
  Timer { interval: 300; running: true; onTriggered: { try { tests.runChecks() } catch(e) { console.error("NATIVE_CHECKS_FAILED", String(e)); Qt.quit() } } }
  IpcHandler {
    target: "preview"
    function state(): string { var list=tests.control("watchlist"); var panel=tests.control("panel"); return JSON.stringify({pinned:pulse.pinnedSymbol,inspected:pulse.inspectedSymbol,settings:harness.saved,rows:list.count,rowHeight:list.height/49,width:panel.contentWidth,height:panel.contentHeight,x:panel.cardOrigin.x,y:panel.cardOrigin.y,focus:panel.activeFocusItem ? panel.activeFocusItem.objectName : ""}) }
    function theme(light: bool): void { Color.shellValues=({"popups.background":light?"#ffffff":"#161b22","popups.text":light?"#20252c":"#eef2f6","popups.border":light?"#59636e":"#8693a0"}); tests.seed() }
    function scale(value: int): void { Style.fontBaseSize=value; Style.spacingScale=1; Style.fontOverrides=({}); }
    function preferences(): void { pulse.preferencesOpen=true }
    function size(width: int, height: int): void { tests.control("panel").contentWidth=width;tests.control("panel").contentHeight=height }
    function capture(path: string): void { tests.control("scope").grabToImage(function(result){result.saveToFile(path)}) }
    function quit(): void { Qt.quit() }
  }
}
