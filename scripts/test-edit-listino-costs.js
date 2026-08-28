#!/usr/bin/env node
'use strict';
/**
 * Documenta i costi listino attesi (raw CheckValueObj × storage scale)
 * vs https://www.nebbiearcane.it/listino-edits/
 *
 * Regressione logica: se il quote clona solo il proto (bug clone_obj),
 * delta = cost(solo_nuovo) - cost(pezzo_gia_editato) → spesso 0 o sottostima.
 * Con clone completo: delta = cost(pezzo+nuovo) - cost(pezzo).
 */
const SCALE = 10000;

const LISTINO = {
  str: { unit: 1500, mxp: 15, rune: 15 },
  wis: { unit: 1500, mxp: 15, rune: 15 },
  int: { unit: 1500, mxp: 15, rune: 15 },
  dex: { unit: 1500, mxp: 15, rune: 15 },
  chr: { unit: 1500, mxp: 15, rune: 10 }, // rune diverse sul listino ufficiale
  con: { unit: 1500, mxp: 15, rune: 15 },
  armor_step: { unit: 100 * 10, mxp: 10, rune: 15 }, // −10 AC
  hitroll: { unit: 4500, mxp: 45, rune: 50 },
  damroll: { unit: 10000, mxp: 100, rune: 120 },
  acid: { unit: 7500, mxp: 75, rune: 90 },
  blunt: { unit: 30000, mxp: 300, rune: 400 },
  imm_drain: { unit: 10000, mxp: 100, rune: 100 },
  fire: { unit: 10000, mxp: 100, rune: 120 },
};

function mxpFromUnit(unit) {
  return (unit * SCALE) / 1e6;
}

/** Simula il bug: after=solo nuovo, before=gia' editato */
function buggyDelta(existingUnits, newUnit) {
  const before = existingUnits * SCALE;
  const after = newUnit * SCALE; // manca existing!
  return Math.max(0, after - before);
}

function fixedDelta(existingUnits, newUnit) {
  const before = existingUnits * SCALE;
  const after = (existingUnits + newUnit) * SCALE;
  return Math.max(0, after - before);
}

const fails = [];
const ok = (n, c, d) => {
  if (!c) fails.push(`${n}: ${d}`);
  else console.log('OK', n);
};

for (const [k, v] of Object.entries(LISTINO)) {
  ok(`${k}-mxp`, mxpFromUnit(v.unit) === v.mxp, `${mxpFromUnit(v.unit)} vs ${v.mxp}`);
}

// Pezzo gia' con Res Fire (100 MXP raw units 10000), aggiungi STR +1 (1500)
const fireUnits = 10000;
const strUnit = 1500;
ok(
  'buggy-str-after-fire-is-zero',
  buggyDelta(fireUnits, strUnit) === 0,
  String(buggyDelta(fireUnits, strUnit)),
);
ok(
  'fixed-str-after-fire-is-15mxp',
  fixedDelta(fireUnits, strUnit) === 15 * 1e6,
  String(fixedDelta(fireUnits, strUnit)),
);

// Armor −40 sul pezzo vuoto = 4 step
ok('armor-40', mxpFromUnit(100 * 40) === 40, String(mxpFromUnit(100 * 40)));

if (fails.length) {
  console.error('FAILS\n' + fails.join('\n'));
  process.exit(1);
}
console.log('listino coherence + clone-delta regression OK');
