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
  if (!q) return "Aguardando consulta"
  if (q.price === null || q.price === undefined) return "Indisponível · tente atualizar"
  if (q.error) return "Falha na consulta · último valor preservado"
  if (!q.timestamp) return "Horário da cotação não informado"
  var age = Math.max(0, now - q.timestamp)
  if (age > 900) return "Cotação antiga · há " + (age < 3600 ? Math.floor(age / 60) + " min" : age < 86400 ? Math.floor(age / 3600) + " h" : Math.floor(age / 86400) + " dias")
  if (Number(q.dataDelayMinutes) > 0) return "Atraso informado: " + q.dataDelayMinutes + " min"
  return "Cotação há " + Math.floor(age / 60) + " min · pode ter atraso"
}
function session(q) {
  var states = {REGULAR: "Sessão regular", PRE: "Pré-mercado", POST: "Pós-mercado", CLOSED: "Mercado fechado", PREPRE: "Pré-mercado", POSTPOST: "Pós-mercado"}
  return states[q && q.marketState] || "Sessão não informada"
}
function unique(values) {
  return (Array.isArray(values) ? values : []).filter(function(v, i, all) { return typeof v === "string" && v !== "" && all.indexOf(v) === i })
}
