# Riferimento mondo di produzione (per agenti e patch)

Il mondo **live** non è in git. Gli stub in root (`myst.obj`, …) e quelli in
`mudroot/lib/` su clone freschi **non** riflettono la produzione.

## Cosa usare come riferimento

| Priorità | Percorso | Chi lo vede |
|----------|----------|-------------|
| 1 | `world-reference/snippets/` | Tutti (commit in git, estratti piccoli) |
| 2 | `mudroot/lib/myst.*` sulla tua macchina | Agent locale / Cloud con copia |
| 3 | `world-reference/production/` (opzionale) | Solo locale, gitignored |

## Setup sulla tua macchina (una tantum)

Hai già il mondo buono in `mudroot/lib/`. Da root del repo:

```bash
# 1) Estratti committabili (vnum, zone Spanky/Flasite, conflitti 18500-18505)
./scripts/export-production-world-reference.sh

# 2) Opzionale: copia completa per agent che lavorano in locale
./scripts/export-production-world-reference.sh --full-copy

# 3) Commit degli snippet (NON committare production/)
git add world-reference/snippets/
git commit -m "Update production world reference snippets"
git push
```

Dopo il push, **ogni agent** (anche Cloud) può leggere `world-reference/snippets/`
senza avere i file myst completi.

## Aggiornare quando cambia la produzione

Dopo aver copiato un nuovo backup in `mudroot/lib/`:

```bash
./scripts/export-production-world-reference.sh
git add world-reference/snippets/
git commit -m "Refresh world reference after production update"
```

## Per Cursor Cloud Agents

Nel dashboard Cursor → Cloud Agent → variabili ambiente (opzionale):

```bash
MYST_WORLD_SRC=/path/al/backup/produzione
```

Lo script `scripts/cursor-cloud-agent-install.sh` copierà il mondo in
`mudroot/lib/` all’avvio dell’agent. In ogni caso, **`world-reference/snippets/`**
resta la fonte più affidabile per vnum e ancore zone.

## Regole per chi patcha il mondo

1. **Non** assumere che 18500–18505 siano liberi: leggi
   `snippets/obj-thief-vnum-window.txt` e `snippets/vnum-suggestions.txt`.
2. **Non** usare gli stub in root per scegliere vnum.
3. Se i vnum ladro devono cambiare, aggiornare anche `src/utils.hpp` (`THIEF_ING_*`)
   e i fragment in `world-patches/thief-crafting/`.
