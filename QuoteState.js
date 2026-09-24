.pragma library

function copy(value) { return JSON.parse(JSON.stringify(value || {})) }
function merge(previous, snapshot) {
  var next = copy(previous)
  var now = Number(snapshot.fetchedAt || 0)
  ;(snapshot.quotes || []).forEach(function(q) {
    if (!q || !q.symbol || q.price === null || !isFinite(q.price)) return
    next[q.symbol] = Object.assign({}, q, {error: "", stale: false,
      fetchedAt: Number(q.fetchedAt || now), lastSuccessAt: Number(q.lastSuccessAt || now)})
  })
  ;(snapshot.errors || []).forEach(function(e) {
    if (!e.symbol) return
    next[e.symbol] = Object.assign({}, next[e.symbol] || {symbol: e.symbol, price: null, timestamp: 0},
      {error: String(e.message || "Quote unavailable"), stale: true, fetchedAt: now})
  })
  return next
}
function status(q, now) {
  if (!q) return "Waiting for quote"
  if (q.price === null || q.price === undefined) return "Unavailable · try refreshing"
  if (q.error) return "Request failed · last value preserved"
  if (!q.timestamp) return "Quote time not provided"
  var age = Math.max(0, now - q.timestamp)
  if (age > 900) return "Stale quote · " + (age < 3600 ? Math.floor(age / 60) + " min" : age < 86400 ? Math.floor(age / 3600) + " h" : Math.floor(age / 86400) + " d") + " ago"
  if (Number(q.dataDelayMinutes) > 0) return "Reported delay: " + q.dataDelayMinutes + " min"
  return "Quote " + Math.floor(age / 60) + " min ago · may be delayed"
}
function session(q) {
  var states = {REGULAR: "Regular session", PRE: "Pre-market", POST: "After-hours", CLOSED: "Market closed", PREPRE: "Pre-market", POSTPOST: "After-hours"}
  return states[q && q.marketState] || "Session not provided"
}
function unique(values) {
  return (Array.isArray(values) ? values : []).filter(function(v, i, all) { return typeof v === "string" && v !== "" && all.indexOf(v) === i })
}
