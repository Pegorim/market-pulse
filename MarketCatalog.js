.pragma library

var markets = [
  {
    id: "us",
    label: "United States",
    description: "Indexes and large-cap stocks",
    defaultSymbol: "^GSPC",
    instruments: [
      { symbol: "^GSPC", label: "S&P 500 Index", shortLabel: "S&P 500", kind: "Index" },
      { symbol: "^IXIC", label: "Nasdaq Composite", shortLabel: "Nasdaq", kind: "Index" },
      { symbol: "^DJI", label: "Dow Jones Industrial Average", shortLabel: "Dow", kind: "Index" },
      { symbol: "^RUT", label: "Russell 2000", shortLabel: "Russell", kind: "Index" },
      { symbol: "AAPL", label: "Apple", shortLabel: "AAPL", kind: "Stock" },
      { symbol: "MSFT", label: "Microsoft", shortLabel: "MSFT", kind: "Stock" },
      { symbol: "NVDA", label: "NVIDIA", shortLabel: "NVDA", kind: "Stock" },
      { symbol: "AMZN", label: "Amazon", shortLabel: "AMZN", kind: "Stock" },
      { symbol: "GOOGL", label: "Alphabet", shortLabel: "GOOGL", kind: "Stock" },
      { symbol: "META", label: "Meta Platforms", shortLabel: "META", kind: "Stock" },
      { symbol: "TSLA", label: "Tesla", shortLabel: "TSLA", kind: "Stock" }
    ]
  },
  {
    id: "futures",
    label: "US Futures",
    description: "Equity, energy, and metals futures",
    defaultSymbol: "ES=F",
    instruments: [
      { symbol: "ES=F", label: "E-mini S&P 500", shortLabel: "ES", kind: "Future" },
      { symbol: "NQ=F", label: "E-mini Nasdaq 100", shortLabel: "NQ", kind: "Future" },
      { symbol: "YM=F", label: "E-mini Dow", shortLabel: "YM", kind: "Future" },
      { symbol: "RTY=F", label: "E-mini Russell 2000", shortLabel: "RTY", kind: "Future" },
      { symbol: "CL=F", label: "Crude Oil", shortLabel: "Oil", kind: "Future" },
      { symbol: "GC=F", label: "Gold", shortLabel: "Gold", kind: "Future" },
      { symbol: "SI=F", label: "Silver", shortLabel: "Silver", kind: "Future" },
      { symbol: "HG=F", label: "Copper", shortLabel: "Copper", kind: "Future" }
    ]
  },
  {
    id: "brazil",
    label: "Brazil",
    description: "IBOV and leading B3 stocks",
    defaultSymbol: "^BVSP",
    instruments: [
      { symbol: "^BVSP", label: "Ibovespa Index", shortLabel: "IBOV", kind: "Index" },
      { symbol: "PETR4.SA", label: "Petrobras PN", shortLabel: "PETR4", kind: "Stock" },
      { symbol: "VALE3.SA", label: "Vale", shortLabel: "VALE3", kind: "Stock" },
      { symbol: "ITUB4.SA", label: "Itaú Unibanco PN", shortLabel: "ITUB4", kind: "Stock" },
      { symbol: "BBDC4.SA", label: "Bradesco PN", shortLabel: "BBDC4", kind: "Stock" }
    ]
  },
  {
    id: "europe",
    label: "Europe",
    description: "Major European equity indexes",
    defaultSymbol: "^STOXX50E",
    instruments: [
      { symbol: "^STOXX50E", label: "Euro Stoxx 50", shortLabel: "Stoxx 50", kind: "Index" },
      { symbol: "^FTSE", label: "FTSE 100", shortLabel: "FTSE", kind: "Index" },
      { symbol: "^GDAXI", label: "DAX", shortLabel: "DAX", kind: "Index" },
      { symbol: "^FCHI", label: "CAC 40", shortLabel: "CAC 40", kind: "Index" }
    ]
  },
  {
    id: "asia",
    label: "Asia",
    description: "Major Asian equity indexes",
    defaultSymbol: "^N225",
    instruments: [
      { symbol: "^N225", label: "Nikkei 225", shortLabel: "Nikkei", kind: "Index" },
      { symbol: "^HSI", label: "Hang Seng", shortLabel: "Hang Seng", kind: "Index" },
      { symbol: "000001.SS", label: "Shanghai Composite", shortLabel: "Shanghai", kind: "Index" },
      { symbol: "^KS11", label: "KOSPI Composite", shortLabel: "KOSPI", kind: "Index" }
    ]
  },
  {
    id: "commodities",
    label: "Commodities",
    description: "Energy, metals, grains, softs, and livestock",
    defaultSymbol: "GC=F",
    instruments: [
      { symbol: "GC=F", label: "Gold", shortLabel: "Gold", kind: "Metal", unit: "USD/oz" },
      { symbol: "SI=F", label: "Silver", shortLabel: "Silver", kind: "Metal", unit: "USD/oz" },
      { symbol: "HG=F", label: "Copper", shortLabel: "Copper", kind: "Metal", unit: "USD/lb" },
      { symbol: "PL=F", label: "Platinum", shortLabel: "Platinum", kind: "Metal", unit: "USD/oz" },
      { symbol: "PA=F", label: "Palladium", shortLabel: "Palladium", kind: "Metal", unit: "USD/oz" },
      { symbol: "BHP", label: "Iron Ore Exposure (BHP proxy)", shortLabel: "Iron proxy", kind: "Equity proxy", unit: "USD/share" },
      { symbol: "CL=F", label: "WTI Crude Oil", shortLabel: "WTI Oil", kind: "Energy", unit: "USD/barrel" },
      { symbol: "BZ=F", label: "Brent Crude Oil", shortLabel: "Brent", kind: "Energy", unit: "USD/barrel" },
      { symbol: "NG=F", label: "Natural Gas", shortLabel: "Nat Gas", kind: "Energy", unit: "USD/MMBtu" },
      { symbol: "KC=F", label: "Coffee", shortLabel: "Coffee", kind: "Soft", unit: "US¢/lb" },
      { symbol: "SB=F", label: "Sugar No. 11", shortLabel: "Sugar", kind: "Soft", unit: "US¢/lb" },
      { symbol: "CC=F", label: "Cocoa", shortLabel: "Cocoa", kind: "Soft", unit: "USD/metric ton" },
      { symbol: "CT=F", label: "Cotton No. 2", shortLabel: "Cotton", kind: "Soft", unit: "US¢/lb" },
      { symbol: "OJ=F", label: "Orange Juice", shortLabel: "Orange Juice", kind: "Soft", unit: "US¢/lb" },
      { symbol: "ZC=F", label: "Corn", shortLabel: "Corn", kind: "Grain", unit: "US¢/bushel" },
      { symbol: "ZW=F", label: "Wheat", shortLabel: "Wheat", kind: "Grain", unit: "US¢/bushel" },
      { symbol: "ZS=F", label: "Soybeans", shortLabel: "Soybeans", kind: "Grain", unit: "US¢/bushel" },
      { symbol: "LE=F", label: "Live Cattle", shortLabel: "Live Cattle", kind: "Livestock", unit: "US¢/lb" },
      { symbol: "GF=F", label: "Feeder Cattle", shortLabel: "Feeder Cattle", kind: "Livestock", unit: "US¢/lb" },
      { symbol: "HE=F", label: "Lean Hogs", shortLabel: "Lean Hogs", kind: "Livestock", unit: "US¢/lb" },
      { symbol: "LBR=F", label: "Lumber", shortLabel: "Lumber", kind: "Forest product", unit: "USD/1,000 board ft" }
    ]
  }
]

function marketById(id) {
  for (var i = 0; i < markets.length; i++) {
    if (markets[i].id === id) return markets[i]
  }
  return markets[0]
}

function normalizedMarketId(id) {
  return marketById(String(id || "")).id
}

function instrumentBySymbol(marketId, symbol) {
  var market = marketById(marketId)
  for (var i = 0; i < market.instruments.length; i++) {
    if (market.instruments[i].symbol === symbol) return market.instruments[i]
  }
  return market.instruments[0]
}

function hasInstrument(marketId, symbol) {
  var market = marketById(marketId)
  for (var i = 0; i < market.instruments.length; i++) {
    if (market.instruments[i].symbol === symbol) return true
  }
  return false
}

function normalizedSymbol(marketId, symbol) {
  var market = marketById(marketId)
  var instrument = instrumentBySymbol(market.id, String(symbol || ""))
  return instrument ? instrument.symbol : market.defaultSymbol
}

function marketOptions() {
  var result = []
  for (var i = 0; i < markets.length; i++) {
    result.push({
      value: markets[i].id,
      label: markets[i].label,
      description: markets[i].description
    })
  }
  return result
}

function instrumentOptions(marketId) {
  var market = marketById(marketId)
  var result = []
  for (var i = 0; i < market.instruments.length; i++) {
    var item = market.instruments[i]
    result.push({
      value: item.symbol,
      label: item.label,
      description: item.symbol + " · " + item.kind
    })
  }
  return result
}

function symbolsForMarket(marketId) {
  var market = marketById(marketId)
  var result = []
  for (var i = 0; i < market.instruments.length; i++) result.push(market.instruments[i].symbol)
  return result
}

function allInstruments(customSymbols) {
  var result = [], seen = {}
  // Commodity units override generic futures metadata, while first position stays stable.
  markets.forEach(function(market) {
    market.instruments.forEach(function(item) {
      var entry = Object.assign({}, item, {marketId: market.id})
      if (seen[item.symbol] !== undefined) {
        if (item.unit) result[seen[item.symbol]] = entry
      } else { seen[item.symbol] = result.length; result.push(entry) }
    })
  })
  ;(customSymbols || []).forEach(function(symbol) {
    if (seen[symbol] === undefined) {
      seen[symbol] = result.length
      result.push({symbol: symbol, label: symbol, shortLabel: symbol, kind: "Custom", marketId: "custom"})
    }
  })
  return result
}
function findInstrument(symbol, customSymbols) {
  var all = allInstruments(customSymbols)
  return all.filter(function(item) { return item.symbol === symbol })[0]
    || {symbol: symbol, label: symbol, shortLabel: symbol, kind: "Custom", marketId: "custom"}
}
function searchable(value) {
  return String(value || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")
}
function matches(item, query) {
  var aliases = {"KC=F": "cafe café", "GC=F": "ouro", "SI=F": "prata", "CL=F": "petroleo petróleo", "ZC=F": "milho", "ZS=F": "soja", "ZW=F": "trigo", "SB=F": "acucar açúcar", "BHP": "minerio minério ferro proxy"}
  return searchable(item.symbol + " " + item.label + " " + (aliases[item.symbol] || "")).indexOf(searchable(query)) >= 0
}
