const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const path = require('node:path');
function load(file) { const ctx = {}; vm.createContext(ctx); vm.runInContext(fs.readFileSync(path.join(__dirname, '..', file), 'utf8').replace('.pragma library', ''), ctx); return ctx; }
const state = load('QuoteState.js'), catalog = load('MarketCatalog.js');
let q = state.merge({}, {quotes:[{symbol:'A',price:11,timestamp:1000}], fetchedAt:5000});
assert.match(state.status(q.A,5000), /Stale quote/);
q = state.merge(q,{errors:[{symbol:'A',message:'offline'},{symbol:'B',message:'offline'}],fetchedAt:6000});
assert.equal(q.A.price,11); assert.equal(q.A.timestamp,1000); assert.equal(q.A.lastSuccessAt,5000);
assert.equal(q.B.price,null); assert.match(state.status(q.B,6000), /Unavailable/);
q = state.merge(q,{quotes:[{symbol:'A',price:12,timestamp:5900}],fetchedAt:6000});
assert.equal(q.A.error,''); assert.equal(q.B.error,'offline');
assert.equal(state.session(q.A),'Session not provided');
assert.equal(state.session({marketState:'CLOSED'}),'Market closed');
for (const query of ['café','cafe','KC=F']) assert(catalog.matches(catalog.findInstrument('KC=F',[]),query));
assert(catalog.matches(catalog.findInstrument('PETR4.SA',[]),'petrobras'));
assert.equal(catalog.findInstrument('GC=F',[]).unit,'USD/oz');
assert.equal(catalog.allInstruments(['BTC-USD','BTC-USD']).filter(i => i.symbol==='BTC-USD').length,1);
console.log('State/catalog regressions passed');
