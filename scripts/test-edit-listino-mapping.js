#!/usr/bin/env node
'use strict';
/**
 * Mapping edit_listino (listino unico Server) <-> campi storici del portale
 * (listino_affect / listino_pool). Nessun DB: solo funzioni pure.
 * Atteso: stessi raw del vecchio listino_seed.inc v2 per le voci comuni.
 */
const store = require('../edit-portal/lib/listino-store');

const rules = {
  malus_mult: { num: 2, den: 1 },
  artifact_cost_xp: { num: 100000000, den: 1 },
  class_mult_1: { num: 1, den: 1 },
  class_mult_2: { num: 3, den: 2 },
  class_mult_3: { num: 2, den: 1 },
};
const row = (o) => ({ rune_den: 1, sign: 1, step: 1, buy_step: 1, enabled: 1, on_obj: 1, on_pc: 0, cap_pc: 0, cap_group: '', apply_bit: '0', ...o });

const fails = [];
const eq = (name, got, exp) => {
  const g = JSON.stringify(got);
  const e = JSON.stringify(exp);
  if (g !== e) fails.push(`${name}: ${g} != ${e}`);
  else console.log('OK', name);
};

// Affect: stessi raw del vecchio seed (pos/neg) + step/min/max storici.
const str = store.toPortalView(row({ code: 'str', xp: 15000000, rune_num: 15, cap_obj: 3, apply_loc: 1 }), rules);
eq('str', [str.kind, str.id, str.step, str.min_total, str.max_total, str.pos_unit_raw, str.neg_unit_raw, str.rune_num, str.rune_den], ['affect', 'str', 1, 0, 3, 1500, 3000, 15, 1]);
const ac = store.toPortalView(row({ code: 'ac', xp: 10000000, rune_num: 15, sign: -1, step: 10, cap_obj: 40, apply_loc: 17 }), rules);
eq('ac', [ac.id, ac.step, ac.min_total, ac.max_total, ac.pos_unit_raw, ac.neg_unit_raw, ac.rune_num, ac.rune_den], ['armor', -10, -40, 0, 100, 200, 3, 2]);
const dam = store.toPortalView(row({ code: 'damroll', xp: 100000000, rune_num: 120, cap_obj: 2, cap_pc: 30, cap_group: 'dam_sp', apply_loc: 19 }), rules);
eq('damroll', [dam.pos_unit_raw, dam.neg_unit_raw, dam.cap_group, dam.max_total], [10000, 20000, 'dam_sp', 2]);
const hnd = store.toPortalView(row({ code: 'hitndam', xp: 145000000, rune_num: 170, cap_obj: 2, apply_loc: 40 }), rules);
eq('hitndam', [hnd.pos_unit_raw, hnd.neg_unit_raw], [14500, 29000]);

// Pool.
const hit = store.toPortalView(row({ code: 'hit', xp: 3000000, rune_num: 3, on_obj: 0, on_pc: 1, cap_pc: 100, apply_loc: 13, buy_step: 10 }), rules);
eq('hit', [hit.kind, hit.pool_field, hit.cap, hit.xp_per_unit, hit.enabled, hit.step], ['pool', 'hit', 100, 3000000, true, 10]);
const off = store.toPortalView(row({ code: 'str', xp: 15000000, apply_loc: 1, enabled: 0 }), rules);
eq('enabled-column-off', off.enabled, false);
const con = store.toPortalView(row({ code: 'con', xp: 0, on_obj: 0, apply_loc: 5 }), rules);
eq('con-disabled', con.enabled, false);
const art = store.toPortalView(row({ code: 'artifact', xp: 100000000, apply_loc: 0, apply_bit: '262144' }), rules);
eq('artifact-flag', art.kind, 'flag');

// Scrittura stile portale -> colonne edit_listino (riga nuova).
const n1 = store.normalizeItem({ id: 'armor', label: 'AC', location: 17, step: -10, min_total: -40, max_total: 0, pos_unit_raw: 100 }, null);
eq('portal->ac', [n1.code, n1.fields.apply_loc, n1.fields.step, n1.fields.sign, n1.fields.cap_obj, n1.fields.xp, n1.fields.on_obj], ['ac', 17, 10, -1, 40, 10000000, 0]);
const n2 = store.normalizeItem({ code: 'saving_spell', label: 'Saving spell', apply_loc: 12 + 13, xp: 5000000, rune_num: 6, cap_obj: 2, on_obj: 1 }, null);
eq('native-new', [n2.fields.category, n2.fields.step, n2.fields.sign, n2.fields.rune_den, n2.fields.cap_group], ['custom', 1, 1, 1, '']);
const n3 = store.normalizeItem({ code: 'ac', step: 10 }, { code: 'ac', step: 10, sign: -1, apply_loc: 17 });
eq('update-keeps-sign', [n3.fields.step, n3.fields.sign], [10, undefined]);
const n4 = store.normalizeItem({ code: 'hit', enabled: false }, { code: 'hit', apply_loc: 13, on_pc: 1, enabled: 1 });
eq('disable-via-enabled', [n4.fields.enabled, n4.fields.on_pc], [0, undefined]);
const n5 = store.normalizeItem({ code: 'spellfail_obj', label: 'Spellfail oggetto', apply_loc: 41, enabled: 1, on_obj: 1, on_pc: 1 }, null);
eq('new-always-off', [n5.fields.enabled, n5.fields.on_obj, n5.fields.on_pc], [0, 0, 0]);
// Supporto MUD: myst vince, poi colonna mud_supported, altrimenti ignoto.
eq('mud-myst', store.mudSupportFor({ code: 'x' }, { x: { supported: false, reason: 'r' } }).supported, false);
eq('mud-column', store.mudSupportFor({ code: 'x', mud_supported: 1 }, null).supported, true);
eq('mud-myst-ok-server-no', store.mudSupportFor({ code: 'x', mud_supported: 0 }, { x: { supported: true } }, true).supported, false);
eq('mud-myst-ok-column-unused', store.mudSupportFor({ code: 'x', mud_supported: 0 }, { x: { supported: true } }, false).supported, true);
eq('mud-unknown', store.mudSupportFor({ code: 'x' }, null).supported, null);
let threw = false;
try { store.normalizeItem({ code: 'Bad Code!', label: 'x' }, null); } catch { threw = true; }
eq('reject-bad-code', threw, true);

// Artifact: 100M x moltiplicatore classi (class_mult_1/2/3), come EditArtifactFlagListinoCost.
const cm = (n) => rules[`class_mult_${Math.min(3, Math.max(1, n))}`];
const artXp = (n) => Math.round((rules.artifact_cost_xp.num / rules.artifact_cost_xp.den) * (cm(n).num / cm(n).den));
eq('artifact-mono-bi-tri', [artXp(1), artXp(2), artXp(3)], [100000000, 150000000, 200000000]);

// Rune listino parallele (slider): CHR artifact mono, 22.5M o 15 rune; 40% rune.
const quoteXp = 22500000;
const runeAlt = Math.ceil((quoteXp * 10) / 15000000); // stesso rapporto di object_listino_rune_for_quote
const pct = 40;
const payXp = Math.ceil((quoteXp * (100 - pct)) / 100);
const payRune = Math.ceil((runeAlt * pct) / 100);
eq('chr-rune-alt', runeAlt, 15);
eq('chr-mix-covers', payXp / quoteXp + payRune / runeAlt >= 1, true);
// Resistenze a bit: immune_fire 100M XP oppure 120 rune; slider misto come le stat.
const fire = store.toPortalView(row({
  code: 'immune_fire', category: 'resist_bit', xp: 100000000, rune_num: 120,
  apply_loc: 22, apply_bit: '1', resist_equiv: 50, resist_code: 'resist_fire',
}), rules);
eq('immune_fire-kind', fire.kind, 'bit');
eq('immune_fire-xp-rune', [fire.pos_unit_raw, fire.xp_per_unit, fire.rune_num, fire.rune_den], [10000, 100000000, 120, 1]);
const fireQuote = 100000000;
const fireRune = Math.ceil((fireQuote * fire.rune_num) / (fire.rune_den * fire.xp_per_unit));
eq('immune_fire-rune-alt', fireRune, 120);
const firePct = 40;
const firePayXp = Math.ceil((fireQuote * (100 - firePct)) / 100);
const firePayRune = Math.ceil((fireRune * firePct) / 100);
eq('immune_fire-mix-covers', firePayXp / fireQuote + firePayRune / fireRune >= 1, true);
const fireArt = 150000000; // artifact_mult 3/2, stesso rapporto
eq('immune_fire-artifact-rune', Math.ceil((fireArt * 120) / 100000000), 180);
// Editpool: match esatto col resolver (divisione intera su xp e pq).
const poolXp = 22500000, poolPq = 22;
eq('pool-mix-50', [Math.floor((poolXp * 50) / 100), Math.floor((poolPq * 50) / 100)], [11250000, 11]);

if (fails.length) {
  console.error(fails.join('\n'));
  process.exit(1);
}
console.log('edit_listino mapping OK');
