#!/usr/bin/env node
'use strict';
/**
 * Unit-ish checks for resolve_object_edit_payment logic (mirrors C++).
 * Also sanity-check m_immune UI classification.
 */
const kObjEditRunePerMegaXp = 1000000;

function resolve_object_edit_payment(pay_xp, pay_rune, quote_xp, quote_pq) {
  if (pay_xp < 0 || pay_rune < 0) return { ok: false, err: 'invalid' };
  const quote_xp_i = Math.max(0, quote_xp);
  const pq = Math.max(0, quote_pq);
  if (pay_rune < pq) return { ok: false, err: 'pq' };
  const rune_cover_xp = (pay_rune - pq) * kObjEditRunePerMegaXp;
  const covered = pay_xp + rune_cover_xp;
  if (covered < quote_xp_i) return { ok: false, err: 'underpay' };
  return { ok: true, xp_cost: pay_xp, rune_cost: pay_rune };
}

function isYesNoObjectEntry(entry) {
  const kind = entry?.kind || '';
  return kind === 'immune' || kind === 'm_immune' || kind === 'flag' || kind === 'spell';
}

const fails = [];
const ok = (name, cond, detail) => {
  if (!cond) fails.push(`${name}: ${detail}`);
  else console.log('OK', name);
};

// Old bug: max(pay_xp, quote) forced XP even when paying runes
const blunt = 300 * 1000000; // 300 MXP after mult example
const oldXpCost = Math.max(0, blunt);
ok('old-bug-would-charge-xp', oldXpCost === blunt, String(oldXpCost));

const runeOnly = resolve_object_edit_payment(0, 300, blunt, 0);
ok('rune-only-ok', runeOnly.ok && runeOnly.xp_cost === 0 && runeOnly.rune_cost === 300, JSON.stringify(runeOnly));

const under = resolve_object_edit_payment(0, 100, blunt, 0);
ok('rune-underpay', !under.ok, JSON.stringify(under));

const mix = resolve_object_edit_payment(100 * 1000000, 200, blunt, 0);
ok('mix-ok', mix.ok && mix.xp_cost === 100000000 && mix.rune_cost === 200, JSON.stringify(mix));

const mxpOnly = resolve_object_edit_payment(blunt, 0, blunt, 0);
ok('mxp-only', mxpOnly.ok && mxpOnly.xp_cost === blunt, JSON.stringify(mxpOnly));

ok('m_immune-yesno', isYesNoObjectEntry({ kind: 'm_immune' }), 'm_immune');
ok('immune-yesno', isYesNoObjectEntry({ kind: 'immune' }), 'immune');
ok('scalar-not', !isYesNoObjectEntry({ kind: 'scalar' }), 'scalar');

if (fails.length) {
  console.error('FAILS\n' + fails.join('\n'));
  process.exit(1);
}
console.log('all payment/immune checks passed');
